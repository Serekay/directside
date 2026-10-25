use std::{io::{self, Write}, path::PathBuf, time::Duration};
use idevice::{IdeviceService, lockdown::LockdownClient, usbmuxd::{UsbmuxdAddr, UsbmuxdConnection}};
use isideload::{
    anisette::{local::LocalAnisetteProvider, AnisetteProvider, AnisetteDataResponse},
    auth::apple_account::{AppleAccount, AppToken, TwoFactorCallbackParams, TwoFactorCallbackResponse},
    dev::{developer_session::DeveloperSession, teams::DeveloperTeam, app_ids::{AppIdsApi,ListAppIdsResponse},certificates::CertificatesApi},
    sideload::{SideloaderBuilder, TeamSelection, builder::MaxCertsBehavior, sideloader::Sideloader},
    util::{callbacks::{ExtensionsBehaviorCallbackBox, MaxCertsCallbackBox}, keyring_storage::KeyringStorage, storage::SideloadingStorage},
};
use rootcause::prelude::*;
use serde_json::{Value, json};
use base64::Engine as _;

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
    let developer=sideload_apps(&apps);
    let mut overview:Vec<Value>=apps.iter().filter_map(|(bundle,value)| {
        let info=value.as_dictionary()?;
        Some(json!({"id":bundle,"name":info.get("CFBundleDisplayName").or_else(||info.get("CFBundleName")).and_then(plist::Value::as_string).unwrap_or(bundle),"developer":developer.iter().any(|app|app["id"].as_str()==Some(bundle.as_str()))}))
    }).collect();
    overview.sort_by_key(|app|(!app["developer"].as_bool().unwrap_or(false),app["name"].as_str().unwrap_or("").to_lowercase()));
    let developer_mode=tokio::time::timeout(Duration::from_secs(3),async {
        idevice::amfi::AmfiClient::connect(&provider).await?.get_developer_mode_status().await
    }).await.ok().and_then(Result::ok);
    emit(json!({"event":"device_components","device_id":id,"developer_mode":developer_mode,"localdevvpn":app_present(&apps,"com.jkcoxson.LocalDevVPN",false),"livecontainer":app_present(&apps,"com.kdt.livecontainer",true),"directside":app_present(&apps,"com.directside.app",true),"slots_used":developer.len(),"developer_apps":developer,"apps":overview}));
    Ok(())
}

async fn reveal_developer_mode(request:&Value)->Result<(),Report> {
    let id=text(request,"device_id")?;
    let mut mux=UsbmuxdConnection::default().await?;
    let device=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("iPhone nicht mehr verbunden."))?;
    let provider=device.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut amfi=idevice::amfi::AmfiClient::connect(&provider).await?;
    amfi.reveal_developer_mode_option_in_ui().await?;
    emit(json!({"event":"developer_mode_revealed","device_id":id}));Ok(())
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

async fn remove_device_app(request:&Value)->Result<(),Report> {
    require_confirmation(request)?;
    let id=text(request,"device_id")?;let bundle=text(request,"bundle_id")?;
    let mut mux=UsbmuxdConnection::default().await?;
    let device=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("Gerät nicht verbunden."))?;
    let provider=device.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?;
    if !sideload_apps(&proxy.get_apps(Some("User"),None).await?).iter().any(|app|app["id"].as_str()==Some(bundle)) {bail!("Nur installierte Sideload-Apps können hier entfernt werden.");}
    proxy.uninstall(bundle,None).await?;
    emit(json!({"event":"app_removed","device_id":id,"bundle_id":bundle}));Ok(())
}

fn require_confirmation(request:&Value)->Result<(),Report> {
    if request.get("confirmed").and_then(Value::as_bool)!=Some(true) {bail!("Entfernen wurde nicht bestätigt.");}
    Ok(())
}

async fn certificates(engine:&mut Engine)->Result<(),Report> {
    use isideload::sideload::cert_identity::CertificateIdentity;
    let team=engine.get_team().await?;
    // Management must show every record returned by Apple's iOS endpoint,
    // including certificates with a shared/unknown platform. Signing selection
    // keeps its own compatibility checks.
    let records=engine.get_dev_session().list_all_development_certs(&team,isideload::dev::device_type::DeveloperDeviceType::Ios).await?;
    let storage=KeyringStorage::new("DirectSide.signing".to_string());
    let mut overview=Vec::new();
    for cert in records {
        let reusable=match &cert.cert_content {Some(bytes)=>CertificateIdentity::stored_key_matches(engine.get_email(),&storage,bytes.as_ref()).unwrap_or(false),None=>false};
        overview.push(json!({"serial":cert.serial_number.unwrap_or_default(),"name":cert.machine_name.or(cert.name).unwrap_or_else(||"Apple Development".into()),"platform":cert.certificate_platform.or_else(||cert.certificate_type.and_then(|kind|kind.platform)),"expires":cert.expiration_date.map(|d|d.to_xml_format()),"reusable":reusable}));
    }
    emit(json!({"event":"certificates","team_id":team.team_id,"team":team.name,"certificates":overview}));Ok(())
}

async fn revoke_certificate(engine:&mut Engine,request:&Value)->Result<(),Report> {
    require_confirmation(request)?;
    let team=engine.get_team().await?;
    if text(request,"team_id")?!=team.team_id {bail!("Developer-Team hat sich geändert. Zertifikate neu laden.");}
    let serial=text(request,"serial")?;
    let existing=engine.get_dev_session().list_all_development_certs(&team,isideload::dev::device_type::DeveloperDeviceType::Ios).await?;
    if !existing.iter().any(|cert|cert.serial_number.as_deref()==Some(serial)) {bail!("Zertifikat ist nicht mehr vorhanden. Liste neu laden.");}
    engine.get_dev_session().revoke_development_cert(&team,serial,isideload::dev::device_type::DeveloperDeviceType::Ios).await?;
    emit(json!({"event":"certificate_revoked","serial":serial,"team_id":team.team_id}));
    certificates(engine).await
}

async fn prepare_livecontainer(engine:&mut Engine,request:&Value)->Result<(),Report> {
    let bytes=engine.livecontainer_certificate().await?;
    transfer_livecontainer(request,&bytes).await
}
async fn transfer_livecontainer(request:&Value,bytes:&[u8])->Result<(),Report> {
    let id=text(request,"device_id")?;
    let mut mux=UsbmuxdConnection::default().await?;
    let dev=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("iPhone nicht mehr verbunden."))?;
    let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let apps=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?.get_apps(Some("User"),None).await?;
    let targets:Vec<_>=apps.keys().filter(|id|*id=="com.directside.app" || id.starts_with("com.directside.app.")).collect();
    if targets.len()!=1 {bail!("DirectSide auf diesem iPhone öffnen und das Zertifikat dort übertragen.");}
    let mut afc=idevice::house_arrest::HouseArrestClient::connect(&provider).await?.vend_documents(targets[0].clone()).await?;
    let mut file=afc.open("/Documents/DirectSide-livecontainer.json",idevice::afc::opcode::AfcFopenMode::WrOnly).await?;
    file.write_entire(bytes).await?;file.close().await?;
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
    save_session(&session,email,account.spd.as_ref())?;
    make_engine(session,email).await
}

fn save_session(session:&DeveloperSession,email:&str,spd:Option<&plist::Dictionary>)->Result<(),Report> {
    let (token,adsid)=session.session_credentials();
    let mut secret=json!({"email":email,"auth":"local","token":token.token,"adsid":adsid,"duration":token.duration,"expiry":token.expiry});
    if let Some(spd)=spd {
        let refresh:plist::Dictionary=["adsid","GsIdmsToken","sk","c"].iter().filter_map(|key|spd.get(*key).map(|value|((*key).to_string(),value.clone()))).collect();
        if refresh.len()==4 {
            let mut bytes=Vec::new();plist::to_writer_binary(&mut bytes,&refresh)?;secret["refresh"]=json!(base64::prelude::BASE64_STANDARD.encode(bytes));
        }
    }
    // Session tokens, not passwords; stored only in the OS credential store.
    KeyringStorage::new("DirectSide.session".to_string()).store_data("active",&serde_json::to_vec(&secret)?)?;
    Ok(())
}

async fn make_engine(session:DeveloperSession,email:&str)->Result<Engine,Report> {
    let storage=KeyringStorage::new("DirectSide.signing".to_string());
    let machine=isideload::sideload::cert_identity::CertificateIdentity::stored_machine_name(email,&storage)?.unwrap_or_else(||if cfg!(target_os="ios") {"DirectSide iPhone"}else{"DirectSide Windows"}.to_string());
    let mut engine = SideloaderBuilder::<MaxCertsCallbackBox, ExtensionsBehaviorCallbackBox>::new(session,email.to_string())
        .team_selection(TeamSelection::PromptOnce(choose_team))
        .max_certs_behavior(MaxCertsBehavior::Error)
        .machine_name(machine)
        .storage(Box::new(storage))
        .build();
    let team = engine.get_team().await?;
    let quota=tokio::time::timeout(Duration::from_secs(12),engine.get_dev_session().list_app_ids(&team,None)).await;
    emit(json!({"event":"logged_in","team":team.name,"team_id":team.team_id,"type":team.r#type,"email":email}));
    match quota {Ok(Ok(q))=>emit(quota_event(&q)),_=>emit(json!({"event":"account_quota","limit":null,"available":null,"registered":-1}))};
    Ok(engine)
}

fn quota_event(q:&ListAppIdsResponse)->Value {
    // Apple's rolling registration allowance is not the number of existing IDs.
    json!({"event":"account_quota","limit":q.max_quantity,"available":q.available_quantity.map(|n|n.max(0)),"registered":q.app_ids.len()})
}

async fn refresh_account_quota(engine:&mut Engine) {
    let result=tokio::time::timeout(Duration::from_secs(12),async {
        let team=engine.get_team().await?;
        engine.get_dev_session().list_app_ids(&team,None).await
    }).await;
    match result {Ok(Ok(q))=>emit(quota_event(&q)),_=>emit(json!({"event":"account_quota","limit":null,"available":null,"registered":-1}))};
}

async fn restore()->Result<Option<Engine>,Report> {
    let Some(bytes)=KeyringStorage::new("DirectSide.session".to_string()).retrieve_data("active")? else {return Ok(None)};
    let saved:Value=serde_json::from_slice(&bytes)?;
    let email=text(&saved,"email")?;
    let provider=LocalAnisetteProvider::new()?;
    let mut account=AppleAccount::builder(email).anisette_provider(provider).err_429_retries(Some(1)).build().await?;
    let token=AppToken {token:text(&saved,"token")?.to_string(),duration:saved["duration"].as_u64().unwrap_or(0),expiry:saved["expiry"].as_u64().unwrap_or(0)};
    let session=DeveloperSession::new(token,text(&saved,"adsid")?.to_string(),account.grandslam_client.clone(),account.anisette_generator.clone());
    match make_engine(session,email).await {
        Ok(engine)=>Ok(Some(engine)),
        Err(error) if error.to_string().contains("1100") && saved.get("refresh").is_some()=>{
            let bytes=base64::prelude::BASE64_STANDARD.decode(text(&saved,"refresh")?)?;
            if bytes.len()>65536 {bail!("Gespeicherte Sitzung ist ungültig.");}
            let spd:plist::Dictionary=plist::from_bytes(&bytes)?;
            if spd.get("adsid").and_then(plist::Value::as_string)!=saved.get("adsid").and_then(Value::as_str) {bail!("Gespeicherte Sitzung gehört zu einem anderen Account.");}
            account.spd=Some(spd);
            let fresh=DeveloperSession::from_account(&mut account).await?;
            save_session(&fresh,email,account.spd.as_ref())?;
            Ok(Some(make_engine(fresh,email).await?))
        },
        Err(error)=>Err(error),
    }
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

fn check_signed_slots(installed:&std::collections::HashMap<String,plist::Value>,signed:&std::path::Path)->Result<String,Report> {
    let info:plist::Dictionary=plist::from_file(signed.join("Info.plist"))?;
    let target=info.get("CFBundleIdentifier").and_then(plist::Value::as_string).ok_or_else(||report!("Signierte App-Kennung fehlt."))?.to_string();
    let profile=apple_codesign_quick::ProvisioningProfile::parse(&std::fs::read(signed.join("embedded.mobileprovision"))?)?;
    if profile.plist().get("LocalProvision").and_then(plist::Value::as_boolean)==Some(true) {check_slots(installed,Some(&target))?;}
    else {emit(json!({"event":"slots","used":developer_apps(installed).len(),"limit":null,"apps":developer_apps(installed)}));}
    Ok(target)
}
fn validate_self_update(request:&Value,path:&std::path::Path)->Result<(),Report> {
    if let Some(version)=request["self_update_version"].as_str() {
        let info=isideload::sideload::application::inspect_ipa(path)?;
        if info.get("CFBundleIdentifier").and_then(plist::Value::as_string)!=Some("com.directside.app") || info.get("CFBundleShortVersionString").and_then(plist::Value::as_string)!=Some(version) {bail!("Die Update-IPA gehört nicht zu DirectSide oder hat eine andere Version.");}
    }
    Ok(())
}
fn validate_installed_target(request:&Value,target:&str)->Result<(),Report> {
    if let Some(expected)=request["expected_installed_bundle_id"].as_str() {
        if expected!=target {bail!("Zum Erneuern oder Aktualisieren von DirectSide dasselbe Signierteam und ein passendes Profil verwenden.");}
    }
    Ok(())
}
async fn install(engine:Option<&mut Engine>,request:&Value)->Result<(),Report> {
    use isideload::dev::devices::DevicesApi;
    let id=text(request,"device_id")?;
    let path=PathBuf::from(text(request,"path")?);
    if !path.is_file() || !path.extension().is_some_and(|x|x.eq_ignore_ascii_case("ipa")) {bail!("Bitte eine vorhandene IPA-Datei auswählen.");}
    let _temporary=isideload::sideload::application::ExtractionCleanup::new(&path)?;
    validate_self_update(request,&path)?;
    let info=isideload::sideload::application::inspect_ipa(&path)?;
    let directside=info.get("CFBundleIdentifier").and_then(plist::Value::as_string).is_some_and(|id|id=="com.directside.app" || id.starts_with("com.directside.app."));
    let livecontainer=info.get("CFBundleIdentifier").and_then(plist::Value::as_string)==Some("com.kdt.livecontainer");
    let mut mux=UsbmuxdConnection::default().await?;
    let dev=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("Das ausgewählte Gerät ist nicht mehr verbunden."))?;
    let provider=dev.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect(&provider).await?;
    let installed=proxy.get_apps(Some("User"),None).await?;
    let imported=request["signing_mode"].as_str()==Some("imported");
    let mut engine=engine;
    let signed=if imported {crate::imported_identity::sign(path.clone(),id).await?} else {
        let engine=engine.as_deref_mut().ok_or_else(||report!("Bitte zuerst anmelden."))?;
        let mut lockdown=LockdownClient::connect(&provider).await?;
        let name=lockdown.get_value(Some("DeviceName"),None).await?.as_string().unwrap_or("iPhone").to_string();
        let team=engine.get_team().await?;
        engine.get_dev_session().ensure_device_registered(&team,&name,id,None).await?;
        engine.sign_app(path.clone(),Some(team),false,Some(|p:f32|async move {emit(json!({"event":"progress","value":p*55.0}));}),None,Some(id)).await?.0
    };
    let installed_bundle_id=check_signed_slots(&installed,&signed)?;
    validate_installed_target(request,&installed_bundle_id)?;
    let expires_at=profile_expiry(&signed.join("embedded.mobileprovision"));
    isideload::sideload::install::install_app(&provider,&signed,|p|emit(json!({"event":"progress","value":55.0+(p as f64)*0.45}))).await?;
    if directside {bootstrap(if imported {None}else{engine.as_deref_mut()},&provider,&path,&installed_bundle_id).await?;}
    if livecontainer {
        // DirectSide forwards the certificate to LiveContainer when next opened.
        // A missing DirectSide installation must not turn a successful LC install
        // into an installation error.
        let transfer=if imported {
            match crate::imported_identity::load()? {Some(identity)=>transfer_livecontainer(request,&identity.livecontainer_certificate().await?).await,None=>Err(report!("Importiertes Zertifikat fehlt."))}
        }else if let Some(engine)=engine.as_deref_mut() {prepare_livecontainer(engine,request).await}else{Err(report!("Sitzung fehlt."))};
        if transfer.is_err() {emit(json!({"event":"status","message":"LiveContainer installiert. Zertifikat in DirectSide unter Einstellungen → LiveContainer übertragen."}));}
    }
    emit(json!({"event":"installed","path":request["path"],"device_id":id,"bootstrap_ready":directside,"installed_bundle_id":installed_bundle_id,"expires_at":expires_at}));Ok(())
}

async fn pairing_step<T>(message:&str,seconds:u64,future:impl std::future::Future<Output=Result<T,Report>>)->Result<T,Report> {
    emit(json!({"event":"status","message":message,"phase":"device_setup"}));
    tokio::time::timeout(Duration::from_secs(seconds),future).await.map_err(|_|report!("{} Zeitlimit erreicht. USB-Verbindung erneut herstellen und Einrichtung reparieren.",message))?
}

async fn usb_remote_pairing(provider:&impl idevice::provider::IdeviceProvider,udid:&str)->Result<idevice::remote_pairing::RpPairingFile,Report> {
    use idevice::remote_pairing::{RemotePairingLockdownService,RpPairingFile};
    let storage=KeyringStorage::new("DirectSide.pairing".into());
    let key=format!("device-{udid}");
    let cached=storage.retrieve_data(&key)?.and_then(|bytes|serde_json::from_slice::<Value>(&bytes).ok()).and_then(|v|{
        let host=v.get("host")?.as_str()?.to_string();
        let bytes:Vec<u8>=serde_json::from_value(v.get("record")?.clone()).ok()?;
        Some((host,RpPairingFile::from_bytes(&bytes).ok()?))
    });
    let (host,mut pairing)=cached.unwrap_or_else(||{
        let seed=RpPairingFile::generate("DirectSide seed");
        let tag=seed.public_key_bytes().iter().take(6).map(|b|format!("{b:02x}")).collect::<String>();
        let host=format!("DirectSide-{tag}");let pairing=RpPairingFile::generate(&host);(host,pairing)
    });
    let service=pairing_step("USB-Kopplungsdienst öffnen …",10,async {Ok(RemotePairingLockdownService::connect(provider).await?)}).await?;
    let mut client=service.into_client(&host)?;
    // Like iloader's USB setup: trusted lockdown uses the protocol's fixed PIN,
    // not an interactive tvOS/wireless PIN prompt. Never wait on stdin here.
    pairing_step("USB-Kopplung automatisch bestätigen …",25,async {Ok(client.connect(&mut pairing,||async {"000000".to_string()}).await?)}).await?;
    drop(client);
    pairing_step("USB-Kopplung prüfen …",15,async {
        let service=RemotePairingLockdownService::connect(provider).await?;
        let mut check=service.into_client(&host)?;
        check.attempt_pair_verify().await?;check.validate_pairing(&mut pairing).await?;Ok(())
    }).await?;
    storage.store_data(&key,&serde_json::to_vec(&json!({"host":host,"record":pairing.to_bytes()}))?)?;
    Ok(pairing)
}

async fn repair_directside(engine:&mut Engine,request:&Value)->Result<(),Report> {
    let id=text(request,"device_id")?;
    let path=PathBuf::from(text(request,"path")?);
    let info=isideload::sideload::application::inspect_ipa(&path)?;
    if info.get("CFBundleIdentifier").and_then(plist::Value::as_string)!=Some("com.directside.app") {bail!("Für die Einrichtung bitte die DirectSide-IPA auswählen.");}
    let mut mux=UsbmuxdConnection::default().await?;
    let device=mux.get_devices().await?.into_iter().find(|d|d.udid==id).ok_or_else(||report!("iPhone nicht mehr verbunden."))?;
    let provider=device.to_provider(UsbmuxdAddr::from_env_var()?,"DirectSide");
    let team=engine.get_team().await?;
    bootstrap(Some(engine),&provider,&path,&format!("com.directside.app.{}",team.team_id)).await?;
    emit(json!({"event":"directside_repaired","device_id":id}));Ok(())
}

async fn bootstrap(engine:Option<&mut Engine>, provider:&impl idevice::provider::IdeviceProvider, ipa:&std::path::Path,bundle:&str) -> Result<(),Report> {
    use idevice::house_arrest::HouseArrestClient;
    let info=pairing_step("Geräteinformationen für die Kopplung lesen …",10,async {isideload::util::device::IdeviceInfo::from_device(provider).await}).await?;
    let pairing=usb_remote_pairing(provider,&info.udid).await?;
    let (signing_name,signing)=if let Some(engine)=engine {
        ("DirectSide-signing.json",pairing_step("Signierschlüssel für DirectSide vorbereiten …",35,async {engine.bootstrap_signing_identity().await}).await?)
    }else{("DirectSide-imported.json",serde_json::to_vec(&crate::imported_identity::load()?.ok_or_else(||report!("Importiertes Zertifikat fehlt."))?)?)};
    let mut afc=pairing_step("DirectSide für die Übertragung öffnen …",10,async {Ok(HouseArrestClient::connect(provider).await?.vend_documents(bundle.to_string()).await?)}).await?;
    let mut files=vec![
        ("DirectSide-pairing.plist",pairing.to_bytes()),
        ("DirectSide-original.ipa",std::fs::read(ipa)?),
        (signing_name,signing),
    ];
    files.push(("DirectSide-bootstrap.json",serde_json::to_vec(&json!({"udid":info.udid,"name":info.name}))?));
    pairing_step("Pairing und Original-IPA übertragen und prüfen …",90,async {
    for (name,data) in files {
        let temporary=format!("/Documents/{name}.pending");
        let destination=format!("/Documents/{name}");
        let mut f=afc.open(&temporary,idevice::afc::opcode::AfcFopenMode::WrOnly).await?;
        for chunk in data.chunks(512*1024) {f.write_entire(chunk).await?;}
        f.close().await?;
        let mut check=afc.open(&temporary,idevice::afc::opcode::AfcFopenMode::RdOnly).await?;
        let transferred=check.read_entire().await?;check.close().await?;
        if transferred!=data {bail!("Pairing-Übertragung unvollständig. DirectSide erneut installieren.");}
        afc.rename(temporary,destination).await?;
    }
    Ok(())
    }).await?;
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

async fn pair_local(request:&Value)->Result<(),Report> {
    use idevice::remote_pairing::{RemotePairingClient,RpPairingFile,RpPairingSocket};
    let peer=text(request,"peer")?;
    let port=request.get("port").and_then(Value::as_u64).filter(|p|*p>0 && *p<=65535).ok_or_else(||report!("Remote-Pairing-Port fehlt. Verbindung in den Einstellungen prüfen."))? as u16;
    let destination=PathBuf::from(text(request,"pairing_path")?);
    let temporary=destination.with_extension("pending");
    let mut record=RpPairingFile::generate("DirectSide iPhone");
    let stream=tokio::time::timeout(Duration::from_secs(10),tokio::net::TcpStream::connect((peer,port))).await??;
    let mut client=RemotePairingClient::new(RpPairingSocket::new(stream),"DirectSide iPhone");
    client.connect(&mut record,||async {
        emit(json!({"event":"pairing_pin"}));
        read().ok().and_then(|r|r.get("code").and_then(Value::as_str).map(str::to_string)).unwrap_or_default()
    }).await?;
    std::fs::write(&temporary,record.to_bytes())?;
    let result:Result<(),Report>=async {
        let mut verify=request.clone();verify["pairing_path"]=json!(temporary.to_string_lossy());
        let (_handle,rsd)=connect_local(&verify).await?;
        let udid=rsd.properties.get("UniqueDeviceID").and_then(plist::Value::as_string).ok_or_else(||report!("Gerätekennung konnte nicht gelesen werden."))?;
        let name=rsd.properties.get("DeviceName").and_then(plist::Value::as_string).unwrap_or("iPhone");
        // Identity comes from the verified tunnel, never a guessed profile/device ID.
        std::fs::write(text(request,"bootstrap_path")?,serde_json::to_vec(&json!({"udid":udid,"name":name}))?)?;
        std::fs::rename(&temporary,&destination)?;
        emit(json!({"event":"paired_local"}));Ok(())
    }.await;
    if result.is_err() {let _=std::fs::remove_file(&temporary);}
    result
}

async fn export_livecontainer(engine:&mut Engine,request:&Value)->Result<(),Report> {
    let bytes=engine.livecontainer_certificate().await?;
    std::fs::write(text(request,"path")?,bytes)?;
    emit(json!({"event":"livecontainer_exported"}));Ok(())
}

fn sideload_apps(installed:&std::collections::HashMap<String,plist::Value>)->Vec<Value> {
    let mut apps=developer_apps(installed);
    for (id,value) in installed {
        let signer=value.as_dictionary().and_then(|d|d.get("SignerIdentity")).and_then(plist::Value::as_string).unwrap_or("");
        if (signer.starts_with("Apple Distribution:") || signer.starts_with("iPhone Distribution:")) && !apps.iter().any(|app|app["id"].as_str()==Some(id)) {apps.push(json!({"id":id,"name":value.as_dictionary().and_then(|d|d.get("CFBundleDisplayName")).and_then(plist::Value::as_string).unwrap_or(id)}));}
    }
    apps
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
    let apps=proxy.get_apps(Some("User"),None).await?;
    emit(json!({"event":"slots","used":developer_apps(&apps).len(),"limit":null,"apps":developer_apps(&apps)}));
    let developer=sideload_apps(&apps);
    let overview:Vec<Value>=apps.iter().filter(|(id,_)|developer.iter().any(|app|app["id"].as_str()==Some(id.as_str()))).filter_map(|(id,value)|{
        let info=value.as_dictionary()?;
        Some(json!({"id":id,"name":info.get("CFBundleDisplayName").or_else(||info.get("CFBundleName")).and_then(plist::Value::as_string).unwrap_or(id),"developer":developer.iter().any(|app|app["id"].as_str()==Some(id.as_str()))}))
    }).collect();
    emit(json!({"event":"local_apps","apps":overview}));Ok(())
}

async fn local_app_icons(request:&Value)->Result<(),Report> {
    use idevice::RsdService;
    let bundles=request["bundles"].as_array().filter(|v|v.len()<=12).ok_or_else(||report!("Ungültige Icon-Auswahl."))?;
    let (mut handle,mut rsd)=connect_local(request).await?;
    let mut spring=idevice::springboardservices::SpringBoardServicesClient::connect_rsd(&mut handle,&mut rsd).await?;
    let mut icons=Vec::new();
    for bundle in bundles {
        if let Some(bundle)=bundle.as_str() {
            if let Ok(Ok(data))=tokio::time::timeout(Duration::from_secs(1),spring.get_icon_pngdata(bundle.to_string())).await {
                if data.len()<=1024*1024 {icons.push(json!({"id":bundle,"png":base64::prelude::BASE64_STANDARD.encode(data)}));}
            }
        }
    }
    emit(json!({"event":"local_app_icons","icons":icons}));Ok(())
}

async fn remove_local_app(request:&Value)->Result<(),Report> {
    use idevice::RsdService;
    require_confirmation(request)?;
    let bundle=text(request,"bundle_id")?;
    let (mut handle,mut rsd)=connect_local(request).await?;
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect_rsd(&mut handle,&mut rsd).await?;
    if !sideload_apps(&proxy.get_apps(Some("User"),None).await?).iter().any(|app|app["id"].as_str()==Some(bundle)) {bail!("Nur installierte Sideload-Apps können hier entfernt werden.");}
    proxy.uninstall(bundle,None).await?;
    emit(json!({"event":"app_removed","bundle_id":bundle}));Ok(())
}

async fn install_local(engine:Option<&mut Engine>, request:&Value) -> Result<(),Report> {
    use idevice::RsdService;
    use isideload::dev::devices::DevicesApi;
    let path=PathBuf::from(text(request,"path")?);
    if !path.is_file() || !path.extension().is_some_and(|x|x.eq_ignore_ascii_case("ipa")) {bail!("IPA-Datei fehlt.");}
    let _temporary=isideload::sideload::application::ExtractionCleanup::new(&path)?;
    validate_self_update(request,&path)?;
    let udid=text(request,"udid")?;
    let name=text(request,"device_name")?;
    let(mut handle,mut rsd)=connect_local(request).await?;
    let mut proxy=idevice::installation_proxy::InstallationProxyClient::connect_rsd(&mut handle,&mut rsd).await?;
    let installed=proxy.get_apps(Some("User"),None).await?;
    let signed=if request["signing_mode"].as_str()==Some("imported") {crate::imported_identity::sign(path,udid).await?} else {
        let engine=engine.ok_or_else(||report!("Bitte zuerst anmelden."))?;
        let team=engine.get_team().await?;
        engine.get_dev_session().ensure_device_registered(&team,name,udid,None).await?;
        engine.sign_app(path,Some(team),false,Some(|p:f32|async move {emit(json!({"event":"progress","value":p*55.0}));}),None,Some(udid)).await?.0
    };
    let installed_bundle_id=check_signed_slots(&installed,&signed)?;
    validate_installed_target(request,&installed_bundle_id)?;
    emit(json!({"event":"status","message":"Signierte App wird installiert …"}));
    let expires_at=profile_expiry(&signed.join("embedded.mobileprovision"));
    let result=isideload::sideload::install::install_app_rsd(&mut handle,&mut rsd,&signed,|p|emit(json!({"event":"progress","value":55.0+(p as f64)*0.45}))).await;
    let _=std::fs::remove_dir_all(&signed);
    result?;
    emit(json!({"event":"installed","path":request["path"],"device_id":udid,"installed_bundle_id":installed_bundle_id,"expires_at":expires_at}));
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
            "remove_app"=>match tokio::time::timeout(Duration::from_secs(45),remove_device_app(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("App konnte nicht rechtzeitig entfernt werden. Gerät erneut prüfen."))},
            "remove_local_app"=>match tokio::time::timeout(Duration::from_secs(45),remove_local_app(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("App konnte nicht rechtzeitig entfernt werden. Verbindung erneut prüfen."))},
            "certificates"=>match engine.as_mut() {Some(e)=>certificates(e).await,None=>Err(report!("Bitte zuerst anmelden."))},
            "app_ids"=>match engine.as_mut() {
                Some(e)=>async {
                    let team=e.get_team().await?;
                    let q=e.get_dev_session().list_app_ids(&team,None).await?;
                    emit(json!({"event":"app_ids","limit":q.max_quantity,"available":q.available_quantity,"ids":q.app_ids.iter().map(|id|json!({"name":id.name,"identifier":id.identifier,"expires_at":id.expiration_date.map(|d|d.to_xml_format())})).collect::<Vec<_>>()}));
                    Ok(())
                }.await,
                None=>Err(report!("Bitte zuerst anmelden.")),
            },
            "revoke_certificate"=>match engine.as_mut() {Some(e)=>revoke_certificate(e,&request).await,None=>Err(report!("Bitte zuerst anmelden."))},
            "prepare_livecontainer" if request["signing_mode"].as_str()==Some("imported")=>match crate::imported_identity::load() {Ok(Some(identity))=>match identity.livecontainer_certificate().await {Ok(bytes)=>transfer_livecontainer(&request,&bytes).await,Err(e)=>Err(e)},Ok(None)=>Err(report!("Zertifikat fehlt.")),Err(e)=>Err(e)},
            "prepare_livecontainer" => match engine.as_mut() {Some(e)=>prepare_livecontainer(e,&request).await,None=>Err(report!("Bitte zuerst anmelden."))},
            "export_livecontainer" if request["signing_mode"].as_str()==Some("imported")=>async {
                let bytes=crate::imported_identity::load()?.ok_or_else(||report!("Zertifikat fehlt."))?.livecontainer_certificate().await?;
                std::fs::write(text(&request,"path")?,bytes)?;emit(json!({"event":"livecontainer_exported"}));Ok(())
            }.await,
            "export_livecontainer"=>match engine.as_mut() {Some(e)=>export_livecontainer(e,&request).await,None=>Err(report!("Bitte zuerst anmelden."))},
            "import_identity"=>{
                let result=crate::imported_identity::import(&request).map(|metadata|emit(json!({"event":"imported_identity","identity":metadata})));
                request.as_object_mut().map(|value|value.remove("password"));result
            },
            "imported_identity"=>crate::imported_identity::metadata().map(|metadata|emit(json!({"event":"imported_identity","identity":metadata}))),
            "forget_identity"=>crate::imported_identity::forget().map(|_|emit(json!({"event":"imported_identity","identity":null}))),
            "pair_local"=>pair_local(&request).await,
            "local_app_icons"=>match tokio::time::timeout(Duration::from_secs(18),local_app_icons(&request)).await {Ok(r)=>r,Err(_)=>Err(report!("Icons konnten nicht geladen werden."))},
            "reveal_developer_mode"=>reveal_developer_mode(&request).await,
            "repair_directside"=>match engine.as_mut() {Some(e)=>repair_directside(e,&request).await,None=>Err(report!("Zum Übertragen des Signierschlüssels bitte am PC anmelden."))},
            "restore" => {
                match tokio::time::timeout(Duration::from_secs(45),restore()).await {
                    Ok(Ok(Some(e)))=>{engine=Some(e);Ok(())},
                    Ok(Err(e))=>{let detail=format!("{e}");let reason=if detail.contains("1100") {"expired"}else{"signed_out"};emit(json!({"event":"status","message":format!("Gespeicherte Sitzung konnte lokal nicht übernommen werden: {detail}")}));emit(json!({"event":"logged_out","reason":reason}));Ok(())},
                    _=>{emit(json!({"event":"logged_out"}));Ok(())},
                }
            },
            "profile"=>{emit(json!({"event":"profile","expires_at":profile_expiry(std::path::Path::new(text(&request,"path").unwrap_or("")))}));Ok(())},
            "inspect_ipa"=>(||->Result<(),Report>{
                let path=text(&request,"path")?;
                match isideload::sideload::application::inspect_ipa(std::path::Path::new(path)) {
                    Ok(info)=>{emit(json!({"event":"ipa_inspected","path":path,"bundle_id":info.get("CFBundleIdentifier").and_then(plist::Value::as_string),"name":info.get("CFBundleDisplayName").or_else(||info.get("CFBundleName")).and_then(plist::Value::as_string).unwrap_or("Imported app"),"version":info.get("CFBundleShortVersionString").and_then(plist::Value::as_string)}));Ok(())},
                    Err(error)=>Err(error),
                }
            })(),
            "import_signing"=>{
                let result=(||->Result<(),Report>{
                    let path=PathBuf::from(text(&request,"path")?);
                    let bytes=std::fs::read(&path)?;
                    let email=isideload::sideload::cert_identity::CertificateIdentity::import_bootstrap(&bytes,&KeyringStorage::new("DirectSide.signing".to_string()))?;
                    std::fs::remove_file(path)?;
                    emit(json!({"event":"signing_imported","email":email}));Ok(())
                })();result
            },
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
            "install" if request["signing_mode"].as_str()==Some("imported")=>install(None,&request).await,
            "install_local" if request["signing_mode"].as_str()==Some("imported")=>install_local(None,&request).await,
            "install" => match engine.as_mut() {
                Some(e) => {let result=install(Some(&mut *e),&request).await;refresh_account_quota(e).await;result},
                None => Err(report!("Bitte zuerst mit deiner Apple-ID anmelden.")),
            },
            "install_local" => match engine.as_mut() {
                Some(e)=>install_local(Some(e),&request).await,
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
    #[tokio::test]
    async fn pairing_steps_complete_or_fail_with_their_phase_instead_of_hanging() {
        assert_eq!(pairing_step("Test phase",1,async {Ok(42)}).await.unwrap(),42);
        let result=pairing_step("Blocked pairing phase",0,std::future::pending::<Result<(),Report>>()).await;
        assert!(result.unwrap_err().to_string().contains("Blocked pairing phase"));
    }
    #[test]
    fn removal_requires_an_explicit_boolean_confirmation() {
        for request in [json!({}),json!({"confirmed":false}),json!({"confirmed":"true"})] {assert!(require_confirmation(&request).is_err());}
        assert!(require_confirmation(&json!({"confirmed":true})).is_ok());
    }
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
    #[test]
    fn distribution_apps_are_managed_but_do_not_consume_personal_development_slots() {
        let mut apps=std::collections::HashMap::new();
        for (id,signer) in [("store","Apple iPhone OS Application Signing"),("paid","Apple Distribution: Fixture"),("dev","Apple Development: Fixture")] {
            let mut info=plist::Dictionary::new();info.insert("SignerIdentity".into(),plist::Value::String(signer.into()));apps.insert(id.into(),plist::Value::Dictionary(info));
        }
        let managed=sideload_apps(&apps);
        assert_eq!(managed.len(),2);assert!(!managed.iter().any(|app|app["id"]=="store"));
        assert_eq!(developer_apps(&apps).len(),1);
    }
    #[test]
    fn self_update_rejects_malformed_archive_before_signing() {
        let directory=std::env::temp_dir().join(format!("directside-update-test-{}",std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        std::fs::create_dir_all(&directory).unwrap();
        let path=directory.join("update.ipa");
        // inspect_ipa is shared with normal imports; malformed archives are never
        // passed to signing merely because an update version was supplied.
        std::fs::write(&path,b"not an IPA").unwrap();
        assert!(validate_self_update(&json!({"self_update_version":"0.2.0"}),&path).is_err());
        std::fs::remove_dir_all(directory).unwrap();
    }
    #[test]
    fn self_updates_must_replace_the_current_app_instead_of_installing_a_second_team_copy() {
        let request=json!({"expected_installed_bundle_id":"com.directside.app.ORIGINAL"});
        assert!(validate_installed_target(&request,"com.directside.app.ORIGINAL").is_ok());
        assert!(validate_installed_target(&request,"com.directside.app.OTHER").is_err());
        assert!(validate_installed_target(&request,"com.directside.app").is_err());
        assert!(validate_installed_target(&json!({}),"com.directside.app.OTHER").is_ok());
    }
}
