# Teststand vom 24. Oktober 2026

Release 0.1.0 vom Besitzer am 24. Oktober 2026 ausdrücklich freigegeben.
Repository bleibt privat. EXE und IPA stammen unverändert aus dem geprüften
Build 847f4bf; die Freigabe ersetzt keine noch ausstehenden Gerätetests.

LiveContainer wurde inzwischen vom Besitzer geöffnet und fordert die Einrichtung
des JIT-less-Modus an. Diagnose und Start einer Gast-App sind noch nicht bestätigt.
Die folgenden Einträge dokumentieren auch frühere Entwicklungsstände.

## Bestätigung vom Besitzer und neue Einrichtung

Neubau auf ausdrückliches „bau“: Stand 847f4bf lokal als Windows-EXE gebaut;
46 Python-/UI-Tests, fünf Rust-Tests und der echte gepackte Starttest mit lokaler
Authentifizierung bestanden. Die EXE wurde nach Prozessprüfung und Hashvergleich
nach `dist/DirectSide.exe` übernommen. Der Besitzer hat danach die vollständige
Reparatur über die Oberfläche bestätigt: automatische USB-Kopplung, frische
Verifikation, Vorbereitung der passenden Signieridentität sowie Übertragung und
Rückleseprüfung. Damit ist nun auch der komplette PC-Transfer bestätigt. Import
auf dem iPhone und anschließende LiveContainer-Installation bleiben zu prüfen.

iPhone-Action 40106177179 erfolgreich. Quellen-/HTTP-/Übersetzungstests,
Abbruchklassifizierung, Tagesgrenzen und der neue Regressionstest für fortgesetzte
gemeinsame Quellenabfragen trotz abgebrochenem Ansichtswarter bestanden. Echte
lokale TCI-Provisionierung, Wiederherstellung und wiederholte OTP-Erzeugung
ebenfalls bestanden. `dist/DirectSide.ipa`: Version 0.1.0, Build 5, 10.216.181
Bytes. Bundle-ID, HTTP-Konfiguration, 393 eingebettete Übersetzungen, CoreADI-Hash
und Hashgleichheit zur heruntergeladenen IPA geprüft. Keine Veröffentlichung.

Vor dem nächsten Build gesammelt: Quellenaktualisierung erhält einen eigenen,
von Ansichten unabhängigen und zusammengeführten Task. Swift-CancellationError
und URLSession-Abbruch werden nicht mehr als Serverausfall gespeichert. Der
Status ist auch in der Quellenzeile sichtbar. Native List/swipeActions ersetzen
den Entfernen-Text; zum Aktualisieren gibt es nur Herunterziehen. Automatisch
angezeigte IP-/Host-Adressen sind aus Karten und Vorschau entfernt. Geräte-Apps
verwalten nutzt das Raster-Symbol. Erneuerung erfolgt pro App über ein Tages-
Badge: ab vier Tagen grün, zwei/drei Tage gelb, null/ein Tag rot; unbekannte
Gültigkeit wird nicht erfunden. Neue Swift-Regressionen für gemeinsame Refreshes,
abgebrochene Ansichtswarter, Fehlerklassifizierung und Tagesgrenzen vorbereitet.
Sie wurden auf diesem Windows-PC nicht ausgeführt; kein neuer Build gestartet.
Der vorher gestartete iPhone-Build 40100949040 ist auf Wunsch des Besitzers
abgebrochen (GitHub: cancelled). Die Artefakte unter dist bleiben vorerst beim
bisher ausgelieferten Stand.

Nachtrag Signieridentität: Der erste reine Pairing-Reparaturweg ließ die
Signieridentität aus. Nach der erfolgreichen Pairing-Reparatur meldete der
Besitzer deshalb beim LiveContainer-Installieren Fehler 7460. Die Einrichtung
überträgt jetzt zwingend auch die passende Identität und benötigt hierfür die
Apple-Anmeldung im Windows-Programm. Export und LiveContainer-Zertifikatsübergabe
verwenden ausschließlich einen vorhandenen Schlüssel und ein dazu passendes
aktives Apple-Zertifikat; sie erzeugen weder einen Schlüssel noch einen CSR.
Der Regressionstest prüft auch das Ersetzen eines bereits auf dem iPhone
erzeugten anderen Schlüssels sowie die Ablehnung unpassender Transfers ohne
Beschädigung des gespeicherten Schlüssels. 46 Python-/UI-Tests und zwei gezielte
Vendor-Tests bestanden. Die PC-Sitzung ließ sich bei der automatischen Prüfung
nicht wiederherstellen; die vollständige Identitätsreparatur ist daher noch
nach Anmeldung des Besitzers über die neue Windows-Oberfläche zu prüfen.

iOS Build 5 entfernt den zusätzlichen QR-Einstieg unter den Quellen und das
Einstellungen-Icon auf Entdecken. Meine Apps trennt nun Signaturen, eine knappe
Update-Übersicht und die installierten Apps. Import ist unter dem Plus-Icon,
Geräteverwaltung beim Abschnitt Installiert. Es gibt keine zusätzlichen
Zurück-Buttons, entsprechend der zurückgenommenen Änderung des Besitzers.

Nachtrag USB-Pairing: Der Besitzer meldete eine Code-Abfrage ohne Code auf dem
iPhone. Vergleich mit `nab138/iloader/src-tauri/src/pairing.rs` bestätigt: Über
den bereits vertrauten USB-Lockdown-Kanal verwendet iLoader automatisch die
Protokoll-PIN `000000`. Der DirectSide-USB-Pfad wartete stattdessen auf eine
Eingabe. Das ist korrigiert; der drahtlose Reparaturweg bleibt getrennt.

Der korrigierte Windows-Kern hat am angeschlossenen iPhone tatsächlich eine
Remote-Kopplung aufgebaut, diese auf einer frischen USB-Verbindung verifiziert,
im Windows-Schlüsselbund gerätespezifisch gespeichert und Pairing, Original-IPA
und Bootstrap-Metadaten in die vorhandene DirectSide-App übertragen und
zurückgelesen. Der Reparaturbefehl meldete Erfolg ohne Apple-Anmeldung und ohne
Neuinstallation. Keine Kopplungsschlüssel oder Gerätekennungen protokolliert
oder eingecheckt. Jede Phase besitzt ein Zeitlimit. Die Oberfläche zeigt die
Phase im Installationsbereich; unter Einstellungen ist eine Reparatur ohne
Neuinstallation verfügbar. 46 Python-/UI-Tests und fünf Rust-Tests decken unter
anderem die Reparatur ohne Anmeldung, Gerätezuordnung, sichtbare Phase ohne
PIN-Abfrage und den Abbruch einer blockierten Phase ab.

Der Besitzer hat nach dem Zertifikatswiderruf die erfolgreiche Installation und
die lokale Apple-ID-Anmeldung in DirectSide auf dem echten iPhone bestätigt.
Selbsterneuerung ist damit noch nicht bestätigt.

Build 4 ergänzt englische/deutsche Sprache mit gespeicherter Auswahl, ein
gegliedertes Einstellungsmenü, normale Installation oder LiveContainer aus
Quellen sowie HTTP-Quellen einschließlich IPA und Bildern. Die offizielle
LiveContainer-Standalone-IPA 3.8.0 wird vor lokaler Installation nach Größe und
GitHub-SHA-256 geprüft. Die Zertifikatsübergabe kann lokal vorbereitet werden.
Quelle für das verwendete URL-/Zertifikatprotokoll ist LiveContainer 3.8.0,
Commit e370a92dfc03ce109ebce00ed4a7cfc64ad1c801.

Windows erkennt DirectSide beim Installieren anhand der IPA selbst und führt
das Pairing unabhängig vom Installationsknopf automatisch aus. Dateien werden
zunächst temporär übertragen, zurückgelesen und vor Abschluss verglichen; die
Bootstrap-Metadaten werden zuletzt übergeben. Eine zusätzliche lokale Kopplung
in der iPhone-App ist als Reparaturweg eingebaut, nicht am Gerät bestätigt.

Die Windows-Abfrage über AMFI hat am angeschlossenen iPhone den eingeschalteten
Entwicklermodus tatsächlich erkannt. Aus/nicht lesbar und die Anleitung wurden
mit simulierten Ereignissen geprüft; „Option auf dem Gerät anzeigen“ wurde
nicht am Gerät ausgelöst. Die Anleitung folgt Apples Dokumentation:
https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
44 Python-/UI-Tests, vier Rust-Tests und der gepackte Windows-Starttest bestanden.
Die Anleitung wurde bei 960 × 680 mit synthetischen Daten geprüft.

Noch am Gerät zu prüfen: vollständiger neuer automatischer Pairing-Transfer,
HTTP-Katalog/IPA-Installation, Sprachwechsel, LiveContainer-Installation,
Zertifikatsimport und Start einer Gast-App sowie Selbsterneuerung.

Artefakte dieses Stands: Windows aus `build/ios-settings-setup` nach bestandenem
Paketstarttest und nach Schließen durch den Besitzer nach `dist/DirectSide.exe`
übernommen. iPhone-Action 40098669744 erfolgreich; `dist/DirectSide.ipa` ist
Version 0.1.0, Build 4. IPA-Bundle-ID, CoreADI-Hash, eingebettete 389
Übersetzungseinträge und HTTP-Transportkonfiguration geprüft. Swift-Tests für
Quellen/HTTP und Übersetzungen sowie echte lokale TCI-Provisionierung,
Zustandswiederherstellung und wiederholte OTP-Erzeugung bestanden. Der erste
Build wurde wegen eines SwiftUI-Section-Initialisierers korrigiert. Kein Release
erstellt.

## Windows

- Ergänzung Account-/Zertifikatsansicht: insgesamt 43 Python-Tests bestanden. Neue Tests prüfen die sichtbare automatische Anmeldung in der Account-Karte bis zur bestätigten Sitzung, die erneute Anmeldung nach Ablauf sowie getrennte Zertifikats-/App-Zähler und Seitenwechsel nach Entfernung. Die Verwaltung zeigt alle von Apples iOS-Zertifikatsabfrage gelieferten Einträge ohne zusätzlichen Plattformfilter; der Auswahlpfad zum Signieren bleibt unverändert. Ansichten mit synthetischen Daten bei 960 × 680 geprüft. Die tatsächliche Zertifikatszahl dieses Accounts ist damit noch nicht bestätigt.

- Rust-Kern lokal kompiliert. Vier Tests prüfen das Drei-App-Limit samt Erneuerung bestehender Apps, die Erkennung anhand korrekter Bundle-IDs den lokalen Anisette-Callback samt Neusynchronisierung sowie die ausdrückliche Bestätigung vor Löschvorgängen. Zwei zusätzliche Vendor-Tests prüfen Callback-Payloads, passenden und unpassenden Schlüssel-/Zertifikatsimport sowie die Erkennung vorhandener privater Schlüssel.
- 43 Python-Tests bestanden: IPA-Auswahl, Voreinstellungen ohne Passwort, lokale Anmeldung, Komponentenprüfung, Hashprüfung, integrierte Bestätigungen, automatisches Gerätescannen, getrennte Gerätezustände, Icon-Cache und gespeicherte Sprachwahl. QML-Regressionstests prüfen Eingabeerhalt, Anmeldeklick und App-ID-Kontingente. Weitere Tests prüfen den abgelehnten Token, DPAPI-Schutz samt Manipulationserkennung und die Beschränkung der Provisionierung auf Apple-HTTPS-Endpunkte.
- Die echte gepackte EXE wurde mit --smoke-test gestartet: Qt, QML, Fenster-Icon, eigene Titelleiste, Signierkern und tatsächliche lokale Anisette-Erzeugung erfolgreich. Bericht: build/smoke-test.json.
- Die frühere native Windows-CoreADI bestand OTP-Tests, scheiterte beim echten Xcode-Token aber weiterhin mit −80046, auch nach Anpassung des Clientprofils. Die alte Sitzung wurde mit Fehler 1100 zurückgewiesen. Diese Tests bestätigten keine erfolgreiche Anmeldung.
- Neuer Windows-Provider: Apples Mac-CoreADI aus iTunes 12.8.3 unter lokalem Unicorn. Tatsächliche Provisionierung bei Apple mit geprüfter TLS-Verbindung, lokale OTP-Erzeugung und Wiederverwendung des DPAPI-geschützten Zustands erfolgreich. Derselbe Weg wurde in der fertig gepackten EXE einschließlich Rust-Kern und besitzergeschützter Windows-Pipe erfolgreich geprüft. Keine Apple-ID bei diesen Tests verwendet. Der Besitzer hat die erfolgreiche Apple-ID-Anmeldung in der neuen gepackten Windows-App am 24. Oktober ausdrücklich bestätigt.
- Ein zusätzlicher Rust-Vendor-Test prüft den OTP-Wechsel am echten 30-Sekunden-Fenster. Der Windows-Build verwendet einen selbst gebauten PyInstaller-Starter gemäß dokumentierter `--no-cfg`-Kompatibilitätsoption; keine Windows-Richtlinie wurde verändert. Der frühere Paketabsturz mit Unicorn tritt im aktuellen Starttest nicht mehr auf.
- Am angeschlossenen Gerät wurden 191 Benutzer-Apps gelesen. LocalDevVPN wurde erkannt; LiveContainer war nicht vorhanden. Drei angefragte echte App-Icons wurden erfolgreich von SpringBoard Services gelesen.
- Offizielle LiveContainer-Standalone-IPA 3.8.0 heruntergeladen; SHA-256 und Haupt-Bundle-ID geprüft. Keine Installation oder Zertifikatsübertragung auf dem Gerät vorgenommen.
- Apple-USB-Dienst war auf diesem PC bereits installiert und gestartet. Deshalb wurde keine Neuinstallation ausgelöst. Download-/Prüf-/Startpfade wurden mit Testdaten geprüft; ein kompletter Installerlauf auf einem unvorbereiteten PC steht aus.
- Oberfläche auf Mindestgröße 960 × 680 in Deutsch und Englisch geprüft: kurze VPN-Karte, farbige Status-Badges, Hilfe aus dem ⋯-Menü, Einstellungen und App-Kacheln ohne Haupt-Scrollbar.
- Überarbeitete Windows-Oberfläche mit synthetischen Daten außerhalb des Benutzerfensters gerendert: Status unten rechts, bündige Konto-/Geräteüberschriften, USB im Header und unterschiedliche Vektor-Icons. Keine Anmeldung mit Test-Zugangsdaten ausgelöst.

Der frühere QtCore-DLL-Fehler kam von einer fremden ICU-DLL im Build-PATH. Der lokale Paketbau isoliert diesen Pfad und schließt die fremde DLL aus.

## GitHub-Updates

- Release-Erkennung am echten privaten Repository mit der bestehenden GitHub-Anmeldung auch aus der fertig gepackten EXE geprüft: Zugriff erfolgreich, noch keine freigegebene Version vorhanden. Bericht: build/release-probe.json. Keine Release-Erstellung oder Uploads.
- Vierzehn neue Tests decken Release-/Privatzugriff, Versionsvergleich, Weiterleitungen ohne Tokenweitergabe an das CDN, SHA-256-Prüfung, beschädigte Downloads, fremde IPA-Bundle-IDs, DPAPI-Tokenablage, EXE-Austausch samt Sicherung und Wiederherstellung, gesperrte Dateien sowie UI-Zustand und aufgeschobenen Neustart während einer Anmeldung ab. Zusätzlich geprüft: direkter Download mit anschließender Installation, Warten auf USB-Abfragen, unveränderte eigene IPA-Auswahl und Abbruch bei gewechseltem Zielgerät.
- Neue Windows-EXE unter build/github-updates/DirectSide.exe lokal gebaut; erneuter echter Paketstarttest mit Qt, QML, Fenster-Icon, Rust-Kern und lokaler Apple-Authentifizierung bestanden. Die bislang geöffnete dist/DirectSide.exe wurde nicht beendet oder ersetzt.
- Oberfläche mit simuliertem Release auf Mindestgröße in Deutsch und Englisch gerendert. Ein Geometrietest prüft die komplette IPA-Zeile innerhalb der Karte bei vorhandenem und fehlendem VPN. Der QR-Bereich passt sich an die Kartenhöhe an; kein Überlagern des Kartenrands. Ein Install-DirectSide-Button, ein Windows-Update-Button im Header und IPA-Version am App-Kopf. Echte Release-Downloads und vollständige Versions-Upgrades bleiben bis zur ersten freigegebenen Version ungetestet.

## iPhone und LiveContainer

Aktuelle IPA: Quellstand `53be0e7`, Version 0.1.0, Build 2. Privater manueller Build:
https://github.com/Serekay/directside/actions/runs/40094299353 . Die IPA wurde nach
`dist/DirectSide.ipa` übernommen und auf Bundle-ID, Buildnummer, eingebetteten
Mac-Runtime-Hash, fehlende Android-Bibliotheken, IPA-Dokumenttyp, VPN-URL-Schema
und Lizenzdateien geprüft.

Die lokale iOS-Anmeldung verwendet jetzt dieselbe echte Mac-CoreADI wie Windows,
mit x86-64-Gastemulation unter TCI und ausschließlich les-/schreibbarem
Interpreter-Speicher. Rust-Mac-Adapter, Swift-Provisionierung, iOS-C-Callbacks samt
Neusynchronisierung und Signierkern wurden gemeinsam mit Xcode kompiliert. Die
frühere ARM64/AnisetteKit-Abhängigkeit ist entfernt.

Auf dem Buildrechner bestanden tatsächliche Apple-Provisionierung, Export des
modernen Provisionierungszustands, Laden in einen neu erzeugten Interpreter und
wiederholte OTP-Erzeugung. Keine Apple-ID oder Anmeldedaten wurden dabei verwendet
oder in Actions gespeichert. Der beim Portieren gefundene Verlust des Zustands
nach einem virtuellen Prozessneustart wurde durch Ausschließen der veralteten
adi.pb bei Sitzungsneustarts behoben. Beide erfolgreichen neuen Builds führten
diese Probe mit dem Software-Interpreter aus, nicht mit JIT.

Der Geräte-Installationsversuch des Besitzers scheiterte noch vor der eigentlichen
Installation mit Apple-Fehler 7460 (Zertifikatlimit). Deshalb ist eine erfolgreiche
Anmeldung oder Selbst-Erneuerung auf dem echten iPhone weiterhin nicht bestätigt.
Das iPhone wurde per USB erkannt. Die neue Windows-EXE und die neue IPA enthalten
nun ausdrücklich bestätigte App-Entfernung sowie Zertifikatverwaltung. Es wurde
kein Zertifikat automatisch widerrufen und keine Benutzer-App für einen Test
gelöscht. Der nächste Hardwaretest erfolgt über diese Oberfläche.

Direkter IPA-Import über Dateien und „Öffnen in“, Vorschau der Haupt-App und
Weitergabe an den vorhandenen lokalen Signier-/Installationspfad sind kompiliert.
Der native Inspector akzeptierte die echte DirectSide-IPA und lehnte ein
Testarchiv mit zwei Haupt-Apps ab. Der vollständige Import mit anschließender
Geräteinstallation bleibt noch am iPhone zu prüfen.

Die VPN-Leiste ist auf allen Tabs und in den modalen Ansichten eingebaut. Sie
prüft im Vordergrund alle fünf Sekunden die tatsächliche TCP-Erreichbarkeit des
lokalen Remote-Pairing-Ports. Das ist ein Erreichbarkeitstest, keine Abfrage des
privaten Prozesszustands von LocalDevVPN und kein Ersatz für die kryptografische
Pairingprüfung. Das offizielle Schema `localdevvpn://enable?scheme=directside`
öffnet/aktiviert die VPN-App und führt zu DirectSide zurück. Diese Übergabe und
die Statusänderung beim Abschalten sind noch am Gerät zu prüfen.

Die optionale LiveContainer-Installation und lokale Zertifikatsübergabe bleiben
gebaut, jedoch noch nicht am Gerät getestet. Ein eingebettetes LiveContainer-
Laufzeitsystem ist nicht umgesetzt.

## Vor einer Freigabe offen

- Frische lokale Windows-Anmeldung vom Besitzer bestätigt; weitere Varianten der Zwei-Faktor-Bestätigung separat prüfen.
- Zertifikatlimit über die neue Oberfläche lösen; Signierung und Erstinstallation der eigenen IPA samt Remote-Pairing.
- Lokale iOS-Authentifizierung am echten Gerät einschließlich 2FA und Wiederherstellung der Sitzung prüfen.
- App-Installation aus Quelle und direkter IPA, Update mit Datenerhalt und Selbsterneuerung über LocalDevVPN.
- Bestätigtes Entfernen fremd installierter Apps und Widerrufen eines ausgewählten Zertifikats auf PC und iPhone.
- VPN-App-Übergabe, Rückkehr und sichtbarer Status bei ausgeschaltetem Tunnel.
- Wiederherstellung einer abgelaufenen Xcode-Sitzung aus dem neuen, im Schlüsselbund gespeicherten Refresh-Kontext. Dieser neue Kontext enthält kein Passwort; bestehende alte Sitzungen benötigen einmalig eine neue Anmeldung.
- Gleichzeitiger Hardwaretest mit mehreren Geräten; bisherige Trennungsprüfungen verwenden simulierte Ereignisse.
- LiveContainer-Installation, Zertifikatseinrichtung und Start einer Gast-App.

Windows wird ausschließlich lokal gebaut. iPhone-Actions sind nur manuell auslösbar. Das GitHub-Repository bleibt privat; es gibt keine öffentliche Veröffentlichung und keinen Release.

## Ergänzung Account-/Zertifikatsverwaltung

Stand e3c5997: Windows-EXE lokal gebaut und nach bestandenem Paketstarttest nach dist/DirectSide.exe übernommen. 43 Python-Tests und vier Rust-Tests bestanden. iPhone-Action 40096167045 erfolgreich: Build 3, lokale TCI-Provisionierung, Zustandswiederherstellung und wiederholte OTP-Erzeugung bestanden; IPA samt Bundle-ID, Buildnummer und CoreADI-Hash geprüft und nach dist/DirectSide.ipa übernommen. Kein Zertifikat widerrufen. Der Besitzer hat die früher mit SideStore installierten Apps selbst gelöscht; die Oberfläche meldet 0/3 Entwickler-Apps und ein Zertifikat namens iloader. Die tatsächliche Installation und iPhone-Anmeldung bleiben zu prüfen.
