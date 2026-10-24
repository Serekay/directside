//! In-process Swift/AnisetteKit bridge. Secrets never enter UI events or command queues.
use super::*;
use std::{ffi::{c_char,CStr},sync::{Mutex,OnceLock}};
use serde::Deserialize;

pub type Generate=unsafe extern "C" fn()->*mut c_char;
pub type Release=unsafe extern "C" fn(*mut c_char);
#[derive(Clone,Copy)]
struct Callbacks {generate:Generate,release:Release}
static CALLBACKS:OnceLock<Callbacks>=OnceLock::new();

pub fn register(generate:Generate,release:Release)->bool {
    CALLBACKS.set(Callbacks{generate,release}).is_ok()
}

#[derive(Deserialize)]
pub(crate) struct Payload {headers:std::collections::HashMap<String,String>,pub(crate) client_info:String,pub(crate) user_agent:String}
impl Payload {
    pub(crate) fn decode(bytes:&[u8])->Result<Self,Report> {
        if bytes.len()>65536 {bail!("Local authentication response is too large.");}
        let value:serde_json::Value=serde_json::from_slice(bytes).map_err(|_|report!("Invalid local authentication response."))?;
        if let Some(error)=value.get("error").and_then(serde_json::Value::as_str) {bail!("Local iPhone authentication: {}",error);}
        let payload:Self=serde_json::from_value(value).map_err(|_|report!("Incomplete local authentication response."))?;
        for key in ["X-Apple-I-MD","X-Apple-I-MD-M","X-Mme-Device-Id","X-Apple-I-MD-LU","X-Apple-I-MD-RINFO"] {
            if !payload.headers.get(key).is_some_and(|s|!s.is_empty() && s.len()<16384 && !s.contains(['\r','\n'])) {bail!("Missing or invalid local authentication field: {}",key);}
        }
        if payload.client_info.is_empty() || payload.user_agent.is_empty(){bail!("Local authentication client information is missing.");}
        Ok(payload)
    }
    pub(crate) fn data(self)->AnisetteData {
        let extra_headers=self.headers.iter().filter(|(key,_)|["X-Apple-I-Client-Time","X-Apple-I-TimeZone","X-Apple-Locale","X-Apple-I-SRL-NO"].contains(&key.as_str())).map(|(k,v)|(k.clone(),v.clone())).collect();
        AnisetteData{machine_id:self.headers["X-Apple-I-MD-M"].clone(),one_time_password:self.headers["X-Apple-I-MD"].clone(),routing_info:self.headers["X-Apple-I-MD-RINFO"].clone(),_device_description:self.client_info,device_unique_identifier:self.headers["X-Mme-Device-Id"].clone(),_local_user_id:self.headers["X-Apple-I-MD-LU"].clone(),generated_at:web_time::SystemTime::now(),extra_headers}
    }
}

pub struct LocalAnisetteProvider {callbacks:Callbacks,pending:Mutex<Option<Payload>>}
impl LocalAnisetteProvider {
    pub fn new()->Result<Self,Report> {
        let callbacks=*CALLBACKS.get().ok_or_else(||report!("The local iPhone authentication bridge was not registered."))?;
        Ok(Self{callbacks,pending:Mutex::new(None)})
    }
    async fn generate(&self)->Result<Payload,Report> {
        let callbacks=self.callbacks;
        tokio::task::spawn_blocking(move||{
            // The registered Swift callback returns a strdup allocation and its matching disposer.
            let pointer=unsafe{(callbacks.generate)()};
            if pointer.is_null(){bail!("The local authentication runtime did not return a response.");}
            let result=Payload::decode(unsafe{CStr::from_ptr(pointer)}.to_bytes());
            unsafe{(callbacks.release)(pointer)};
            result
        }).await.map_err(|_|report!("The local authentication worker stopped."))?
    }
}
#[async_trait::async_trait]
impl AnisetteProvider for LocalAnisetteProvider {
    async fn get_client_info(&self)->Result<AnisetteClientInfo,Report> {
        let payload=self.generate().await?;
        let info=AnisetteClientInfo{client_info:payload.client_info.clone(),user_agent:payload.user_agent.clone()};
        *self.pending.lock().map_err(|_|report!("Local authentication state is unavailable."))?=Some(payload);
        Ok(info)
    }
    async fn get_anisette_data(&self)->Result<AnisetteDataResponse,Report> {
        let pending=self.pending.lock().map_err(|_|report!("Local authentication state is unavailable."))?.take();
        let payload=match pending {Some(payload)=>payload,None=>self.generate().await?};
        Ok(AnisetteDataResponse::Data(payload.data()))
    }
    async fn provision(&mut self,_:&Arc<GrandSlam>,_:bool)->Result<(),Report> {
        // AnisetteClient provisions directly with Apple before returning headers.
        self.generate().await?;Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn local_payload_validates_required_headers_without_exposing_secrets() {
        let mut value=serde_json::json!({"headers":{"X-Apple-I-MD":"otp-fixture","X-Apple-I-MD-M":"mid-fixture","X-Mme-Device-Id":"uuid-fixture","X-Apple-I-MD-LU":"user-fixture","X-Apple-I-MD-RINFO":"17106176"},"client_info":"client-fixture","user_agent":"agent-fixture"});
        assert!(Payload::decode(&serde_json::to_vec(&value).unwrap()).is_ok());
        value["headers"]["X-Apple-I-MD"]=serde_json::json!("");
        let error=Payload::decode(&serde_json::to_vec(&value).unwrap()).err().unwrap().to_string();
        assert!(!error.contains("mid-fixture"));
        assert!(Payload::decode(br#"{"error":"runtime unavailable"}"#).is_err());
    }
}
