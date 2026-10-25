use std::path::PathBuf;
use rootcause::prelude::*;
use serde_json::{Value,json};
use isideload::{sideload::imported::ImportedIdentity,util::{keyring_storage::KeyringStorage,storage::SideloadingStorage}};

fn storage()->KeyringStorage {KeyringStorage::new("DirectSide.imported".into())}
// Small credential records also work within Windows Credential Manager limits.
// Publish the manifest last so a failed replacement preserves the old identity.
pub fn load()->Result<Option<ImportedIdentity>,Report> {
    let Some(raw)=storage().retrieve("active")? else {return Ok(None)};
    let manifest:Value=serde_json::from_str(&raw)?;
    let prefix=manifest["prefix"].as_str().ok_or_else(||report!("Zertifikatspeicher ist beschädigt."))?;
    let count=manifest["count"].as_u64().filter(|n|*n<=6000).ok_or_else(||report!("Zertifikatspeicher ist beschädigt."))?;
    let mut data=Vec::new();
    for i in 0..count {
        data.extend(storage().retrieve_data(&format!("{prefix}/{i}"))?.ok_or_else(||report!("Zertifikatspeicher ist unvollständig."))?);
        if data.len()>12_000_000 {bail!("Zertifikatspeicher ist zu groß.");}
    }
    Ok(Some(serde_json::from_slice(&data)?))
}
pub fn metadata()->Result<Value,Report> {Ok(match load()? {
    Some(identity)=>match identity.metadata() {
        Ok(mut info)=>{info["valid"]=json!(true);info},
        Err(error)=>{
            let profile=identity.profiles.first().and_then(|bytes|apple_codesign_quick::ProvisioningProfile::parse(bytes).ok());
            json!({"name":profile.as_ref().and_then(|p|p.plist().get("Name")).and_then(plist::Value::as_string).unwrap_or("Imported certificate"),"team_id":profile.as_ref().map(|p|p.team_id()).unwrap_or(""),"expires_at":profile.as_ref().and_then(|p|p.plist().get("ExpirationDate")).and_then(plist::Value::as_date).map(|date|date.to_xml_format()),"profiles":identity.profiles.len(),"free":false,"valid":false,"problem":error.to_string()})
        }
    },None=>Value::Null
})}
fn discard(manifest:&Value) {
    if let (Some(prefix),Some(count))=(manifest["prefix"].as_str(),manifest["count"].as_u64().filter(|n|*n<=6000)) {
        for i in 0..count {let _=storage().delete(&format!("{prefix}/{i}"));}
    }
}
pub fn forget()->Result<(),Report> {
    let previous=storage().retrieve("active")?.and_then(|raw|serde_json::from_str::<Value>(&raw).ok());
    storage().delete("active")?;
    if let Some(previous)=previous {discard(&previous)}
    Ok(())
}
pub fn import(request:&Value)->Result<Value,Report> {
    fn bounded(path:&str,limit:u64)->Result<Vec<u8>,Report> {
        if std::fs::metadata(path)?.len()>limit {bail!("Zertifikat oder Profil ist zu groß.");}
        Ok(std::fs::read(path)?)
    }
    if let Some(path)=request["archive_path"].as_str() {
        let identity:ImportedIdentity=serde_json::from_slice(&bounded(path,12_000_000)?)?;
        let result=store(identity)?;std::fs::remove_file(path)?;return Ok(result);
    }
    let p12=request["p12_path"].as_str().ok_or_else(||report!("P12-Datei fehlt."))?;
    let files=request["profile_paths"].as_array().filter(|v|!v.is_empty() && v.len()<=32).ok_or_else(||report!("Mindestens ein Profil auswählen."))?;
    let identity=ImportedIdentity{p12:bounded(p12,131072)?,password:request["password"].as_str().unwrap_or("").to_string(),profiles:files.iter().map(|file|bounded(file.as_str().ok_or_else(||report!("Profilpfad fehlt."))?,262144)).collect::<Result<_,_>>()?};
    store(identity)
}
fn store(identity:ImportedIdentity)->Result<Value,Report> {
    let metadata=identity.metadata()?;
    let data=serde_json::to_vec(&identity)?;
    if data.len()>12_000_000 {bail!("Zertifikat und Profile sind zusammen zu groß. Nur die benötigten Profile importieren.");}
    let prefix=format!("identity-{}",std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?.as_nanos());
    let manifest=json!({"prefix":prefix,"count":data.chunks(2000).len()});
    let old=storage().retrieve("active")?.and_then(|raw|serde_json::from_str::<Value>(&raw).ok());
    let result:Result<(),Report>=(|| {
        for (i,chunk) in data.chunks(2000).enumerate(){storage().store_data(&format!("{prefix}/{i}"),chunk)?;}
        storage().store("active",&manifest.to_string())?;Ok(())
    })();
    if result.is_err(){discard(&manifest);result?;}
    if let Some(old)=old {discard(&old)}
    Ok(metadata)
}
pub async fn sign(path:PathBuf,udid:&str)->Result<PathBuf,Report> {
    load()?.ok_or_else(||report!("Zuerst ein Zertifikat und passende Profile importieren."))?.sign(path,udid).await
}
