use serde::Serialize;
use std::convert::TryFrom;

#[derive(Serialize)]
#[serde(tag = "type")]
pub enum Record {
    #[serde(rename = "meta")]
    Meta(MetaRecord),
    #[serde(rename = "energy")]
    Energy(EnergyRecord),
    #[serde(rename = "band")]
    Band(BandEnergies),
    #[serde(rename = "spectrum")]
    Spectrum(SpectrumRecord),
    #[serde(rename = "beat")]
    Beat(BeatRecord),
    #[serde(rename = "event")]
    Event(EventRecord),
    #[serde(rename = "done")]
    Done,
}

#[derive(Serialize)]
pub struct SpectrumRecord {
    pub t: f64,
    pub bins: Vec<f32>,
}
#[derive(Serialize)]
pub enum Bands {
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
pub struct EventRecord {
    pub t: f64,
    pub band: Bands,
    pub s: f32,
}

#[derive(Serialize)]
pub struct BandEnergies {
    pub t: f64,
    pub low: f32,
    pub mid: f32,
    pub high: f32,
}

#[derive(Serialize)]
pub struct MetaRecord {
    pub sr: u32,
    pub channels: u16,
    pub win: u32,
    pub hop: u32,
}

#[derive(Serialize)]
pub struct EnergyRecord {
    pub t: f64,
    pub e: f32,
}

#[derive(Serialize)]
pub struct BeatRecord {
    pub t: f64,
}
