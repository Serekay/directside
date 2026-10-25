//! Explicitly scoped reset for the owner-requested fresh setup test.
use idevice::{IdeviceService,provider::IdeviceProvider,usbmuxd::{UsbmuxdConnection,UsbmuxdAddr},lockdown::LockdownClient,installation_proxy::InstallationProxyClient};
use isideload::util::{keyring_storage::KeyringStorage,storage::SideloadingStorage};
use rootcause::prelude::*;

fn test_app(id:&str)->bool {
    ["com.directside.app","com.kdt.livecontainer","com.jkcoxson.LocalDevVPN"].iter().any(|base|id==*base || id.strip_prefix(*base).is_some_and(|suffix|suffix.starts_with('.')))
}
#[tokio::main]
async fn main()->Result<(),Report> {
    let _=rustls::crypto::ring::default_provider().install_default();
    tokio::time::timeout(std::time::Duration::from_secs(90),run()).await??;Ok(())
}
async fn run()->Result<(),Report> {
    let action=std::env::args().nth(1).unwrap_or_else(||"--inventory".into());
    if !["--inventory","--remove-test-apps","--remove-directside","--account-transfer-status","--forget-pairing"].contains(&action.as_str()){bail!("Unknown scoped setup action.");}
    let mut mux=UsbmuxdConnection::default().await?;
    let devices=mux.get_devices().await?;
    if devices.len()!=1 {bail!("Exactly one trusted, unlocked iPhone is required.");}
    let dev=&devices[0];let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide fresh setup test");
    let mode=idevice::amfi::AmfiClient::connect(&provider).await?.get_developer_mode_status().await?;
    let mut proxy=InstallationProxyClient::connect(&provider).await?;
    let apps=proxy.get_apps(Some("User"),None).await?;
    let targets:Vec<_>=apps.iter().filter(|(id,_)|test_app(id)).map(|(id,info)|(id.clone(),info.as_dictionary().and_then(|d|d.get("CFBundleDisplayName")).and_then(plist::Value::as_string).unwrap_or("Test app").to_string())).collect();
    println!("Developer Mode: {}. Test apps present: {}.",if mode {"on"}else{"off"},targets.len());
    for (_,name) in &targets {println!("Test app: {name}");}
    if action=="--account-transfer-status" {
        let ids:Vec<_>=targets.iter().filter(|(id,_)|id=="com.directside.app" || id.starts_with("com.directside.app.")).collect();
        if ids.len()!=1 {bail!("Exactly one DirectSide is required.");}
        let mut container=idevice::house_arrest::HouseArrestClient::connect(&provider).await?.vend_container(&ids[0].0).await?;
        for path in ["/Library/Caches/DirectSide-session-import.json","/Library/Application Support/DirectSide/signing-import.json","/Documents/DirectSide-signing.json"] {
            println!("{}: {}",path,container.get_file_info(path).await.is_ok());
        }
        let report="/Library/Caches/DirectSide-account-status.json";
        if container.get_file_info(report).await.is_ok() {
            let mut file=container.open(report,idevice::afc::opcode::AfcFopenMode::RdOnly).await?;
            let bytes=file.read_entire().await?;file.close().await?;
            if bytes.len()<=8192 {let value:serde_json::Value=serde_json::from_slice(&bytes)?;println!("Account handoff: {}",value);}
        }
    } else if action=="--remove-directside" {
        for (id,name) in &targets {
            if id=="com.directside.app" || id.starts_with("com.directside.app.") {
                proxy.uninstall(id.clone(),None).await?;println!("Removed: {name}");
            }
        }
        let remaining=proxy.get_apps(Some("User"),None).await?;
        if remaining.keys().any(|id|id=="com.directside.app" || id.starts_with("com.directside.app.")){bail!("DirectSide is still installed.");}
        println!("DirectSide absent. Other apps, Apple App IDs and certificates were not modified.");
    } else if action=="--remove-test-apps" {
        for (id,name) in &targets {proxy.uninstall(id.clone(),None).await?;println!("Removed: {name}");}
        let remaining=proxy.get_apps(Some("User"),None).await?;
        if remaining.keys().any(|id|test_app(id)){bail!("A test app is still installed.");}
        println!("All three setup apps absent. Apple App IDs, certificates and personal apps were not modified.");
    } else if action=="--forget-pairing" {
        if mode || !targets.is_empty(){bail!("Remove the three setup apps and turn Developer Mode off before forgetting this PC's pairing.");}
        KeyringStorage::new("DirectSide.pairing".into()).delete(&format!("device-{}",dev.udid))?;
        let record=provider.get_pairing_file().await?;
        LockdownClient::connect(&provider).await?.unpair(record.host_id).await?;
        mux.delete_pair_record(&dev.udid).await?;
        println!("This PC's USB trust and DirectSide remote-pairing cache were cleared. Signing identity and Apple App IDs retained.");
    }
    Ok(())
}
