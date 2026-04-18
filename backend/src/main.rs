use std::f32::consts::PI;
use clap::{Args, Parser, Subcommand};
use serde::{Serialize};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::sync::Arc;
use rustfft::{Fft, FftPlanner};
use rustfft::num_complex::Complex;
use std::convert::TryFrom;
use std::path::Path;
use aubio;
use symphonia::core::audio::AudioBufferRef;
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::errors::Error;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::{MediaSourceStream, MediaSourceStreamOptions};
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::audio::Signal;

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
    #[arg(long)]
    threshold: f32,
    #[arg(long, num_args=3)]
    refractory: Vec<u32>,
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
    #[serde(rename = "spectrum")]
    Spectrum(SpectrumRecord),
    #[serde(rename  = "beat")]
    Beat(BeatRecord),
    #[serde(rename = "event")]
    Event(EventRecord),
    #[serde(rename= "done")]
    Done,
}

#[derive(Serialize)]
struct SpectrumRecord {
    t: f64,
    bins: Vec<f32>,
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
}

#[derive(Serialize)]
struct EnergyRecord {
    t: f64,
    e: f32
}

#[derive(Serialize)]
struct BeatRecord {
    t: f64,
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
// const THRESH_K: f32 = 5.0;
// const REFRACTORY_FRAMES: [usize; 3] = [10, 6, 3];

impl BandDetect {
    fn new() -> Self {
        BandDetect { prev_smooth: 0.0, smooth: 0.0, mean: 0.0, dev: 0.0, refractory: 0 }
    }
}

fn main() -> anyhow::Result<()> {
    let args = CLI::parse();
    match args.command {
        Commands::AnalyzeWav(params) => {
            let path = Path::new(&params.input);

            let file = Box::new(File::open(path).unwrap());
            let stream = MediaSourceStream::new(file, MediaSourceStreamOptions::default());

            let mut hint = Hint::new();
            if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
                hint.with_extension(ext);
            }

            let format_opts = FormatOptions::default();
            let metadata_opts = MetadataOptions::default();
            let decoder_opts = DecoderOptions::default();

            let probed = symphonia::default::get_probe()
                .format(&hint, stream, &format_opts, &metadata_opts)
                .expect("Format unsupported");

            let mut format = probed.format;

            let track = format
                .tracks()
                .iter()
                .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
                .expect("no supported audio tracks");
            let track_id = track.id;

            let mut decoder = symphonia::default::get_codecs()
                .make(&track.codec_params, &decoder_opts)
                .expect("unsupported codec");

            let mut samples: Vec<f32> = Vec::new();
            let mut sample_rate = 44100u32;
            let mut channels: u16 = 2;

            loop {
                let packet = match format.next_packet() {
                    Ok(packet) => packet,
                    Err(Error::IoError(err)) if err.kind() == std::io::ErrorKind::UnexpectedEof => {
                        break
                    },
                    Err(err) => return Err(err.into()),
                };

                if packet.track_id() != track_id { continue; }

                match decoder.decode(&packet) {
                    Ok(AudioBufferRef::F32(buf)) => {
                        sample_rate = buf.spec().rate as u32;
                        channels = buf.spec().channels.count() as u16;

                        for frame in 0..buf.frames() {
                            let mut sum = 0.0;
                            for ch in 0..channels as usize {
                                sum += buf.chan(ch)[frame];
                            }
                            samples.push(sum / channels as f32);
                        }
                    },
                    Ok(AudioBufferRef::U8(buf)) => {
                        sample_rate = buf.spec().rate as u32;
                        channels = buf.spec().channels.count() as u16;

                        for frame in 0..buf.frames() {
                            let mut sum = 0.0;
                            for ch in 0..channels as usize {
                                sum += buf.chan(ch)[frame] as f32 / 128.0 - 1.0;
                            }
                            samples.push(sum / channels as f32);
                        }
                    },
                    Ok(AudioBufferRef::U16(buf)) => {
                        sample_rate = buf.spec().rate as u32;
                        let channels = buf.spec().channels.count() as u16;

                        for frame in 0..buf.frames() {
                            let mut sum = 0.0;
                            for ch in 0..channels as usize {
                                sum += buf.chan(ch)[frame] as f32 / 32768.0 - 1.0;
                            }
                            samples.push(sum / channels as f32);
                        }
                    },
                    Ok(AudioBufferRef::S16(buf)) => {
                        sample_rate = buf.spec().rate as u32;
                        channels = buf.spec().channels.count() as u16;

                        for frame in 0..buf.frames() {
                            let mut sum = 0.0;
                            for ch in 0..channels as usize {
                                sum += buf.chan(ch)[frame] as f32 / 32768.0;
                            }
                            samples.push(sum / channels as f32);
                        }
                    },
                    Ok(AudioBufferRef::S32(buf)) => {
                        sample_rate = buf.spec().rate as u32;
                        let channels = buf.spec().channels.count() as u16;

                        for frame in 0..buf.frames() {
                            let mut sum = 0.0;
                            for ch in 0..channels as usize {
                                sum += buf.chan(ch)[frame] as f32 / 2147483648.0;
                            }
                            samples.push(sum / channels as f32);
                        }
                    },
                    Err(Error::DecodeError(_)) => continue,
                    _ => break,
                }
            }

            let mut tempo = aubio::Tempo::new(aubio::OnsetMode::SpecDiff, WINDOW, HOP, sample_rate)?;
            let mut last_beat_time = -1.0;

            let hann: Vec<f32> = (0..WINDOW)
                .map(|i| {
                    0.5 - 0.5 * f32::cos(2.0 * PI * i as f32 / WINDOW as f32)
                })
                .collect();

            let fft: Arc<dyn Fft<f32>> = FftPlanner::new().plan_fft_forward(WINDOW);

            let bin_hz = sample_rate as f32 / WINDOW as f32;
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
                let t = start as f64 / sample_rate as f64;

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

                records.push(
                    Record::Spectrum(
                        SpectrumRecord { t, bins: power_spectrum.clone() })
                );

                let aubio_input = samples[start..start+WINDOW].to_vec();
                tempo.do_(&aubio_input, &mut [0.0f32; 1]).unwrap();
                let beat_t = tempo.get_last_s();

                if beat_t > last_beat_time + 1e-4 {
                    records.push(Record::Beat(BeatRecord { t: beat_t as f64 }));
                    last_beat_time = beat_t;
                }

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
                    if onset > detector.mean + &params.threshold * detector.dev && detector.refractory == 0 {
                        let strength = ((onset - (detector.mean + &params.threshold * detector.dev)) / (detector.mean + &params.threshold * detector.dev + 1e-8)).clamp(0.0, 1.0);

                        records.push(Record::Event(EventRecord {
                            t,
                            band: Bands::try_from(b).unwrap(),
                            s: strength,
                        }));

                        detector.refractory = params.refractory[b] as usize;
                    }
                }

                i += 1;
            }

            let file = File::create(&params.output)?;
            let mut w = BufWriter::new(file);

            let meta = Record::Meta(MetaRecord {
                sr: sample_rate,
                channels,
                win: WINDOW as u32,
                hop: HOP as u32,
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
