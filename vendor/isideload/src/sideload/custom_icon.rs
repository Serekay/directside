//! DirectSide's visual treatment, applied before signing the standalone LiveContainer.
use super::bundle::Bundle;
use rootcause::prelude::*;
use plist::{Dictionary,Value};

pub fn apply(bundle:&mut Bundle)->Result<(),Report> {
    if bundle.bundle_identifier()!=Some("com.kdt.livecontainer") {return Ok(())}
    let image=image::load_from_memory_with_format(include_bytes!("../../../../assets/livecontainer-directside.png"),image::ImageFormat::Png)?;
    for (name,size) in [("DirectSideLC60x60@2x.png",120),("DirectSideLC60x60@3x.png",180),("DirectSideLC76x76@2x~ipad.png",152),("DirectSideLC83x83@2x~ipad.png",167)] {
        let resized=image.resize_exact(size,size,image::imageops::FilterType::Lanczos3).to_rgb8();
        let mut bytes=std::io::Cursor::new(Vec::new());
        image::DynamicImage::ImageRgb8(resized).write_to(&mut bytes,image::ImageFormat::Png)?;
        isideload_vfs::fs::write(bundle.bundle_dir.join(name),bytes.into_inner())?;
    }
    for (key,names) in [("CFBundleIcons",vec!["DirectSideLC60x60"]),("CFBundleIcons~ipad",vec!["DirectSideLC60x60","DirectSideLC76x76","DirectSideLC83x83"])] {
        let primary:Dictionary=[("CFBundleIconFiles".to_string(),Value::Array(names.into_iter().map(|name|Value::String(name.into())).collect()))].into_iter().collect();
        bundle.app_info.insert(key.into(),Value::Dictionary([("CFBundlePrimaryIcon".to_string(),Value::Dictionary(primary))].into_iter().collect()));
    }
    bundle.app_info.remove("CFBundleIconName");bundle.app_info.remove("CFBundleIconFile");
    bundle.app_info.insert("CFBundleIconFiles".into(),Value::Array(vec![Value::String("DirectSideLC60x60".into())]));
    bundle.write_info()?;Ok(())
}

