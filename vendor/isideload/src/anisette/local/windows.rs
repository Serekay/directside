//! Windows CoreADI interoperability. Protocol facts: ADI operation numbers,
//! big-endian parameter blocks and Windows identity components documented by
//! https://github.com/Dadoum/apple-crates/tree/main/adi and library-coreadi.
use super::*;
use base64::{Engine as _,prelude::BASE64_STANDARD as B64};
use md5::{Digest,Md5};
use std::{ffi::{CStr,OsStr},os::windows::ffi::OsStrExt,path::{Path,PathBuf},ptr::{null,null_mut},sync::Mutex};
use windows_sys::Win32::{Foundation::FreeLibrary,System::{LibraryLoader::{LoadLibraryExW,GetProcAddress,LOAD_LIBRARY_SEARCH_DEFAULT_DIRS,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR},Registry::*,WindowsProgramming::{GetComputerNameW,GetCurrentHwProfileW,HW_PROFILE_INFOW}},Storage::FileSystem::GetVolumeInformationW,NetworkManagement::IpHelper::{GetAdaptersAddresses,GAA_FLAG_INCLUDE_ALL_INTERFACES,IP_ADAPTER_ADDRESSES_LH}};

const DSID:i64=-2;
const CLIENT:&str="<PC> <Windows;6.2(0,0);9200> <com.apple.AuthKit/1 (com.apple.akd/1.0)>";
#[repr(C)]
struct Parameters { data:*mut u8,input:u32,output:u32,flags:u32 }
struct Native {module:usize,dispatch:unsafe extern "C" fn(u32,*const Parameters)->i32}
impl Native {
    fn open(path:&Path)->Result<Self,Report> {
        let wide:Vec<u16>=path.as_os_str().encode_wide().chain(Some(0)).collect();
        let module=unsafe{LoadLibraryExW(wide.as_ptr(),null_mut(),LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)};
        if module.is_null(){bail!("Lokale Apple-Bibliothek konnte nicht geladen werden: {}",std::io::Error::last_os_error());}
        let Some(entry)= (unsafe{GetProcAddress(module,c"vdfut768ig".as_ptr().cast())}) else {unsafe{FreeLibrary(module)};bail!("Lokale Apple-Bibliothek hat keine kompatible ADI-Schnittstelle.");};
        let native=Self {module:module as usize,dispatch:unsafe{std::mem::transmute(entry)}};
        native.call(0x12db31c5,&[])?;
        Ok(native)
    }
    fn call(&self,op:u32,args:&[u8])->Result<(),Report> {
        let mut block=Vec::with_capacity(8+args.len());block.extend_from_slice(&1u32.to_be_bytes());block.extend_from_slice(&1u32.to_be_bytes());block.extend_from_slice(args);
        let params=Parameters{data:block.as_mut_ptr(),input:block.len() as u32,output:4,flags:0};
        let transport=unsafe{(self.dispatch)(op,&params)};
        let code=if transport<0 {transport} else {i32::from_be_bytes(block[..4].try_into().unwrap())};
        if code<0 {bail!("Lokale Apple-Authentifizierung: ADI {}",code);}
        Ok(())
    }
    fn copy_and_free(&self,p:*const u8,len:u32)->Result<Vec<u8>,Report> {
        if p.is_null() || len==0 || len>65536 {bail!("Ungültige lokale ADI-Antwort.");}
        let value=unsafe{std::slice::from_raw_parts(p,len as usize)}.to_vec();
        self.call(0x3e58e7f9,&(p as usize as u64).to_be_bytes())?;Ok(value)
    }
    fn otp(&self)->Result<(Vec<u8>,Vec<u8>),Report> {
        let(mut mid,mut otp)= (null::<u8>(),null::<u8>());let(mut ml,mut ol)=(0u32,0u32);
        let mut args=DSID.to_be_bytes().to_vec();
        for p in [&mut mid as *mut _ as usize,&mut ml as *mut _ as usize,&mut otp as *mut _ as usize,&mut ol as *mut _ as usize] {args.extend_from_slice(&(p as u64).to_be_bytes());}
        self.call(0xcfe0b46a,&args)?;
        let m=self.copy_and_free(mid,ml);let o=self.copy_and_free(otp,ol);Ok((m?,o?))
    }
    fn routing(&self)->u64 {
        let mut value=0u64;let mut args=DSID.to_be_bytes().to_vec();args.extend_from_slice(&(&mut value as *mut _ as usize as u64).to_be_bytes());
        let _=self.call(0x85fe63b0,&args);value
    }
    fn provisioned(&self)->Result<bool,Report> {
        match self.call(0xb0eda7af,&DSID.to_be_bytes()) {Ok(())=>Ok(true),Err(e) if e.to_string().contains("ADI -45061")=>Ok(false),Err(e)=>Err(e)}
    }
    fn begin(&self,spim:&[u8])->Result<(Vec<u8>,u32),Report> {
        let(mut cpim,mut len,mut session)=(null::<u8>(),0u32,0u32);
        let mut args=DSID.to_be_bytes().to_vec();args.extend_from_slice(&(spim.as_ptr() as usize as u64).to_be_bytes());args.extend_from_slice(&(spim.len() as u32).to_be_bytes());
        for p in [&mut cpim as *mut _ as usize,&mut len as *mut _ as usize,&mut session as *mut _ as usize] {args.extend_from_slice(&(p as u64).to_be_bytes());}
        self.call(0x716bd86c,&args)?;
        if cpim.is_null() || len==0 || len>65536 {let _=self.cancel(session);bail!("Ungültige lokale Provisioning-Antwort.");}
        Ok((unsafe{std::slice::from_raw_parts(cpim,len as usize)}.to_vec(),session))
    }
    fn cancel(&self,session:u32)->Result<(),Report>{self.call(0x55a637c0,&session.to_be_bytes())}
    fn finish(&self,session:u32,ptm:&[u8],tk:&[u8],routing:u64)->Result<(),Report> {
        let mut args=session.to_be_bytes().to_vec();
        for bytes in [ptm,tk] {args.extend_from_slice(&(bytes.as_ptr() as usize as u64).to_be_bytes());args.extend_from_slice(&(bytes.len() as u32).to_be_bytes());}
        self.call(0x0b2b3196,&args)?;
        let mut args=DSID.to_be_bytes().to_vec();args.extend_from_slice(&routing.to_be_bytes());self.call(0x632b8d6e,&args)
    }
    fn synchronize(&self,sim:&[u8])->Result<(Vec<u8>,Vec<u8>),Report> {
        let(mut mid,mut srm)=(null::<u8>(),null::<u8>());let(mut ml,mut sl)=(0u32,0u32);
        let mut args=DSID.to_be_bytes().to_vec();args.extend_from_slice(&(sim.as_ptr() as usize as u64).to_be_bytes());args.extend_from_slice(&(sim.len() as u32).to_be_bytes());
        for p in [&mut mid as *mut _ as usize,&mut ml as *mut _ as usize,&mut srm as *mut _ as usize,&mut sl as *mut _ as usize] {args.extend_from_slice(&(p as u64).to_be_bytes());}
        self.call(0xa54951ec,&args)?;
        let m=self.copy_and_free(mid,ml);let s=self.copy_and_free(srm,sl);Ok((m?,s?))
    }
}
impl Drop for Native {fn drop(&mut self){let _=self.call(0x08c0fe9e,&[]);unsafe{FreeLibrary(self.module as _)};}}

static LIBRARY:Mutex<Option<Arc<Mutex<Native>>>>=Mutex::new(None);
pub struct LocalAnisetteProvider {native:Arc<Mutex<Native>>,device:String}
impl LocalAnisetteProvider {
    pub fn new()->Result<Self,Report> {
        let mut library=LIBRARY.lock().map_err(|_|report!("Lokale Apple-Bibliothek nicht verfügbar."))?;
        if let Some(native)=library.as_ref(){return Ok(Self{native:native.clone(),device:device_id()});}
        let mut paths=Vec::new();
        if let Ok(executable)=std::env::current_exe() {if let Some(parent)=executable.parent(){paths.push(parent.join("apple/CoreADI64.dll"));}}
        for variable in ["ProgramW6432","ProgramFiles"] {
            if let Some(root)=std::env::var_os(variable) {for folder in ["iTunes","Common Files/Apple/Apple Application Support","Common Files/Apple/Internet Services"] {for file in ["CoreADI64.dll","CoreADI.dll"] {paths.push(PathBuf::from(&root).join(folder).join(file));}}}
        }
        let path=paths.into_iter().find(|p|p.is_file()).ok_or_else(||report!("Apples lokale CoreADI-Bibliothek fehlt auf diesem PC. Ein Fremdserver wird nicht verwendet."))?;
        let native=Arc::new(Mutex::new(Native::open(&path)?));*library=Some(native.clone());
        Ok(Self{native,device:device_id()})
    }
    fn lock(&self)->Result<std::sync::MutexGuard<'_,Native>,Report>{self.native.lock().map_err(|_|report!("Lokale ADI-Schnittstelle wurde beendet."))}
    fn headers(&self)->Result<reqwest::header::HeaderMap,Report> {
        let mut h=reqwest::header::HeaderMap::new();
        h.insert("X-Mme-Device-Id",self.device.parse()?);
        h.insert("X-Apple-I-MD-LU",B64.encode(self.device.as_bytes()).parse()?);
        Ok(h)
    }
    fn apple_url(gs:&GrandSlam,key:&str)->Result<String,Report> {
        let value=gs.get_url(key)?;let url=reqwest::Url::parse(&value)?;
        let host=url.host_str().unwrap_or_default();
        if url.scheme()!="https" || !(host=="apple.com" || host.ends_with(".apple.com")) || url.username()!="" || url.password().is_some() {bail!("Provisioning-Endpunkt ist kein Apple-HTTPS-Dienst.");}
        Ok(value)
    }
}

#[async_trait::async_trait]
impl AnisetteProvider for LocalAnisetteProvider {
    async fn get_client_info(&self)->Result<AnisetteClientInfo,Report> {Ok(AnisetteClientInfo{client_info:CLIENT.into(),user_agent:"akd/1.0 CFNetwork/1408.0.4".into()})}
    async fn get_anisette_data(&self)->Result<AnisetteDataResponse,Report> {
        let native=self.lock()?;if !native.provisioned()? {return Ok(AnisetteDataResponse::NeedsProvisioning);}let(mid,otp)=native.otp()?;
        Ok(AnisetteDataResponse::Data(AnisetteData{machine_id:B64.encode(mid),one_time_password:B64.encode(otp),routing_info:native.routing().to_string(),_device_description:CLIENT.into(),device_unique_identifier:self.device.clone(),_local_user_id:B64.encode(self.device.as_bytes()),generated_at:web_time::SystemTime::now()}))
    }
    async fn provision(&mut self,gs:&Arc<GrandSlam>,_:bool)->Result<(),Report> {
        use plist_macro::plist;
        if self.lock()?.provisioned()? {return Ok(());}
        let start=Self::apple_url(gs,"midStartProvisioning")?;
        let response=gs.plist_request(&start,&plist!(dict{"Header":{},"Request":{}}),Some(self.headers()?),Some(1)).await?;
        let spim=B64.decode(response.get("spim").and_then(plist::Value::as_string).ok_or_else(||report!("Apple-Provisioning enthält kein SPIM."))?)?;
        let(cpim,session)=self.lock()?.begin(&spim)?;
        let result=async {
            let end=Self::apple_url(gs,"midFinishProvisioning")?;
            let response=gs.plist_request(&end,&plist!(dict{"Header":{},"Request":{"cpim":B64.encode(cpim)}}),Some(self.headers()?),Some(1)).await?;
            let read=|key:&str|->Result<Vec<u8>,Report>{Ok(B64.decode(response.get(key).and_then(plist::Value::as_string).ok_or_else(||report!("Apple-Provisioning unvollständig."))?)?)};
            let routing=response.get("X-Apple-I-MD-RINFO").and_then(|v|v.as_unsigned_integer().or_else(||v.as_string()?.parse().ok())).unwrap_or(17106176);
            self.lock()?.finish(session,&read("ptm")?,&read("tk")?,routing)
        }.await;
        if result.is_err(){let _=self.lock()?.cancel(session);}result
    }
    async fn resync(&self,sim:&str)->Result<AnisetteDataResponse,Report>{
        use plist_macro::plist;
        let(mid,srm)=self.lock()?.synchronize(&B64.decode(sim)?)?;
        let gs=GrandSlam::new(self.get_client_info().await?,false,None).await?;
        let url=Self::apple_url(&gs,"midSyncMachine")?;
        let response=gs.plist_request(&url,&plist!(dict{"Header":{},"Request":{"X-Apple-I-MD-M":B64.encode(mid),"srm":B64.encode(srm)}}),Some(self.headers()?),Some(1)).await?;
        if let Some(code)=response.get("Status").and_then(plist::Value::as_dictionary).and_then(|s|s.get("ec")).and_then(plist::Value::as_signed_integer) {if code!=0 {bail!("Apple-Synchronisierung fehlgeschlagen: {}",code);}}
        self.get_anisette_data().await
    }
}

fn registry_bytes(path:&CStr,name:&CStr)->Option<Vec<u8>> {
    let mut key=null_mut();
    if unsafe{RegOpenKeyExA(HKEY_LOCAL_MACHINE,path.as_ptr().cast(),0,KEY_READ,&mut key)}!=0{return None;}
    let mut len=0u32;
    let result=unsafe{RegQueryValueExA(key,name.as_ptr().cast(),null(),null_mut(),null_mut(),&mut len)};
    let mut bytes=vec![0;len as usize];
    let result=if result==0 {unsafe{RegQueryValueExA(key,name.as_ptr().cast(),null(),null_mut(),bytes.as_mut_ptr(),&mut len)}} else {result};
    unsafe{RegCloseKey(key)};if result!=0{return None;}bytes.truncate(len as usize);Some(bytes)
}
fn device_id()->String {
    let mac={let mut size=16384u32;let mut data=vec![0u64;2048];let mut result=unsafe{GetAdaptersAddresses(0,GAA_FLAG_INCLUDE_ALL_INTERFACES,null(),data.as_mut_ptr().cast(),&mut size)};
        if result==111 {data.resize((size as usize).div_ceil(8),0);result=unsafe{GetAdaptersAddresses(0,GAA_FLAG_INCLUDE_ALL_INTERFACES,null(),data.as_mut_ptr().cast(),&mut size)};}
        if result==0 {let p=unsafe{&*(data.as_ptr().cast::<IP_ADAPTER_ADDRESSES_LH>())};let mut m=vec![0;6];let len=(p.PhysicalAddressLength as usize).min(6);m[..len].copy_from_slice(&p.PhysicalAddress[..len]);Some(m)}else{None}};
    let volume={let mut serial=0;let root:Vec<u16>=OsStr::new("C:\\").encode_wide().chain(Some(0)).collect();if unsafe{GetVolumeInformationW(root.as_ptr(),null_mut(),0,&mut serial,null_mut(),null_mut(),null_mut(),0)}!=0{Some(serial.to_le_bytes().to_vec())}else{None}};
    let name={let mut data=[0u16;16];let mut len=16;if unsafe{GetComputerNameW(data.as_mut_ptr(),&mut len)}!=0 {Some(data.iter().flat_map(|x|x.to_le_bytes()).take(len as usize).collect())}else{None}};
    let profile={let mut p:HW_PROFILE_INFOW=unsafe{std::mem::zeroed()};if unsafe{GetCurrentHwProfileW(&mut p)}!=0{Some(p.szHwProfileGuid.iter().take_while(|x|**x!=0).flat_map(|x|x.to_le_bytes()).collect())}else{None}};
    [mac,volume,registry_bytes(cr"SOFTWARE\Microsoft\Windows NT\CurrentVersion",c"ProductId"),registry_bytes(cr"HARDWARE\DESCRIPTION\System\CentralProcessor\0",c"ProcessorNameString"),registry_bytes(cr"HARDWARE\DESCRIPTION\System",c"SystemBiosVersion"),name,profile].iter().map(|part|part.as_ref().map(|bytes|Md5::digest(bytes)[..4].iter().map(|b|format!("{b:02X}")).collect::<String>()).unwrap_or_else(||"00000000".into())).collect::<Vec<_>>().join(".")
}
