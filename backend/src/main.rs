use std::f32::consts::PI;
use clap::{Args, Parser, Subcommand};
use serde::{Serialize};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::sync::Arc;
use hound;
use itertools::Itertools;
use rustfft::{Fft, FftPlanner};
use rustfft::num_complex::Complex;
use std::convert::TryFrom;

const WINDOW: usize = 2048;
const HOP: usize = 512;

#[derive(Parser)]
#[command(name = "CircleSiegeBackend")]
struct CLI {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    #[command(name = "analyze-wav")]
    AnalyzeWav(AnalyzeArgs),
}

#[derive(Args)]
struct AnalyzeArgs {
    #[arg(short, long)]
    input: String,
    #[arg(short, long)]
    output: String,
}


#[derive(Serialize)]
#[serde(tag = "type")]
enum Record {
    #[serde(rename = "meta")]
    Meta(MetaRecord),
    #[serde(rename = "energy")]
    Energy(EnergyRecord),
    #[serde(rename = "band")]
    Band(BandEnergies),
    #[serde(rename = "event")]
    Event(EventRecord),
    #[serde(rename= "done")]
    Done,
}

#[derive(Serialize)]
enum Bands {
    Low,
    Mid,
    High,
}

impl TryFrom<usize> for Bands {
    type Error = &'static str;

    fn try_from(value: usize) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Bands::Low),
            1 => Ok(Bands::Mid),
            2 => Ok(Bands::High),
            _ => Err("Value out of Bounds"),
        }
    }
}

#[derive(Serialize)]
struct EventRecord {
    t: f64,
    band: Bands,
    s: f32,
}

#[derive(Serialize)]
struct BandEnergies {
    t: f64,
    low: f32,
    mid: f32,
    high: f32,
}

#[derive(Serialize)]
struct MetaRecord {
    sr: u32,
    channels: u16,
    win: u32,
    hop: u32,
    duration: f64,
}

#[derive(Serialize)]
struct EnergyRecord {
    t: f64,
    e: f32
}

struct BandDetect {
    prev_smooth: f32,
    smooth: f32,
    mean: f32,
    dev: f32,
    refractory: usize,
}

const BAND_EMA: f32 = 0.25;
const ONSET_MEAN_EMA: f32 = 0.08;
const ONSET_DEV_EMA: f32 = 0.08;
const THRESH_K: f32 = 5.0;
const REFRACTORY_FRAMES: [usize; 3] = [10, 6, 3];

impl BandDetect {
    fn new() -> Self {
        BandDetect { prev_smooth: 0.0, smooth: 0.0, mean: 0.0, dev: 0.0, refractory: 0 }
    }
}

fn main() -> anyhow::Result<()> {
    let args = CLI::parse();
    match args.command {
        Commands::AnalyzeWav(params) => {
            let mut reader = hound::WavReader::open(&params.input).unwrap();
            let spec = reader.spec();

            let samples: Vec<f32> = reader
                .samples::<i16>()
                .chunks(spec.channels as usize)
                .into_iter()
                .map(|chunk| {
                    let mut sum: f32 = 0.0;
                    let mut count: f32 = 0.0;
                    for s in chunk {
                        if let Ok(sample) = s {
                            sum += sample as f32;
                            count += 1.0
                        }
                    }
                    (sum / count) / 37268.0
                })
                .collect();

            let hann: Vec<f32> = (0..WINDOW)
                .map(|i| {
                    0.5 - 0.5 * f32::cos(2.0 * PI * i as f32 / WINDOW as f32)
                })
                .collect();

            let fft: Arc<dyn Fft<f32>> = FftPlanner::new().plan_fft_forward(WINDOW);

            let bin_hz = spec.sample_rate as f32 / WINDOW as f32;
            let bands = [
                (20.0, 160.0),
                (160.0, 2000.0),
                (2000.0, 8000.0),
            ];

            let bins = bands.map(|(f_low, f_high)| ((f_low/bin_hz).round() as usize, (f_high/bin_hz).round() as usize));

            let mut records: Vec<Record> = Vec::new();

            let mut rms_max: f32 = 1e-6;
            let mut e_smooth: f32 = 0f32;

            let mut fft_in: Vec<Complex<f32>> = vec![Complex::new(0.0, 0.0); WINDOW];

            let mut band_detectors = [BandDetect::new(), BandDetect::new(), BandDetect::new()];

            let mut i = 0;
            while (HOP * i) + WINDOW < samples.len() {
                let start = i * HOP;
                let t = start as f64 / spec.sample_rate as f64;

                let rms = (samples[start..start+WINDOW].iter().map(|&x: &f32| x * x).sum::<f32>() / WINDOW as f32).sqrt();
                rms_max = rms.max(rms_max * 0.9995);

                let e_raw = (rms / (rms_max + 1e-6)).clamp(0.0, 1.0);
                e_smooth = e_smooth * 0.8 + e_raw * 0.2;

                // downsampling to prevent flooding buffer
                if i % 2 == 0 {
                    records.push(Record::Energy(EnergyRecord { t, e: e_smooth }));
                }

                fft_in.clear();
                fft_in.extend(
                    samples[start..start+WINDOW]
                        .iter()
                        .zip(hann.iter())
                        .map(|(&s, &h)| Complex::new(s*h, 0f32))
                );

                fft.process(&mut fft_in);

                let power_spectrum: Vec<f32> = fft_in[0..=WINDOW/2].iter().map(|c| c.norm_sqr()).collect();

                let energies: [f32; 3] = bins.map(|(lo, hi)| power_spectrum[lo..=hi].iter().sum::<f32>());

                records.push(
                    Record::Band(
                        BandEnergies {
                            t,
                            low: energies[0],
                            mid: energies[1],
                            high: energies[2]
                        }
                    )
                );

                for b in 0..3 {
                    let energy = energies[b];
                    let detector = &mut band_detectors[b];

                    detector.smooth = detector.smooth * (1.0 - BAND_EMA) + energy * BAND_EMA;

                    let onset = (detector.smooth - detector.prev_smooth).max(0.0);
                    detector.prev_smooth = detector.smooth;

                    detector.mean = detector.mean * (1.0 - ONSET_MEAN_EMA) + onset * ONSET_MEAN_EMA;
                    let abs_deviation = (onset - detector.mean).abs();
                    detector.dev = detector.dev * (1.0 - ONSET_DEV_EMA) + abs_deviation * ONSET_DEV_EMA;

                    detector.refractory = detector.refractory.saturating_sub(1);
                    if onset > detector.mean + THRESH_K * detector.dev && detector.refractory == 0 {
                        let strength = ((onset - (detector.mean + THRESH_K * detector.dev)) / (detector.mean + THRESH_K * detector.dev + 1e-8)).clamp(0.0, 1.0);

                        records.push(Record::Event(EventRecord {
                            t,
                            band: Bands::try_from(b).unwrap(),
                            s: strength,
                        }));

                        detector.refractory = REFRACTORY_FRAMES[b];
                    }
                }

                i += 1;
            }

            let file = File::create(&params.output)?;
            let mut w = BufWriter::new(file);

            let meta = Record::Meta(MetaRecord {
                sr: spec.sample_rate,
                channels: spec.channels,
                win: WINDOW as u32,
                hop: HOP as u32,
                duration: (reader.len() / spec.channels as u32) as f64 / spec.sample_rate as f64,
            });

            serde_json::to_writer(&mut w, &meta)?;
            w.write_all(b"\n")?;

            for record in &records {
                serde_json::to_writer(&mut w, record)?;
                w.write_all(b"\n")?;
            }

            serde_json::to_writer(&mut w, &Record::Done)?;
            w.write_all(b"\n")?;
        },
    }

    Ok(())
}
