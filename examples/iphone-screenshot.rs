//! Explicit, one-shot README capture. Does not install developer images or
//! publish screenshots. Probe is safe to run before the owner opens DirectSide.
use idevice::{IdeviceService,lockdown::LockdownClient,provider::IdeviceProvider,usbmuxd::{UsbmuxdConnection,UsbmuxdAddr},dvt::{remote_server::RemoteServerClient,screenshot::ScreenshotClient}};
use rootcause::prelude::*;
use std::{path::PathBuf,time::Duration};

async fn remote_screenshot_service(provider:&impl IdeviceProvider)->Result<(Box<dyn idevice::ReadWrite>,idevice::tcp::handle::AdapterHandle),Report> {
    use idevice::{core_device_proxy::CoreDeviceProxy,rsd::RsdHandshake};
    let proxy=CoreDeviceProxy::connect(provider).await?;
    let rsd_port=proxy.tunnel_info().server_rsd_port;
    let adapter=proxy.create_software_tunnel()?;
    let mut handle=adapter.to_async_handle();
    let handshake=RsdHandshake::new(handle.connect(rsd_port).await?).await?;
    let port=handshake.services.iter().find(|(name,_)|name.contains("dtservicehub")).map(|(_,service)|service.port).ok_or_else(||report!("The iPhone does not advertise its screenshot developer service. A mounted developer image may be required; no image was downloaded or installed."))?;
    use idevice::provider::RsdProvider;
    Ok((handle.connect_to_service_port(port).await?,handle))
}

#[tokio::main]
async fn main()->Result<(),Report> {
    let _=rustls::crypto::ring::default_provider().install_default();
    let args:Vec<_>=std::env::args().skip(1).collect();
    let probe=args.first().is_some_and(|a|a=="--probe");
    let version_only=args.first().is_some_and(|a|a=="--installed-version");
    let launch=args.first().is_some_and(|a|a=="--launch");
    if !probe && args.len()!=1 {bail!("Use --probe or an output .png path. Open DirectSide on the unlocked iPhone before capture.");}
    let mut mux=UsbmuxdConnection::default().await?;
    let devices=mux.get_devices().await?;
    if devices.len()!=1 {bail!("Connect exactly one unlocked, trusted iPhone (found {}).",devices.len());}
    let provider=devices[0].to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide README screenshot");
    let mut launch_bundle=None;
    if version_only || launch {
        let apps=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?.get_apps(Some("User"),None).await?;
        for (id,info) in apps.iter().filter(|(id,_)|*id=="com.directside.app" || id.starts_with("com.directside.app.")) {
            if launch {if launch_bundle.is_some(){bail!("Multiple DirectSide apps found.");}launch_bundle=Some(id.clone());}
            let info=info.as_dictionary().ok_or_else(||report!("App metadata is missing."))?;
            println!("DirectSide installed: version {}, build {}",info.get("CFBundleShortVersionString").and_then(plist::Value::as_string).unwrap_or("unknown"),info.get("CFBundleVersion").and_then(plist::Value::as_string).unwrap_or("unknown"));
        }
        if version_only {return Ok(())}
        if launch_bundle.is_none(){bail!("DirectSide is not installed.");}
    }
    let mut lockdown=LockdownClient::connect(&provider).await?;
    let pairing=provider.get_pairing_file().await?;
    lockdown.start_session(&pairing).await?;
    let mut service=None;
    for name in ["com.apple.instruments.remoteserver.DVTSecureSocketProxy","com.apple.instruments.remoteserver"] {
        if let Ok(Ok(connection))=tokio::time::timeout(Duration::from_secs(5),lockdown.start_service(name)).await {service=Some(connection);break}
    }
    let (socket,_tunnel)=if let Some((port,ssl))=service {
        let mut connection=provider.connect(port).await?;
        if ssl {connection.start_session(&pairing,false).await?;}
        (connection.get_socket().ok_or_else(||report!("Developer service connection is missing."))?,None)
    } else {
        let (socket,handle)=tokio::time::timeout(Duration::from_secs(20),remote_screenshot_service(&provider)).await??;
        (socket,Some(handle))
    };
    let mut client=RemoteServerClient::new(socket);
    if _tunnel.is_some() {
        let mut capabilities=plist::Dictionary::new();
        capabilities.insert("com.apple.private.DTXBlockCompression".into(),plist::Value::Integer(0.into()));
        capabilities.insert("com.apple.private.DTXConnection".into(),plist::Value::Integer(1.into()));
        use idevice::dvt::message::AuxValue;
        client.call_method(0,Some(plist::Value::String("_notifyOfPublishedCapabilities:".into())),Some(vec![AuxValue::archived_value(plist::Value::Dictionary(capabilities))]),false).await?;
    }
    if let Some(bundle)=launch_bundle {
        let mut process=idevice::dvt::process_control::ProcessControlClient::new(&mut client).await?;
        tokio::time::timeout(Duration::from_secs(15),process.launch_app(&bundle,None,None,false,false)).await??;
        println!("DirectSide launch requested. Verify the foreground screen with a screenshot.");return Ok(())
    }
    if probe {
        let _=tokio::time::timeout(Duration::from_secs(10),ScreenshotClient::new(&mut client)).await??;
        println!("USB pairing and screenshot channel work. No screenshot captured.");return Ok(())
    }
    let output=PathBuf::from(&args[0]);
    if output.extension().is_none_or(|ext|ext!="png") || output.exists() {bail!("Choose a new .png output file.");}
    let png=tokio::time::timeout(Duration::from_secs(15),async {
        let mut screenshot=ScreenshotClient::new(&mut client).await?;
        screenshot.take_screenshot().await
    }).await??;
    if !png.starts_with(b"\x89PNG\r\n\x1a\n") || png.len()>32*1024*1024 {bail!("Screenshot response is not a bounded PNG image.");}
    std::fs::write(&output,&png)?;
    println!("Saved screenshot locally ({} bytes). Review before adding it to README.",png.len());
    Ok(())
}
