use clap::{Args, Parser, Subcommand};
use serde::{Serialize};
use std::fs::File;
use std::io::{BufWriter, Write};
use hound;
use itertools::Itertools;

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
    #[serde(rename= "done")]
    Done,
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

fn main() -> anyhow::Result<()> {
    let args = CLI::parse();
    match args.command {
        Commands::AnalyzeWav(params) => {
            let mut reader = hound::WavReader::open(&params.input).unwrap();
            let spec = reader.spec();

            let samples: Vec<i16> = reader
                .samples::<i16>()
                .chunks(spec.channels as usize)
                .into_iter()
                .map(|chunk| {
                    let mut sum: i32 = 0;
                    let mut count: i32 = 0;
                    for s in chunk {
                        if let Ok(sample) = s {
                            sum += sample as i32;
                            count += 1
                        }
                    }
                    (sum / count) as i16
                })
                .collect();

            let file = File::create(&params.output)?;
            let mut w = BufWriter::new(file);

            let meta = Record::Meta(MetaRecord {
                sr: spec.sample_rate,
                channels: spec.channels,
                win: 2048,
                hop: 512,
                duration: (reader.len() / spec.channels as u32) as f64 / spec.sample_rate as f64,
            });

            serde_json::to_writer(&mut w, &meta)?;
            w.write_all(b"\n")?;

            serde_json::to_writer(&mut w, &Record::Done)?;
            w.write_all(b"\n")?;
        },
    }

    Ok(())
}
