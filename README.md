# DirectSide

Ein eigener App-Katalog für iPhone mit nativer Magazin-Oberfläche, Quellenimport per QR-Code, App-Details, Screenshots, Versionsverlauf, Updates und lokaler Erneuerung der Signaturen. Die Windows-Anwendung übernimmt die Erstinstallation und überträgt das Remote-Pairing automatisch.

**Projektstatus:** Entwicklung und erste Test-Builds. Ein erfolgreicher Build ist noch kein Nachweis, dass Apple-Anmeldung, Geräteinstallation und Selbsterneuerung auf einem echten iPhone funktionieren. Diese Schritte werden vor einer Freigabe gesondert geprüft. Es gibt noch keine öffentliche Veröffentlichung.

## Projektstruktur

| Ordner | Inhalt |
|---|---|
| `ios/` | Native SwiftUI-App mit dem bestätigten Magazin-Design |
| `src/` | Gemeinsamer Rust-Kern für Anmeldung, Signierung, USB und Remote Pairing |
| `ui/` | Native Windows-Anwendung zur Einrichtung |
| `assets/` | Eigenes DirectSide-Icon, Original und Windows-Symbole |
| `vendor/isideload/` | MIT-lizenzierte Signierbibliothek, mit kleiner dokumentierter Erweiterung |
| `.github/workflows/` | Private Test-Builds für iOS und Windows |

## Verwendung des Testpakets

1. `DirectSide-Windows.exe` und `DirectSide.ipa` in denselben Ordner legen.
2. Das iPhone per USB anschließen, entsperren und dem PC vertrauen.
3. In DirectSide für Windows mit der eigenen Apple-ID anmelden und das iPhone auswählen.
4. „DirectSide auf dem iPhone einrichten“ starten. Pairing und Original-IPA werden dabei mit übertragen.
5. Auf dem iPhone dem Entwicklerprofil vertrauen und gegebenenfalls den Entwicklermodus aktivieren.
6. LocalDevVPN verbinden und DirectSide öffnen. Einmalig auch dort mit der eigenen Apple-ID anmelden.
7. Eine Quelle per QR-Code oder HTTPS-Adresse hinzufügen. Apps ansehen, installieren und unter „Meine Apps“ aktualisieren oder erneuern.

Die iPhone-App signiert sich über „DirectSide erneuern“ selbst. „Alle Signaturen erneuern“ bearbeitet zuerst die anderen Apps und DirectSide zuletzt, weil iOS die laufende App beim Ersetzen schließen kann.

## Drei-App-Limit und LiveContainer

DirectSide belegt selbst einen der drei Plätze einer kostenlosen Apple-ID. Die App prüft erkannte Entwickler-Apps vor einer neuen Installation; bestehende Apps dürfen weiterhin aktualisiert und erneuert werden. LocalDevVPN aus dem App Store zählt nicht zu diesen selbst signierten Apps.

App-Detailseiten bieten außerdem „In LiveContainer installieren“. Diese erste Anbindung übergibt die Quellen-IPA an ein separat installiertes offizielles LiveContainer. Sie ist **kein eingebautes LiveContainer-Laufzeitsystem** und behauptet keinen erfolgreichen Gast-Import ohne dessen Bestätigung. Die Kompatibilität der jeweiligen App muss in LiveContainer geprüft werden. DirectSide und ein separates LiveContainer benötigen zusammen zwei Plätze. Einrichtung und Zertifikatsimport in LiveContainer sind gesondert zu testen.

## Was weiterhin von Apple abhängt

- Bei einer normalen kostenlosen Apple-ID gelten Apples Sieben-Tage-Profile und App-/App-ID-Limits weiter.
- Ein kostenlos signiertes Exemplar kann keine eigene Packet-Tunnel-Erweiterung bereitstellen. LocalDevVPN bleibt daher separat erforderlich.
- Anisette und Apples Authentifizierungsdienste sind weiterhin Teil der Apple-ID-Anmeldung. DirectSide beseitigt diese Plattformabhängigkeit nicht.
- Hintergrundausführung garantiert iOS nicht. Die erste Version erneuert auf ausdrücklichen Aufruf in der geöffneten App.
- Die IPA aus dem Build ist absichtlich **unsigniert**. Erst das Windows-Programm signiert sie für den eigenen Account und das eigene Gerät.

## Datenschutz

Passwörter werden nicht in Dateien oder Git gespeichert und nicht als Prozessargumente übergeben. Sitzung, Signierschlüssel und Anisette-Zustand liegen im jeweiligen Betriebssystem-Schlüsselbund. Die iPhone-Pairingdatei wird nach der Erstübertragung aus dem freigegebenen Dokumentordner in den geschützten App-Bereich verschoben. Apple-Zugangsdaten und Pairingdateien gehören niemals in GitHub oder Build-Artefakte.

Windows merkt sich die Apple-ID und die gewählte Serveradresse unter `%LOCALAPPDATA%\DirectSide\preferences.json`. Das Passwort steht dort nicht. Bei gültiger Schlüsselbund-Sitzung erfolgt die Anmeldung nach dem Start automatisch; andernfalls ist die Apple-ID bereits ausgefüllt. Bestätigungscode, SMS-Auswahl, Team-Auswahl, Pairing, Fehler und nächste Schritte nach der Installation sind in das Hauptfenster integriert. Nur die normale Windows-Dateiauswahl öffnet ein eigenes Fenster.

## Entwicklung und Freigabe

Siehe [DEVELOPMENT.md](DEVELOPMENT.md), [ARCHITECTURE.md](ARCHITECTURE.md), [TESTSTATUS.md](TESTSTATUS.md) und [CHANGELOG.md](CHANGELOG.md).

Das GitHub-Repository bleibt privat. **Öffentliche Veröffentlichung, Sichtbarkeitsänderungen und Releases erfolgen nur nach ausdrücklicher Freigabe des Eigentümers, wenn Design und Gerätefunktionen geprüft sind.**

## Abhängigkeiten und Icon

DirectSide benötigt keine installierte SideStore-App. Es nutzt `isideload` und `idevice` als offene Bibliotheken für die Apple- und Geräteprotokolle. `vendor/LICENSE-isideload` enthält die Lizenz; die lokale Änderung ist in `vendor/README-DirectSide.md` dokumentiert.

Das individuelle App-Icon wurde mit der integrierten Bildgenerierung erstellt. Briefing und Assetpfade stehen in [assets/icon-prompt.md](assets/icon-prompt.md).
