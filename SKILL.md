---
name: ios-usb-security-audit
description: >-
  Audit a USB-connected iPhone or iPad from a Mac or Linux host for security and
  storage issues WITHOUT a jailbreak, using libimobiledevice. Enumerate installed
  apps and triage each one's declared permissions, ad/tracking SDKs, and insecure
  transport (ATS) settings; flag identity/name mismatches; review crash reports;
  check for rogue provisioning/MDM profiles; inspect free space; and safely
  uninstall risky apps. Use when asked to security-check, audit, privacy-review,
  or clean up a physically connected iOS device over USB. Only for devices the
  user owns or is authorized to test.
---

# iOS USB Security Audit

Audit an iPhone/iPad connected over USB from a Mac or Linux machine — no jailbreak
required. Everything here uses Apple's own lockdown/AFC/installation services via
the open-source `libimobiledevice` suite, so it works on current iOS, but it is
limited to what those services expose (metadata, not app sandbox contents).

## Authorization (read first)
Only run this against a device the user **owns or is explicitly authorized to
test**. Confirm before uninstalling apps or pulling data — those are the user's
call. Never route a third party's banking/finance app traffic through a proxy.

## Prerequisites
- A Mac (Homebrew) or Linux (apt) host.
- The iPhone/iPad connected by a **data** USB cable, **unlocked**, with
  **"Trust This Computer"** accepted (re-accept after a reboot).
- Tools installed: run `scripts/setup.sh` once.

## Workflow

1. **Set up tooling** (first time only):
   ```bash
   bash scripts/setup.sh
   ```
   Installs `libimobiledevice` + `ideviceinstaller` (and optionally `mitmproxy`).

2. **Confirm the device is connected and paired:**
   ```bash
   idevice_id -l            # should print a UDID
   idevicepair validate     # should say "Validated pairing"
   ideviceinfo -k ProductType -k ProductVersion
   ```

3. **Run the full audit** (device info + app triage + storage + profiles + network):
   ```bash
   bash scripts/audit.sh
   ```
   Add `--crash` to also pull and summarize crash reports, and `--out DIR` to
   choose an output directory (default: `./audit-<udid>`).

4. **Read the triage output.** Apps are risk-ranked. For each flagged app the
   report shows *why* (ATS disabled, ad SDKs, sensitive permissions, identity
   mismatch). Present the findings to the user and recommend removals.

5. **Uninstall risky apps — only with explicit per-app confirmation:**
   ```bash
   ideviceinstaller uninstall <bundle.id>      # PERMANENT: removes app + data
   ```
   Then re-verify:
   ```bash
   ideviceinstaller list --user -b <bundle.id> --xml   # empty array = gone
   ```

6. **Hand off the on-device checks** that USB cannot reach (see Limits). Give the
   user the exact Settings paths.

## What each script does
- `scripts/setup.sh` — installs the toolchain (macOS/Homebrew or Debian/apt).
- `scripts/apptriage.py` — reads `ideviceinstaller list --user --xml` on **stdin**
  and prints a risk-ranked security triage of every user app. Pure stdlib Python 3.
- `scripts/audit.sh` — orchestrates the whole audit and writes a report folder.

Run the triage standalone too:
```bash
ideviceinstaller list --user --xml | python3 scripts/apptriage.py
```

## Risk signals the triage flags
- `NSAllowsArbitraryLoads = true` — App Transport Security disabled (cleartext HTTP).
- Ad/tracking SDKs — AdMob (`GADApplicationIdentifier`), Facebook
  (`FacebookClientToken`/`FacebookAppID`), declared `NSPrivacyTrackingDomains`.
- "Advertisement would like to…" usage strings — ad SDKs driving sensitive
  permissions (Calendar, Bluetooth).
- Sensitive permissions (Camera, Microphone, Location, Calendar, Contacts, Photos).
- Display-name vs bundle-ID mismatch (e.g. a "Network Scanner" whose bundle ID is
  `com.spycamera.app`).

## Limits — what USB CANNOT do on a non-jailbroken device
These need the device's own Settings (tell the user, don't claim to do them):
- **Per-app storage sizes** and app **cache contents** (sandboxed). Only the
  **Media** folder (camera roll) is reachable via AFC.
- **Clearing app caches** (Telegram/Snapchat/Instagram): on-device or delete+reinstall.
- **Configuration profiles, trusted root CAs, VPN/proxy/DNS config**:
  Settings → General → VPN & Device Management, and → About → Certificate Trust Settings.
- **Screenshots** (`idevicescreenshot`) need the Developer Disk Image, which ships
  with full Xcode (iOS 17+ uses a personalized DDI).
- **Runtime app instrumentation** (frida/objection) requires re-signing the target
  app with a frida gadget (no jailbreak exists for recent A-series chips).

See `references/capabilities.md` for the full capability map and the dynamic-analysis
(mitmproxy) setup.
