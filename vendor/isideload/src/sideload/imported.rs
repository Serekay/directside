//! Offline signing with an explicitly imported identity. No Apple account or
//! certificate allocation is involved; the device still enforces Apple's trust.
use std::{collections::BTreeMap,path::PathBuf,time::SystemTime};
use apple_codesign_quick::{BundleSigningSettings,ProvisioningProfile,RustCryptoCmsSigner,sign_bundle};
use p12_keystore::{KeyStore,Pkcs12ImportPolicy};
use rootcause::prelude::*;
use rsa::{RsaPrivateKey,pkcs8::DecodePrivateKey,pkcs1::EncodeRsaPublicKey};
use x509_cert::{Certificate,der::Decode};
use super::{application::Application,cert_identity::CertificateIdentity};

#[derive(serde::Serialize,serde::Deserialize)]
pub struct ImportedIdentity {pub p12:Vec<u8>,pub password:String,pub profiles:Vec<Vec<u8>>}

pub fn permits(pattern:&str,bundle:&str)->bool {
    pattern==bundle || pattern=="*" || pattern.strip_suffix(".*").is_some_and(|prefix|!prefix.contains('*') && bundle.strip_prefix(prefix).is_some_and(|rest|rest.starts_with('.') && rest.len()>1))
}
fn profile_pattern(profile:&ProvisioningProfile)->Result<&str,Report> {
    let id=profile.entitlements().get("application-identifier").and_then(plist::Value::as_string).ok_or_else(||report!("Profil enthält keine App-Zuordnung."))?;
    id.split_once('.').map(|(_,bundle)|bundle).ok_or_else(||report!("Ungültige App-Zuordnung im Profil."))
}
fn check_profile(profile:&ProvisioningProfile,certificate:&[u8],udid:Option<&str>)->Result<(),Report> {
    let expiry=profile.plist().get("ExpirationDate").and_then(plist::Value::as_date).ok_or_else(||report!("Profil hat kein Ablaufdatum."))?;
    if SystemTime::from(expiry)<=SystemTime::now() {bail!("Das importierte Profil ist abgelaufen. Bitte ein neues Profil importieren.");}
    if !profile.plist().get("DeveloperCertificates").and_then(plist::Value::as_array).is_some_and(|certs|certs.iter().any(|item|item.as_data()==Some(certificate))) {bail!("Zertifikat und Profil gehören nicht zusammen.");}
    if let Some(udid)=udid {
        if profile.plist().get("ProvisionsAllDevices").and_then(plist::Value::as_boolean)!=Some(true) && !profile.plist().get("ProvisionedDevices").and_then(plist::Value::as_array).is_some_and(|devices|devices.iter().any(|item|item.as_string()==Some(udid))) {bail!("Dieses iPhone ist im importierten Profil nicht freigeschaltet.");}
    }
    Ok(())
}

impl ImportedIdentity {
    fn identity(&self)->Result<CertificateIdentity,Report> {
        if self.p12.len()>131072 || self.profiles.is_empty() || self.profiles.len()>32 || self.profiles.iter().any(|p|p.len()>262144) {bail!("Zertifikat oder Profile sind zu groß oder fehlen.");}
        let store=KeyStore::from_pkcs12(&self.p12,&self.password,Pkcs12ImportPolicy::Strict).map_err(|_|report!("Zertifikat konnte nicht geöffnet werden. P12-Datei und Passwort prüfen."))?;
        let (_,chain)=store.private_key_chain().ok_or_else(||report!("Die P12-Datei enthält keinen privaten Signierschlüssel."))?;
        let private_key=RsaPrivateKey::from_pkcs8_der(chain.key().as_der()).map_err(|_|report!("Dieses Schlüsselformat wird noch nicht unterstützt. Ein RSA-Apple-Signierzertifikat verwenden."))?;
        let certificate_bytes=chain.certs().first().ok_or_else(||report!("Signierzertifikat fehlt."))?.as_der();
        let certificate=Certificate::from_der(certificate_bytes)?;
        if certificate.tbs_certificate.subject_public_key_info.subject_public_key.as_bytes()!=Some(private_key.to_public_key().to_pkcs1_der()?.as_bytes()) {bail!("Privater Schlüssel und Zertifikat passen nicht zusammen.");}
        let now=SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)?;
        if certificate.tbs_certificate.validity.not_after.to_unix_duration()<=now || certificate.tbs_certificate.validity.not_before.to_unix_duration()>now {bail!("Das Signierzertifikat ist noch nicht gültig oder abgelaufen.");}
        for bytes in &self.profiles {check_profile(&ProvisioningProfile::parse(bytes)?,certificate_bytes,None)?;}
        Ok(CertificateIdentity{machine_id:self.password.clone(),machine_name:"Imported identity".into(),private_key,certificate})
    }
    pub fn metadata(&self)->Result<serde_json::Value,Report> {
        let _=self.identity()?;
        let profile=ProvisioningProfile::parse(&self.profiles[0])?;
        Ok(serde_json::json!({"name":profile.plist().get("Name").and_then(plist::Value::as_string).unwrap_or("Imported certificate"),"team_id":profile.team_id(),"expires_at":profile.plist().get("ExpirationDate").and_then(plist::Value::as_date).map(|d|d.to_xml_format()),"profiles":self.profiles.len(),"free":profile.plist().get("LocalProvision").and_then(plist::Value::as_boolean)==Some(true)}))
    }
    pub async fn livecontainer_certificate(&self)->Result<Vec<u8>,Report> {
        let identity=self.identity()?;
        let password=uuid::Uuid::new_v4().to_string();
        Ok(serde_json::to_vec(&serde_json::json!({"certificate":identity.as_p12(&password).await?,"password":password}))?)
    }
    pub async fn sign(&self,path:PathBuf,udid:&str)->Result<PathBuf,Report> {
        use x509_cert::der::Encode;
        let identity=self.identity()?;
        let certificate_der=identity.certificate.to_der()?;
        let profiles:Vec<_>=self.profiles.iter().map(|bytes|ProvisioningProfile::parse(bytes)).collect::<Result<_,_>>()?;
        let mut app=Application::new(path)?;
        let original=app.main_bundle_id()?;
        // Preserve the original ID whenever the profile allows it. A previously
        // registered DirectSide ID with the team suffix is also supported.
        let (main_index,target)=profiles.iter().enumerate().find_map(|(i,p)| {
            let pattern=profile_pattern(p).ok()?;
            if permits(pattern,&original) {Some((i,original.clone()))}
            else {let target=format!("{}.{}",original,p.team_id());permits(pattern,&target).then_some((i,target))}
        }).ok_or_else(||report!("Kein importiertes Profil passt zu dieser App. Ein Profil für die App oder ein passendes Wildcard-Profil hinzufügen."))?;
        app.update_bundle_id(&original,&target)?;
        let main=&profiles[main_index];
        let mut profile_map=BTreeMap::new();let mut entitlement_map=BTreeMap::new();
        for bundle in app.bundle.collect_nested_bundles().iter().filter(|b|b.bundle_dir.extension().is_some_and(|ext|ext=="appex" || ext=="app")) {
            let id=bundle.bundle_identifier().ok_or_else(||report!("Erweiterung ohne App-Kennung."))?;
            let (index,profile)=profiles.iter().enumerate().find(|(_,p)|p.team_id()==main.team_id() && profile_pattern(p).is_ok_and(|pattern|permits(pattern,id))).ok_or_else(||report!("Für die Erweiterung {} fehlt ein passendes Profil. Das Profil zusätzlich importieren.",id))?;
            check_profile(profile,&certificate_der,Some(udid))?;
            profile_map.insert(id.to_string(),self.profiles[index].as_slice());
            entitlement_map.insert(id.to_string(),entitlements_for(profile,id)?);
        }
        check_profile(main,&certificate_der,Some(udid))?;
        app.bundle.write_info()?;
        for bundle in app.bundle.collect_nested_bundles().into_iter().filter(|b|b.bundle_dir.is_dir()) {bundle.write_info()?;}
        let chain=identity.profile_to_certificate_chain(main)?;
        let signer=RustCryptoCmsSigner::new(identity.private_key,identity.certificate,chain);
        let livecontainer=original=="com.kdt.livecontainer";
        let mut main_entitlements=entitlements_for(main,&target)?;
        if livecontainer {
            let groups=livecontainer_keychain(main)?;
            main_entitlements.insert("keychain-access-groups".into(),plist::Value::Array(groups));
            for (id,entitlements) in entitlement_map.iter_mut() {
                if id.ends_with("LiveProcess") {
                    let profile=profiles.iter().find(|p|p.team_id()==main.team_id() && profile_pattern(p).is_ok_and(|pattern|permits(pattern,id))).ok_or_else(||report!("LiveProcess-Profil fehlt."))?;
                    entitlements.insert("keychain-access-groups".into(),plist::Value::Array(livecontainer_keychain(profile)?));
                }
            }
        }
        let mut settings=BundleSigningSettings::new(main.team_id(),main_entitlements,Some(&signer));
        settings.embedded_mobileprovision=Some(&self.profiles[main_index]);
        settings.embedded_mobileprovisions_by_bundle_id=profile_map;
        settings.entitlements_by_bundle_id=entitlement_map;
        sign_bundle(&app.bundle.bundle_dir,&settings)?;
        Ok(app.bundle.bundle_dir)
    }
}

fn livecontainer_keychain(profile:&ProvisioningProfile)->Result<Vec<plist::Value>,Report> {
    let allowed=profile.entitlements().get("keychain-access-groups").and_then(plist::Value::as_array).ok_or_else(||report!("Das Profil erlaubt keine LiveContainer-Schlüsselbundgruppen."))?;
    let mut groups=vec![format!("{}.com.kdt.livecontainer.shared",profile.team_id())];
    groups.extend((1..128).map(|n|format!("{}.com.kdt.livecontainer.shared.{n}",profile.team_id())));
    if !groups.iter().all(|group|allowed.iter().any(|value|value.as_string().is_some_and(|pattern|permits(pattern,group)))) {bail!("Das importierte Profil erlaubt die benötigten LiveContainer-Schlüsselbundgruppen nicht. Ein passendes Wildcard-Profil verwenden.");}
    Ok(groups.into_iter().map(plist::Value::String).collect())
}

fn entitlements_for(profile:&ProvisioningProfile,bundle:&str)->Result<plist::Dictionary,Report> {
    let full=profile.entitlements().get("application-identifier").and_then(plist::Value::as_string).ok_or_else(||report!("App-Zuordnung fehlt."))?;
    let prefix=full.split_once('.').ok_or_else(||report!("App-Zuordnung ist ungültig."))?.0;
    fn resolve(value:&mut plist::Value,bundle:&str) {
        match value {
            plist::Value::String(s) if s.contains('*')=>*s=s.replace('*',bundle),
            plist::Value::Array(items)=>for item in items {resolve(item,bundle)},
            plist::Value::Dictionary(items)=>for (_,item) in items.iter_mut(){resolve(item,bundle)},
            _=>{}
        }
    }
    let mut entitlements=profile.entitlements().clone();
    for (_,value) in entitlements.iter_mut(){resolve(value,bundle)}
    entitlements.insert("application-identifier".into(),plist::Value::String(format!("{prefix}.{bundle}")));
    Ok(entitlements)
}

#[cfg(test)] mod tests {
    use super::*;
    fn fixture(certificate:&[u8],expired:bool,enterprise:bool)->Vec<u8> {
        // Synthetic CMS envelope for local policy tests. No Apple signature and
        // never submitted to a device or treated as installable test evidence.
        fn der(tag:u8,bytes:Vec<u8>)->Vec<u8> {
            let mut out=vec![tag];
            if bytes.len()<128 {out.push(bytes.len() as u8)} else {
                let length=bytes.len().to_be_bytes();let first=length.iter().position(|v|*v!=0).unwrap();
                out.push(0x80|(length.len()-first) as u8);out.extend(&length[first..]);
            }
            out.extend(bytes);out
        }
        let mut info=plist::Dictionary::new();
        info.insert("TeamIdentifier".into(),plist::Value::Array(vec![plist::Value::String("TEAM".into())]));
        info.insert("Name".into(),plist::Value::String("Synthetic test profile".into()));
        info.insert("DeveloperCertificates".into(),plist::Value::Array(vec![plist::Value::Data(certificate.to_vec())]));
        let expiry=if expired {SystemTime::UNIX_EPOCH}else{SystemTime::now()+std::time::Duration::from_secs(86400)};
        info.insert("ExpirationDate".into(),plist::Value::Date(expiry.into()));
        info.insert("ProvisionedDevices".into(),plist::Value::Array(vec![plist::Value::String("fixture-device".into())]));
        info.insert("ProvisionsAllDevices".into(),plist::Value::Boolean(enterprise));
        let mut entitlements=plist::Dictionary::new();
        entitlements.insert("application-identifier".into(),plist::Value::String("TEAM.com.fixture.*".into()));
        entitlements.insert("keychain-access-groups".into(),plist::Value::Array(vec![plist::Value::String("TEAM.*".into())]));
        info.insert("Entitlements".into(),plist::Value::Dictionary(entitlements));
        let mut xml=Vec::new();plist::to_writer_xml(&mut xml,&info).unwrap();
        let mut data_oid=vec![6,9,0x2a,0x86,0x48,0x86,0xf7,0x0d,1,7,1];
        data_oid.extend(der(0xa0,der(4,xml)));
        let mut signed=vec![2,1,1,0x31,0];signed.extend(der(0x30,data_oid));signed.extend([0x31,0]);
        let mut signed_oid=vec![6,9,0x2a,0x86,0x48,0x86,0xf7,0x0d,1,7,2];signed_oid.extend(der(0xa0,der(0x30,signed)));
        der(0x30,signed_oid)
    }
    #[test] fn profile_patterns_are_bounded() {
        assert!(permits("*","com.example.app"));assert!(permits("com.example.*","com.example.app"));
        assert!(!permits("com.example.*","com.exampleevil.app"));assert!(!permits("com.example.*","com.example"));
        assert!(!permits("com.*.app","com.example.app"));assert!(!permits("com.example.app","com.example.app.extension"));
    }
    #[test] fn bad_archives_do_not_become_identities() {
        let identity=ImportedIdentity{p12:vec![0,1,2],password:"wrong".into(),profiles:vec![vec![0]]};
        assert!(identity.metadata().is_err());
    }
    #[test] fn imported_profile_checks_expiry_certificate_and_device_allowance() {
        let bytes=fixture(b"fixture-cert",false,false);let profile=ProvisioningProfile::parse(&bytes).unwrap();
        assert!(check_profile(&profile,b"fixture-cert",Some("fixture-device")).is_ok());
        assert!(check_profile(&profile,b"wrong-cert",Some("fixture-device")).is_err());
        assert!(check_profile(&profile,b"fixture-cert",Some("different-device")).is_err());
        let expired=ProvisioningProfile::parse(&fixture(b"fixture-cert",true,false)).unwrap();
        assert!(check_profile(&expired,b"fixture-cert",None).is_err());
        let enterprise=ProvisioningProfile::parse(&fixture(b"fixture-cert",false,true)).unwrap();
        assert!(check_profile(&enterprise,b"fixture-cert",Some("different-device")).is_ok());
        let entitlements=entitlements_for(&profile,"com.fixture.app").unwrap();
        assert_eq!(entitlements["application-identifier"].as_string(),Some("TEAM.com.fixture.app"));
        assert_eq!(livecontainer_keychain(&profile).unwrap().len(),128);
    }
    #[tokio::test] async fn real_p12_import_checks_password_and_profile_membership() {
        use rsa::pkcs8::{EncodePrivateKey,LineEnding};
        use rcgen::{CertificateParams,KeyPair,PKCS_RSA_SHA256};
        let private_key=RsaPrivateKey::new(&mut rand::thread_rng(),2048).unwrap();
        let pair=KeyPair::from_pkcs8_pem_and_sign_algo(&private_key.to_pkcs8_pem(LineEnding::LF).unwrap(),&PKCS_RSA_SHA256).unwrap();
        let certificate=CertificateParams::new(vec![]).unwrap().self_signed(&pair).unwrap();
        let identity=CertificateIdentity{machine_id:"fixture".into(),machine_name:"fixture".into(),private_key,certificate:Certificate::from_der(certificate.der()).unwrap()};
        let p12=identity.as_p12("fixture-password").await.unwrap();
        let mut imported=ImportedIdentity{p12,password:"fixture-password".into(),profiles:vec![fixture(certificate.der(),false,false)]};
        assert_eq!(imported.metadata().unwrap()["team_id"],"TEAM");
        imported.password="wrong-password".into();assert!(imported.metadata().is_err());
        imported.password="fixture-password".into();imported.profiles=vec![fixture(b"another-certificate",false,false)];
        assert!(imported.metadata().is_err());
    }
}
