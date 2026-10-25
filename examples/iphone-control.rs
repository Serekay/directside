//! Explicit USB accessibility inspection. No automation app is installed.
use idevice::{IdeviceService,provider::RsdProvider,usbmuxd::{UsbmuxdConnection,UsbmuxdAddr},core_device_proxy::CoreDeviceProxy,rsd::RsdHandshake,dvt::{remote_server::RemoteServerClient,message::AuxValue}};
use rootcause::prelude::*;
use plist::Value;
use std::{time::Duration,collections::HashSet};

fn pass(value:Value)->Value {Value::Dictionary([("ObjectType".to_string(),Value::String("passthrough".into())),("Value".to_string(),value)].into_iter().collect())}
fn field<'a>(value:&'a Value,key:&str)->Option<&'a Value> {
    match value {
        Value::Dictionary(d)=>d.get(key).or_else(||d.values().find_map(|v|field(v,key))),
        Value::Array(a)=>a.iter().find_map(|v|field(v,key)),
        _=>None,
    }
}
fn unpass(value:&Value)->&Value {
    if let Some(d)=value.as_dictionary() {if d.get("ObjectType").and_then(Value::as_string)==Some("passthrough") {if let Some(v)=d.get("Value"){return unpass(v)}}}
    value
}
async fn invoke(client:&mut RemoteServerClient<Box<dyn idevice::ReadWrite>>,name:&str,args:Vec<Value>)->Result<(),Report> {
    client.call_method(0,Some(Value::String(name.into())),Some(args.into_iter().map(AuxValue::archived_value).collect()),false).await?;Ok(())
}
#[tokio::main]
async fn main()->Result<(),Report> {
    let _=rustls::crypto::ring::default_provider().install_default();
    tokio::time::timeout(Duration::from_secs(45),run()).await??;Ok(())
}
async fn run()->Result<(),Report> {
    let args:Vec<_>=std::env::args().skip(1).collect();
    let focus_only=args.first().is_some_and(|a|a=="focus");
    let target=if focus_only || args.first().is_some_and(|a|a=="press") {Some(args.get(1).ok_or_else(||report!("Use press/focus <exact accessibility label>."))?.as_str())} else {None};
    let mut mux=UsbmuxdConnection::default().await?;
    let devices=mux.get_devices().await?;
    if devices.len()!=1 {bail!("Connect exactly one trusted, unlocked iPhone.");}
    let provider=devices[0].to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide UI inspection");
    let proxy=CoreDeviceProxy::connect(&provider).await?;
    let rsd_port=proxy.tunnel_info().server_rsd_port;
    let mut handle=proxy.create_software_tunnel()?.to_async_handle();
    let rsd=RsdHandshake::new(handle.connect(rsd_port).await?).await?;
    let port=rsd.services.get("com.apple.accessibility.axAuditDaemon.remoteserver.shim.remote").ok_or_else(||report!("Accessibility developer service is unavailable."))?.port;
    let mut service=idevice::Idevice::new(handle.connect_to_service_port(port).await?,"DirectSide UI inspection");
    service.rsd_checkin().await.context("Accessibility service check-in failed")?;
    let mut client=RemoteServerClient::new(service.get_socket().ok_or_else(||report!("Accessibility transport missing"))?);
    for _ in 0..3 {if tokio::time::timeout(Duration::from_millis(350),client.read_message(0)).await.is_err(){break}}
    invoke(&mut client,"deviceSetAppMonitoringEnabled:",vec![Value::Boolean(true)]).await?;
    invoke(&mut client,"deviceInspectorSetMonitoredEventType:",vec![0.into()]).await?;
    let mut seen=HashSet::new();let mut pressed=false;let mut silent=0;let mut duplicates=0;
    for index in 0..90 {
        let options=pass(Value::Dictionary([("allowNonAX".to_string(),pass(0.into())),("direction".to_string(),pass(if index==0 {5.into()} else {4.into()})),("includeContainers".to_string(),pass(1.into()))].into_iter().collect()));
        invoke(&mut client,"deviceInspectorMoveWithOptions:",vec![options]).await?;
        let message=match tokio::time::timeout(Duration::from_secs(2),client.read_message(0)).await {
            Ok(Ok(m))=>m,_=>{silent+=1;if silent>=3 {break}continue},
        };
        if message.data.as_ref().and_then(Value::as_string)!=Some("hostInspectorCurrentElementChanged:"){continue}
        let Some(raw)=message.aux.and_then(|a|a.values.into_iter().find_map(|v|if let AuxValue::Array(bytes)=v {ns_keyed_archive::decode::from_bytes(&bytes).ok()} else {None})) else {continue};
        let caption=field(&raw,"CaptionTextValue_v1").map(unpass).and_then(Value::as_string).unwrap_or("");
        let token=field(&raw,"ElementValue_v1");
        let identity=format!("{token:?}:{caption}");
        if !seen.insert(identity){duplicates+=1;if duplicates>=6{break}continue}
        duplicates=0;
        println!("Element: {}",if caption.contains('@'){"[account]"}else{caption});
        if target==Some(caption) || (target==Some("[account]") && caption.contains('@')) {
            if focus_only {pressed=true;break}
            let element=token.ok_or_else(||report!("Selected element has no activation token."))?.clone();
            let fields:plist::Dictionary=[("AttributeNameValue_v1",Value::String("AXAction-2010".into())),("DisplayAsTree_v1",0.into()),("HumanReadableNameValue_v1","Activate".into()),("IsInternal_v1",0.into()),("PerformsActionValue_v1",1.into()),("SettableValue_v1",0.into()),("ValueTypeValue_v1",1.into())].into_iter().map(|(k,v)|(k.to_string(),pass(v))).collect();
            let action=Value::Dictionary([("ObjectType".to_string(),Value::String("AXAuditElementAttribute_v1".into())),("Value".to_string(),pass(Value::Dictionary(fields)))].into_iter().collect());
            invoke(&mut client,"deviceElement:performAction:withValue:",vec![element,action,0.into()]).await?;
            tokio::time::sleep(Duration::from_millis(400)).await;pressed=true;break;
        }
    }
    invoke(&mut client,"deviceSetAppMonitoringEnabled:",vec![Value::Boolean(false)]).await?;
    if target.is_some() && !pressed {bail!("Target was not found or no accessibility focus events arrived.");}
    if seen.is_empty() {bail!("No accessibility elements received.");}
    println!("Inspected {} elements; activation requested: {}. Confirm any navigation with a screenshot.",seen.len(),pressed && !focus_only);
    Ok(())
}
