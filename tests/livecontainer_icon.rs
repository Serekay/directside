use isideload::sideload::{bundle::Bundle,custom_icon};
use plist::{Dictionary,Value};

#[test]
fn icon_replacement_is_scoped_and_preserves_livecontainer_identity() {
    for id in ["com.kdt.livecontainer","com.kdt.livecontainer.other"] {
        let directory=std::env::temp_dir().join(format!("directside-icon-{}-{}",std::process::id(),id));
        std::fs::create_dir_all(&directory).unwrap();
        let info:Dictionary=[("CFBundleIdentifier".to_string(),Value::String(id.into())),("CFBundleName".to_string(),Value::String("LiveContainer".into()))].into_iter().collect();
        plist::to_file_binary(directory.join("Info.plist"),&info).unwrap();
        let mut bundle=Bundle::new(directory.clone()).unwrap();custom_icon::apply(&mut bundle).unwrap();
        assert_eq!(bundle.bundle_identifier(),Some(id));assert_eq!(bundle.bundle_name(),Some("LiveContainer"));
        let icon=directory.join("DirectSideLC60x60@3x.png");
        if id=="com.kdt.livecontainer" {
            let png=std::fs::read(icon).unwrap();
            assert_eq!(&png[..8],b"\x89PNG\r\n\x1a\n");
            assert_eq!(u32::from_be_bytes(png[16..20].try_into().unwrap()),180);
            assert_eq!(u32::from_be_bytes(png[20..24].try_into().unwrap()),180);
            assert_eq!(png[25],2); // RGB PNG, no alpha channel.
            assert!(!bundle.app_info["CFBundleIcons"].as_dictionary().unwrap()["CFBundlePrimaryIcon"].as_dictionary().unwrap().contains_key("CFBundleIconName"));
        } else {assert!(!icon.exists());assert_eq!(bundle.app_info,info);}
        std::fs::remove_dir_all(directory).unwrap();
    }
}
