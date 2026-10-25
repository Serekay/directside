//! Packaged Mac CoreADI emulator in a private child process. No listener or service.
use super::*;
use super::callback::Payload;
use std::{process::Stdio,sync::Mutex,time::Duration};
use tokio::io::{AsyncReadExt,AsyncWriteExt};

#[repr(C)]
struct SecurityAttributes {length:u32,descriptor:*mut std::ffi::c_void,inherit:i32}
#[link(name="advapi32")]
unsafe extern "system" {fn ConvertStringSecurityDescriptorToSecurityDescriptorW(text:*const u16,revision:u32,out:*mut *mut std::ffi::c_void,size:*mut u32)->i32;}
#[link(name="kernel32")]
unsafe extern "system" {fn LocalFree(memory:*mut std::ffi::c_void)->*mut std::ffi::c_void;}

fn private_pipe(name:&str)->Result<tokio::net::windows::named_pipe::NamedPipeServer,Report> {
    // System and object owner only; other local users cannot read machine proofs.
    let sddl:Vec<u16>="D:P(A;;GA;;;SY)(A;;GA;;;OW)".encode_utf16().chain(Some(0)).collect();
    let mut descriptor=std::ptr::null_mut();
    if unsafe{ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.as_ptr(),1,&mut descriptor,std::ptr::null_mut())}==0 {bail!("Could not secure the local authentication channel.");}
    let mut attributes=SecurityAttributes{length:std::mem::size_of::<SecurityAttributes>() as u32,descriptor,inherit:0};
    let result=unsafe{tokio::net::windows::named_pipe::ServerOptions::new().first_pipe_instance(true).reject_remote_clients(true).create_with_security_attributes_raw(name,(&mut attributes as *mut SecurityAttributes).cast())};
    unsafe{LocalFree(descriptor)};
    Ok(result?)
}

pub struct LocalAnisetteProvider {command:Vec<String>,pending:Mutex<Option<Payload>>}
impl LocalAnisetteProvider {
    pub fn new()->Result<Self,Report> {
        let raw=std::env::var("DIRECTSIDE_LOCAL_HELPER").map_err(|_|report!("Start local authentication through the DirectSide application."))?;
        let command:Vec<String>=serde_json::from_str(&raw).map_err(|_|report!("Invalid local authentication configuration."))?;
        if command.is_empty() || command.len()>3 || !std::path::Path::new(&command[0]).is_file(){bail!("Local authentication executable is missing.");}
        Ok(Self{command,pending:Mutex::new(None)})
    }
    async fn exchange(&self,operation:&str,sim:Option<&str>)->Result<Vec<u8>,Report> {
        let mut command=tokio::process::Command::new(&self.command[0]);
        let pipe_name=format!(r"\\.\pipe\DirectSide-auth-{}",uuid::Uuid::new_v4());
        let mut pipe=private_pipe(&pipe_name)?;
        command.args(&self.command[1..]).arg("--local-anisette").env("DIRECTSIDE_AUTH_PIPE",&pipe_name).creation_flags(0x08000000).kill_on_drop(true).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());
        let mut child=command.spawn().context("Could not start bundled local Apple authentication.")?;
        let exchange=async {
            pipe.connect().await?;
            pipe.write_all(format!("{}\n",serde_json::json!({"operation":operation,"sim":sim})).as_bytes()).await?;
            let mut output=Vec::new();pipe.take(131073).read_to_end(&mut output).await?;
            let status=child.wait().await?;
            if !status.success(){bail!("Bundled local Apple authentication failed; no remote service was used.");}
            if output.len()>131072 {bail!("Local authentication response exceeds its limit.");}Ok(output)
        };
        tokio::time::timeout(Duration::from_secs(85),exchange).await.context("Local Apple authentication timed out.")?
    }
    async fn fetch(&self,operation:&str,sim:Option<&str>)->Result<Payload,Report> {Payload::decode(&self.exchange(operation,sim).await?)}
    pub async fn export_identity(&self)->Result<Vec<u8>,Report> {self.exchange("export_identity",None).await}
}
#[async_trait::async_trait]
impl AnisetteProvider for LocalAnisetteProvider {
    async fn get_client_info(&self)->Result<AnisetteClientInfo,Report> {
        let payload=self.fetch("headers",None).await?;
        let info=AnisetteClientInfo{client_info:payload.client_info.clone(),user_agent:payload.user_agent.clone()};
        *self.pending.lock().map_err(|_|report!("Local authentication cache is unavailable."))?=Some(payload);Ok(info)
    }
    async fn get_anisette_data(&self)->Result<AnisetteDataResponse,Report> {
        let cached={self.pending.lock().map_err(|_|report!("Local authentication cache is unavailable."))?.take()};
        let payload=match cached{Some(value)=>value,None=>self.fetch("headers",None).await?};
        Ok(AnisetteDataResponse::Data(payload.data()))
    }
    async fn provision(&mut self,_:&Arc<GrandSlam>,_:bool)->Result<(),Report> {self.fetch("headers",None).await?;Ok(())}
    async fn resync(&self,sim:&str)->Result<AnisetteDataResponse,Report> {Ok(AnisetteDataResponse::Data(self.fetch("resync",Some(sim)).await?.data()))}
}
