//! Read version metadata from LiveContainer's file-sharing directory only.
use idevice::afc::{AfcClient,opcode::AfcFopenMode};
use rootcause::prelude::*;
use serde_json::{Value,json};
use std::collections::BTreeMap;

const MAX_PLIST:usize=128*1024;

fn component(name:&str)->bool {
    !name.is_empty() && name.len()<=255 && name!="." && name!=".." && !name.chars().any(|c|c=='/' || c=='\\' || c.is_control())
}
fn field(info:&plist::Dictionary,key:&str)->Option<String> {
    let value=info.get(key)?;
    let text=value.as_string().map(str::to_owned)
        .or_else(||value.as_signed_integer().map(|n|n.to_string()))
        .or_else(||value.as_unsigned_integer().map(|n|n.to_string()))?;
    if text.is_empty() || text.len()>512 || text.chars().any(char::is_control) {None}else{Some(text)}
}
fn hidden(info:&plist::Dictionary)->bool {
    ["isHidden","isLocked"].iter().any(|key|info.get(*key).and_then(plist::Value::as_boolean)==Some(true))
}
fn record(host:&str,info:&plist::Dictionary,metadata:&plist::Dictionary)->Option<Value> {
    if hidden(info) || hidden(metadata) {return None}
    let original=if metadata.get("doUseLCBundleId").and_then(plist::Value::as_boolean)==Some(true) {
        field(metadata,"LCOrignalBundleIdentifier").or_else(||field(metadata,"LCOriginalBundleIdentifier"))
    }else{field(info,"LCBundleIdentifier").or_else(||field(info,"CFBundleIdentifier"))};
    let id=original?;
    if id==host || id.len()>255 || !id.chars().all(|c|c.is_ascii_alphanumeric() || matches!(c,'.'|'-'|'_')) {return None}
    Some(json!({"hostID":host,"bundleID":id,"name":field(info,"CFBundleDisplayName").or_else(||field(info,"CFBundleName")).unwrap_or_else(||id.clone()),
        "version":field(info,"CFBundleShortVersionString").or_else(||field(info,"CFBundleVersion")),"buildVersion":field(info,"CFBundleVersion")}))
}
async fn dictionary(afc:&mut AfcClient,path:&str)->Result<plist::Dictionary,Report> {
    let stat=afc.get_file_info(path).await?;
    if stat.st_ifmt!="S_IFREG" || stat.size>MAX_PLIST {bail!("Unsupported LiveContainer metadata.");}
    let mut file=afc.open(path,AfcFopenMode::RdOnly).await?;
    let data=file.read_n(stat.size+1).await?;file.close().await?;
    if data.len()>MAX_PLIST || data.len()!=stat.size {bail!("LiveContainer metadata changed during reading.");}
    plist::Value::from_reader(std::io::Cursor::new(data))?.into_dictionary().ok_or_else(||report!("Invalid LiveContainer metadata."))
}
pub(crate) async fn read(afc:&mut AfcClient,host:&str)->Result<Value,Report> {
    let base="/Documents/Applications";
    let entries=afc.list_dir(base).await?;
    if entries.len()>514 {bail!("Too many LiveContainer applications to inspect.");}
    let mut apps=BTreeMap::new();let mut unreadable=0;
    for name in entries.into_iter().filter(|n|n!="." && n!="..") {
        if !component(&name) {unreadable+=1;continue}
        if !name.ends_with(".app") {continue}
        let path=format!("{base}/{name}");
        let stat=match afc.get_file_info(&path).await {Ok(stat)=>stat,Err(_)=>{unreadable+=1;continue}};
        if stat.st_ifmt=="S_IFLNK" {unreadable+=1;continue}
        if stat.st_ifmt!="S_IFDIR" {continue}
        let meta_path=format!("{path}/LCAppInfo.plist");
        let metadata=match afc.get_file_info(&meta_path).await {
            Ok(_)=>match dictionary(afc,&meta_path).await {Ok(meta)=>meta,Err(_)=>{unreadable+=1;continue}},
            Err(idevice::IdeviceError::Afc(idevice::afc::errors::AfcError::ObjectNotFound))=>plist::Dictionary::new(),
            Err(_)=>{unreadable+=1;continue}
        };
        if hidden(&metadata) {continue}
        let info=match dictionary(afc,&format!("{path}/Info.plist")).await {Ok(info)=>info,Err(_)=>{unreadable+=1;continue}};
        if hidden(&info) {continue}
        if let Some(app)=record(host,&info,&metadata) {
            let key=format!("{}|{}|{}",app["bundleID"],app["version"],app["buildVersion"]);
            apps.insert(key,app);
        } else {unreadable+=1;}
    }
    Ok(json!({"hostID":host,"state":if unreadable==0 {"ready"}else{"partial"},"apps":apps.into_values().collect::<Vec<_>>()}))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn info()->plist::Dictionary {[("CFBundleIdentifier","example.test"),("CFBundleDisplayName","Example"),("CFBundleShortVersionString","1.2"),("CFBundleVersion","42")].into_iter().map(|(k,v)|(k.to_owned(),plist::Value::String(v.to_owned()))).collect()}
    #[test]
    fn inventory_exports_only_version_fields_and_original_identity() {
        let mut info=info();info.insert("privateField".into(),plist::Value::String("must-not-export".into()));
        let result=record("com.kdt.livecontainer.TESTTEAM01",&info,&plist::Dictionary::new()).unwrap();
        assert_eq!(result["bundleID"],"example.test");assert_eq!(result["version"],"1.2");assert_eq!(result["buildVersion"],"42");
        assert_eq!(result.as_object().unwrap().len(),5);assert!(!result.to_string().contains("must-not-export"));
        let metadata=[("doUseLCBundleId".to_owned(),plist::Value::Boolean(true)),("LCOrignalBundleIdentifier".to_owned(),plist::Value::String("example.original".into()))].into_iter().collect();
        assert_eq!(record("host",&info,&metadata).unwrap()["bundleID"],"example.original");
    }
    #[test]
    fn private_apps_and_unsafe_entries_are_not_exported() {
        let mut metadata=plist::Dictionary::new();metadata.insert("isHidden".into(),plist::Value::Boolean(true));
        assert!(record("host",&info(),&metadata).is_none());
        for name in ["..","../private","other/Info.plist","other\\Info.plist",""] {assert!(!component(name));}
        assert!(component("Example.app"));
        metadata.clear();metadata.insert("doUseLCBundleId".into(),plist::Value::Boolean(true));
        assert!(record("host",&info(),&metadata).is_none());
    }
}
