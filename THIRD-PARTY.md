# Sources and bundled components

- NetSpot Windows UI and feature reference: https://www.netspotapp.com/netspot-windows.html (accessed 2026-10-15). No NetSpot binary, logo, source, vendor AP catalogue or proprietary project format is incorporated in this application.
- WLAN API: Microsoft Windows system library wlanapi.dll, through documented Win32 structures and calls. https://learn.microsoft.com/en-us/windows/win32/nativewifi/native-wifi-reference
- `web/vendors.json`: IEEE MA-L OUI registry, downloaded 2026-10-15, 40,333 organization assignments. Source: https://standards-oui.ieee.org/oui/oui.txt . OUI identifies the registrant, not necessarily the product brand. Locally administered MAC addresses are not looked up. MA-M/MA-S assignments are not included.
- `tools/iperf3.exe` and `tools/cygwin1.dll`: iPerf3 3.22 Windows build, https://github.com/ar51an/iperf3-win-builds/releases/tag/3.22 . Distribution referenced by https://iperf.fr/iperf-download.php . Download archive SHA-256 verified against GitHub asset digest: `c9feabb3d721039508ccb81f74c2ada3ae11b9e75d33d24510573c2aa21da420`.
- iPerf source/license: https://github.com/esnet/iperf . Windows build and Cygwin runtime sources/license: https://github.com/ar51an/iperf3-win-builds and https://www.cygwin.com/ . Preserve their license/source obligations when redistributing this folder. Bundling here is for the local development workspace.

RF predictions are this project's simplified log-distance model. They are not the NetSpot prediction engine and have not been calibrated against physical site measurements.
