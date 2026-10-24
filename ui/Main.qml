import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: win
    width: 1080; height: 720
    minimumWidth: 960; minimumHeight: 680
    visible: true; title: "DirectSide"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    font.family: "Segoe UI Variable"
    font.pixelSize: 14
    property var s: backend.state
    function t(value) { return s.language === "de" ? value : (s.translations[value] || value) }
    property string page: "install"
    property string settingsSection: "system"
    property int appPage: 0
    property int certificatePage: 0
    property bool certificateLimitShown: false
    property string developerHelpDevice: ""
    onSChanged: {
        if(s.developerMode==="disabled" && !s.busy && s.devices.length && page==="install" && developerHelpDevice!==s.devices[s.deviceIndex].id) {developerHelpDevice=s.devices[s.deviceIndex].id;page="developer"}
        if(certificatePage*3>=s.certificates.length) certificatePage=0
        if(s.certificateLimit && !certificateLimitShown) {certificateLimitShown=true;page="certificates";backend.loadCertificates()}
        if(!s.certificateLimit) certificateLimitShown=false
    }
    property bool developerOnly: false
    property var filteredApps: developerOnly ? s.installedApps.filter(a=>a.developer) : s.installedApps
    onFilteredAppsChanged: if(appPage*9>=filteredApps.length) appPage=0
    property var visibleApps: filteredApps.slice(appPage*9,(appPage+1)*9)
    onVisibleAppsChanged: if(page==="apps") backend.loadAppIcons(visibleApps.map(a=>a.id))
    onPageChanged: if(page==="apps") backend.loadAppIcons(visibleApps.map(a=>a.id))
    property color accent: "#36dbb1"
    property color ink: "#f4f5f7"
    property color muted: "#92979f"
    property bool restoringSession: !s.loggedIn && s.authState==="checking"
    property bool authenticating: restoringSession || s.authState==="signing_in"
    property string accountStatus: s.loggedIn ? t("Angemeldet") : s.authState==="checking" ? t("Sitzung prüfen …") : s.authState==="signing_in" ? t("Bei Apple anmelden …") : s.authState==="expired" ? t("Sitzung abgelaufen") : t("Nicht angemeldet")
    property bool quotaKnown: s.appIdsLimit>0 && s.appIdsAvailable>=0
    property string quotaText: quotaKnown ? "App IDs · "+Math.max(0,s.appIdsLimit-s.appIdsAvailable)+" / "+s.appIdsLimit+" "+t("verbraucht")+" · "+s.appIdsAvailable+" "+t("frei") : "App IDs · "+(s.loggedIn ? t("Nicht verfügbar") : t("Anmelden"))

    component Label: Text {
        color: win.ink; font.family: win.font.family; font.pixelSize: 14
        elide: Text.ElideRight
    }
    component Badge: Rectangle {
        property string text: ""
        property bool positive: false
        property string tone: positive ? "ok" : "neutral"
        implicitWidth: badgeText.implicitWidth+22; implicitHeight: 28
        radius: 9; color: tone==="ok"?"#173d33":tone==="missing"?"#48242a":tone==="warning"?"#433a21":"#282b30"
        border.color: tone==="ok"?"#295b4c":tone==="missing"?"#82424c":tone==="warning"?"#7e6934":"#35383e"
        Label {id: badgeText; anchors.centerIn:parent; text:parent.text; font.pixelSize:11; font.weight:Font.DemiBold; color:parent.tone==="ok"?win.accent:parent.tone==="missing"?"#ff9ba6":parent.tone==="warning"?"#f1cf79":"#a5aab2"}
    }
    component Action: Button {
        id: control
        property bool primary: false
        property bool quiet: false
        implicitHeight: 42; implicitWidth: Math.max(42,actionText.implicitWidth+30)
        hoverEnabled: true
        opacity: enabled ? 1 : 0.55
        contentItem: Label {id:actionText; text:control.text; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter; color:!control.enabled ? "#c0d7cf" : control.primary ? "#09271e" : win.ink; font.weight:Font.DemiBold}
        background: Rectangle {radius:12; color:control.primary ? (control.down ? "#27b994" : control.hovered ? "#65e8c5" : win.accent) : control.hovered ? "#35383e" : control.quiet ? "transparent" : "#2a2d33"; border.width:control.primary || control.quiet ? 0 : 1; border.color:"#3b3e45"; Behavior on color {ColorAnimation{duration:120}}}
    }
    component IconButton: Action {
        id:iconControl
        property string hint: ""
        property string iconName: ({"⚙":"settings","↻":"refresh","▦":"apps","?":"help","−":"minimize","□":"maximize","×":"close","‹":"back","›":"forward","≡":"activity","…":"more","⌫":"trash"})[text] || "more"
        implicitWidth:36; implicitHeight:36; quiet:true
        ToolTip.visible: hovered; ToolTip.text:hint; ToolTip.delay:500
        Accessible.name:hint
        contentItem: Item {Image {anchors.centerIn:parent;width:iconControl.text==="↻" || iconControl.text==="▦"?26:21;height:width;source:"../assets/icons/"+iconControl.iconName+".svg";sourceSize.width:width*2;sourceSize.height:height*2}}
    }
    component Field: TextField {
        id: field
        implicitHeight:44; color:win.ink; placeholderTextColor:"#747b84"
        selectByMouse:true; selectionColor:"#287e68"
        leftPadding:14; rightPadding:14; font.pixelSize:14
        background:Rectangle {radius:12;color:"#17191d";border.color:field.activeFocus ? win.accent : "#383b43";Behavior on border.color {ColorAnimation{duration:130}}}
    }
    component Card: Rectangle {radius:20;color:"#1d1f24";border.color:"#30333a"}

    Rectangle {
        anchors.fill:parent; radius: win.visibility===Window.Maximized ? 0 : 20
        color:"#101216"; border.color:"#343840"; border.width:1; clip:true
        Rectangle {
            id:titlebar; anchors{left:parent.left;right:parent.right;top:parent.top;margins:1}
            height:78; color:"transparent"
            DragHandler {target:null; onActiveChanged:if(active)win.startSystemMove()}
            TapHandler {onDoubleTapped:win.visibility===Window.Maximized ? win.showNormal():win.showMaximized()}
            RowLayout {
                anchors.fill:parent;anchors.leftMargin:26;anchors.rightMargin:16;spacing:12
                Image {source:s.icon;Layout.preferredWidth:38;Layout.preferredHeight:38;sourceSize.width:76;sourceSize.height:76}
                Label {text:"DirectSide";font.pixelSize:22;font.weight:Font.DemiBold;font.letterSpacing:-0.6}
                Badge {text:s.version}
                Badge {text:s.devices.length?win.t("●  USB verbunden"):win.t("Nicht verbunden");tone:s.devices.length?"ok":"warning"}
                Item {Layout.fillWidth:true}
                Action {objectName:"windowsUpdateButton";visible:s.windowsUpdate;text:win.t("Update");primary:true;implicitHeight:32;enabled:!s.updateBusy && !s.directsideInstalling && (!s.busy || s.scanning);onClicked:backend.updateWindows();ToolTip.visible:hovered;ToolTip.text:s.releaseVersion}
                IconButton {text:"⚙";hint:win.t("Einstellungen");onClicked:win.page=win.page==="settings" ? "install":"settings"}
                IconButton {id:moreButton;text:"?";hint:win.t("Hilfe & Aktivität");onClicked:moreMenu.popup()
                    Menu {id:moreMenu;y:moreButton.height
                        MenuItem {text:win.t("Hilfe");onTriggered:win.page="help"}
                        MenuItem {text:win.t("Entwicklermodus");onTriggered:win.page="developer"}
                        MenuItem {text:win.t("Aktivität");onTriggered:win.page="activity"}
                        MenuItem {text:win.t("Updates");onTriggered:{win.page="settings";win.settingsSection="updates";backend.checkUpdates()}}
                        MenuItem {text:win.t("Zertifikate");enabled:s.loggedIn;onTriggered:{win.page="certificates";backend.loadCertificates()}}
                    }
                }
                Rectangle {width:1;height:20;color:"#34373e";Layout.leftMargin:6;Layout.rightMargin:6}
                IconButton {text:"−";hint:win.t("Minimieren");onClicked:win.showMinimized()}
                IconButton {text:"□";hint:win.t("Maximieren");onClicked:win.visibility===Window.Maximized ? win.showNormal():win.showMaximized()}
                IconButton {text:"×";hint:win.t("Schließen");onClicked:win.close()}
            }
        }
        Rectangle {anchors.top:titlebar.bottom;anchors.left:parent.left;anchors.right:parent.right;height:1;color:"#25282e"}
        RowLayout {
            anchors{left:parent.left;right:parent.right;top:titlebar.bottom;bottom:footer.top;margins:24;topMargin:26}
            spacing:22
            ColumnLayout {
                Layout.preferredWidth:286;Layout.minimumWidth:286;Layout.maximumWidth:286;Layout.fillHeight:true;spacing:16
                Item {Layout.fillWidth:true;Layout.preferredHeight:30
                    Label {anchors.verticalCenter:parent.verticalCenter;text:"APPLE ACCOUNT";color:win.muted;font.pixelSize:10;font.letterSpacing:1.6;font.weight:Font.DemiBold;anchors.left:parent.left;anchors.leftMargin:4}
                }
                Card {
                    Layout.fillWidth:true
                    Layout.preferredHeight: accountColumn.implicitHeight+40
                    ColumnLayout {
                        id:accountColumn;anchors{left:parent.left;right:parent.right;top:parent.top;margins:20} spacing:12
                        RowLayout {
                            Rectangle {width:38;height:38;radius:12;color:"#30343b";Label {anchors.centerIn:parent;text:"●";color:s.loggedIn?win.accent:"#b1b7c2";font.pixelSize:19}}
                            ColumnLayout {spacing:4;Layout.fillWidth:true
                                Label {text:s.loggedIn ? s.team : "Apple-ID";font.weight:Font.DemiBold;Layout.fillWidth:true}
                                Label {text:s.loggedIn || win.restoringSession && s.email ? s.email : win.t("Dein Account");color:win.muted;font.pixelSize:11;Layout.fillWidth:true}
                            }
                        }
                        RowLayout {objectName:"accountAuthProgress";visible:win.authenticating && !s.challenge;Layout.fillWidth:true;spacing:8
                            BusyIndicator {running:parent.visible;implicitWidth:26;implicitHeight:26;palette.dark:win.accent}
                            Label {objectName:"accountAuthProgressText";text:win.restoringSession?win.t("Automatisch anmelden …"):win.t("Bei Apple anmelden …");color:win.accent;font.pixelSize:12;Layout.fillWidth:true}
                        }
                        Badge {objectName:"accountSessionExpired";visible:!s.loggedIn && s.authState==="expired";text:win.t("Sitzung abgelaufen");tone:"warning"}
                        Field {id:email;objectName:"emailField";visible:!s.loggedIn && !s.challenge && !win.restoringSession;Layout.fillWidth:true;placeholderText:"Apple-ID";text:s.email;enabled:!win.authenticating;onTextEdited:backend.editEmail(text);onAccepted:password.forceActiveFocus()}
                        Field {id:password;objectName:"passwordField";visible:!s.loggedIn && !s.challenge && !win.restoringSession;Layout.fillWidth:true;placeholderText:win.t("Passwort");echoMode:TextInput.Password;enabled:!win.authenticating;onAccepted:loginButton.clicked()}
                        Action {id:loginButton;objectName:"loginButton";visible:!s.loggedIn && !s.challenge && !win.restoringSession;Layout.fillWidth:true;text:win.authenticating?win.t("Bitte warten …"):win.t("Anmelden");primary:true;enabled:!win.authenticating && (!s.busy || s.scanning);onClicked:if(backend.login(email.text,password.text))password.clear()}
                        Action {visible:s.loggedIn && !s.challenge;Layout.fillWidth:true;text:win.t("Abmelden");enabled:!s.busy && !s.directsideInstalling;onClicked:backend.logout()}
                        ColumnLayout {
                            visible:s.challenge.length>0;Layout.fillWidth:true;spacing:10
                            Label {text:s.challenge==="team"?win.t("Team auswählen"):s.challenge==="pairing"?win.t("Pairing-Code"):win.t("Bestätigungscode");font.weight:Font.DemiBold}
                            Field {id:code;visible:s.challenge!=="team";Layout.fillWidth:true;placeholderText:"000000";font.pixelSize:24;font.letterSpacing:6;horizontalAlignment:Text.AlignHCenter;maximumLength:12;onAccepted:backend.submitCode(text)}
                            Label {visible:s.challengeError.length>0;text:s.challengeError;color:"#ffb49a";font.pixelSize:12}
                            Action {visible:s.challenge!=="team";Layout.fillWidth:true;text:win.t("Bestätigen");primary:true;onClicked:{backend.submitCode(code.text);code.clear()}}
                            Action {visible:s.challenge==="code";Layout.fillWidth:true;text:win.t("Code erneut senden");onClicked:backend.requestCode("devices",0)}
                            ComboBox {id:smsNumber;visible:s.challenge==="code" && s.numbers.length>1;Layout.fillWidth:true;model:s.numbers;textRole:"numberWithDialCode"}
                            Action {visible:s.challenge==="code" && s.numbers.length>0;Layout.fillWidth:true;text:win.t("SMS senden");onClicked:backend.requestCode("sms",s.numbers[Math.max(0,smsNumber.currentIndex)].id)}
                            ComboBox {id:team;visible:s.challenge==="team";Layout.fillWidth:true;model:s.teams;textRole:"name"}
                            Action {visible:s.challenge==="team";Layout.fillWidth:true;text:win.t("Team verwenden");primary:true;enabled:team.currentIndex>=0;onClicked:backend.selectTeam(s.teams[team.currentIndex].id)}
                            Action {Layout.fillWidth:true;text:win.t("Abbrechen");quiet:true;onClicked:backend.cancelChallenge()}
                        }
                    }
                }
                Card {
                    visible:s.usbState!=="ready" && !s.challenge.length
                    Layout.fillWidth:true;Layout.preferredHeight:missingColumn.implicitHeight+32
                    ColumnLayout {id:missingColumn;anchors{left:parent.left;right:parent.right;top:parent.top;margins:16} spacing:10
                        RowLayout {Label {text:"Apple USB";Layout.fillWidth:true;font.weight:Font.DemiBold} Badge {text:s.usbState==="stopped"?win.t("Gestoppt"):s.usbState==="missing"?win.t("Fehlt"):win.t("Nicht geprüft");tone:s.usbState==="missing"?"missing":"warning"}}
                        Action {text:s.usbState==="stopped"?win.t("Dienst starten"):win.t("USB / iTunes installieren");Layout.fillWidth:true;primary:true;enabled:!s.busy;onClicked:backend.setupComponents()}
                    }
                }
                Item {Layout.fillHeight:true}
            }
            ColumnLayout {
                Layout.fillWidth:true;Layout.fillHeight:true;spacing:16
                RowLayout {Layout.preferredHeight:30
                    IconButton {visible:win.page!=="install";text:"‹";hint:win.t("Zurück");onClicked:win.page="install"}
                    Label {text:win.page==="developer"?win.t("Entwicklermodus"):win.page==="certificates"?win.t("Zertifikate"):win.page==="confirm"?win.t("Entfernen bestätigen"):win.page==="settings"?win.t("Einstellungen"):win.page==="activity"?win.t("Aktivität"):win.page==="help"?win.t("Hilfe"):win.page==="apps"?win.t("Installierte Apps"):win.t("DEIN GERÄT");font.pixelSize:win.page==="install"?10:17;font.letterSpacing:win.page==="install"?1.6:0;color:win.page==="install"?win.muted:win.ink;font.weight:Font.DemiBold}
                    Item {Layout.fillWidth:true}
                    Action {visible:win.page==="activity";text:win.t("Kopieren");enabled:s.logs.length>0;onClicked:backend.copyActivity()}
                }
                Card {
                    visible:win.page==="install";Layout.fillWidth:true;Layout.preferredHeight:122
                    RowLayout {anchors.fill:parent;anchors.margins:20;spacing:18
                        Rectangle {width:43;height:70;radius:10;color:"#15171b";border.color:"#737c87";border.width:2
                            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:6;width:15;height:4;radius:2;color:"#737c87"}
                            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:7;width:18;height:2;radius:1;color:"#737c87"}
                            Label {anchors.centerIn:parent;text:"✓";color:win.accent;font.pixelSize:22;visible:s.devices.length>0}
                        }
                        ColumnLayout {Layout.fillWidth:true;spacing:6
                            Label {text:s.devices.length ? s.devices[s.deviceIndex].name:win.t("iPhone verbinden");font.pixelSize:19;font.weight:Font.DemiBold;Layout.fillWidth:true}
                        }
                        ComboBox {visible:s.devices.length>1;model:s.devices;textRole:"label";currentIndex:s.deviceIndex;enabled:!s.busy;onActivated:index=>backend.selectDevice(index);Layout.maximumWidth:210}
                        Badge {visible:s.devices.length>0;text:s.developerMode==="enabled"?"Dev ✓":s.developerMode==="disabled"?"Dev ✕":"Dev ?";tone:s.developerMode==="enabled"?"ok":s.developerMode==="disabled"?"missing":"warning";MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:win.page="developer"}}
                        IconButton {text:"↻";implicitWidth:44;implicitHeight:44;hint:win.t("Geräte aktualisieren");enabled:!s.busy;onClicked:backend.refresh()}
                        IconButton {text:"▦";implicitWidth:44;implicitHeight:44;hint:win.t("Installierte Apps");enabled:s.devices.length>0;onClicked:{win.appPage=0;win.page="apps"}}
                    }
                }
                Card {
                    objectName:"developerModeGuide";visible:win.page==="developer";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:18
                        RowLayout {Label {text:win.t("Entwicklermodus");font.pixelSize:20;font.weight:Font.DemiBold;Layout.fillWidth:true} Badge {text:s.developerMode==="enabled"?win.t("Aktiv"):s.developerMode==="disabled"?win.t("Aus"):win.t("Nicht geprüft");tone:s.developerMode==="enabled"?"ok":s.developerMode==="disabled"?"missing":"warning"}}
                        Text {text:win.t("Damit DirectSide auf deinem iPhone oder iPad starten kann.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Text {text:win.t("1. Auf dem Gerät: Einstellungen → Datenschutz & Sicherheit → Entwicklermodus einschalten.");color:win.ink;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Text {text:win.t("2. Gerät neu starten. Danach entsperren und Aktivieren bestätigen.");color:win.ink;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Text {text:win.t("3. Falls iOS fragt: Einstellungen → Allgemein → VPN & Geräteverwaltung → deinem Entwicklerprofil vertrauen.");color:win.ink;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        RowLayout {Action {text:win.t("Option auf dem Gerät anzeigen");enabled:s.devices.length>0 && !s.busy;onClicked:backend.revealDeveloperMode()} Action {text:win.t("Erneut prüfen");enabled:s.devices.length>0 && !s.busy;onClicked:backend.inspectDevice()}}
                        Item {Layout.fillHeight:true}
                        Action {text:win.t("Weiter zur Installation");primary:true;onClicked:win.page="install"}
                    }
                }
                Card {
                    id:installCard;objectName:"installCard";visible:win.page==="install";Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:272;border.color:s.vpnState==="missing"?"#805440":"#30333a"
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:12
                        RowLayout {visible:s.vpnState!=="missing" || s.settingUp;spacing:8
                            Image {source:s.icon;Layout.preferredWidth:56;Layout.preferredHeight:56;sourceSize.width:112;sourceSize.height:112}
                            ColumnLayout {spacing:6
                                RowLayout {spacing:8
                                    Label {text:win.t("DirectSide für iPhone");font.pixelSize:21;font.weight:Font.DemiBold;font.letterSpacing:-0.4}
                                    Badge {objectName:"ipaVersionBadge";visible:s.releaseVersion.length>0;text:s.releaseVersion}
                                }
                                Label {text:"iOS 17+ · "+win.t("Pairing inklusive");font.pixelSize:12;color:win.muted}
                            }
                        }
                        RowLayout {objectName:"vpnInstallPrompt";visible:s.vpnState==="missing" && !s.settingUp;Layout.fillWidth:true;spacing:20
                            Rectangle {property real codeSize:Math.max(96,Math.min(156,installCard.height-180));Layout.preferredWidth:codeSize;Layout.preferredHeight:codeSize;radius:12;color:"white"
                                Image {anchors.fill:parent;anchors.margins:6;source:s.vpnQr;fillMode:Image.PreserveAspectFit;smooth:false}
                            }
                            ColumnLayout {Layout.fillWidth:true;spacing:12
                                Badge {text:win.t("LocalDevVPN fehlt");tone:"missing"}
                                Text {text:win.t("Auf dem ausgewählten Gerät installieren");font.pixelSize:18;font.weight:Font.DemiBold;color:win.ink;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                                Text {text:win.t("Der Anleitung in der App folgen.");color:win.muted;font.pixelSize:13;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                            }
                        }
                        RowLayout {objectName:"deviceSetupProgress";visible:s.settingUp;Layout.fillWidth:true;spacing:10
                            BusyIndicator {running:parent.visible;implicitWidth:30;implicitHeight:30}
                            Text {objectName:"deviceSetupProgressText";text:win.t(s.setupPhase);color:win.accent;wrapMode:Text.WordWrap;Layout.fillWidth:true;font.pixelSize:13}
                        }
                        Action {objectName:"installDirectSideButton";text:s.directsideInstalling?win.t("Bitte warten …"):win.t("DirectSide installieren");primary:true;Layout.fillWidth:true;implicitHeight:48;enabled:s.loggedIn && s.devices.length>0 && (!s.busy || s.scanning) && !s.updateBusy && !s.directsideInstalling && s.releaseIPA;onClicked:backend.downloadDirectSide()}
                        RowLayout {objectName:"customIPARow";Layout.fillWidth:true;spacing:8
                        Rectangle {Layout.fillWidth:true;implicitHeight:44;radius:12;color:"#15171b";border.color:"#30343b"
                            RowLayout {anchors.fill:parent;anchors.leftMargin:15;anchors.rightMargin:8;spacing:12
                                Label {text:"↳";color:win.muted;font.pixelSize:19}
                                Label {text:s.customIPAName || win.t("Eigene IPA");Layout.fillWidth:true;color:s.customIPAName?win.ink:win.muted}
                                IconButton {text:"…";hint:win.t("IPA auswählen");enabled:!s.busy && !s.updateBusy && !s.directsideInstalling;onClicked:backend.chooseIPA()}
                            }
                        }
                        Action {objectName:"installCustomIPAButton";text:win.t("IPA installieren");enabled:s.loggedIn && s.devices.length>0 && s.customIPA.length>0 && !s.busy && !s.updateBusy && !s.directsideInstalling;onClicked:backend.installCustomIPA()}
                        }
                        Item {Layout.fillHeight:true}
                    }
                }
                Card {
                    visible:win.page==="settings";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
                        RowLayout {
                            Action {text:win.t("Komponenten");quiet:win.settingsSection!=="system";onClicked:win.settingsSection="system"}
                            Action {text:"LiveContainer";quiet:win.settingsSection!=="livecontainer";onClicked:win.settingsSection="livecontainer"}
                            Action {text:win.t("Sprache");quiet:win.settingsSection!=="language";onClicked:win.settingsSection="language"}
                            Action {text:win.t("Updates");quiet:win.settingsSection!=="updates";onClicked:win.settingsSection="updates"}
                        }
                        ColumnLayout {visible:win.settingsSection==="system";Layout.fillWidth:true;spacing:16
                        RowLayout {Label {text:win.t("Apple USB-Treiber");Layout.fillWidth:true} Badge {text:s.usbState==="ready"?win.t("Installiert"):s.usbState==="stopped"?win.t("Gestoppt"):s.usbState==="missing"?win.t("Fehlt"):win.t("Nicht geprüft");tone:s.usbState==="ready"?"ok":s.usbState==="missing"?"missing":"warning"}}
                        RowLayout {Label {text:win.t("Apple-Anmeldung · lokal");Layout.fillWidth:true} Badge {text:s.authLocal?win.t("Bereit"):win.t("Prüfen");tone:s.authLocal?"ok":"warning"}}
                        RowLayout {Label {text:win.t("LocalDevVPN · dieses Gerät");Layout.fillWidth:true} Badge {text:s.vpnState==="installed"?win.t("Installiert"):s.vpnState==="missing"?win.t("Fehlt"):win.t("Nicht geprüft");tone:s.vpnState==="installed"?"ok":s.vpnState==="missing"?"missing":"warning"}}
                        Action {visible:s.usbState!=="ready";text:s.usbState==="stopped"?win.t("Apple USB starten"):win.t("Apple USB / iTunes installieren");primary:true;enabled:!s.busy;onClicked:backend.setupComponents()}
                        Action {text:win.t("Erneut prüfen");enabled:!s.busy;onClicked:backend.checkComponents()}
                        Action {objectName:"repairDirectSideButton";text:win.t("DirectSide-Einrichtung reparieren");enabled:s.devices.length>0 && !s.busy && !s.updateBusy;onClicked:if(backend.repairDirectSide())win.page="install"}
                        Action {text:s.slotsUsed>=0?win.t("Apps ansehen · ")+s.slotsUsed+win.t(" / 3 Plätze"):win.t("Apps ansehen");enabled:s.devices.length>0;onClicked:{win.appPage=0;win.page="apps"}}
                        Action {text:win.t("Zertifikate verwalten");enabled:s.loggedIn && !s.busy;onClicked:{win.page="certificates";backend.loadCertificates()}}
                        }
                        ColumnLayout {visible:win.settingsSection==="livecontainer";Layout.fillWidth:true;spacing:16
                        RowLayout {Label {text:"LiveContainer";Layout.fillWidth:true} Badge {text:"Optional"} Badge {text:s.lcState==="installed"?win.t("Installiert"):s.lcState==="missing"?win.t("Fehlt"):win.t("Nicht geprüft");tone:s.lcState==="installed"?"ok":s.lcState==="missing"?"missing":"warning"}}
                        RowLayout {
                            Action {text:s.lcState==="installed"?win.t("Neu installieren"):win.t("Installieren");enabled:!s.busy && s.loggedIn && s.devices.length>0;onClicked:backend.installLiveContainer()}
                            Action {text:win.t("Zertifikat übertragen");enabled:!s.busy && s.loggedIn && s.lcState==="installed" && s.directsidePresent;onClicked:backend.prepareLiveContainer()}
                        }
                        Label {visible:s.lcPrepared;text:win.t("Auf dem iPhone: DirectSide → Konto → LiveContainer einrichten");color:win.accent;font.pixelSize:12;Layout.fillWidth:true}
                        }
                        RowLayout {visible:win.settingsSection==="language";Layout.fillWidth:true
                            Label {text:win.t("Sprache");Layout.fillWidth:true}
                            ComboBox {model:["English","Deutsch"];currentIndex:s.language==="de"?1:0;onActivated:index=>backend.setLanguage(index===1?"de":"en")}
                        }
                        ColumnLayout {visible:win.settingsSection==="updates";Layout.fillWidth:true;spacing:12
                            RowLayout {Label {text:"DirectSide · "+s.version;Layout.fillWidth:true} Badge {text:s.updateBusy?win.t("Prüfen …"):s.updateState==="empty"?win.t("Noch kein Release"):s.updateState==="available"?s.releaseVersion:s.updateState==="current"?win.t("Aktuell"):win.t("Nicht geprüft");tone:s.updateState==="current"?"ok":s.updateState==="error"?"missing":"warning"}}
                            RowLayout {
                                Action {text:win.t("Nach Updates suchen");enabled:!s.updateBusy;onClicked:backend.checkUpdates()}
                            }
                            Label {text:win.t("GitHub · privates Repository");font.weight:Font.DemiBold;Layout.topMargin:8}
                            RowLayout {Layout.fillWidth:true
                                Field {id:githubToken;Layout.fillWidth:true;placeholderText:win.t("GitHub-Token · Contents: Read");echoMode:TextInput.Password;enabled:!s.updateBusy}
                                Action {text:win.t("Speichern");enabled:githubToken.text.length>0 && !s.updateBusy;onClicked:{backend.saveGitHub(githubToken.text);githubToken.clear()}}
                                IconButton {visible:s.githubSaved;text:"×";hint:win.t("GitHub-Zugang entfernen");enabled:!s.updateBusy;onClicked:backend.forgetGitHub()}
                            }
                            Text {text:win.t("Zugriff nur für Serekay/directside. Verschlüsselt für deinen Windows-Benutzer gespeichert.");color:win.muted;font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                            Label {text:win.t("Automatische Prüfung beim Start und alle 6 Stunden.");color:win.muted;font.pixelSize:12;Layout.fillWidth:true}
                        }
                        Item {Layout.fillHeight:true}
                    }
                }
                Card {
                    visible:win.page==="help";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:12
                        Label {text:win.t("So richtest du es ein");font.pixelSize:20;font.weight:Font.DemiBold}
                        Label {text:win.t("1   Gerät verbinden");font.weight:Font.DemiBold}
                        Text {text:win.t("iPhone oder iPad entsperren, USB anschließen und Vertrauen bestätigen. Bei mehreren Geräten oben das Ziel wählen.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Label {text:win.t("2   Anmelden und installieren");font.weight:Font.DemiBold}
                        Text {text:win.t("Apple-ID eingeben. Bestätigungscode hier eintragen, IPA wählen und installieren. Fehlende PC-Komponenten unter Einstellungen einrichten.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Label {text:win.t("3   Auf dem iPhone vorbereiten");font.weight:Font.DemiBold}
                        Text {text:win.t("LocalDevVPN über den angezeigten QR-Code installieren und verbinden. Entwicklerprofil vertrauen; falls verlangt Entwicklermodus aktivieren.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Label {text:win.t("LiveContainer · optional");font.weight:Font.DemiBold}
                        Text {text:win.t("Unter Einstellungen installieren und Zertifikat übertragen. Dann auf dem iPhone: DirectSide → Konto → LiveContainer einrichten. In LiveContainer den JIT-less-Test ausführen.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Item {Layout.fillHeight:true}
                        RowLayout {Badge {text:win.t("3 Apps / Gerät")} Badge {text:win.t("10 App-IDs / Account")} Badge {text:win.t("Max. 3 Geräte / Account")}}
                    }
                }
                Card {
                    visible:win.page==="apps";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:20;spacing:14
                        RowLayout {Layout.fillWidth:true
                            ComboBox {model:s.devices;textRole:"label";currentIndex:s.deviceIndex;enabled:!s.busy;Layout.fillWidth:true;onActivated:index=>{win.appPage=0;backend.selectDevice(index)}}
                        }
                        RowLayout {spacing:8
                            Action {text:win.t("Alle Apps · ")+s.installedApps.length;quiet:win.developerOnly;onClicked:{win.appPage=0;win.developerOnly=false}}
                            Action {text:win.t("Entwickler · ")+s.developerApps.length;quiet:!win.developerOnly;onClicked:{win.appPage=0;win.developerOnly=true}}
                        }
                        GridView {Layout.fillWidth:true;Layout.fillHeight:true;clip:true;interactive:false;model:win.visibleApps;cellWidth:width/3;cellHeight:height/3
                            delegate:Item {required property var modelData;width:GridView.view.cellWidth;height:GridView.view.cellHeight
                                Rectangle {anchors.fill:parent;anchors.rightMargin:8;anchors.bottomMargin:8;radius:12;color:"#25282e"
                                    RowLayout {anchors.fill:parent;anchors.margins:12;spacing:10
                                        Rectangle {Layout.preferredWidth:44;Layout.preferredHeight:44;radius:11;color:"#363e49"
                                            Image {anchors.fill:parent;source:modelData.icon || "";visible:source.toString().length>0;fillMode:Image.PreserveAspectFit}
                                            Label {anchors.centerIn:parent;visible:!modelData.icon;text:modelData.name.charAt(0).toUpperCase();font.pixelSize:21;font.weight:Font.DemiBold}
                                        }
                                        ColumnLayout {Layout.fillWidth:true;spacing:5
                                            Label {text:modelData.name;Layout.fillWidth:true;font.pixelSize:12;font.weight:Font.DemiBold}
                                            Label {text:modelData.developer?win.t("Entwickler-App"):win.t("Installiert");color:modelData.developer?win.accent:win.muted;font.pixelSize:10;Layout.fillWidth:true}
                                        }
                                        IconButton {text:"⌫";hint:win.t("App entfernen");enabled:!s.busy && !s.updateBusy && !s.directsideInstalling;onClicked:{backend.requestAppRemoval(modelData.id);if(backend.state.removal.kind)win.page="confirm"}}
                                    }
                                }
                            }
                        }
                        Label {visible:s.installedApps.length===0;text:s.devices.length?(s.scanning?win.t("Apps werden gelesen …"):win.t("App-Liste nicht verfügbar. Gerät entsperren.")):win.t("Kein Gerät verbunden");color:win.muted;Layout.fillWidth:true}
                        RowLayout {Layout.fillWidth:true
                            IconButton {text:"‹";hint:win.t("Vorherige Seite");enabled:win.appPage>0;onClicked:win.appPage--}
                            Item {Layout.fillWidth:true}
                            Label {text:(win.appPage+1)+" / "+Math.max(1,Math.ceil(win.filteredApps.length/9));font.pixelSize:12;color:win.muted}
                            Item {Layout.fillWidth:true}
                            IconButton {text:"›";hint:win.t("Nächste Seite");enabled:(win.appPage+1)*9<win.filteredApps.length;onClicked:win.appPage++}
                        }
                    }
                }
                Card {
                    visible:win.page==="certificates";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:12
                        RowLayout {Label {text:s.team;Layout.fillWidth:true} Badge {objectName:"certificateCountBadge";text:win.t("Zertifikate")+" · "+(s.certificatesLoaded?String(s.certificates.length):"?");tone:s.certificateLimit?"missing":"neutral"} IconButton {text:"↻";hint:win.t("Erneut prüfen");enabled:s.loggedIn && !s.busy;onClicked:backend.loadCertificates()}}
                        Text {text:win.t("Ein Zertifikat kann mehrere Apps signieren.");color:win.muted;font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        Action {objectName:"manageDeviceAppsButton";text:win.t("Apps auf diesem Gerät")+" · "+(s.slotsUsed>=0?s.slotsUsed+" / 3":"?");enabled:s.devices.length>0 && !s.busy;onClicked:{win.page="apps";win.developerOnly=true;backend.inspectDevice()}}
                        Repeater {model:s.certificates.slice(win.certificatePage*3,win.certificatePage*3+3)
                            delegate:Rectangle {required property var modelData;Layout.fillWidth:true;implicitHeight:66;radius:12;color:"#25282e"
                                RowLayout {anchors.fill:parent;anchors.margins:12;spacing:8
                                    ColumnLayout {Layout.fillWidth:true;spacing:4
                                        Label {text:modelData.name;Layout.fillWidth:true;font.weight:Font.DemiBold}
                                        Label {text:win.t("Seriennummer · ")+(modelData.serial || "?").slice(-8)+(modelData.platform?" · "+modelData.platform:"");font.pixelSize:11;color:win.muted;Layout.fillWidth:true}
                                    }
                                    Badge {visible:modelData.reusable;text:win.t("Schlüssel vorhanden");tone:"ok"}
                                    IconButton {text:"⌫";hint:win.t("Zertifikat widerrufen");enabled:!s.busy && !s.updateBusy && !!modelData.serial;onClicked:{backend.requestCertificateRemoval(modelData.serial);if(backend.state.removal.kind)win.page="confirm"}}
                                }
                            }
                        }
                        Label {visible:s.certificatesLoaded && s.certificates.length===0;text:win.t("Keine Zertifikate vorhanden");color:win.muted}
                        Item {Layout.fillHeight:true}
                        RowLayout {Layout.fillWidth:true
                            IconButton {text:"‹";hint:win.t("Vorherige Seite");enabled:win.certificatePage>0;onClicked:win.certificatePage--}
                            Item {Layout.fillWidth:true}
                            Label {text:(win.certificatePage+1)+" / "+Math.max(1,Math.ceil(s.certificates.length/3));font.pixelSize:12;color:win.muted}
                            Item {Layout.fillWidth:true}
                            IconButton {text:"›";hint:win.t("Nächste Seite");enabled:(win.certificatePage+1)*3<s.certificates.length;onClicked:win.certificatePage++}
                        }
                    }
                }
                Card {
                    visible:win.page==="confirm";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:18
                        Item {Layout.fillHeight:true}
                        Label {text:s.removal.name || "";font.pixelSize:20;font.weight:Font.DemiBold;Layout.fillWidth:true}
                        Text {text:s.removal.kind==="app"?win.t("App und zugehörige Daten werden vom ausgewählten Gerät gelöscht."):win.t("Damit signierte Apps auf allen Geräten müssen anschließend neu signiert werden.");color:win.muted;wrapMode:Text.WordWrap;Layout.fillWidth:true}
                        RowLayout {spacing:12
                            Action {objectName:"confirmRemovalButton";text:s.removal.kind==="app"?win.t("App entfernen"):win.t("Zertifikat widerrufen");enabled:!!s.removal.id && !s.busy;onClicked:{var target=s.removal.kind==="app"?"apps":"certificates";backend.confirmRemoval();win.page=target}}
                            Action {text:win.t("Abbrechen");onClicked:{var target=s.removal.kind==="app"?"apps":"certificates";backend.cancelRemoval();win.page=target}}
                        }
                        Item {Layout.fillHeight:true}
                    }
                }
                Card {
                    visible:win.page==="activity";Layout.fillWidth:true;Layout.fillHeight:true
                    ScrollView {anchors.fill:parent;anchors.margins:20;clip:true;contentWidth:availableWidth
                        TextArea {text:s.logs.join("\n\n");readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;color:"#adb4bf";font.family:"Consolas";font.pixelSize:12;selectionColor:"#287e68";selectedTextColor:win.ink;background:null}
                    }
                }
            }
        }
        Rectangle {
            id:footer;anchors{left:parent.left;right:parent.right;bottom:parent.bottom;margins:1} height:88;color:"#17191e";radius:18
            Rectangle {anchors.top:parent.top;width:parent.width;height:18;color:parent.color}
            ColumnLayout {anchors.fill:parent;anchors.leftMargin:24;anchors.rightMargin:24;anchors.topMargin:8;anchors.bottomMargin:12;spacing:4
            RowLayout {Layout.fillWidth:true;spacing:8
                Item {Layout.fillWidth:true}
                Label {visible:s.updateBusy || s.updateMessage.length>0;text:s.updateBusy?win.t("GitHub …")+(s.updateProgress>0?" "+s.updateProgress+"%":""):win.t(s.updateMessage);font.pixelSize:12;color:s.updateState==="error"?"#ffb49a":win.muted;Layout.maximumWidth:parent.width*0.55;horizontalAlignment:Text.AlignRight}
                Label {visible:!!s.error || (s.busy && !s.scanning && !s.settingUp) || s.lcPrepared || s.success;text:(s.error || (s.busy && !s.scanning?s.status:s.lcPrepared?win.t("Zertifikat übertragen · auf dem iPhone fortfahren"):s.success?s.status:"")).split("\n")[0];font.pixelSize:12;color:s.error?"#ffb49a":win.muted;Layout.maximumWidth:parent.width-150;horizontalAlignment:Text.AlignRight}
                IconButton {visible:s.error.length>0;text:"≡";hint:win.t("Aktivität");onClicked:win.page="activity"}
                ProgressBar {visible:s.busy && !s.scanning;Layout.preferredWidth:100;from:0;to:100;value:s.progress;indeterminate:s.progress<=0
                    background:Rectangle{implicitHeight:4;radius:2;color:"#343a42"}
                    contentItem:Item {Rectangle{width:parent.width*(s.progress>0?s.progress/100:0.4);height:4;radius:2;color:win.accent}}
                }
                IconButton {visible:s.error.length>0;text:"×";hint:win.t("Fehler ausblenden");onClicked:backend.dismissError()}
            }
            RowLayout {Layout.fillWidth:true;spacing:8
                Item {Layout.fillWidth:true}
                Badge {visible:win.page==="settings" && win.settingsSection!=="updates" && s.email.length>0 && s.email===s.savedEmail;text:win.t("Apple-ID gespeichert")}
                Badge {visible:win.page==="settings" && win.settingsSection!=="updates";text:win.t("Windows-Schlüsselbund")}
                Badge {visible:win.page==="settings" && win.settingsSection==="updates" && s.githubSaved;text:win.t("GitHub gespeichert");tone:"ok"}
                Badge {id:quotaBadge;objectName:"quotaBadge";text:win.quotaText;tone:!win.quotaKnown?"warning":s.appIdsAvailable===0?"missing":s.appIdsAvailable<=3?"warning":"ok"
                    ToolTip.visible:quotaHover.hovered;ToolTip.text:win.t("Neue App-Kennungen pro Account innerhalb von 7 Tagen. Keine installierten Apps.")+(s.appIdsRegistered>=0?"\n"+s.appIdsRegistered+" "+win.t("registrierte Kennungen"):"");HoverHandler {id:quotaHover}
                }
                Badge {visible:win.page==="install" || win.page==="apps";text:s.slotsUsed>=0?"Apps · "+s.slotsUsed+" / 3 · "+win.t("Gerät"):win.t("App-Plätze nicht geprüft");tone:s.slotsUsed<0?"warning":s.slotsUsed>=3?"missing":s.slotsUsed===2?"warning":"ok"}
                Badge {objectName:"sessionBadge";text:win.accountStatus;tone:s.loggedIn?"ok":s.authState==="expired" || s.authState==="rejected"?"missing":"warning"}
                Badge {text:win.t("7 Tage")}
            }
            }
        }
    }
    // Invisible edge handles keep the custom window resizable without OS chrome.
    Repeater {model:[Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.LeftEdge|Qt.TopEdge,Qt.RightEdge|Qt.TopEdge,Qt.LeftEdge|Qt.BottomEdge,Qt.RightEdge|Qt.BottomEdge]
        delegate:MouseArea {required property int modelData;z:10;width:(modelData&Qt.LeftEdge || modelData&Qt.RightEdge)?5:win.width-10;height:(modelData&Qt.TopEdge || modelData&Qt.BottomEdge)?5:win.height-10;x:modelData&Qt.RightEdge?win.width-5:modelData&Qt.LeftEdge?0:5;y:modelData&Qt.BottomEdge?win.height-5:modelData&Qt.TopEdge?0:5;onPressed:win.startSystemResize(modelData)}
    }
}
