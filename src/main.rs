use clap::{command, Parser};

#[derive(Clone, Debug, Parser)]
#[command(author, version, about, long_about = None)]
pub struct Options {
    pub first: String,
    pub second: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let options = Options::parse();
    let mut config = tun::Configuration::default();
    config.up();
    config.name(options.first);
    let dev1 = tun::create_as_async(&config)?;
    config.name(options.second);
    let dev2 = tun::create_as_async(&config)?;
    let (mut read1, mut write1) = tokio::io::split(dev1);
    let (mut read2, mut write2) = tokio::io::split(dev2);
    tokio::try_join! {
        tokio::io::copy(&mut read1, &mut write2),
        tokio::io::copy(&mut read2, &mut write1),
    }?;
    Ok(())
}
