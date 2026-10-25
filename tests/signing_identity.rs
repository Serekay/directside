use isideload::sideload::identifier::account_bundle_identifier;

#[test]
fn reinstalling_directside_twenty_times_uses_one_identity() {
    let mut id = "com.directside.app".to_string();
    for _ in 0..20 {
        id = account_bundle_identifier(&id, "TESTTEAM01").unwrap();
        assert_eq!(id, "com.directside.app.TESTTEAM01");
    }
    assert_eq!(account_bundle_identifier("com.directside.app.TESTTEAM01.TESTTEAM01", "TESTTEAM01").unwrap(), id);
}

#[test]
fn changed_directside_identifiers_cannot_register_another_app() {
    for id in ["com.directside.app.OTHERTEAM1", "com.directside.app.build7", "com.directside.app.TESTTEAM01.OTHERTEAM1"] {
        assert!(account_bundle_identifier(id, "TESTTEAM01").is_err());
    }
}

#[test]
fn resigning_other_apps_does_not_repeat_the_team_suffix() {
    let id = account_bundle_identifier("example.app", "TESTTEAM01").unwrap();
    assert_eq!(account_bundle_identifier(&id, "TESTTEAM01").unwrap(), id);
}
