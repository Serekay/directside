pub mod core;
use std::{collections::VecDeque, ffi::{CStr,CString,c_char}, sync::{Mutex,OnceLock,mpsc}};

pub(crate) struct Bridge {
    input: mpsc::Sender<String>,
    output: Mutex<VecDeque<String>>,
    receiver: Mutex<mpsc::Receiver<String>>,
}
pub(crate) static BRIDGE: OnceLock<Bridge> = OnceLock::new();

#[unsafe(no_mangle)]
pub extern "C" fn ds_set_anisette_callback(generate:Option<isideload::anisette::local::callback::Generate>,release:Option<isideload::anisette::local::callback::Release>)->bool {
    match (generate,release) {(Some(generate),Some(release))=>isideload::anisette::local::callback::register(generate,release),_=>false}
}

#[unsafe(no_mangle)]
pub extern "C" fn ds_start() {
    BRIDGE.get_or_init(|| {
        let (input,receiver)=mpsc::channel();
        Bridge {input,receiver:Mutex::new(receiver),output:Mutex::new(VecDeque::new())}
    });
    static START: std::sync::Once = std::sync::Once::new();
    START.call_once(||{std::thread::spawn(core::run);});
}

/// # Safety
/// `command` must point to a NUL-terminated UTF-8 string valid for this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ds_send(command: *const c_char) -> bool {
    if command.is_null() {return false;}
    let Ok(text)=(unsafe {CStr::from_ptr(command)}).to_str() else {return false;};
    if text.len()>131072 {return false;}
    BRIDGE.get().is_some_and(|b|b.input.send(text.to_owned()).is_ok())
}

#[unsafe(no_mangle)]
pub extern "C" fn ds_poll() -> *mut c_char {
    let Some(b)=BRIDGE.get() else {return std::ptr::null_mut();};
    let Ok(mut q)=b.output.lock() else {return std::ptr::null_mut();};
    let Some(event)=q.pop_front() else {return std::ptr::null_mut();};
    CString::new(event).map_or(std::ptr::null_mut(),CString::into_raw)
}

/// # Safety
/// `pointer` must come from ds_poll and must be freed exactly once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ds_free(pointer: *mut c_char) {
    if !pointer.is_null() {drop(unsafe {CString::from_raw(pointer)});}
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize,Ordering};
    use isideload::anisette::{AnisetteProvider,AnisetteDataResponse};
    static CALLS:AtomicUsize=AtomicUsize::new(0);
    unsafe extern "C" fn fixture()->*mut c_char {
        CALLS.fetch_add(1,Ordering::SeqCst);
        CString::new(r#"{"headers":{"X-Apple-I-MD":"otp-fixture","X-Apple-I-MD-M":"mid-fixture","X-Mme-Device-Id":"device-fixture","X-Apple-I-MD-LU":"user-fixture","X-Apple-I-MD-RINFO":"17106176"},"client_info":"client-fixture","user_agent":"agent-fixture"}"#).unwrap().into_raw()
    }
    unsafe extern "C" fn release(pointer:*mut c_char){drop(unsafe{CString::from_raw(pointer)});}
    #[tokio::test]
    async fn callback_initializes_once_then_refreshes_without_ui_events() {
        assert!(ds_set_anisette_callback(Some(fixture),Some(release)));
        let provider=isideload::anisette::local::callback::LocalAnisetteProvider::new().unwrap();
        assert_eq!(provider.get_client_info().await.unwrap().client_info,"client-fixture");
        let AnisetteDataResponse::Data(data)=provider.get_anisette_data().await.unwrap() else {panic!("Expected local headers")};
        assert_eq!(data.get_headers()["X-Apple-I-MD"],"otp-fixture");
        assert_eq!(CALLS.load(Ordering::SeqCst),1);
        provider.get_anisette_data().await.unwrap();
        assert_eq!(CALLS.load(Ordering::SeqCst),2);
    }
}
