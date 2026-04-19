mod record;
mod processor;

use ringbuf::traits::{Consumer, Producer, Split};
use clap::{Args, Parser, Subcommand};
use std::fs::File;
use std::io::{BufWriter, Write};
use std::path::Path;
use symphonia::core::audio::AudioBufferRef;
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::errors::Error;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::{MediaSourceStream, MediaSourceStreamOptions};
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::audio::Signal;
use tokio::net::TcpListener;
use tokio;
use tokio_tungstenite::tungstenite::Message;
use futures_util::stream::StreamExt;
use futures_util::sink::SinkExt;
use record::{Record, MetaRecord};
use processor::ProcessorState;
use ringbuf::HeapRb;
use tokio::sync::mpsc::Receiver;
use wasapi;

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
    AnalyzeLive(LiveArgs),
}

#[derive(Args)]
struct LiveArgs {
    #[arg(short, long)]
    port: usize,
    #[arg(long)]
    threshold: f32,
    #[arg(long, num_args=3)]
    refractory: Vec<u32>,
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

const WINDOW: usize = 2048;
const HOP: usize = 512;
const BAND_EMA: f32 = 0.25;
const ONSET_MEAN_EMA: f32 = 0.08;
const ONSET_DEV_EMA: f32 = 0.08;

struct BandDetect {
    prev_smooth: f32,
    smooth: f32,
    mean: f32,
    dev: f32,
    refractory: usize,
}

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

            let mut processor = ProcessorState::new(sample_rate, params.threshold, params.refractory);

            let mut records: Vec<Record> = Vec::new();

            let mut i = 0;
            while (HOP * i) + WINDOW < samples.len() {
                let start = i * HOP;
                processor.time = start as f64 / sample_rate as f64;

                let slice = &samples[start..start+WINDOW];

                records.extend(processor.process(slice));

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
        Commands::AnalyzeLive(params) => {
            let rb = HeapRb::<f32>::new(48000usize * 2usize);
            let (mut producer, mut consumer) = rb.split();

            let (tx, mut rx) = tokio::sync::mpsc::channel(1024);
            let (sr_tx, mut sr_rx) = tokio::sync::mpsc::channel(102);

            std::thread::spawn(move || {
                wasapi::initialize_mta().unwrap();
                let enumerator = wasapi::DeviceEnumerator::new().unwrap();

                // TODO: Support device selecton
                let device = enumerator.get_default_device(&wasapi::Direction::Render).expect("no output device");

                let mut audio_client = device.get_iaudioclient().unwrap();
                let format = audio_client.get_mixformat().unwrap();

                sr_tx.blocking_send(format.get_samplespersec() as u32).unwrap();

                audio_client.initialize_client(
                    &format,
                    &wasapi::Direction::Capture,
                    &wasapi::StreamMode::PollingShared {autoconvert: true, buffer_duration_hns: 100000},
                ).unwrap();

                let capture_client = audio_client.get_audiocaptureclient().unwrap();
                audio_client.start_stream().unwrap();

                let mut buf: Vec<u8> = Vec::new();

                loop {
                    loop {
                        let Some(packet_size) = (match capture_client.get_next_packet_size() {
                            Ok(s) => s,
                            Err(e) => {
                                eprintln!("{:?}", e);
                                continue
                            },
                        }) else { continue };
                        if packet_size == 0 {
                            break;
                        }

                        let bytes_per_frame = format.get_nchannels() as usize * (format.get_validbitspersample() as usize / 8);

                        let needed = packet_size as usize * bytes_per_frame;
                        if buf.len() < needed {
                            buf.resize(needed, 0);
                        }

                        let Ok((frames_read, _)) = capture_client.read_from_device(&mut buf) else { continue };
                        let bytes_read = frames_read as usize * bytes_per_frame;
                        let raw_bytes = &buf[..bytes_read];

                        match format.get_subformat().unwrap() {
                            wasapi::SampleType::Float => unsafe {
                                let slice = std::slice::from_raw_parts(raw_bytes.as_ptr() as *const f32, bytes_read / 4);
                                for frame in slice.chunks(format.get_nchannels() as usize) {
                                    let mono = frame.iter().sum::<f32>() / frame.len() as f32;
                                    let _ = producer.try_push(mono);
                                }
                            },
                            wasapi::SampleType::Int => unsafe {
                                let slice = std::slice::from_raw_parts(raw_bytes.as_ptr() as *const i16, bytes_read / 2);
                                for frame in slice.chunks(format.get_nchannels() as usize ) {
                                    let mono = frame.iter()
                                        .map(|&v| v as f32 / i16::MAX as f32)
                                        .sum::<f32>() / frame.len() as f32;
                                    let _ = producer.try_push(mono);
                                }
                            },
                        };
                    }
                    std::thread::yield_now();
                }
            });

            std::thread::spawn(move || {
                let sample_rate = sr_rx.blocking_recv().unwrap();

                let mut processor = ProcessorState::new(sample_rate, params.threshold, params.refractory);
                let mut buffer = vec![0f32; WINDOW];
                let mut temp = Vec::with_capacity(WINDOW);

                loop {
                    while temp.len() < WINDOW {
                        match consumer.try_pop() {
                            Some(s) => temp.push(s),
                            None => {
                                std::thread::yield_now();
                                continue;
                            }
                        }
                    }
                    buffer.copy_from_slice(&temp[..WINDOW]);
                    processor.time += HOP as f64 / sample_rate as f64;

                    let events = processor.process(&buffer);

                    for e in events {
                        let _ = tx.blocking_send(e);
                    }
                    temp.drain(..HOP);
                }
            });

            tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()?
                .block_on(run_live(params.port, &mut rx))?;
        },
    }

    Ok(())
}

async fn run_live(port: usize, rx: &mut Receiver<Record>) -> anyhow::Result<()> {
    let mut addr = port.to_string();
    addr.insert_str(0, "127.0.0.1:");
    let listener = TcpListener::bind(&addr).await?;
    println!("WebSocket server running at ws://{}", addr);

    let (stream, _) = listener.accept().await?;
    let ws_stream = tokio_tungstenite::accept_async(stream).await?;
    println!("WebSocket client connected");

    let (mut ws_write, _) = ws_stream.split();

    loop {
        while let Some(record) = rx.recv().await {
            let msg = serde_json::to_string(&record)?;
            ws_write.send(Message::Text(msg.into())).await?;
        }
    }
}