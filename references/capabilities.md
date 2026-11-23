# Capability map — what you can and cannot do over USB

All of this assumes a **non-jailbroken** iPhone/iPad connected by USB, driven with
`libimobiledevice`. It talks to Apple's own lockdown / AFC / installation_proxy /
diagnostics services, so it works on current iOS — but it is confined to what those
services expose.

## ✅ Possible over USB (no jailbreak)
| Task | Command |
|------|---------|
| List device info | `ideviceinfo` / `ideviceinfo -k <Key>` / `-q <Domain>` |
| List user apps | `ideviceinstaller list --user` |
| Full app metadata (Info.plist) | `ideviceinstaller list --user -b <id> --xml` |
| Install / uninstall apps | `ideviceinstaller install <ipa>` / `uninstall <id>` |
| Live system log (filterable) | `idevicesyslog -p <App>` / `-m <match>` |
| Pull crash reports | `idevicecrashreport -k <dir>` |
| Full logical backup | `idevicebackup2 backup --full <dir>` |
| Browse/copy camera roll | `afcclient ls /DCIM` / `afcclient get <path> <dst>` |
| Free-space totals | `ideviceinfo -q com.apple.disk_usage` |
| Dev/enterprise profiles | `ideviceprovision list` |
| Restart / shutdown | `idevicediagnostics restart` / `shutdown` |

## ❌ Not possible over USB (need the device Settings, or a jailbreak)
- **Per-app storage sizes** and app **cache contents** — sandboxed. Only
  `/var/mobile/Media` (camera roll) is reachable via AFC. Apps are only reachable
  via `afcclient --documents <id>` if they set `UIFileSharingEnabled`, and even then
  only their Documents folder.
- **Clearing app caches** (Telegram/Snapchat/Instagram) — on-device, per app, or
  delete + reinstall.
- **Reading installed configuration profiles, trusted root CAs, VPN/proxy/DNS** —
  `ideviceprovision` only lists *developer* provisioning profiles, not config
  profiles. Check on device:
  - Settings → General → VPN & Device Management
  - Settings → General → About → Certificate Trust Settings
  - Settings → Wi-Fi → (i) → Proxy / Configure DNS
- **Screenshots** (`idevicescreenshot`) — need the Developer Disk Image mounted.
  iOS 17+ uses a *personalized* DDI that ships with full Xcode. Without Xcode, use
  QuickTime Player (File → New Movie Recording → pick the iPhone) to mirror + capture.
- **Runtime instrumentation** (frida/objection) on arbitrary/App Store apps — App
  Store binaries are FairPlay-encrypted; hooking them needs a jailbreak, which does
  not exist for recent A-series chips on current iOS. You *can* embed the frida
  **gadget** into an app you re-sign yourself (apps you control).

## Dynamic analysis: mitmproxy traffic capture
Prove what an app actually sends:

1. On the host: `mitmweb` (listens on port 8080; UI on http://127.0.0.1:8081).
2. On the device: Wi-Fi → network → Configure Proxy → Manual → server = host LAN IP,
   port = 8080.
3. On the device Safari: visit `mitm.it`, install the mitmproxy CA, then enable full
   trust in Settings → General → About → Certificate Trust Settings.
4. Open the target app and watch requests in mitmweb.
5. **Remove the CA cert and the proxy when done** — a left-behind CA is a standing
   MITM risk. Only test low-risk apps; never a third party's banking/finance app.

## Safety / ethics
- Only audit devices the user owns or is authorized to test.
- Uninstalling an app with `ideviceinstaller uninstall` **permanently deletes the app
  and its data**. Confirm per app.
- Treat anything you copy off the device (backups, crash logs, photos) as the user's
  private data — keep it local.
