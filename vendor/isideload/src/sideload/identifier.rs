//! Stable signing identities, independent of build number and signing attempts.
use rootcause::prelude::*;

pub const DIRECTSIDE_ID: &str = "com.directside.app";

pub fn account_bundle_identifier(original: &str, team: &str) -> Result<String, Report> {
    if team.is_empty() || team.contains('.') { bail!("Invalid signing team identifier."); }
    if original == DIRECTSIDE_ID {
        return Ok(format!("{DIRECTSIDE_ID}.{team}"));
    }
    if let Some(suffix) = original.strip_prefix("com.directside.app.") {
        // Re-signing an already signed IPA must never allocate TEAM.TEAM IDs.
        // Also repair repeated suffixes produced by older signing versions.
        if suffix.split('.').all(|part| part == team) {
            return Ok(format!("{DIRECTSIDE_ID}.{team}"));
        }
        bail!("Diese DirectSide-IPA wurde für ein anderes Team verändert. Bitte die unveränderte DirectSide-IPA verwenden.");
    }
    let suffix = format!(".{team}");
    Ok(if original.ends_with(&suffix) { original.to_string() } else { format!("{original}{suffix}") })
}

