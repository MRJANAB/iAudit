# Example output

Illustrative, **sanitized** output — fake device identifiers and a small
representative app set (not a real person's inventory). Your own run will show
your device's real apps.

## `bash scripts/audit.sh --crash`

```text
== iOS USB Security Audit ==
Device UDID: 00000000-0000000000000000
Report dir : ./audit-00000000-0000000000000000

# Device info
DeviceName:      Example iPhone
ProductType:     iPhone15,4
ProductName:     iPhone OS
ProductVersion:  26.5.2
BuildVersion:    23F84
CPUArchitecture: arm64e
ModelNumber:     MT...
ActivationState: Activated

# Storage
Free : 13.63 GB
Used : 100.96 GB of 114.59 GB (88.1% full)

# App inventory + security triage
iOS app security triage — 6 user apps

RISK  SCORE   BUNDLE ID                          APP
------------------------------------------------------------------------------
HIGH  11      com.gnux.trans.de                  German Translator
HIGH  9       com.spycamera.app                  Network Scanner
HIGH  9       com.paperclipglobal.AllRoundTools  Toolbox
MEDIUM 4       com.gofinger.railway               Where is my Train
LOW   1       net.whatsapp.WhatsApp              WhatsApp
OK    0       com.apple.exampleapp               Example Bank

=== Details for flagged apps ===

### [HIGH] German Translator  (com.gnux.trans.de)  v12.14.27
    - ad-driven permission (Calendars)
    - ad-driven permission (BluetoothPeripheral)
    - ATS disabled (cleartext HTTP to any host)
    - ad SDKs: AdMob, Facebook
    perm Calendars: 'Advertisement would like to create a calendar event.'
    perm BluetoothPeripheral: 'Advertisement would like to use bluetooth.'
    perm Microphone: 'Translator uses Microphone for voice search feature.'

### [HIGH] Network Scanner  (com.spycamera.app)  v2.5.3
    - identity mismatch: bundle id contains 'spy' but app is named 'Network Scanner'
    - ad SDKs: AdMob, Facebook
    - tracking domains: ep1.facebook.com
    perm Camera: "Allow to use your device's camera to use it with colored filter."
    perm BluetoothAlways: 'Allow Bluetooth connection to find nearby devices'

### [HIGH] Toolbox  (com.paperclipglobal.AllRoundTools)  v1.6.3
    - ATS disabled (cleartext HTTP to any host)
    - ad SDKs: AdMob
    perm PhotoLibrary: 'Please allow us to use your photo library ...'
    perm LocalNetwork: 'Please allow us to use your network'

### [MEDIUM] Where is my Train  (com.gofinger.railway)  v4.13
    - ATS disabled (cleartext HTTP to any host)
    - ad SDKs: AdMob
    perm LocationAlways: 'App uses device location to show live train status ...'

# Provisioning profiles (dev/enterprise)
Device has 0 provisioning profiles installed:

# Wireless lockdown settings
EnableWifiDebugging: false
SupportsWifi: true

# Crash reports
Crash files by source:
   7 SiriSearchFeedback
   3 JetsamEvent
   1 Instagram
   1 StreamingUnzipService

== Done ==
Report written to: ./audit-00000000-0000000000000000

On-device checks USB cannot do (hand these to the user):
  - Settings > General > VPN & Device Management (rogue profiles/MDM)
  - Settings > General > About > Certificate Trust Settings (rogue root CAs)
  - Settings > Wi-Fi > (i) (unexpected Proxy / DNS)
  - Settings > General > iPhone Storage (per-app sizes, offload)
```

## How to read it

- **RISK / SCORE** rank apps by security signals that actually separate shady apps
  from legitimate ones — not by how many permissions they request (every free app
  requests a lot). The weighted signals are:
  - **ATS disabled** (`NSAllowsArbitraryLoads`) — the app can send data over
    plaintext HTTP to any host.
  - **ad-driven permission** — the permission's own justification cites advertising
    (e.g. *"Advertisement would like to create a calendar event."*).
  - **identity mismatch** — the bundle ID contradicts the display name
    (`com.spycamera.app` shown as "Network Scanner").
  - Ad SDKs (AdMob/Facebook) and tracking domains are shown as context.
- Mainstream apps (WhatsApp, banks, Google) land at **LOW/OK** — they don't disable
  transport security and don't drive permissions through ad SDKs.
- Scores are a **heuristic triage to prioritize review**, not a verdict. Confirm real
  behavior with dynamic analysis (mitmproxy — see `references/capabilities.md`).

## JSON output

For piping into other tools:

```bash
ideviceinstaller list --user --xml | python3 scripts/apptriage.py --json
```

```json
[
  {
    "name": "German Translator",
    "bundle_id": "com.gnux.trans.de",
    "version": "12.14.27",
    "score": 11,
    "risk": "HIGH",
    "permissions": { "Calendars": "Advertisement would like to create a calendar event.", "...": "..." },
    "flags": [
      "ad-driven permission (Calendars)",
      "ATS disabled (cleartext HTTP to any host)",
      "ad SDKs: AdMob, Facebook"
    ]
  }
]
```
