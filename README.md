# DirectSide

Ein eigener App-Katalog für iPhone mit nativer Magazin-Oberfläche, Quellenimport per QR-Code, App-Details, Screenshots, Versionsverlauf, Updates und lokaler Erneuerung der Signaturen. Die Windows-Anwendung übernimmt die Erstinstallation und überträgt das Remote-Pairing automatisch.

**Projektstatus:** Entwicklung und erste Test-Builds. Ein erfolgreicher Build ist noch kein Nachweis, dass Apple-Anmeldung, Geräteinstallation und Selbsterneuerung auf einem echten iPhone funktionieren. Diese Schritte werden vor einer Freigabe gesondert geprüft. Es gibt noch keine öffentliche Veröffentlichung.

**Lokale Anmeldung:** Windows erzeugt Anisette im eigenen Prozess mit Apples lokalem CoreADI. Es gibt keinen voreingestellten Fremdserver und keinen automatischen Remote-Fallback. Die entsprechende lokale Authentifizierung auf iOS ist noch nicht implementiert; die iPhone-Anmeldung und damit die vollständige Selbsterneuerung sind derzeit blockiert. Die bisherige IPA stammt aus einem älteren Stand und erfüllt diese lokale Authentifizierungsanforderung noch nicht.

## Projektstruktur

| Ordner | Inhalt |
|---|---|
| `ios/` | Native SwiftUI-App mit dem bestätigten Magazin-Design |
| `src/` | Gemeinsamer Rust-Kern für Anmeldung, Signierung, USB und Remote Pairing |
| `ui/` | Qt-Quick-Oberfläche im kompakten iLoader-Stil |
| `assets/` | Eigenes DirectSide-Icon, Original und Windows-Symbole |
| `packaging/` | Versionierte Konfiguration für das Windows-Paket |
| `scripts/` | Lokaler Build inklusive Starttest der fertigen EXE |
| `docs/` | Architektur, Entwicklungsanleitung und tatsächlicher Teststand |
| `vendor/isideload/` | MIT-lizenzierte Signierbibliothek, mit kleiner dokumentierter Erweiterung |
| `.github/workflows/` | Nur manuell gestartete private iPhone-Builds |

## Verwendung des Testpakets

1. `DirectSide.exe` und `DirectSide.ipa` in denselben Ordner legen.
2. Das iPhone per USB anschließen, entsperren und dem PC vertrauen.
3. Fehlende Apple-USB-Unterstützung über die Komponentenansicht installieren beziehungsweise einen gestoppten Dienst starten. Danach mit der eigenen Apple-ID anmelden und das iPhone auswählen.
4. „DirectSide auf dem iPhone einrichten“ starten. Pairing und Original-IPA werden dabei mit übertragen.
5. Auf dem iPhone dem Entwicklerprofil vertrauen und gegebenenfalls den Entwicklermodus aktivieren.
6. Zielablauf nach Fertigstellung der lokalen iOS-Anmeldung: LocalDevVPN verbinden, DirectSide öffnen und einmalig mit der eigenen Apple-ID anmelden. Dieser Schritt funktioniert im aktuellen lokalen Authentifizierungsstand noch nicht.
7. Eine Quelle per QR-Code oder HTTPS-Adresse hinzufügen. Apps ansehen, installieren und unter „Meine Apps“ aktualisieren oder erneuern.

Der vorgesehene Ablauf „DirectSide erneuern“ signiert die Original-IPA neu. „Alle Signaturen erneuern“ bearbeitet zuerst die anderen Apps und DirectSide zuletzt, weil iOS die laufende App beim Ersetzen schließen kann. Das ist noch nicht erfolgreich am Gerät nachgewiesen und benötigt die ausstehende lokale iOS-Anmeldung.

## Drei-App-Limit und LiveContainer

DirectSide belegt selbst einen der drei Plätze einer kostenlosen Apple-ID. Die App prüft erkannte Entwickler-Apps vor einer neuen Installation; bestehende Apps dürfen weiterhin aktualisiert und erneuert werden. LocalDevVPN aus dem App Store zählt nicht zu diesen selbst signierten Apps.

App-Detailseiten bieten außerdem „In LiveContainer installieren“. Die optionale Windows-Einrichtung unter Einstellungen → LiveContainer lädt die offizielle Standalone-Version 3.8.0, prüft deren SHA-256 und installiert sie mit der eigenen Apple-ID. „Zertifikat übertragen“ überträgt die verschlüsselte PKCS#12-Identität lokal an DirectSide auf dem ausgewählten Gerät. Der neue iOS-Code speichert sie im Geräteschlüsselbund und übergibt sie erst auf ausdrücklichen Aufruf an LiveContainer. Der JIT-less-Test in LiveContainer bleibt der Funktionsnachweis.

Das ist **kein eingebautes LiveContainer-Laufzeitsystem**. DirectSide und LiveContainer benötigen zusammen zwei Plätze pro Gerät. Die Zertifikatsübergabe benötigt einen neuen iOS-Build; sie ist in der älteren IPA nicht enthalten und noch nicht am Gerät getestet.

Windows erkennt Geräte automatisch und zeigt deren installierte Benutzer-Apps mit echten Geräte-Icons. App-Plätze und VPN-Status gehören zum ausgewählten Gerät; bei fehlgeschlagener Prüfung wird kein erfundener Belegungswert angezeigt. Die zehn App-IDs sind eine separate Account-Grenze, keine gemeinsame Drei-App-Grenze für iPhone und iPad. Siehe [Apple-Account-Grenzen](https://developer.apple.com/help/account/basics/about-your-developer-account/).

## Was weiterhin von Apple abhängt

- Bei einer normalen kostenlosen Apple-ID gelten Apples Sieben-Tage-Profile und App-/App-ID-Limits weiter.
- Ein kostenlos signiertes Exemplar kann keine eigene Packet-Tunnel-Erweiterung bereitstellen. LocalDevVPN bleibt daher separat erforderlich.
- Anisette und Apples Authentifizierungsdienste sind weiterhin Teil der Apple-ID-Anmeldung. DirectSide beseitigt diese Plattformabhängigkeit nicht.
- Hintergrundausführung garantiert iOS nicht. Die erste Version erneuert auf ausdrücklichen Aufruf in der geöffneten App.
- Die IPA aus dem Build ist absichtlich **unsigniert**. Erst das Windows-Programm signiert sie für den eigenen Account und das eigene Gerät.

## Datenschutz

Passwörter werden nicht in Dateien oder Git gespeichert und nicht als Prozessargumente übergeben. Sitzung, Signierschlüssel und Anisette-Zustand liegen im jeweiligen Betriebssystem-Schlüsselbund. Die iPhone-Pairingdatei wird nach der Erstübertragung aus dem freigegebenen Dokumentordner in den geschützten App-Bereich verschoben. Apple-Zugangsdaten und Pairingdateien gehören niemals in GitHub oder Build-Artefakte.

Windows merkt sich Apple-ID und Oberflächensprache unter `%LOCALAPPDATA%\DirectSide\preferences.json`. Alte Serveradressen werden beim Laden verworfen. Das Passwort steht dort nicht. Bei gültiger Schlüsselbund-Sitzung erfolgt die Anmeldung nach dem Start automatisch; andernfalls ist die Apple-ID bereits ausgefüllt. Bestätigungscode, SMS-Auswahl, Team-Auswahl, Pairing und Fehler sind in das Hauptfenster integriert. Für die Installation von Apple-USB-Unterstützung erscheint die normale Windows-Administratorbestätigung.

Windows wird ausschließlich lokal mit `scripts/build-windows.ps1` gebaut. Die aktuelle EXE liegt unter `dist/DirectSide.exe`. GitHub Actions baut nur die iPhone-IPA und nur bei manuellem Start. Pushes lösen keine Builds aus.

Windows startet auf Englisch. Deutsch lässt sich unter Settings → Language auswählen und wird gespeichert. Die kurze Einrichtungshilfe befindet sich im ⋯-Menü. Rot kennzeichnet fehlende Komponenten, Gelb Warnungen beziehungsweise ungeprüfte Zustände und Grün erfolgreiche Prüfungen. Fehlt LocalDevVPN, zeigt Windows einen lokal erzeugten App-Store-QR-Code für das ausgewählte iPhone oder iPad.

## Entwicklung und Freigabe

Siehe [DEVELOPMENT.md](docs/DEVELOPMENT.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [TESTSTATUS.md](docs/TESTSTATUS.md) und [CHANGELOG.md](CHANGELOG.md).

Das GitHub-Repository bleibt privat. **Öffentliche Veröffentlichung, Sichtbarkeitsänderungen und Releases erfolgen nur nach ausdrücklicher Freigabe des Eigentümers, wenn Design und Gerätefunktionen geprüft sind.**

## Abhängigkeiten und Icon

DirectSide benötigt keine installierte SideStore-App. Es nutzt `isideload` und `idevice` als offene Bibliotheken für die Apple- und Geräteprotokolle. `vendor/LICENSE-isideload` enthält die Lizenz; die lokale Änderung ist in `vendor/README-DirectSide.md` dokumentiert.

Das private Windows-Paket enthält die lokal vorhandene Apple-Datei `CoreADI64.dll`; sie wird nicht ins Repository übertragen. Der Komponentenassistent lädt bei fehlender USB-Unterstützung den festgelegten iTunes-x64-Installer direkt von Apple und prüft dessen SHA-256 vor dem Start. Eine vorhandene funktionierende Installation bleibt unangetastet. Das Weiterverbreiten von Apple-Komponenten ist vor einer späteren öffentlichen Veröffentlichung gesondert zu klären.

Das individuelle App-Icon wurde mit der integrierten Bildgenerierung erstellt. Briefing und Assetpfade stehen in [assets/icon-prompt.md](assets/icon-prompt.md).
