# Architektur

## Gemeinsamer Kern

`src/core.rs` verwendet `isideload` für GrandSlam/Apple-Anmeldung, Developer-Team, Zertifikate, App-IDs, Provisioning und Mach-O-Signierung. `idevice` übernimmt USB, AFC, Installation Proxy, Remote Pairing und RSD. Es werden keine fremden Apps gestartet oder über deren Oberfläche gesteuert.

Unter Windows kommuniziert die Oberfläche über JSON-Zeilen in anonymen Prozesspipes mit dem eigenen Engine-Prozess. Unter iOS läuft derselbe Kern in einem separaten Worker-Thread. Eine kleine C-ABI übergibt Befehle und Ereignisse an SwiftUI. Die Oberfläche bleibt während Netzwerk- und Signiervorgängen bedienbar.

## iPhone-Transport

Windows generiert Anisette im eigenen Prozess über CoreADI64.dll. Provisionierung und Synchronisation kontaktieren Apple direkt; es gibt keinen automatischen Remote-Anisette-Fallback. Der lokale Provider existiert derzeit nur für Windows. Unter iOS schlägt er ausdrücklich fehl. Die unten beschriebene Erneuerung ist deshalb noch kein funktionierender Gesamtprozess.

1. LocalDevVPN stellt den lokalen Netzwerkweg bereit.
2. Bonjour ermittelt den Remote-Pairing-Port.
3. Die eigene Pairingdatei authentifiziert den Gegenpart.
4. Ein TLS-PSK-/CDTunnel-Handshake und ein Software-TCP-Stack öffnen RSD-Dienste.
5. AFC überträgt die signierte App; Installation Proxy installiert sie.

Ein gefundener Port gilt nicht automatisch als erfolgreiches Pairing. Die eigentliche Verbindung validiert den gespeicherten Schlüssel.

## Quellen

Windows liest Benutzer-Apps über Installation Proxy. Entwickler-Apps werden anhand von SignerIdentity beziehungsweise get-task-allow erkannt und pro Gerät gezählt. SpringBoard Services liefert die Original-Icons der aktuellen Seite. Antworten tragen die Geräte-ID; die UI verwirft Antworten eines anderen Geräts. Im Leerlauf läuft die Gerätesuche alle drei Sekunden, die App-Prüfung spätestens nach 30 Sekunden. Während Anmeldung und Installation starten keine konkurrierenden Geräteabfragen.

Die App liest HTTPS-Quellen im AltStore-/SideStore-JSON-Format. Sie unterstützt alte Downloadfelder und Versionslisten, Beschreibungen, Icons, Kategorien, News und beide verbreiteten Screenshotformate. Eine Quelle wird vor dem Hinzufügen angezeigt. Der QR-Code lädt nur die Quelle; er installiert keine App automatisch.

Installierte Apps merken sich Quell-URL, ursprüngliche Bundle-ID, Version, Build-Version und Original-IPA. Dadurch sind Updates aus Quellen und das reine Erneuern einer Signatur unterschiedliche Vorgänge.

## Selbst-Erneuerung

Der PC überträgt die ursprüngliche DirectSide-IPA. Die iPhone-App signiert diese Originaldatei für dasselbe Team neu und installiert sie über die eigene RSD-Verbindung. Die laufende App kann dabei durch iOS beendet werden. Bei Sammelerneuerungen steht sie deshalb zuletzt.

## Keine Geheimnisse in der Build-Umgebung

Die optionale LiveContainer-Einrichtung verwendet die offizielle Standalone-IPA mit Hashprüfung. Das vorhandene Signierzertifikat wird verschlüsselt als PKCS#12 direkt über USB an DirectSides Documents-Bereich übertragen, ohne Ausgabe im JSON-Ereignisprotokoll. iOS validiert das Archiv, speichert es im Geräteschlüsselbund und entfernt die Übertragungsdatei. Erst „LiveContainer einrichten“ übergibt die Identität über LiveContainers lokales certificate-URL-Protokoll. Ein erfolgreicher URL-Aufruf bestätigt keine funktionierende Gast-Signierung. Diese neuen iOS-Pfade sind noch nicht gebaut beziehungsweise am Gerät getestet.

GitHub erstellt nur den unsignierten Programmcode. Apple-ID-Anmeldung und die gerätespezifische Signierung laufen erst lokal beim Benutzer. Das Repository und seine Artefakte enthalten keine Pairingdateien, persönlichen Profile oder Zertifikate.
