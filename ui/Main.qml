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
    property string page: "install"
    property color accent: "#36dbb1"
    property color ink: "#f4f5f7"
    property color muted: "#92979f"
    property bool ready: s.loggedIn && s.devices.length > 0 && s.ipa.length > 0 && !s.busy

    component Label: Text {
        color: win.ink; font.family: win.font.family; font.pixelSize: 14
        elide: Text.ElideRight
    }
    component Badge: Rectangle {
        property string text: ""
        property bool positive: false
        implicitWidth: badgeText.implicitWidth+22; implicitHeight: 28
        radius: 9; color: positive ? "#173d33" : "#282b30"
        border.color: positive ? "#295b4c" : "#35383e"
        Label {id: badgeText; anchors.centerIn:parent; text:parent.text; font.pixelSize:11; font.weight:Font.DemiBold; color:parent.positive ? win.accent : "#a5aab2"}
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
        property string hint: ""
        implicitWidth:36; implicitHeight:36; quiet:true
        ToolTip.visible: hovered; ToolTip.text:hint; ToolTip.delay:500
        Accessible.name:hint
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
                Badge {text:"0.1.0"}
                Item {Layout.fillWidth:true}
                IconButton {text:"⚙";hint:"Einstellungen";onClicked:win.page=win.page==="settings" ? "install":"settings"}
                IconButton {text:"≡";hint:"Aktivität";onClicked:win.page=win.page==="activity" ? "install":"activity"}
                Rectangle {width:1;height:20;color:"#34373e";Layout.leftMargin:6;Layout.rightMargin:6}
                IconButton {text:"−";hint:"Minimieren";onClicked:win.showMinimized()}
                IconButton {text:"□";hint:"Maximieren";onClicked:win.visibility===Window.Maximized ? win.showNormal():win.showMaximized()}
                IconButton {text:"×";hint:"Schließen";onClicked:win.close()}
            }
        }
        Rectangle {anchors.top:titlebar.bottom;anchors.left:parent.left;anchors.right:parent.right;height:1;color:"#25282e"}
        RowLayout {
            anchors{left:parent.left;right:parent.right;top:titlebar.bottom;bottom:footer.top;margins:24;topMargin:26}
            spacing:22
            ColumnLayout {
                Layout.preferredWidth:286;Layout.minimumWidth:286;Layout.maximumWidth:286;Layout.fillHeight:true;spacing:16
                Label {text:"APPLE ACCOUNT";color:win.muted;font.pixelSize:10;font.letterSpacing:1.6;font.weight:Font.DemiBold;Layout.leftMargin:4}
                Card {
                    Layout.fillWidth:true
                    Layout.preferredHeight: accountColumn.implicitHeight+40
                    ColumnLayout {
                        id:accountColumn;anchors{left:parent.left;right:parent.right;top:parent.top;margins:20} spacing:12
                        RowLayout {
                            Rectangle {width:38;height:38;radius:12;color:"#30343b";Label {anchors.centerIn:parent;text:"●";color:s.loggedIn?win.accent:"#b1b7c2";font.pixelSize:19}}
                            ColumnLayout {spacing:4;Layout.fillWidth:true
                                Label {text:s.loggedIn ? s.team : "Apple-ID";font.weight:Font.DemiBold;Layout.fillWidth:true}
                                Label {text:s.loggedIn ? s.email : "Dein Account";color:win.muted;font.pixelSize:11;Layout.fillWidth:true}
                            }
                        }
                        Badge {visible:s.loggedIn;text:"●  Angemeldet";positive:true}
                        Field {id:email;visible:!s.loggedIn && !s.challenge;Layout.fillWidth:true;placeholderText:"Apple-ID";text:s.email;enabled:!s.busy;onAccepted:password.forceActiveFocus()}
                        Field {id:password;visible:!s.loggedIn && !s.challenge;Layout.fillWidth:true;placeholderText:"Passwort";echoMode:TextInput.Password;enabled:!s.busy;onAccepted:loginButton.clicked()}
                        Action {id:loginButton;visible:!s.loggedIn && !s.challenge;Layout.fillWidth:true;text:"Anmelden";primary:true;enabled:!s.busy;onClicked:{backend.login(email.text,password.text);password.clear()}}
                        Action {visible:s.loggedIn && !s.challenge;Layout.fillWidth:true;text:"Abmelden";enabled:!s.busy;onClicked:backend.logout()}
                        ColumnLayout {
                            visible:s.challenge.length>0;Layout.fillWidth:true;spacing:10
                            Label {text:s.challenge==="team"?"Team auswählen":s.challenge==="pairing"?"Pairing-Code":"Bestätigungscode";font.weight:Font.DemiBold}
                            Field {id:code;visible:s.challenge!=="team";Layout.fillWidth:true;placeholderText:"000000";font.pixelSize:24;font.letterSpacing:6;horizontalAlignment:Text.AlignHCenter;maximumLength:12;onAccepted:backend.submitCode(text)}
                            Label {visible:s.challengeError.length>0;text:s.challengeError;color:"#ffb49a";font.pixelSize:12}
                            Action {visible:s.challenge!=="team";Layout.fillWidth:true;text:"Bestätigen";primary:true;onClicked:{backend.submitCode(code.text);code.clear()}}
                            Action {visible:s.challenge==="code";Layout.fillWidth:true;text:"Code erneut senden";onClicked:backend.requestCode("devices",0)}
                            ComboBox {id:smsNumber;visible:s.challenge==="code" && s.numbers.length>1;Layout.fillWidth:true;model:s.numbers;textRole:"numberWithDialCode"}
                            Action {visible:s.challenge==="code" && s.numbers.length>0;Layout.fillWidth:true;text:"SMS senden";onClicked:backend.requestCode("sms",s.numbers[Math.max(0,smsNumber.currentIndex)].id)}
                            ComboBox {id:team;visible:s.challenge==="team";Layout.fillWidth:true;model:s.teams;textRole:"name"}
                            Action {visible:s.challenge==="team";Layout.fillWidth:true;text:"Team verwenden";primary:true;enabled:team.currentIndex>=0;onClicked:backend.selectTeam(s.teams[team.currentIndex].id)}
                            Action {Layout.fillWidth:true;text:"Abbrechen";quiet:true;onClicked:backend.cancelChallenge()}
                        }
                    }
                }
                Item {Layout.fillHeight:true}
                RowLayout {spacing:8;Badge {text:"3 App-Plätze"} Badge {text:"7 Tage"}}
            }
            ColumnLayout {
                Layout.fillWidth:true;Layout.fillHeight:true;spacing:16
                RowLayout {
                    IconButton {visible:win.page!=="install";text:"‹";hint:"Zurück";onClicked:win.page="install"}
                    Label {text:win.page==="settings"?"Einstellungen":win.page==="activity"?"Aktivität":"DEIN IPHONE";font.pixelSize:win.page==="install"?10:17;font.letterSpacing:win.page==="install"?1.6:0;color:win.page==="install"?win.muted:win.ink;font.weight:Font.DemiBold}
                    Item {Layout.fillWidth:true}
                    Badge {visible:win.page==="install";text:s.devices.length?"●  USB verbunden":"Nicht verbunden";positive:s.devices.length>0}
                }
                Card {
                    visible:win.page==="install";Layout.fillWidth:true;Layout.preferredHeight:122
                    RowLayout {anchors.fill:parent;anchors.margins:20;spacing:18
                        Rectangle {width:43;height:70;radius:10;color:"#15171b";border.color:"#737c87";border.width:2
                            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;y:6;width:15;height:4;radius:2;color:"#737c87"}
                            Rectangle {anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:7;width:18;height:2;radius:1;color:"#737c87"}
                            Label {anchors.centerIn:parent;text:"✓";color:win.accent;font.pixelSize:22;visible:s.devices.length>0}
                        }
                        ColumnLayout {Layout.fillWidth:true;spacing:8
                            Label {text:s.devices.length ? s.devices[s.deviceIndex].name:"iPhone verbinden";font.pixelSize:19;font.weight:Font.DemiBold;Layout.fillWidth:true}
                            RowLayout {Badge {text:"USB";positive:s.devices.length>0} Badge {text:s.devices.length?"Bereit":"Entsperren & vertrauen";positive:s.devices.length>0}}
                        }
                        ComboBox {visible:s.devices.length>1;model:s.devices;textRole:"name";currentIndex:s.deviceIndex;onActivated:index=>backend.selectDevice(index);Layout.maximumWidth:130}
                        IconButton {text:"↻";hint:"Geräte aktualisieren";enabled:!s.busy;onClicked:backend.refresh()}
                    }
                }
                Card {
                    visible:win.page==="install";Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:272
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
                        RowLayout {spacing:14
                            Image {source:s.icon;Layout.preferredWidth:56;Layout.preferredHeight:56;sourceSize.width:112;sourceSize.height:112}
                            ColumnLayout {spacing:6
                                Label {text:"DirectSide für iPhone";font.pixelSize:21;font.weight:Font.DemiBold;font.letterSpacing:-0.4}
                                RowLayout {Badge {text:"iOS 17+"} Badge {text:"Pairing inklusive";positive:true}}
                            }
                        }
                        Item {Layout.fillHeight:true}
                        Rectangle {Layout.fillWidth:true;implicitHeight:52;radius:12;color:"#15171b";border.color:"#30343b"
                            RowLayout {anchors.fill:parent;anchors.leftMargin:15;anchors.rightMargin:8;spacing:12
                                Label {text:"↳";color:win.muted;font.pixelSize:19}
                                Label {text:s.ipaName || "IPA auswählen";Layout.fillWidth:true;color:s.ipaName?win.ink:win.muted}
                                IconButton {text:"…";hint:"IPA auswählen";enabled:!s.busy;onClicked:backend.chooseIPA()}
                            }
                        }
                        Action {text:s.success?"✓  Installiert":s.busy?"Bitte warten …":"Auf iPhone installieren  →";primary:true;enabled:win.ready;Layout.fillWidth:true;implicitHeight:48;onClicked:backend.install()}
                        RowLayout {spacing:8
                            Badge {text:s.loggedIn?"✓ Apple-ID":"Apple-ID fehlt";positive:s.loggedIn}
                            Badge {text:s.devices.length?"✓ iPhone":"iPhone fehlt";positive:s.devices.length>0}
                            Badge {text:s.ipaName?"✓ IPA":"IPA fehlt";positive:s.ipaName.length>0}
                        }
                    }
                }
                Card {
                    visible:win.page==="settings";Layout.fillWidth:true;Layout.fillHeight:true
                    ColumnLayout {anchors.fill:parent;anchors.margins:24;spacing:16
                        Label {text:"Anmeldeverbindung";font.pixelSize:18;font.weight:Font.DemiBold}
                        Badge {text:"HTTPS";positive:true}
                        Field {id:server;Layout.fillWidth:true;text:s.server;placeholderText:"Anisette-Server";enabled:!s.busy}
                        Action {text:"Speichern";primary:true;enabled:!s.busy;onClicked:backend.saveServer(server.text)}
                        Item {Layout.fillHeight:true}
                        RowLayout {Badge {text:"Apple-ID gespeichert"} Badge {text:"Windows-Schlüsselbund";positive:true}}
                    }
                }
                Card {
                    visible:win.page==="activity";Layout.fillWidth:true;Layout.fillHeight:true
                    ListView {anchors.fill:parent;anchors.margins:20;clip:true;model:s.logs;spacing:12
                        delegate:Text {required property string modelData;width:ListView.view.width;text:modelData;wrapMode:Text.Wrap;color:"#adb4bf";font.family:"Consolas";font.pixelSize:12}
                    }
                }
            }
        }
        Rectangle {
            id:footer;anchors{left:parent.left;right:parent.right;bottom:parent.bottom;margins:1} height:54;color:"#17191e";radius:18
            Rectangle {anchors.top:parent.top;width:parent.width;height:18;color:parent.color}
            RowLayout {anchors.fill:parent;anchors.leftMargin:26;anchors.rightMargin:20;spacing:10
                Rectangle {width:6;height:6;radius:3;color:s.error?"#ff8d76":s.busy?"#eac17e":win.accent}
                Label {text:s.error || (s.busy?s.status:s.success?"Installiert":"Bereit");font.pixelSize:12;color:s.error?"#ffb49a":win.muted;Layout.fillWidth:true}
                ProgressBar {visible:s.busy;Layout.preferredWidth:100;from:0;to:100;value:s.progress;indeterminate:s.progress<=0
                    background:Rectangle{implicitHeight:4;radius:2;color:"#343a42"}
                    contentItem:Item {Rectangle{width:parent.width*(s.progress>0?s.progress/100:0.4);height:4;radius:2;color:win.accent}}
                }
                IconButton {visible:s.error.length>0;text:"×";hint:"Fehler ausblenden";onClicked:backend.dismissError()}
            }
        }
    }
    // Invisible edge handles keep the custom window resizable without OS chrome.
    Repeater {model:[Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.LeftEdge|Qt.TopEdge,Qt.RightEdge|Qt.TopEdge,Qt.LeftEdge|Qt.BottomEdge,Qt.RightEdge|Qt.BottomEdge]
        delegate:MouseArea {required property int modelData;z:10;width:(modelData&Qt.LeftEdge || modelData&Qt.RightEdge)?5:win.width-10;height:(modelData&Qt.TopEdge || modelData&Qt.BottomEdge)?5:win.height-10;x:modelData&Qt.RightEdge?win.width-5:modelData&Qt.LeftEdge?0:5;y:modelData&Qt.BottomEdge?win.height-5:modelData&Qt.TopEdge?0:5;onPressed:win.startSystemResize(modelData)}
    }
}
