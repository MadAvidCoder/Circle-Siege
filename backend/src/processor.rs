use crate::record::{BandEnergies, Bands, BeatRecord, EnergyRecord, EventRecord, Record, SpectrumRecord};
use crate::{BAND_EMA, BandDetect, HOP, ONSET_DEV_EMA, ONSET_MEAN_EMA, WINDOW};
use aubio::Tempo;
use rustfft::num_complex::Complex;
use rustfft::{Fft, FftPlanner};
use std::f32::consts::PI;
use std::sync::Arc;

pub struct ProcessorState {
    rms_max: f32,
    e_smooth: f32,
    fft_in: Vec<Complex<f32>>,
    band_detectors: [BandDetect; 3],
    fft: Arc<dyn Fft<f32>>,
    hann: Vec<f32>,
    tempo: Tempo,
    last_beat_time: f32,
    bins: [(usize, usize); 3],
    threshold: f32,
    refractory: Vec<u32>,
    pub time: f64,
}

impl ProcessorState {
    pub fn new(sample_rate: u32, threshold: f32, refractory: Vec<u32>) -> Self {
        let bin_hz = sample_rate as f32 / WINDOW as f32;
        let bands = [(20.0, 160.0), (160.0, 2000.0), (2000.0, 8000.0)];

        let bins = bands.map(|(f_low, f_high)| {
            (
                (f_low / bin_hz).round() as usize,
                (f_high / bin_hz).round() as usize,
            )
        });

        Self {
            rms_max: 1e-6,
            e_smooth: 0f32,
            fft_in: vec![Complex::new(0.0, 0.0); WINDOW],
            band_detectors: [BandDetect::new(), BandDetect::new(), BandDetect::new()],
            fft: FftPlanner::new().plan_fft_forward(WINDOW),
            hann: (0..WINDOW)
                .map(|i| 0.5 - 0.5 * f32::cos(2.0 * PI * i as f32 / WINDOW as f32))
                .collect(),
            tempo: Tempo::new(aubio::OnsetMode::SpecDiff, WINDOW, HOP, sample_rate).unwrap(),
            last_beat_time: -1.0,
            bins,
            threshold,
            refractory,
            time: 0f64,
        }
    }

    pub fn process(&mut self, samples: &[f32]) -> Vec<Record> {
        let mut records: Vec<Record> = Vec::new();

        let rms = (samples.iter().map(|&x: &f32| x * x).sum::<f32>() / WINDOW as f32).sqrt();
        self.rms_max = rms.max(self.rms_max * 0.9995);

        let e_raw = (rms / (self.rms_max + 1e-6)).clamp(0.0, 1.0);
        self.e_smooth = self.e_smooth * 0.8 + e_raw * 0.2;

        records.push(Record::Energy(EnergyRecord {
            t: self.time,
            e: self.e_smooth,
        }));

        self.fft_in.clear();
        self.fft_in.extend(
            samples
                .iter()
                .zip(self.hann.iter())
                .map(|(&s, &h)| Complex::new(s * h, 0f32)),
        );

        self.fft.process(&mut self.fft_in);

        let power_spectrum: Vec<f32> = self.fft_in[0..=WINDOW / 2]
            .iter()
            .map(|c| c.norm_sqr())
            .collect();

        records.push(Record::Spectrum(SpectrumRecord {
            t: self.time,
            bins: power_spectrum.clone(),
        }));

        let aubio_input = samples.to_vec();
        self.tempo.do_(&aubio_input, &mut [0.0f32; 1]).unwrap();
        let beat_t = self.tempo.get_last_s();

        if beat_t > self.last_beat_time + 1e-4 {
            records.push(Record::Beat(BeatRecord { t: beat_t as f64 }));
            self.last_beat_time = beat_t;
        }

        let energies: [f32; 3] = self
            .bins
            .map(|(lo, hi)| power_spectrum[lo..=hi].iter().sum::<f32>());

        // disabled for huge performance gain
        // records.push(
        //     Record::Band(
        //         BandEnergies {
        //             t: self.time,
        //             low: energies[0],
        //             mid: energies[1],
        //             high: energies[2]
        //         }
        //     )
        // );

        for b in 0..3 {
            let energy = energies[b];
            let detector = &mut self.band_detectors[b];

            detector.smooth = detector.smooth * (1.0 - BAND_EMA) + energy * BAND_EMA;

            let onset = (detector.smooth - detector.prev_smooth).max(0.0);
            detector.prev_smooth = detector.smooth;

            detector.mean = detector.mean * (1.0 - ONSET_MEAN_EMA) + onset * ONSET_MEAN_EMA;
            let abs_deviation = (onset - detector.mean).abs();
            detector.dev = detector.dev * (1.0 - ONSET_DEV_EMA) + abs_deviation * ONSET_DEV_EMA;

            detector.refractory = detector.refractory.saturating_sub(1);
            if onset > detector.mean + self.threshold * detector.dev && detector.refractory == 0 {
                let strength = ((onset - (detector.mean + self.threshold * detector.dev))
                    / (detector.mean + self.threshold * detector.dev + 1e-8))
                    .clamp(0.0, 1.0);

                records.push(Record::Event(EventRecord {
                    t: self.time,
                    band: Bands::try_from(b).unwrap(),
                    s: strength,
                }));

                detector.refractory = self.refractory[b] as usize;
            }
        }
        records
    }
}
