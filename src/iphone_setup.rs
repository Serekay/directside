//! Windows setup launch verification. Never confirms an iOS security decision.
use idevice::{IdeviceService, provider::{IdeviceProvider,RsdProvider}, core_device_proxy::CoreDeviceProxy,
    rsd::RsdHandshake, dvt::{remote_server::RemoteServerClient,message::AuxValue}};
use rootcause::prelude::*;
use plist::Value;
use std::time::Duration;

async fn launch(provider:&impl IdeviceProvider,bundle:&str)->Result<(),Report> {
    let proxy=CoreDeviceProxy::connect(provider).await?;
    let port=proxy.tunnel_info().server_rsd_port;
    let mut handle=proxy.create_software_tunnel()?.to_async_handle();
    let rsd=RsdHandshake::new(handle.connect(port).await?).await?;
    let port=rsd.services.iter().find(|(name,_)|name.contains("dtservicehub")).map(|(_,s)|s.port)
        .ok_or_else(||report!("Der iPhone-Startdienst ist nicht verfügbar."))?;
    let mut client=RemoteServerClient::new(handle.connect_to_service_port(port).await?);
    let capabilities:plist::Dictionary=[("com.apple.private.DTXBlockCompression".to_string(),Value::Integer(0.into())),
        ("com.apple.private.DTXConnection".to_string(),Value::Integer(1.into()))].into_iter().collect();
    client.call_method(0,Some(Value::String("_notifyOfPublishedCapabilities:".into())),
        Some(vec![AuxValue::archived_value(Value::Dictionary(capabilities))]),false).await?;
    let mut process=idevice::dvt::process_control::ProcessControlClient::new(&mut client).await?;
    let pid=process.launch_app(bundle,None,None,false,false).await?;
    if pid==0 {bail!("iOS hat den App-Start nicht bestätigt.");}
    Ok(())
}

pub async fn launch_directside(provider:&impl IdeviceProvider)->Result<(),Report> {
    let apps=idevice::installation_proxy::InstallationProxyClient::connect(provider).await?
        .get_apps(Some("User"),None).await?;
    let ids:Vec<_>=apps.keys().filter(|id|*id=="com.directside.app" || id.starts_with("com.directside.app.")).collect();
    if ids.len()!=1 {bail!("Eine eindeutige DirectSide-Installation ist erforderlich.");}
    launch(provider,ids[0]).await
}

fn pass(value:Value)->Value {Value::Dictionary([("ObjectType".to_string(),"passthrough".into()),("Value".to_string(),value)].into_iter().collect())}
fn field<'a>(value:&'a Value,key:&str)->Option<&'a Value> {
    match value {Value::Dictionary(d)=>d.get(key).or_else(||d.values().find_map(|v|field(v,key))),
        Value::Array(a)=>a.iter().find_map(|v|field(v,key)),_=>None}
}
fn unpass(value:&Value)->&Value {
    if let Some(d)=value.as_dictionary() {if d.get("ObjectType").and_then(Value::as_string)==Some("passthrough") {
        if let Some(v)=d.get("Value"){return unpass(v)}
    }}value
}
async fn invoke(client:&mut RemoteServerClient<Box<dyn idevice::ReadWrite>>,name:&str,args:Vec<Value>)->Result<(),Report> {
    client.call_method(0,Some(Value::String(name.into())),Some(args.into_iter().map(AuxValue::archived_value).collect()),false).await?;Ok(())
}
const GENERAL:&str="com.apple.settings.general";
const MANAGEMENT:&str="com.apple.settings.general.vpnAndDeviceManagement";
const BACK:&str="BackButton";
fn semantic_identifier(raw:&Value)->&str {
    field(raw,"AccessibilityIdentifier_v1").map(unpass).and_then(Value::as_string).unwrap_or("")
}
fn navigation_allowed(identifier:&str)->bool {matches!(identifier,GENERAL|MANAGEMENT|BACK)}
async fn find_identifier(client:&mut RemoteServerClient<Box<dyn idevice::ReadWrite>>,identifiers:&[&str],activate:bool)->Result<bool,Report> {
    if activate && identifiers.iter().any(|id|!navigation_allowed(id)){bail!("Nur die Einstellungsnavigation darf automatisch aktiviert werden.");}
    let mut seen=std::collections::HashSet::new();let mut duplicates=0;
    for index in 0..90 {
        let options=pass(Value::Dictionary([("allowNonAX".to_string(),pass(0.into())),
            ("direction".to_string(),pass(if index==0 {5.into()}else{4.into()})),("includeContainers".to_string(),pass(1.into()))].into_iter().collect()));
        invoke(client,"deviceInspectorMoveWithOptions:",vec![options]).await?;
        let message=match tokio::time::timeout(Duration::from_secs(2),client.read_message(0)).await {Ok(Ok(m))=>m,_=>return Ok(false)};
        if message.data.as_ref().and_then(Value::as_string)!=Some("hostInspectorCurrentElementChanged:"){continue}
        let Some(raw)=message.aux.and_then(|a|a.values.into_iter().find_map(|v|if let AuxValue::Array(bytes)=v {ns_keyed_archive::decode::from_bytes(&bytes).ok()} else {None})) else {continue};
        let Some(identity)=field(&raw,"PlatformElementValue_v1").map(unpass).and_then(Value::as_data) else {continue};
        if !seen.insert(identity.to_vec()) {duplicates+=1;if duplicates>=6{return Ok(false)}} else {duplicates=0;}
        // Semantic identifiers only: no localized captions, row numbers or coordinates.
        if !identifiers.contains(&semantic_identifier(&raw)){continue}
        if !activate {return Ok(true)}
        let token=field(&raw,"ElementValue_v1").ok_or_else(||report!("Einstellungszeile nicht bedienbar."))?.clone();
        let fields:plist::Dictionary=[("AttributeNameValue_v1","AXAction-2010".into()),("DisplayAsTree_v1",0.into()),
            ("HumanReadableNameValue_v1","Activate".into()),("IsInternal_v1",0.into()),("PerformsActionValue_v1",1.into()),
            ("SettableValue_v1",0.into()),("ValueTypeValue_v1",1.into())].into_iter().map(|(k,v)|(k.to_string(),pass(v))).collect();
        let action=Value::Dictionary([("ObjectType".to_string(),"AXAuditElementAttribute_v1".into()),("Value".to_string(),pass(Value::Dictionary(fields)))].into_iter().collect());
        invoke(client,"deviceElement:performAction:withValue:",vec![token,action,Value::Dictionary(plist::Dictionary::new())]).await?;
        tokio::time::sleep(Duration::from_millis(500)).await;return Ok(true)
    }Ok(false)
}
async fn management_visible(client:&mut RemoteServerClient<Box<dyn idevice::ReadWrite>>)->Result<bool,Report> {
    // Observed on the native device: the management page has the exact VPN
    // identifier and BackButton. The root VPN row has com.apple.settings.vpn.
    Ok(find_identifier(client,&["VPN"],false).await? && find_identifier(client,&[BACK],false).await?)
}
pub async fn open_trust_settings(provider:&impl IdeviceProvider)->Result<(),Report> {
    let proxy=CoreDeviceProxy::connect(provider).await?;
    let port=proxy.tunnel_info().server_rsd_port;
    let mut handle=proxy.create_software_tunnel()?.to_async_handle();
    let rsd=RsdHandshake::new(handle.connect(port).await?).await?;
    let port=rsd.services.get("com.apple.accessibility.axAuditDaemon.remoteserver.shim.remote")
        .ok_or_else(||report!("Die Einstellungsnavigation ist nicht verfügbar."))?.port;
    let mut service=idevice::Idevice::new(handle.connect_to_service_port(port).await?,"DirectSide setup");
    service.rsd_checkin().await?;
    let mut client=RemoteServerClient::new(service.get_socket().ok_or_else(||report!("Einstellungen-Verbindung fehlt."))?);
    for _ in 0..3 {if tokio::time::timeout(Duration::from_millis(350),client.read_message(0)).await.is_err(){break}}
    invoke(&mut client,"deviceSetAppMonitoringEnabled:",vec![true.into()]).await?;
    invoke(&mut client,"deviceInspectorSetMonitoredEventType:",vec![0.into()]).await?;
    let result=async {
        if management_visible(&mut client).await? {return Ok(())}
        launch(provider,"com.apple.Preferences").await?;
        tokio::time::sleep(Duration::from_millis(500)).await;
        for _ in 0..4 {
            if management_visible(&mut client).await? {return Ok(())}
            if find_identifier(&mut client,&[MANAGEMENT],true).await? {
                if management_visible(&mut client).await? {return Ok(())}
                bail!("Der iPhone-Fernklick wurde nicht ausgeführt. Geräteverwaltung am iPhone öffnen.");
            }
            if find_identifier(&mut client,&[GENERAL],true).await? {
                if !find_identifier(&mut client,&[MANAGEMENT],false).await? {
                    bail!("Der iPhone-Fernklick wurde nicht ausgeführt. Allgemein am iPhone öffnen.");
                }
                continue
            }
            if !find_identifier(&mut client,&[BACK],true).await? {bail!("Geräteverwaltung am iPhone öffnen.");}
        }
        bail!("Geräteverwaltung wurde nicht bestätigt.");
    }.await;
    let _=invoke(&mut client,"deviceSetAppMonitoringEnabled:",vec![false.into()]).await;
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn settings_selection_uses_identifiers_instead_of_localized_or_matching_text() {
        for caption in ["Allgemein, Taste, Statischer Text","General, Button","一般"] {
            let raw=Value::Dictionary([("CaptionTextValue_v1".to_string(),pass(caption.into())),
                ("AccessibilityIdentifier_v1".to_string(),pass(GENERAL.into()))].into_iter().collect());
            assert_eq!(semantic_identifier(&raw),GENERAL);
        }
        let raw=Value::Dictionary([("CaptionTextValue_v1".to_string(),pass(GENERAL.into())),
            ("AccessibilityIdentifier_v1".to_string(),pass("com.apple.settings.battery".into()))].into_iter().collect());
        assert_ne!(semantic_identifier(&raw),GENERAL);
    }
    #[test]
    fn automatic_navigation_cannot_confirm_security_decisions() {
        for id in [GENERAL,MANAGEMENT,BACK] {assert!(navigation_allowed(id));}
        for id in ["Trust","Allow","VPN","com.apple.settings.passcodeAndBiometrics",""] {assert!(!navigation_allowed(id));}
    }
}
