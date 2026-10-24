pub mod core;
use std::{collections::VecDeque, ffi::{CStr,CString,c_char}, sync::{Mutex,OnceLock,mpsc}};

pub(crate) struct Bridge {
    input: mpsc::Sender<String>,
    output: Mutex<VecDeque<String>>,
    receiver: Mutex<mpsc::Receiver<String>>,
}
pub(crate) static BRIDGE: OnceLock<Bridge> = OnceLock::new();

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
