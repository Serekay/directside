//! In-process Apple ADI. No HTTP listener, external generator or remote fallback.
use super::{AnisetteClientInfo, AnisetteData, AnisetteDataResponse, AnisetteProvider};
use crate::auth::grandslam::GrandSlam;
use rootcause::prelude::*;
use std::sync::Arc;

#[cfg(windows)]
mod windows;
#[cfg(windows)]
pub use windows::LocalAnisetteProvider;

#[cfg(not(windows))]
pub struct LocalAnisetteProvider;
#[cfg(not(windows))]
impl LocalAnisetteProvider {
    pub fn new() -> Result<Self,Report> {
        bail!("Die lokale Apple-Authentifizierung ist auf diesem System noch nicht implementiert. Fremde Anisette-Dienste sind deaktiviert.")
    }
}
#[cfg(not(windows))]
#[async_trait::async_trait]
impl AnisetteProvider for LocalAnisetteProvider {
    async fn get_anisette_data(&self)->Result<AnisetteDataResponse,Report> { bail!("Lokale Apple-Authentifizierung nicht verfügbar.") }
    async fn get_client_info(&self)->Result<AnisetteClientInfo,Report> { bail!("Lokale Apple-Authentifizierung nicht verfügbar.") }
    async fn provision(&mut self,_:&Arc<GrandSlam>,_:bool)->Result<(),Report> { bail!("Lokale Apple-Authentifizierung nicht verfügbar.") }
}
