# Teststand vom 25. Oktober 2026

## Repository- und Release-Prüfung

Gitleaks 8.30.1 über die gesamte erreichbare Historie: keine Geheimnisse
gefunden. Zusätzlich 643 historische Textblobs und aktuelle Dateien auf
private Adressen, lokale Pfade und Gerätekennungen geprüft; Code-Testwerte,
Lizenzautoren und Emulatorpfade von persönlichen Angaben unterschieden.
Die persönliche Autorenadresse wurde nach ausdrücklicher Nutzerfreigabe aus
allen Commits und Tags entfernt. Autoren und Committer verwenden jetzt den
öffentlichen GitHub-Namen und die GitHub-Noreply-Adresse. Dateibäume und
Quellstand des bestehenden Releases bleiben unverändert; aktuelle
Dokumentationsverweise wurden auf die neuen Commit-IDs angepasst.

Windows-Archivinhalt und IPA-Dateiliste enthalten keine lokalen Konto-,
Pairing-, Profil- oder privaten Signierdateien. Ausschlussregeln ergänzt;
lokaler Pre-Commit-Hook prüft Dateitypen, Autorenadresse und staged Secrets.
85 Python/Qt-Tests bestanden, einschließlich realer Staging-Tests für
erlaubte Dateien, verbotene .env-Dateien und synthetische Tokens. Keine
Kontoanmeldung und keine Signieridentität für die Repository-Prüfung verändert.

Die Prüfung erfasst erreichbare Git-Objekte und veröffentlichte Inhalte,
keine Garantie für das Fehlen beliebiger Geheimnisse. Alte GitHub-Commit-Caches
und frühere Actions-Metadaten können nach einem Force-Push weiterhin bestehen;
das Repository wird durch diese Arbeit nicht öffentlich geschaltet.

## Windows-Aufnahme und aufklappbare README

Aktuelle QML-Ansicht 0.1.1 (16) über Windows-Screenshotwerkzeug aufgenommen.
Dokumentationsvorschau mit Beispieldaten und isolierten temporären Einstellungen;
kein Signierkern gestartet und keine Geräte- oder Kontoaktion ausgeführt.
Vorschau anschließend geschlossen. README enthält fünf Bilder und 14 geprüfte
Details-/Summary-Bereiche für Einrichtung, Bilder und konkrete Problemfälle.
Bilddateien und lokale Dokumentverweise geprüft. Keine Paketänderung nötig.

## Version 0.1.1 (16) und vier README-Ansichten

Windows-Titelleiste und Einstellungen zeigen Version und Build; auch die
EXE-Dateieigenschaften sind versioniert (FileVersion 0.1.1.16,
ProductVersion 0.1.1 (16)). iPhone-Einstellungen lesen beide Werte aus dem
installierten Bundle. Versionsabgleich zwischen Windows, iPhone, Cargo und
Lockdatei als Regressionstest ergänzt. 82 Python/Qt-Tests, 12 native Tests und
Windows-Paketstart bestanden. Private iPhone-Prüfung 40200121156 für Quellstand
0354a3a erfolgreich. IPA geprüft: 0.1.1 (16), com.directside.app,
14.712.801 Bytes, SHA-256
c06812e8b38e0dc505e71d906af4d64ae0d76efb2e80f57a77685e73cbab7cc2.
Kein Release veröffentlicht und keine Installation auf dem iPhone ausgelöst.

README zeigt vier echte iPhone-Ansichten aus installiertem Build 14:
Einführung, Meine Apps, Quelle hinzufügen und Einstellungen. Die Kontokarte
liegt bei der Einstellungsaufnahme außerhalb des sichtbaren Bereichs.
Persönliche Angaben nicht abgebildet; Bildmetadaten entfernt. Die sichtbare
ältere Versionszeile wurde nicht künstlich verändert. README enthält nur
Produktbeschreibung und Bedienung; interne Prüfdetails bleiben hier.
Windows-UI-Steuerung wurde vom Werkzeug wegen nicht sicher bestimmbarer
Browseradresse beendet; keine weiteren Windows-UI-Eingaben vorgenommen.

## README-Aufnahmen vom echten iPhone

Zwei PNG-Aufnahmen aus der installierten Version 0.1.0 (Build 14): Meine Apps
mit DirectSide/LiveContainer und Quelle hinzufuegen. Beide Ansichten bleiben
in Build 15 unveraendert. Sichtpruefung: keine persoenlichen Kontodaten,
Geraetekennungen oder privaten Quellenadressen im Bild. EXIF- und Textmetadaten
wurden entfernt; die PNG-Pixeldaten bleiben unveraendert. Keine Konto- oder
Signiereinstellungen geaendert, keine Installation ausgeloest. README zeigt
nur diese zwei Aufnahmen; die veralteten Windows-Abbildungen sind dort entfernt.
Lokale Bild- und Dokumentverweise geprueft. Private iPhone-Buildpruefung 15
bestanden (Actions 40199099636, Quellstand cacbe35). IPA lokal geprueft:
Version 0.1.0, Build 15, com.directside.app, 14.711.841 Bytes, SHA-256
c4929671c46fca8d4201bb28d15f843e24524a83de0dbea21cf0008526348101.
Kein Release erstellt und kein Update auf dem iPhone installiert; der
native Update-Test bleibt beim Nutzer.


## Entwicklerteam: Anleitung statt iPhone-Fernsteuerung

Die Windows-Einrichtung sendet keine Befehle zum Start von DirectSide oder
zum Navigieren der iPhone-Einstellungen mehr. Nach Installation und
Konto-/Zertifikatsuebertragung erscheint ausschliesslich die manuelle Anleitung:
Geraeteverwaltung, Entwicklungsteam vertrauen, DirectSide selbst oeffnen.
Auch Polling, USB-Wiederverbindung und Wiederaufnahme eines gespeicherten
Einrichtungsschritts loesen keinen App-Start aus. Fertig beendet die Anleitung
als Bestaetigung des Nutzers; es wird kein verifizierter App-Start behauptet.
81 Python/Qt-Tests bestanden. Kein Eingriff in iPhone-Einstellungen und kein
weiterer nativer Startversuch bei dieser Aenderung.


## USB-Ausfall nach iPhone-Neustart: Reparatur und Windows-Zustimmung

Am angeschlossenen Gerät erkennt Windows genau ein Apple-USB-Gerät; Apples
laufender Verbindungsdienst liefert gleichzeitig null Geräte. Erneutes
Einstecken und die bisherige reine PnP-Reparatur haben diesen Fall nicht behoben.
Die neue Reparatur startet zusätzlich den Apple Mobile Device Service neu und
setzt ausschließlich das einzeln geprüfte Apple-USB-Verbundgerät zurück.
Sie beginnt erst nach einem bewussten Klick mit vorheriger Erklärung der
Windows-Abfrage. Nein/Schließen wird als Abbruch behandelt, ohne automatische
Wiederholung. Nach dem Helfer wird bis zu 25 Sekunden die tatsächliche
USB-Geräteliste geprüft; ein erfolgreicher Prozess alleine zählt nicht als
wiederhergestellte Verbindung. 81 Python/Qt-Tests bestanden, einschließlich
Abbruch, fehlgeschlagener Diensterneuerung und leerer Geräteliste trotz
Helfer-Erfolg. Hardware-Reparatur mit anschließender Windows-Zustimmung des
Nutzers noch ausstehend; keine erfolgreiche Wiederverbindung behauptet.


## Einrichtung ohne Zurückspringen aus Einstellungen und Hilfe

Die bisherige Navigation wertete jede Statusmeldung als Anlass aus, den
Einrichtungsschritt erneut aufzurufen. Automatische Schrittwechsel gelten jetzt
nur innerhalb der Einrichtungsansichten; manuell geöffnete Einstellungen, Hilfe,
Protokoll und Detailseiten bleiben geöffnet. Zurück führt direkt zum aktuellen
Schritt statt kurz zur erneut installierbaren Hauptkarte.
„Show switch“ entfällt: Der Aufruf blendet den iOS-Schalter ein, öffnet aber
keine Einstellungsseite; dieser Aufruf erfolgt bereits bei der Installation.
Entwicklermodus wird automatisch geprüft, ohne manuelles Check-again und ohne
deaktivierten Warte-Button. Der technische Prüfintervall-Text wurde durch den
Handlungshinweis ersetzt: Nach dem Neustart bei fehlender Erkennung USB kurz
abziehen und wieder einstecken sowie eine Vertrauensabfrage bestätigen.
Die USB-Neuprüfung liegt als Aktualisieren-Symbol
mit Tooltip „USB-Verbindung prüfen“ auf dem Disconnect-Bildschirm. Der explizite
Start nach Teamfreigabe heißt „DirectSide starten“, Zertifikate haben eine
konkrete Aktualisieren-Beschriftung. 78 Python/Qt-Tests bestanden, einschließlich
Seitenstabilität bei Prüfungen, Freigabe- und Startzustandswechseln sowie
expliziter Rückkehr in den Ablauf. Windows neu gebaut, Paket-Startprüfung
bestanden. Im laufenden echten Einrichtungsschritt blieben Einstellungen
und Hilfe jeweils über mehrere automatische Prüfungen geöffnet; Zurück führte
zum Entwicklermodus-Schritt. Anmeldefelder waren nach dem Windows-Neustart
wieder sichtbar; der Assistent hat keine erneute Anmeldung vorgenommen.
Keine iPhone-Einstellungen automatisiert.

## Stabile Statusanzeigen am zugehörigen Bereich

Die Geräteprüfung setzte vor jeder Antwort App-Anzahl und Komponentenstatus
auf unbekannt zurück. Sie behält jetzt die zuletzt bestätigten Werte bis zum
Ergebnis. Bei Gerätewechsel, Trennung oder tatsächlichem Prüfungsfehler werden
sie weiterhin verworfen; andere Geräte übernehmen keine alten Werte.
App-Kennungen stehen kompakt am Konto, Sideload-App-Anzahl unter dem Gerätenamen.
Der doppelte Anmelde-Badge entfällt; die Fußleiste ist im Leerlauf ausgeblendet
und zeigt nur laufende Vorgänge oder Meldungen. 77 Python/Qt-Tests bestanden,
einschließlich stabiler Texte/Geometrie während der Prüfung und unveränderter
Fehlerbehandlung. Windows-Paket neu gebaut, Startprüfung bestanden.
Geräteanzeige und ausgeblendete Leerlauf-Fußleiste im laufenden Paket auch
beim manuellen Aktualisieren geprüft; Kontobadge im Qt-Test mit angemeldetem
Testzustand geprüft. App zur weiteren Prüfung geöffnet. Kein iPhone-Eingriff.

## Einstellungen und Hilfe aus Nutzersicht

Windows-Einstellungen auf Sprache, Updates und Installieren mit Apple Account
oder eigenem Zertifikat reduziert. Keine Komponenten-/LiveContainer-Tabs,
doppelten App-Listen, Schlüsselbund-Badges oder ständigen Reparaturbuttons.
Zertifikatfelder erscheinen erst bei ausgewähltem eigenem Zertifikat;
Apple-Zertifikate lassen sich in der Auswahl der Installationsmethode verwalten.
Hilfe öffnet direkt und zeigt nur den nächsten Schritt passend zu Verbindung,
Anmeldung und App-Status. Unbekannter Entwicklermodus fordert eine erneute
Prüfung, nicht dessen angeblich fehlende Aktivierung. Reparatur erst unter
„App startet nicht?“ bei vorhandener App, Anmeldung und geeigneter lokaler IPA.
„Aktivität“ heißt jetzt „Protokoll“ und ist aus der Hilfe beziehungsweise bei
Fehlern erreichbar. Zertifikat-Dateiauswahl geht bei Hintergrundprüfungen nicht
mehr verloren. 76 Python/Qt-Tests bestanden, einschließlich Zustandswechseln,
Dateidialog-Warteschlange und Layout in beiden Sprachen. Windows-Paket neu
gebaut und Paket-Startprüfung bestanden. Die drei Einstellungszeilen,
zustandsabhängige Hilfe und der als Log bezeichnete Protokoll-Zugang wurden
im laufenden Paket geprüft. Neue Einstellungen zur Ansicht geöffnet.
Kein iPhone-Eingriff.

## Vereinfachte Windows-Startseite

Kein dauerhafter Dev-Badge und kein Entwicklermodus-Hinweis unter Installieren.
Die erforderliche Anleitung nach einer Installation bleibt erhalten, weil
DirectSide bei ausgeschaltetem Entwicklermodus noch nicht starten kann.
Ein sichtbares Plus neben dem Gerät öffnet einen eigenen IPA-Bereich mit
Dateiauswahl und Installieren; die DirectSide-Karte enthält nur DirectSide.
Zahnrad symmetrisch korrigiert. Hilfemenü auf Einrichtung und Aktivität gekürzt;
Updates, Zertifikate und App-Kennungen über die Einstellungen erreichbar.
74 Python/Qt-Tests bestanden, einschließlich Plus-Navigation und getrennten
Installationsbereichen sowie erreichbaren Einstellungen bei minimaler
Fenstergröße in beiden Sprachen. Windows-Paket neu gebaut, Startprüfung
bestanden. Plus-Seite, Zahnrad, zweizeiliges Hilfemenü und vollständig sichtbare
Einstellungen im laufenden Paket geprüft; anschließend Startseite geöffnet.
Kein iPhone-Eingriff.

## LocalDevVPN ausschließlich auf dem iPhone einrichten

Windows zeigt keinen LocalDevVPN-Installationsbereich, QR-Code oder fehlenden
VPN-Status mehr. Die DirectSide-Karte mit Versionsanzeige bleibt auch ohne
installiertes LocalDevVPN sichtbar und ihr Installationsbutton benutzbar.
Die Windows-Hilfe verweist auf die Einführung am iPhone. 74 Python/Qt-Tests
bestanden, einschließlich Installationsansicht ohne VPN in beiden Sprachen.
Keine Änderung oder Zurücksetzung des iPhones für diesen Windows-Fix.

## Vorbereiteter frischer Ablauf mit iPhone-Build 14

Private iPhone-Aktion 40163435691 erfolgreich, Artefakt lokal als
`dist/DirectSide.ipa`: Version 0.1.0, Build 14, Kennung `com.directside.app`,
SHA-256 `c6f1927539385feb71368bc6353f963bdf6ab26d8170e379a7197e36705f5901`.
Kein Release veröffentlicht. Der primäre Windows-Installationsbutton verwendet
eine gültige nebenliegende DirectSide-IPA, sofern deren Version mindestens
der bekannten Release-Version entspricht. Andere Apps, beschädigte Dateien
und ältere Pakete werden nicht dafür verwendet. Version samt Build sichtbar.
74 Python/Qt-Tests und Paket-Startprüfung bestanden; Windows neu gebaut.

Für den ausdrücklich gewünschten Reset: In DirectSide am iPhone abgemeldet,
danach DirectSide, LiveContainer und LocalDevVPN entfernt; Abwesenheit aller
drei Apps vom Gerät bestätigt. Windows-Sitzung abgemeldet, anschließend
`missing_session` bestätigt; lokale Benutzereinstellungen entfernt.
Signieridentität, Apple-Kennungen, vorhandene Windows-Treiber und persönliche
Apps bleiben erhalten. Entwicklermodus ausschalten und Neustart am iPhone
beim Betreiber angefragt; Kopplungsreset folgt erst nach bestätigtem Aus-Zustand.
Der eigentliche neue Einrichtungsdurchlauf wurde noch nicht gestartet.

## Update-Ansicht und nächster vollständiger Durchlauf

Windows-Updateansicht ohne Repository-/Token-Eingabe und ohne technische
GitHub-Badges. Fehlender Zugriff erscheint als vorübergehend nicht verfügbare
Updateprüfung; er wird nicht als erfolgreiche Prüfung ohne Updates gewertet.
72 Python/Qt-Tests und Paket-Startprüfung bestanden. Windows-Paket neu gebaut
und für den Betreiber geöffnet. Das Repository bleibt unverändert privat.
Der Betreiber führt den nächsten Ablauf selbst aus. Keine automatische
Zurücksetzung oder verdeckte Einrichtung für diesen Durchlauf.
Die USB-Wiederherstellung ist implementiert, ihre zuverlässige Wirkung bei
der zuvor beobachteten PnP/usbmux-Abweichung bleibt am Gerät nachzuweisen.

## Windows-Hilfe und Entwicklermodus-Status

Nach Abschluss der iPhone-Einführung zeigte die manuell geöffnete
Entwicklermodus-Hilfe fälschlich „Completing setup…“, obwohl kein Auftrag mehr
lief. Die Ansicht unterscheidet jetzt aktiviert (grün, fertig), deaktiviert
(Aktivierungsschritte), unbekannt (Verbindung und Prüfung) und tatsächlich
laufende Einrichtung (warten). „Quick setup“ folgt dem aktuellen Ablauf:
USB-Vertrauen, Installation und Entwicklermodus, Team-Freigabe, iPhone-Einführung
mit LocalDevVPN und optionalem LiveContainer. Englische Beschriftungen ergänzt.
72 Python/Qt-Tests einschließlich der vier Entwicklermodus-Zustände bestanden.
Windows-Paket mit unveränderter Engine neu gebaut; Paket-Startprüfung bestanden.
Im laufenden Paket mit angeschlossenem iPhone geprüft: Entwicklermodus zeigt
grüne Bestätigung und „Done“, die überarbeitete Hilfe wird vollständig angezeigt.

## USB-Wiederherstellung und tatsächlicher erster App-Start

Nach manueller Freigabe des Entwicklungsteams „Check again“ im gepackten
Windows-Programm betätigt. Nativ bestätigt: DirectSide startet mit der
Willkommensseite der Einführung; Windows zeigt erst danach „DirectSide opened“
in Grün. Keine Neuinstallation und Kontingent weiterhin 9/10. Kontoübernahme
auch in diesem frischen Durchlauf erfolgreich: Diagnose `restored`, keine
erneute Passworteingabe, temporäre Konto-/Signierübergabedateien entfernt.
Danach den LiveContainer-Schritt erreicht; laut Betreiber lief die Installation
durch und wechselte automatisch zu LiveContainer. Dieser Wechsel kam aus der
Zertifikatübergabe. Für den nächsten iPhone-Build bleibt die Installation in
DirectSide; Export und sichere Ablage des Zertifikats bleiben automatisch.
Der ausdrückliche Schritt „LiveContainer einrichten“ übergibt es anschließend
an LiveContainer. Die Installation allein bestätigt damit noch keine fertige
JIT-less-Einrichtung. Swift-Syntax, Übersetzungs-JSON und Diff geprüft; noch
kein neuer iPhone-Build und kein Hardwaretest dieser Änderung.
Die LocalDevVPN-Einführung erhält außerdem die Anleitung für Installation,
VPN-Freigabe, Verbindung und Rückkehr zu DirectSide (Deutsch/Englisch).

Windows erkennt im aktuellen Ausfall genau ein Apple-USB-Composite-Gerät,
während Apples USB-Dienst null Geräte meldet. Neuer Wiederherstellungspfad:
Nach acht Sekunden anhaltender Diskrepanz und vorher gesehenem iPhone wird
einmal pro Ausfall die gezielte PnP-Neuinitialisierung dieses einen Geräts
angeboten/angestoßen. Dafür verwendet das Paket seine eigene begrenzte
Hilfsfunktion mit normaler Windows-Administratorabfrage und Microsofts
`pnputil /restart-device`. Keine Hub-Neustarts, keine Treiberdeinstallation,
kein globaler Gerätescan und keine Änderung an Apple-Kennungen oder Zertifikaten.
Fehlende oder mehrere passende Geräte werden nicht neu gestartet. Abbruch
führt nicht zu wiederholten automatischen Administratorabfragen.

Abgeschlossene Konto-/Kopplungsübertragung ist künftig noch kein grüner
Einrichtungsabschluss. Windows fordert danach den Start der eindeutigen
DirectSide-Installation über den nativen iPhone-Startdienst an. Nur ein
positiver Prozessbezeichner zählt als bestätigter Start. Bei fehlender
Bestätigung bleibt der Einrichtungsschritt gespeichert und die Oberfläche
zeigt die noch nötige iPhone-Freigabe an. Sie versucht, Einstellungen und
anschließend Allgemein → VPN und Geräteverwaltung über vorhandene native
Accessibility-Dienste zu öffnen. Die endgültige Vertrauensbestätigung wird
nicht automatisiert. Die Steuerung nutzt ausschließlich semantische Kennungen,
keine übersetzten Zeilentexte, Koordinaten oder festen Zeilennummern. Am Gerät
ausgelesen: `com.apple.settings.general`,
`com.apple.settings.general.vpnAndDeviceManagement`, `BackButton`; auf der
Zielseite die Kombination `VPN` und `BackButton`. Der iOS-Lesedienst funktioniert,
Fernaktivierung der Systemzeilen wurde auf diesem iPhone jedoch nicht
ausgeführt. Automatische Navigation ist deshalb weiterhin nicht vollständig
nativ belegt. Die manuelle Navigation des Betreibers zählt nur zur Prüfung
der Kennungen. Bei nicht bestätigtem Ziel erscheint im selben Schritt die
lokalisierte manuelle Anleitung. Die Fallback-Pflicht steht auch in AGENTS.md.
Der sichtbare Pfad und erneuter Start bleiben dann verfügbar. Es gibt keinen
behaupteten universellen Einstellungen-Deep-Link und keine Garantie, dass ein
angeforderter Prozessstart auch einen späteren App-Absturz ausschließt.

Abmelden bleibt während normaler USB-Hintergrundabfragen bedienbar; ein Klick
während einer Abfrage wird anschließend ausgeführt, statt still ignoriert zu
werden. Dadurch flackert der Button nicht mehr bei jedem Prüfzyklus.
71 Python-/Qt-Tests und zwölf Kern-Tests bestanden. Hintergrundscans beeinflussen nun generell
weder sichtbare Button-Aktivierung noch deren Beschriftung. Während einer
Abfrage angeklickte Aktionen werden einmal anschließend ausgeführt; ein
inzwischen gewechseltes Zielgerät verhindert gerätespezifische Aktionen.
Native Wiederherstellung noch nicht belegt: Nach dem Paketneustart war das
iPhone bereits wieder verfügbar; ob der PnP-Neustart dafür verantwortlich war,
ist ohne bestätigten Reparaturdurchlauf nicht nachgewiesen.

Nativer Startversuch über „Einrichtung reparieren“ in der Windows-App hat
tatsächlich den iOS-Dialog „Entwicklungsteam, dem nicht vertraut wird“ gezeigt.
Windows blieb korrekt ohne grünen Abschluss. Dieser Dialog blockierte zunächst
das automatische Öffnen der Einstellungen. Die endgültige Fassung enthält
keine sprachabhängige Erkennung oder automatische Bestätigung dieses Dialogs.
Der erste Startversuch wird persistent markiert. Ein noch offener Startschritt
wird nach Neustart der Windows-App oder USB-Wiederkehr nicht erneut automatisch
gestartet. Auch ältere gespeicherte Startschritte gelten beim Laden vorsorglich
als bereits versucht. Dadurch wiederholt sich der Untrusted-Developer-Dialog
nicht wegen App-Neustarts; ein erneuter Versuch benötigt einen bewussten Klick.
Paket danach mit gespeicherter offener Freigabe gestartet: Die Windows-App
zeigt direkt die neutrale Freigabe-Anleitung, keine neue Startanforderung.
Der einmalige Klick auf „Einstellungen am iPhone öffnen“ landete auf der von
iOS wiederhergestellten Batterie-Unterseite. Die korrigierte Fassung versucht
den Rückweg über `BackButton` und bestätigt Folgeseiten anhand ihrer semantischen
Kennungen. Eine angeforderte Aktivierung wird nicht als Navigationserfolg
gewertet. Direkte URL-Startparameter wurden ebenfalls nicht als funktionierend
bestätigt und sind nicht im Produkt enthalten.

Protokollgrundlagen: [Microsoft PnPUtil](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax),
[Apple Entwicklervertrauen](https://help.apple.com/xcode/mac/current/en.lproj/dev96a12fb84.html).

## Erneuter Einrichtungsdurchlauf und USB-Nachprüfung

Build 13 über den Dateidialog der gepackten Windows-App ausgewählt und installiert.
Die App wechselte selbstständig zur Entwicklermodus-Anleitung; Kontingent 9/10.
Nach Aktivierung und Neustart meldete Windows das USB-Gerät, Apples USB-Dienst
lieferte bei unabhängiger Abfrage jedoch null Geräte. Die Wiederaufnahme ist in
diesem Durchlauf deshalb noch nicht bestätigt. Die vorherige Vertrauensabfrage
wurde mit einem Hilfsbefehl abgeschlossen und zählt nicht als vollständiger
Nachweis des Vertrauensschritts über die Windows-Oberfläche.

Korrigiert: Die Entwicklermodus-Anleitung erhält eine hervorgehobene Karte mit
animiertem iPhone und großer Handlungsüberschrift. Die USB-Wiederverbindung
nennt zusätzlich die Bestätigung von „Vertrauen“, automatische Prüfung alle drei
Sekunden und den Zeitpunkt der letzten Antwort. „Erneut prüfen“ in der
Entwicklermodus-Anleitung startet eine vollständige Gerätelistenabfrage statt
einer Prüfung des alten Geräteeintrags. Fehlgeschlagene Komponentenabfragen
verwerfen auch den alten Entwicklermodus-Status. 61 Windows-Tests bestanden,
einschließlich manueller Neuerkennung ohne vorhandenes Gerät, automatischer
Folgeabfrage und Komponentenprüfung nach Rückkehr ohne Neuinstallation.
Die Änderungen beweisen keine Wiederherstellung eines hängenden Apple-Dienstes.
Windows-Paket erfolgreich neu gebaut und Paketstartprüfung bestanden. Neue
Wiederverbindungsansicht am laufenden Paket visuell geprüft; zeigt den
Vertrauenshinweis und den Zeitpunkt der automatischen Geräteabfrage.

## Einführung, Kontoübernahme und LiveContainer-Icon

Überflüssige Entwicklermodus-Anleitung aus der laufenden iPhone-App entfernt;
die Einrichtung vor dem ersten Start bleibt in Windows. Neue überspringbare
Einführung: Willkommen, VPN-Verbindung und optional LiveContainer mit kurzer
Erklärung des gemeinsamen App-Platzes und der Kompatibilitätsgrenze. Kein
Kontoübernahme-Schritt in der Einführung. Wieder aufrufbar in Einstellungen.
Die lokale Netzwerksuche beginnt erst im Verbindungsschritt oder nach dem
Überspringen. Bereits vorhandene Kopplung/VPN/LiveContainer werden berücksichtigt.

Windows bereitet eine einmalige Sitzungskopie über den vertrauenswürdigen USB-
App-Container vor. Kein Passwort, kein Einbau in die IPA und keine Sitzung im
freigegebenen Dokumentenordner. Die private Übergabedatei liegt außerhalb von
Backups im Cache und wird nach Import/Verwerfung entfernt. iOS prüft Account und
Team gegen das eingebettete Profil, speichert im Schlüsselbund und prüft die
Sitzung mit Apple. Das zuvor ausgewählte Entwicklerteam wird wiederverwendet;
bei abgelehnter Sitzung bleibt die Anmeldung mit vorausgefüllter Apple-ID möglich.
Neue Kern-Tests prüfen Feldfreigabe, Größenbegrenzung und fremde Accountdaten.
Build 10 und 11 wurden erfolgreich gebaut und über dieselbe Kennung installiert.
Einführung, Weiter/Zurück, Überspringen, vorhandene VPN-Verbindung und Entfernung
der Entwicklermodus-Anleitung nativ geprüft. Die erste reine Sitzungsübernahme
scheiterte mit Fehler 1100. Build 12 übernimmt zusätzlich den zugehörigen lokalen
Authentifizierungskontext aus dem geschützten Windows-Speicher in den iOS-
Schlüsselbund; er wird vor dem Sitzungsaufruf im echten Interpreter validiert.
Native Wiederprüfung erfolgreich: automatisch angemeldet, Kontingent 9/10 direkt
in der iPhone-App geladen, Übergabedateien entfernt, Diagnose `restored`.
Keine zweite Passworteingabe. Nachfolgende Windows-Abfrage funktioniert ebenfalls.

Neues LiveContainer-Icon mit dem Bildwerkzeug erstellt und in
`assets/livecontainer-directside.png` gespeichert. Die Signierung ersetzt nur
das Icon der eigenständigen App mit exakt passender Bundle-ID. Passende deckende
iPhone-/iPad-PNGs und die Icon-Metadaten werden vor dem Signieren erzeugt. Name,
Kennung und Erweiterungen bleiben erhalten. Ein Integrationstest prüft die
Abgrenzung zu ähnlich benannten Apps sowie Größe, Deckkraft und Identität.
LiveContainer anschließend direkt aus der Einführung über VPN installiert.
Native Rückkehr meldet „Installiert“; Zertifikat automatisch an LiveContainer
übergeben, dort „Zertifikat entfernen“ im JIT-less-Bereich vorhanden. Das neue
Homescreen-Icon über SpringBoard ausgelesen und visuell bestätigt. App-IDs nach
der Installation weiterhin 9/10. Gast-App-Start ist damit noch nicht belegt.
Ein fehlendes Bild in der Einführung ist in Build 13 korrigiert und durch einen
erneuten nativen Screenshot bestätigt. Build 13 erfolgreich gebaut, installiert
und gestartet; Kontoübernahme erneut ohne Passwort bestätigt. Einführung mit
bereits installiertem LiveContainer erkennt ihn und bietet „Fertig“, ohne eine
zweite Installation zu starten. Zwei geprüfte iPhone-Screenshots ohne Accountdaten
sind in der README eingebunden.

Aktuelle IPA: 0.1.0 Build 13, 14.716.511 Bytes,
SHA256 `262492e70ff47ee851552e143c8f69e70ff09f2d8f5a6e31bcf9dba405763f83`.
Privater Build: [40156691407](https://github.com/Serekay/directside/actions/runs/40156691407).
Keine Veröffentlichung und keine neue App-Kennung.

Windows mit 60 Python-/Qt-Tests, zehn Kern-Tests und Paketstartprüfung bestanden.
Zusätzlicher Icon-Integrationstest bestanden. Die private Sitzung wird nur mit
ihrem zugehörigen lokalen Authentifizierungskontext übertragen; keine entfernte
Anisette und kein gespeichertes Passwort.

## USB-Verbindungsverlust

Windows erkennt den Verlust eines bereits gesehenen iPhones sowie Fehler beim
Abrufen der USB-Geräteliste. Es zeigt eine große Ansicht mit animiertem
Kabelstecker, „USB-Verbindung verloren“ und „iPhone entsperren und Kabel neu
einstecken“. Der Titelbereich markiert die Unterbrechung rot. Beim ersten Start
ohne Gerät erscheint keine falsche Verlustmeldung. Erneutes Prüfen ist möglich;
nach Wiedererkennung kehrt die Oberfläche automatisch zur vorherigen Ansicht
beziehungsweise zur noch offenen Einrichtung zurück. Keine automatische zweite
Installation bei bloßem Wiederverbinden.

Zustandswechsel, Ausfall des USB-Dienstes, Seitenrückkehr und Start/Stopp der
Animation durch Qt-Tests geprüft. Darstellung in Deutsch und Englisch bei
960 × 680 visuell geprüft. Insgesamt 59 Windows-Tests bestanden. Die neue
Warnansicht wurde mit eingespeisten Geräteereignissen geprüft; ein erneuter
physischer Abbruch mit diesem Paket ist noch nicht beobachtet worden.

## Oberflächenkorrektur, App-ID-Übersicht und Erststart

USB-Screenshots und echte Accessibility-Navigation auf dem iPhone eingerichtet.
Die vorhandene App wurde durch Entdecken, Meine Apps, Quellenliste/-details,
App-Details samt Berechtigungen, Quelle hinzufügen sowie Einstellungen,
Updateprüfung, Entwicklermodus, Verbindung, Signierung und LiveContainer
navigiert und ausgelesen. Screenshots bleiben lokal; Accountangaben und
private Quellen werden nicht in die README übernommen. Build 7 und 8 wurden
anschließend über dieselbe Kennung installiert und gestartet; App-ID-Kontingent
weiterhin 9/10. Quellenüberschrift, Berechtigungen, VPN-Badge, Updateansicht und
App-ID-Liste am Gerät geprüft. Build 8 zeigt nur Labels/Status/Aktionen und
lokalisierte Ablaufdaten. Der aktuelle Folgebuild ist 9.

Korrigiert: Geräteprüfung im Hintergrund ohne allgemeines Busy/Progress-Banner,
kurzer Cache gegen Prüfungen bei jedem Tabwechsel, Wisch-Erklärung entfernt,
Quellenüberschrift nur einmal, keine technischen Berechtigungsangaben,
LocalDevVPN als eigene Karte mit Status-Badge. iPhone-Updater für öffentliche
Releases ohne Token-/Accountoberfläche, mit automatischer/manueller Prüfung,
festem Release-Downloadpfad und Größen-/SHA256-Prüfung. Das Repository wird
dadurch nicht öffentlich gemacht; derzeit ist kein öffentliches Update abrufbar.

App-ID-Details: Windows-Zähler anklickbar, zusätzlich im Hilfemenü;
iPhone unter Einstellungen → App-Kennungen. Name, Ablauf, Zuordnung von
Erweiterungen und Kontingent kommen nur lesend von Apple. Neun Einträge
einschließlich Erweiterungszuordnung real abgefragt. Die Windows-Ansicht mit
Beispieldaten in Deutsch/Englisch bei 960 × 680 visuell geprüft.

55 Python-/Qt-Tests, acht Kern-Tests und drei Signierkennungs-Tests bestanden.
Windows-Paket gebaut und Startprüfung bestanden. iPhone-Build 8 über Action
[40150440163](https://github.com/Serekay/directside/actions/runs/40150440163)
erfolgreich gebaut und am Gerät geprüft. Größen-/SHA256-Prüfung der IPA bestanden.

Erststartlücke korrigiert: Eine erfolgreich installierte Entwickler-App wartet
bei ausgeschaltetem/unbekanntem Entwicklermodus auf den Benutzerschritt, statt
direkt die noch nicht mögliche Kopplung zu versuchen. AMFI bereitet den Schalter
vor; Windows zeigt die zwei nötigen Geräteschritte. Ein kleines lokales
Setup-Protokoll überlebt den App-Neustart. Nach bestätigtem Entwicklermodus
setzt Windows die Kopplung/Schlüsselübertragung für genau dieses Gerät und den
ursprünglichen Account fort. Importierte Zertifikate werden dabei unterstützt.
Tests decken Warten, Trennen/Wiederverbinden, Fortsetzen, App-Neustart und die
Abgrenzung zu anderen Geräten ab. Der echte Frischstarttest mit ausgeschaltetem
Entwicklermodus läuft: Am angeschlossenen Gerät wurde Modus „aus“ und nach
gezielter Deinstallation keine der drei Setup-Apps festgestellt. Die lokale
Build-9-IPA wurde über den echten Windows-Einrichtungsablauf installiert;
das Ereignis `developer_mode_required` erreicht die vorgesehene Warteansicht.
Nach Aktivierung/Neustartbestätigung blieb Apples USB-Geräteliste zunächst leer,
obwohl Windows die Treiber ohne Fehler erkannte. Einmaliges erneutes Einstecken
stellte die Verbindung her. Anschließend setzte Windows die Kopplung automatisch
fort und erreichte `setupReady`, ohne zweite Installation. Am Gerät bestätigt:
Entwicklermodus aktiv, DirectSide 0.1.0 Build 9, ein belegter App-Platz und
weiterhin 9/10 App-IDs. Der erste native Start erreichte Apples Dialog
„Entwicklungsteam, dem nicht vertraut wird“. Nach Bestätigung durch den Betreiber
startet DirectSide erfolgreich; native Accessibility bestätigt den frischen
Entdecken-Bildschirm und die erste iOS-Abfrage für das lokale Netzwerk.
LocalDevVPN wurde anschließend durch den Betreiber aus dem App Store installiert
und eingerichtet. DirectSide erkennt den Zustand „installiert, nicht verbunden“
nativ korrekt und zeigt „Verbinden“. Die Schaltfläche erreicht die iOS-Abfrage
zum Öffnen von LocalDevVPN; der verbundene Zustand, Installation über VPN und
Selbsterneuerung sind durch diesen Teilschritt noch nicht belegt.
Bei der Suche nach den wiederkehrenden USB-Ausfällen blieb die Verbindung während
manueller App-Wechsel mit ausschließlich lesender USB-Gerätelistenbeobachtung
erhalten. Auch eine einzelne AX-Abfrage und ein Screenshot lösten im anschließenden
Versuch keinen Abbruch aus. Ursache weiterhin ungeklärt; kein allgemeiner
Windows-11-Fehler und kein Fehler der Steuerung nachgewiesen.
Ein gezielter USB-Hinweis in der Warteansicht und ein
Fehler beim erwarteten Beenden des Testfensters wurden korrigiert; 57 Windows-
Tests einschließlich beider Regressionen bestanden.
Der auf diesem Gerät bereits sichtbare Schalter belegt keinen
Hardwaretest mit anfänglich unsichtbarem Schalter. Windows ohne installierte
Apple-Komponenten ist ebenfalls noch nicht praktisch geprüft.

Build 9 ist über Action
[40151158809](https://github.com/Serekay/directside/actions/runs/40151158809)
gebaut, über dieselbe Kennung installiert und auf dem iPhone gestartet worden.
Auch die anfängliche Sitzungsprüfung bleibt ohne Fortschrittsbanner; die
Geräteprüfung läuft nach der Anmeldung automatisch an. App-ID-Stand weiterhin
9/10. Windows ist einschließlich automatischer USB-Vertrauensabfrage neu gebaut;
gepackte Startprüfung bestanden. Fehlende Vertrauensbeziehung und abgelehnte
Bestätigung sind zusätzlich durch Ablauf-Tests abgedeckt; bestehende Kopplungen
werden wiederverwendet.

Ausgangszustand des Frischstarttests: iPhone-Anmeldung über die echte Oberfläche
abgemeldet; DirectSide, LiveContainer einschließlich Gastdaten und LocalDevVPN
gezielt entfernt. Keine anderen Apps, Fotos, Apple-App-IDs oder Zertifikate
verändert. Verifiziert: null Setup-Apps. Der Betreiber hat den Entwicklermodus
deaktiviert und neu gestartet, vor der Neuinstallation wurde „aus“ am Gerät
bestätigt. Eine neue USB-Vertrauensabfrage wurde in diesem Durchlauf nicht
beobachtet; der Fall einer vollständig entfernten PC-Kopplung ist damit noch
nicht nativ belegt. Kontokennungen und Signieridentität bleiben
für den Test ohne neue Registrierungen erhalten. Das ist ein frischer
Geräte-Setup-Test mit vorhandenem Apple-Konto, kein neues Apple-Konto und kein
Werksreset des persönlichen iPhones.

## App-ID-Prüfung und feste Kennung

Apple-Konto nur lesend geprüft: neun registrierte IDs, davon DirectSide eine,
LiveContainer einschließlich drei Erweiterungen vier, SideStore einschließlich
Widget zwei sowie E&P Test und E&P Dev jeweils eine. Keine DirectSide-Duplikate.
Alle lokal vorliegenden iPhone-Builds 1 bis 6 enthalten `com.directside.app`;
die Kennung ist auch in der gesamten Historie der Build-Konfiguration unverändert.
Keine Team- oder Gerätekennungen und keine Zugangsdaten hier gespeichert.

Der Account-Signierer hängt die Teamkennung jetzt höchstens einmal an und
vereinheitlicht bereits mehrfach angehängte gleiche DirectSide-Teamsuffixe.
Veränderte oder fremde DirectSide-Suffixe werden vor der App-ID-Registrierung
abgewiesen. Der iPhone-Build prüft die fertige IPA auf die feste ursprüngliche
Kennung. 51 Python-/Qt-Tests, acht Kern-Tests und drei neue Rust-Regressionstests
bestanden. Windows mit korrigiertem Signierkern neu gebaut; Startprüfung der
gepackten EXE einschließlich Qt/QML und lokalem Signierkern bestanden.
Die vorhandene iPhone-IPA bleibt Build 6; die zusätzliche Signierkorrektur ist
erst in einem neu gebauten iPhone-Kern enthalten.

## Neuer Korrekturstand: zwölf gemeldete Punkte

Windows lokal gebaut. Auf ausdrücklichen Buildauftrag wurde iPhone-Build 6
erfolgreich über Action [40146215784](https://github.com/Serekay/directside/actions/runs/40146215784)
gebaut: Swift-Modell-/Quellentests, lokale Apple-Provisionierungsprüfung,
Rust-Kern für aarch64-apple-ios und Xcode-App bestanden. Quellstand `1cabc8c`.
`dist/DirectSide.ipa`: Version 0.1.0, Build 6, 10.470.986 Bytes,
SHA256 `fe072e3495ccc7dcd9501dffa52212650603ec9b96fb47acb64079db1ef92772`.
App-Kennung und Buildnummer nach Download direkt aus der IPA geprüft.
Kein Release veröffentlicht; Gerätetest der neuen Oberfläche durch den Besitzer
steht aus. Drüberinstallieren dieser lokalen IPA aktualisiert die App;
Signaturerneuerung verwendet dagegen die auf dem iPhone gespeicherte Original-IPA.

| Punkt | Änderung |
| --- | --- |
| 1 | VPN-Leiste aus Hauptansicht und Dialogen entfernt; Status in Einstellungen. Vor Downloads/Installationen echte Verbindungsprüfung und Hinweis mit Öffnen-/Installieren-Aktion. |
| 2 | Entwicklermodus vor dem ersten Start in Windows-Installation, Hilfe, iPhone-Einstellungen und README. Neustart, Bestätigung, fehlender Schalter und Profilvertrauen erklärt. |
| 3 | Fensterweiter Tastaturabschluss beim Tippen außerhalb; Textfelder und weitere Bedienelemente bleiben bedienbar. |
| 4 | Berechtigungen mit Symbol, verständlichem Namen und Erklärung in Deutsch/Englisch. Rohkennung nur unter Technische Angabe, Anbietertext als solcher gekennzeichnet. |
| 5 | Reguläre App-Store-Apps aus der Verwaltung ausgeschlossen, auch im Kern gegen Löschen gesperrt. Meine Apps verwendet native Wischaktionen und langes Drücken mit Löschbestätigung; Geräte-Icons über SpringBoard. Tatsächliche signierte Kennung wird gespeichert, alte IPA nach erfolgreicher Ablösung entfernt. |
| 6 | Eigener iPhone-Updater mit Start-/manueller Prüfung, Angebot, privaten GitHub-Zugang im Schlüsselbund, Größen-/SHA256-/App-ID-/Versionsprüfung und Signierung über LocalDevVPN. Neue Original-IPA wird nach Neustart übernommen. Teamwechsel darf keine zweite DirectSide-Kopie erzeugen. |
| 7 | iPhone-Installation von LiveContainer startet die Zertifikatsübergabe automatisch. Windows überträgt sie nach DirectSide; das nächste Öffnen von DirectSide übergibt sie an LiveContainer. Reparaturknopf bleibt. |
| 8 | LiveContainer 3.8.0 wählt JIT-less anhand seines gespeicherten Zertifikatpassworts. Übergabe setzt diese Voraussetzung; Diagnose ist kein verpflichtender zusätzlicher Modusschalter. Gast-App-Start noch nicht bestätigt. |
| 9 | Account oder importierte P12 plus mehrere Profile in beiden Oberflächen. Schlüssel-/Zertifikatsabgleich, Ablauf, Profilzugehörigkeit und Gerätefreigabe; keine pauschale Drei-App-Sperre für bezahlte Profile. Importierte Identität und Pairing werden beim ersten USB-Setup ebenfalls übertragen. |
| 10 | Quellen mit Quellensymbol und Herkunft; Detail und Vorschau ohne doppeltes App-Icon. App-Liste als Apps aus dieser Quelle benannt. |
| 11 | Dauerhafte Updates/Aktuell-Zeile entfernt. Aktualisieren nur an betroffener App, einschließlich DirectSide selbst. |
| 12 | Add-Source-Intro entfernt; QR als Symbolknopf, Quelle prüfen als hervorgehobener Knopf erst bei nichtleerer Eingabe. |

Prüfungen: 50 Python-/Qt-Tests, acht Kern-Tests und sieben Vendor-Tests erfolgreich.
Enthalten sind Original-App-Schutz, gerätebezogene Löschbestätigung, Signieren ohne
Apple-Anmeldung mit importierter Identität, keine Passwörter in Einstellungen,
Fenstergrenzen sowie echter P12-Rundlauf mit falschem Passwort und falschem Profil.
Windows-Signierkern und EXE gebaut; gepackter Qt-/QML-/Icon-/Engine-Starttest mit
lokaler Authentifizierung erfolgreich. Zertifikatsansicht und Hilfe bei minimaler
Fenstergröße visuell geprüft. Swift-Syntax aller App-Dateien geprüft. Neue
Swift-Modelltests für Versionsvergleich und alte/neue Installationskennungen
sind jetzt auf dem macOS-Buildhost erfolgreich ausgeführt worden.
Das iPhone wurde anschließend per USB erkannt. Der direkte Screenshot-Kanal
über CoreDeviceProxy/RSD/DTX ließ sich erfolgreich öffnen, ohne Bildschirmbild
aufzunehmen. Native README-Aufnahmen warten auf die neue installierte App.

Noch nativ zu prüfen: Tastatur und Wisch-/Langdruckgesten, VPN-Hinweis bei echter
Unterbrechung, vollständiges Selbstupdate mit Prozessneustart, automatische
Zertifikatsübernahme/JIT-less-Gaststart und Signierung mit bezahltem beziehungsweise
fremdem Zertifikat. Die synthetischen Profiltests sind keine Apple- oder
Hardware-Freigabe. Keine Zugangsdaten oder Profile im Repository.

## Bisheriger veröffentlichter Stand vom 24. Oktober

Release 0.1.0 vom Besitzer am 24. Oktober 2026 ausdrücklich freigegeben.
Repository bleibt privat. EXE und IPA stammen unverändert aus dem geprüften
Build 44d764f; die Freigabe ersetzt keine noch ausstehenden Gerätetests.

[Release v0.1.0](https://github.com/Serekay/directside/releases/tag/v0.1.0)
mit `DirectSide.exe`, `DirectSide.ipa` und `SHA256SUMS.txt` veröffentlicht.
Dateigrößen und GitHub-SHA256 aller Assets mit lokalen Dateien abgeglichen.
Der Release-Client der Windows-App erkennt die stabile Version und beide Assets;
IPA-Download darüber einschließlich Hash- und Bundle-ID-Prüfung bestanden.
Private Repository-Sichtbarkeit nach Veröffentlichung erneut geprüft.

LiveContainer wurde inzwischen vom Besitzer geöffnet und fordert die Einrichtung
des JIT-less-Modus an. Diagnose und Start einer Gast-App sind noch nicht bestätigt.
Die folgenden Einträge dokumentieren auch frühere Entwicklungsstände.

## Bestätigung vom Besitzer und neue Einrichtung

Neubau auf ausdrückliches „bau“: Stand 44d764f lokal als Windows-EXE gebaut;
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

Aktuelle IPA: Quellstand `3640815`, Version 0.1.0, Build 2. Privater manueller Build:
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

Stand 63e4674: Windows-EXE lokal gebaut und nach bestandenem Paketstarttest nach dist/DirectSide.exe übernommen. 43 Python-Tests und vier Rust-Tests bestanden. iPhone-Action 40096167045 erfolgreich: Build 3, lokale TCI-Provisionierung, Zustandswiederherstellung und wiederholte OTP-Erzeugung bestanden; IPA samt Bundle-ID, Buildnummer und CoreADI-Hash geprüft und nach dist/DirectSide.ipa übernommen. Kein Zertifikat widerrufen. Der Besitzer hat die früher mit SideStore installierten Apps selbst gelöscht; die Oberfläche meldet 0/3 Entwickler-Apps und ein Zertifikat namens iloader. Die tatsächliche Installation und iPhone-Anmeldung bleiben zu prüfen.
