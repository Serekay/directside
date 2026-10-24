use std::{io::{self, Write}, path::PathBuf, time::Duration};
use idevice::{IdeviceService, lockdown::LockdownClient, usbmuxd::{UsbmuxdAddr, UsbmuxdConnection}};
use isideload::{
    anisette::{local::LocalAnisetteProvider, AnisetteProvider, AnisetteDataResponse},
    auth::apple_account::{AppleAccount, AppToken, TwoFactorCallbackParams, TwoFactorCallbackResponse},
    dev::{developer_session::DeveloperSession, teams::DeveloperTeam},
    sideload::{SideloaderBuilder, TeamSelection, builder::MaxCertsBehavior, sideloader::Sideloader},
    util::{callbacks::{ExtensionsBehaviorCallbackBox, MaxCertsCallbackBox}, keyring_storage::KeyringStorage, storage::SideloadingStorage},
};
use rootcause::prelude::*;
use serde_json::{Value, json};

type Engine = Sideloader<MaxCertsCallbackBox, ExtensionsBehaviorCallbackBox>;

fn emit(value: Value) {
    if let Some(b)=crate::BRIDGE.get() {
        if let Ok(mut q)=b.output.lock() { q.push_back(value.to_string()); }
        return;
    }
    let mut out = io::stdout().lock();
    let _ = writeln!(out, "{}", value);
    let _ = out.flush();
}

fn read() -> Result<Value, Report> {
    if let Some(b)=crate::BRIDGE.get() {
        let line=b.receiver.lock().map_err(|_|report!("Eingabekanal nicht verfügbar"))?.recv()?;
        return Ok(serde_json::from_str(&line)?);
    }
    let mut line = String::new();
    if io::stdin().read_line(&mut line)? == 0 { bail!("Die Verbindung zur Oberfläche wurde beendet."); }
    if line.len() > 131072 { bail!("Anfrage zu groß."); }
    Ok(serde_json::from_str(&line)?)
}

fn text<'a>(v: &'a Value, key: &str) -> Result<&'a str, Report> {
    v.get(key).and_then(Value::as_str).ok_or_else(|| report!("Feld fehlt: {}", key))
}

async fn devices() -> Result<Value, Report> {
    let mut mux = UsbmuxdConnection::default().await?;
    let list = mux.get_devices().await?;
    let mut result = Vec::new();
    for dev in list {
        let provider = dev.to_provider(UsbmuxdAddr::from_env_var()?, "DirectSide");
        let name = match tokio::time::timeout(Duration::from_secs(8), async {
            let mut l = LockdownClient::connect(&provider).await?;
            l.get_value(Some("DeviceName"), None).await
        }).await {
            Ok(Ok(name)) => name.as_string().unwrap_or("Apple-Gerät").to_string(),
            _ => "Apple-Gerät – entsperren / Vertrauen prüfen".to_string(),
        };
        result.push(json!({"id":dev.udid,"name":name}));
    }
    Ok(json!({"event":"devices", "devices":result}))
}

fn app_present(apps:&std::collections::HashMap<String,plist::Value>,bundle:&str,allow_team_suffix:bool)->bool {
    apps.keys().any(|id|id==bundle || (allow_team_suffix && id.strip_prefix(bundle).is_some_and(|suffix|suffix.starts_with('.') && suffix.len()>1)))
}

async fn device_components(request:&Value)->Result<(),Report> {
    let id=text(request,"device_id")?;
    let mut mux=UsbmuxdConnection::default().await?;
    let dev=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("iPhone nicht mehr verbunden."))?;
    let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?;
    let apps=proxy.get_apps(Some("User"),None).await?;
    let developer=developer_apps(&apps);
    let mut overview:Vec<Value>=apps.iter().filter_map(|(bundle,value)| {
        let info=value.as_dictionary()?;
        Some(json!({"id":bundle,"name":info.get("CFBundleDisplayName").or_else(||info.get("CFBundleName")).and_then(plist::Value::as_string).unwrap_or(bundle),"developer":developer.iter().any(|app|app["id"].as_str()==Some(bundle.as_str()))}))
    }).collect();
    overview.sort_by_key(|app|(!app["developer"].as_bool().unwrap_or(false),app["name"].as_str().unwrap_or("").to_lowercase()));
    emit(json!({"event":"device_components","device_id":id,"localdevvpn":app_present(&apps,"com.jkcoxson.LocalDevVPN",false),"livecontainer":app_present(&apps,"com.kdt.livecontainer",true),"directside":app_present(&apps,"com.directside.app",true),"slots_used":developer.len(),"developer_apps":developer,"apps":overview}));
    Ok(())
}

async fn app_icons(request:&Value)->Result<(),Report> {
    use base64::Engine as _;
    let id=text(request,"device_id")?;
    let bundles=request["bundles"].as_array().ok_or_else(||report!("App-Auswahl fehlt."))?;
    if bundles.len()>12 {bail!("Zu viele Icons angefragt.");}
    let mut mux=UsbmuxdConnection::default().await?;
    let dev=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("Gerät nicht verbunden."))?;
    let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut spring=idevice::springboardservices::SpringBoardServicesClient::connect(&provider).await?;
    let mut icons=Vec::new();
    for bundle in bundles {
        let Some(bundle)=bundle.as_str() else {continue};
        let png=match tokio::time::timeout(Duration::from_secs(2),spring.get_icon_pngdata(bundle.to_string())).await {
            Ok(Ok(data)) if data.len()<=1024*1024=>base64::prelude::BASE64_STANDARD.encode(data),
            _=>String::new(),
        };
        icons.push(json!({"id":bundle,"png":png}));
    }
    emit(json!({"event":"app_icons","device_id":id,"icons":icons}));Ok(())
}

async fn prepare_livecontainer(engine:&mut Engine,request:&Value)->Result<(),Report> {
    let id=text(request,"device_id")?;
    let mut mux=UsbmuxdConnection::default().await?;
    let dev=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("iPhone nicht mehr verbunden."))?;
    let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let team=engine.get_team().await?;
    let bytes=engine.livecontainer_certificate().await?;
    let mut afc=idevice::house_arrest::HouseArrestClient::connect(&provider).await?.vend_documents(format!("com.directside.app.{}",team.team_id)).await?;
    let mut file=afc.open("/Documents/DirectSide-livecontainer.json",idevice::afc::opcode::AfcFopenMode::WrOnly).await?;
    file.write_entire(&bytes).await?;file.close().await?;
    emit(json!({"event":"livecontainer_prepared","device_id":id}));
    Ok(())
}

fn choose_team(teams: &Vec<DeveloperTeam>) -> Option<String> {
    emit(json!({"event":"choose_team", "teams":teams.iter().map(|t|json!({"id":t.team_id,"name":t.name,"type":t.r#type})).collect::<Vec<_>>()}));
    let r = read().ok()?;
    let id = r.get("team_id")?.as_str()?;
    teams.iter().find(|t| t.team_id == id).map(|t|t.team_id.clone())
}

async fn second_factor(p: TwoFactorCallbackParams) -> Result<TwoFactorCallbackResponse, Report> {
    emit(json!({"event":"two_factor", "unknown":p.unknown,"sms":p.sms,"numbers":p.numbers,"last_error":p.last_error}));
    let r = read()?;
    Ok(match r.get("action").and_then(Value::as_str).unwrap_or("code") {
        "devices" => TwoFactorCallbackResponse::SendToDevices,
        "resend" => TwoFactorCallbackResponse::ResendCode,
        "sms" => TwoFactorCallbackResponse::SendSms(r.get("number_id").and_then(Value::as_u64).ok_or_else(||report!("Telefonnummer fehlt"))? as u32),
        "cancel" => TwoFactorCallbackResponse::Abort,
        _ => {
            let code = text(&r,"code")?.trim();
            if code.len()!=6 || !code.bytes().all(|b|b.is_ascii_digit()) { bail!("Der Bestätigungscode muss sechs Ziffern haben."); }
            TwoFactorCallbackResponse::SubmitCode(code.to_string())
        }
    })
}

async fn login(request: &Value) -> Result<Engine, Report> {
    let email = text(request,"email")?.trim();
    let password = text(request,"password")?;
    emit(json!({"event":"status","message":"Apple-Anmeldung wird aufgebaut …"}));
    let provider = LocalAnisetteProvider::new()?;
    let mut account = AppleAccount::builder(email)
        .anisette_provider(provider)
        .err_429_retries(Some(1))
        .login(password, second_factor).await?;
    emit(json!({"event":"status","message":"Anmeldung bestätigt. Developer-Team wird geladen …"}));
    let session = DeveloperSession::from_account(&mut account).await?;
    let (token,adsid)=session.session_credentials();
    let secret=json!({"email":email,"auth":"local","token":token.token,"adsid":adsid,"duration":token.duration,"expiry":token.expiry});
    // Session tokens, not passwords; stored only in the OS credential store.
    KeyringStorage::new("DirectSide.session".to_string()).store_data("active",&serde_json::to_vec(&secret)?)?;
    make_engine(session,email).await
}

async fn make_engine(session:DeveloperSession,email:&str)->Result<Engine,Report> {
    let mut engine = SideloaderBuilder::<MaxCertsCallbackBox, ExtensionsBehaviorCallbackBox>::new(session,email.to_string())
        .team_selection(TeamSelection::PromptOnce(choose_team))
        .max_certs_behavior(MaxCertsBehavior::Error)
        .machine_name(if cfg!(target_os="ios") {"DirectSide iPhone"}else{"DirectSide Windows"}.to_string())
        .storage(Box::new(KeyringStorage::new("DirectSide.signing".to_string())))
        .build();
    let team = engine.get_team().await?;
    emit(json!({"event":"logged_in","team":team.name,"team_id":team.team_id,"type":team.r#type,"email":email}));
    Ok(engine)
}

async fn restore()->Result<Option<Engine>,Report> {
    let Some(bytes)=KeyringStorage::new("DirectSide.session".to_string()).retrieve_data("active")? else {return Ok(None)};
    let saved:Value=serde_json::from_slice(&bytes)?;
    let email=text(&saved,"email")?;
    let provider=LocalAnisetteProvider::new()?;
    let account=AppleAccount::builder(email).anisette_provider(provider).err_429_retries(Some(1)).build().await?;
    let token=AppToken {token:text(&saved,"token")?.to_string(),duration:saved["duration"].as_u64().unwrap_or(0),expiry:saved["expiry"].as_u64().unwrap_or(0)};
    let session=DeveloperSession::new(token,text(&saved,"adsid")?.to_string(),account.grandslam_client,account.anisette_generator);
    Ok(Some(make_engine(session,email).await?))
}

async fn probe_local_auth()->Result<(),Report> {
    let mut provider=LocalAnisetteProvider::new()?;
    let mut data=provider.get_anisette_data().await?;
    if !matches!(data,AnisetteDataResponse::Data(_)) {
        let gs=std::sync::Arc::new(isideload::auth::grandslam::GrandSlam::new(provider.get_client_info().await?,false,None).await?);
        provider.provision(&gs,false).await?;
        data=provider.get_anisette_data().await?;
    }
    let AnisetteDataResponse::Data(data)=data else {bail!("Lokale Apple-Einrichtung ist unvollständig.");};
    let headers=data.get_headers();
    emit(json!({"event":"local_auth_ready","mode":"local","machine_data_present":headers.get("X-Apple-I-MD-M").is_some_and(|v|!v.is_empty()),"otp_present":headers.get("X-Apple-I-MD").is_some_and(|v|!v.is_empty())}));
    Ok(())
}

fn profile_expiry(path:&std::path::Path)->Option<String> {
    let bytes=std::fs::read(path).ok()?;
    let profile=apple_codesign_quick::ProvisioningProfile::parse(&bytes).ok()?;
    profile.plist().get("ExpirationDate")?.as_date().map(|d|d.to_xml_format())
}

async fn install(engine: &mut Engine, request: &Value) -> Result<(), Report> {
    let id = text(request,"device_id")?;
    let path = PathBuf::from(text(request,"path")?);
    if !path.is_file() || !path.extension().is_some_and(|x|x.eq_ignore_ascii_case("ipa")) { bail!("Bitte eine vorhandene IPA-Datei auswählen."); }
    let mut mux = UsbmuxdConnection::default().await?;
    let dev = mux.get_devices().await?.into_iter().find(|d|d.udid == id)
        .ok_or_else(||report!("Das ausgewählte Gerät ist nicht mehr verbunden. Bitte neu verbinden und Geräte aktualisieren."))?;
    let provider = dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?;
    let installed=proxy.get_apps(Some("User"),None).await?;
    let team=engine.get_team().await?;
    let target=request.get("bundle_id").and_then(Value::as_str).map(|b|format!("{}.{}",b,team.team_id));
    check_slots(&installed,target.as_deref())?;
    emit(json!({"event":"status","message":"Gerät prüfen, signieren und installieren …"}));
    engine.install_app(&provider,path.clone(),false,Some(|p:f32| async move {
        emit(json!({"event":"progress","value":(p*85.0).clamp(0.0,85.0)}));
    }),None).await?;
    if request.get("bootstrap").and_then(Value::as_bool)==Some(true) {
        bootstrap(engine,&provider,&path).await?;
    }
    emit(json!({"event":"installed","path":request["path"],"device_id":id}));
    Ok(())
}

async fn bootstrap(engine: &mut Engine, provider: &impl idevice::provider::IdeviceProvider, ipa: &std::path::Path) -> Result<(),Report> {
    use idevice::{remote_pairing::{RemotePairingLockdownService,RpPairingFile},house_arrest::HouseArrestClient};
    emit(json!({"event":"status","message":"Remote-Pairing für DirectSide einrichten …"}));
    let info=isideload::util::device::IdeviceInfo::from_device(provider).await?;
    let service=RemotePairingLockdownService::connect(provider).await?;
    let mut client=service.into_client("DirectSide Windows")?;
    let mut pairing=RpPairingFile::generate("DirectSide Windows");
    client.connect(&mut pairing,||async {
        emit(json!({"event":"pairing_pin"}));
        read().ok().and_then(|r|r.get("code").and_then(Value::as_str).map(str::to_string)).unwrap_or_default()
    }).await?;
    let team=engine.get_team().await?;
    let bundle=format!("com.directside.app.{}",team.team_id);
    let mut afc=HouseArrestClient::connect(provider).await?.vend_container(bundle).await?;
    for (name,data) in [
        ("DirectSide-pairing.plist",pairing.to_bytes()),
        ("DirectSide-bootstrap.json",serde_json::to_vec(&json!({"udid":info.udid,"name":info.name}))?),
        ("DirectSide-original.ipa",std::fs::read(ipa)?),
    ] {
        let mut f=afc.open(format!("/Documents/{name}"),idevice::afc::opcode::AfcFopenMode::WrOnly).await?;
        for chunk in data.chunks(512*1024) {f.write_entire(chunk).await?;}
        f.close().await?;
    }
    emit(json!({"event":"status","message":"DirectSide ist installiert. Pairing und Original-IPA wurden übertragen."}));
    Ok(())
}

async fn connect_local(request: &Value) -> Result<(idevice::tcp::handle::AdapterHandle,idevice::rsd::RsdHandshake),Report> {
    use idevice::{remote_pairing::{RemotePairingClient,RpPairingFile,RpPairingSocket,connect_tls_psk_tunnel_native},rsd::RsdHandshake};
    let peer=text(request,"peer")?;
    let port=request.get("port").and_then(Value::as_u64).filter(|p|*p>0 && *p<=65535).ok_or_else(||report!("Remote-Pairing-Port fehlt. Verbindung in den Einstellungen prüfen."))? as u16;
    let mut record=RpPairingFile::from_bytes(&std::fs::read(text(request,"pairing_path")?)?)?;
    emit(json!({"event":"status","message":"LocalDevVPN-Verbindung und Remote-Pairing prüfen …"}));
    let stream=tokio::time::timeout(Duration::from_secs(10),tokio::net::TcpStream::connect((peer,port))).await??;
    let mut client=RemotePairingClient::new(RpPairingSocket::new(stream),"DirectSide Windows");
    client.attempt_pair_verify().await?;
    client.validate_pairing(&mut record).await?;
    let tunnel_port=client.create_tcp_listener().await?;
    let transport=tokio::net::TcpStream::connect((peer,tunnel_port)).await?;
    let tunnel=connect_tls_psk_tunnel_native(transport,client.encryption_key()).await?;
    let rsd_port=tunnel.info.server_rsd_port;
    let local_ip:std::net::IpAddr=tunnel.info.client_address.parse()?;
    let remote_ip:std::net::IpAddr=tunnel.info.server_address.parse()?;
    let mtu=tunnel.info.mtu;
    let mut adapter=idevice::tcp::adapter::Adapter::new(Box::new(tunnel.into_inner()),local_ip,remote_ip);
    adapter.set_mss((mtu as usize).saturating_sub(60));
    let mut handle=adapter.to_async_handle();
    let rsd=RsdHandshake::new(handle.connect(rsd_port).await?).await?;
    Ok((handle,rsd))
}

fn developer_apps(installed:&std::collections::HashMap<String,plist::Value>)->Vec<Value> {
    installed.iter().filter_map(|(id,value)|{
        let d=value.as_dictionary()?;
        let signer=d.get("SignerIdentity").and_then(plist::Value::as_string).unwrap_or("");
        let debug=d.get("Entitlements").and_then(plist::Value::as_dictionary).and_then(|e|e.get("get-task-allow")).and_then(plist::Value::as_boolean).unwrap_or(false);
        if debug || signer.contains("iPhone Developer") || signer.contains("Apple Development") {
            Some(json!({"id":id,"name":d.get("CFBundleDisplayName").and_then(plist::Value::as_string).unwrap_or(id)}))
        } else {None}
    }).collect()
}

fn check_slots(installed:&std::collections::HashMap<String,plist::Value>,target:Option<&str>)->Result<(),Report> {
    let developer=developer_apps(installed);
    emit(json!({"event":"slots","used":developer.len(),"limit":3,"apps":developer}));
    if let Some(target)=target {
        if developer.len()>=3 && !installed.contains_key(target) {bail!("Die drei Plätze für selbst signierte Apps sind belegt. Updates und Erneuerungen bestehender Apps bleiben möglich. Für weitere kompatible Apps kannst du LiveContainer verwenden.");}
    }
    Ok(())
}

async fn inspect_local(request:&Value)->Result<(),Report> {
    use idevice::RsdService;
    let(mut handle,mut rsd)=connect_local(request).await?;
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect_rsd(&mut handle,&mut rsd).await?;
    check_slots(&proxy.get_apps(Some("User"),None).await?,None)
}

async fn install_local(engine: &mut Engine, request: &Value) -> Result<(),Report> {
    use idevice::RsdService;
    use isideload::dev::devices::DevicesApi;
    let path=PathBuf::from(text(request,"path")?);
    if !path.is_file() || !path.extension().is_some_and(|x|x.eq_ignore_ascii_case("ipa")) {bail!("IPA-Datei fehlt.");}
    let udid=text(request,"udid")?;
    let name=text(request,"device_name")?;
    let(mut handle,mut rsd)=connect_local(request).await?;
    let team=engine.get_team().await?;
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect_rsd(&mut handle,&mut rsd).await?;
    let target=text(request,"bundle_id").map(|b|format!("{}.{}",b,team.team_id))?;
    check_slots(&proxy.get_apps(Some("User"),None).await?,Some(&target))?;
    engine.get_dev_session().ensure_device_registered(&team,name,udid,None).await?;
    emit(json!({"event":"status","message":"IPA wird auf dem iPhone signiert …"}));
    let (signed,_)=engine.sign_app(path,Some(team),false,Some(|p:f32|async move {emit(json!({"event":"progress","value":p*55.0}));}),None,Some(udid)).await?;
    emit(json!({"event":"status","message":"Signierte App wird installiert …"}));
    let expires_at=profile_expiry(&signed.join("embedded.mobileprovision"));
    let result=isideload::sideload::install::install_app_rsd(&mut handle,&mut rsd,&signed,|p|emit(json!({"event":"progress","value":55.0+(p as f64)*0.45}))).await;
    let _=std::fs::remove_dir_all(&signed);
    result?;
    emit(json!({"event":"installed","path":request["path"],"device_id":udid,"expires_at":expires_at}));
    Ok(())
}

#[tokio::main]
pub async fn run() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    if let Err(e) = isideload::init() { emit(json!({"event":"error","message":e.to_string()})); return; }
    emit(json!({"event":"ready","version":env!("CARGO_PKG_VERSION")}));
    let mut engine: Option<Engine> = None;
    while let Ok(mut request) = read() {
        let command = request.get("command").and_then(Value::as_str).unwrap_or("").to_string();
        let result: Result<(),Report> = match command.as_str() {
            "devices" => match tokio::time::timeout(Duration::from_secs(25),devices()).await {
                Ok(Ok(v)) => {emit(v);Ok(())},
                Ok(Err(e)) => Err(e),
                Err(_) => Err(report!("Die Geräteerkennung antwortet nicht. Apple-USB-Verbindung prüfen.")),
            },
            "local_auth_probe" => match tokio::time::timeout(Duration::from_secs(45),probe_local_auth()).await {Ok(r)=>r,Err(_)=>Err(report!("Lokale Apple-Einrichtung hat zu lange gedauert."))},
            "device_components" => match tokio::time::timeout(Duration::from_secs(20),device_components(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("App-Prüfung nicht möglich. iPhone entsperren und Vertrauen bestätigen."))},
            "app_icons" => match tokio::time::timeout(Duration::from_secs(25),app_icons(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("Icons konnten nicht geladen werden."))},
            "prepare_livecontainer" => match engine.as_mut() {Some(e)=>prepare_livecontainer(e,&request).await,None=>Err(report!("Bitte zuerst anmelden."))},
            "restore" => {
                match tokio::time::timeout(Duration::from_secs(45),restore()).await {
                    Ok(Ok(Some(e)))=>{engine=Some(e);Ok(())},
                    Ok(Err(e))=>{emit(json!({"event":"status","message":format!("Gespeicherte Sitzung konnte lokal nicht übernommen werden: {e}")}));emit(json!({"event":"logged_out"}));Ok(())},
                    _=>{emit(json!({"event":"logged_out"}));Ok(())},
                }
            },
            "profile"=>{emit(json!({"event":"profile","expires_at":profile_expiry(std::path::Path::new(text(&request,"path").unwrap_or("")))}));Ok(())},
            "inspect_local"=>match tokio::time::timeout(Duration::from_secs(25),inspect_local(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("Verbindung zum lokalen Gerät hat zu lange gedauert. LocalDevVPN prüfen."))},
            "login" => {
                engine = None;
                let result = tokio::time::timeout(Duration::from_secs(300),login(&request)).await;
                // Do not retain the password in the protocol request after authentication.
                request.as_object_mut().map(|m|m.remove("password"));
                match result {
                    Ok(Ok(e)) => {engine=Some(e);Ok(())},
                    Ok(Err(e)) => Err(e),
                    Err(_) => Err(report!("Die Anmeldung hat zu lange gedauert. Bitte erneut anmelden.")),
                }
            },
            "install" => match engine.as_mut() {
                Some(e) => install(e,&request).await,
                None => Err(report!("Bitte zuerst mit deiner Apple-ID anmelden.")),
            },
            "install_local" => match engine.as_mut() {
                Some(e)=>install_local(e,&request).await,
                None=>Err(report!("Bitte zuerst anmelden.")),
            },
            "logout" => {engine=None;let _=KeyringStorage::new("DirectSide.session".to_string()).delete("active");emit(json!({"event":"logged_out"}));Ok(())},
            "quit" => break,
            _ => Err(report!("Unbekannter Befehl.")),
        };
        if let Err(e) = result { emit(json!({"event":"error","command":command,"message":format!("{e}")})); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn component_detection_accepts_team_suffix_but_not_similar_app_names() {
        let mut apps=std::collections::HashMap::new();
        apps.insert("com.kdt.livecontainer.TEAM".into(),plist::Value::Boolean(true));
        apps.insert("com.jkcoxson.LocalDevVPN.fake".into(),plist::Value::Boolean(true));
        assert!(app_present(&apps,"com.kdt.livecontainer",true));
        assert!(!app_present(&apps,"com.kdt.live",true));
        assert!(!app_present(&apps,"com.jkcoxson.LocalDevVPN",false));
    }
    #[test]
    fn three_slots_allow_existing_app_refresh_but_block_new_app() {
        let mut apps=std::collections::HashMap::new();
        for id in ["one","two","three"] {
            let mut d=plist::Dictionary::new();d.insert("SignerIdentity".into(),plist::Value::String("Apple Development: Test".into()));apps.insert(id.to_string(),plist::Value::Dictionary(d));
        }
        assert!(check_slots(&apps,Some("one")).is_ok());
        assert!(check_slots(&apps,Some("four")).is_err());
    }
}
