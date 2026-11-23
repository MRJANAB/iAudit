#!/usr/bin/env python3
"""
iOS app security triage.

Reads the XML property list produced by:
    ideviceinstaller list --user --xml
on STDIN, and prints a risk-ranked security triage of every installed user app.

Pure standard library (plistlib). Works on Python 3.6+.

Usage:
    ideviceinstaller list --user --xml | python3 apptriage.py
    ideviceinstaller list --user --xml | python3 apptriage.py --json
"""
import sys
import json
import plistlib

SENSITIVE_PERMS = {
    "Camera", "Microphone", "LocationAlways", "LocationWhenInUse",
    "LocationAlwaysAndWhenInUse", "Calendars", "Contacts", "PhotoLibrary",
    "BluetoothAlways", "BluetoothPeripheral", "SpeechRecognition",
    "FaceID", "Reminders", "Motion", "LocalNetwork",
}


def perm_label(key):
    return key.replace("UsageDescription", "").replace("NS", "")


def triage_app(d):
    """Return a dict describing one app's risk signals + score."""
    bid = d.get("CFBundleIdentifier", "?")
    name = d.get("CFBundleDisplayName") or d.get("CFBundleName") or "?"
    ver = d.get("CFBundleShortVersionString", "?")

    flags = []
    score = 0

    # Scoring philosophy: almost every free app requests sensitive permissions and
    # bundles ad SDKs, so those are NOT scored (only displayed for context). Score
    # only the signals that actually separate shady/adware apps from legitimate ones:
    #   - App Transport Security globally disabled (cleartext HTTP anywhere)
    #   - permission usage strings that blame "advertisement" (ad SDK driving access)
    #   - bundle-id / display-name identity mismatch
    # Ad SDKs and tracking domains are shown as context with a tiny weight.

    # Permissions (displayed, mostly unscored)
    perms = {}
    for k, v in d.items():
        if k.endswith("UsageDescription"):
            label = perm_label(k)
            perms[label] = v
            # Strong adware tell: the justification literally cites advertising.
            if isinstance(v, str) and ("advertis" in v.lower() or "广告" in v):
                score += 4
                flags.append("ad-driven permission (%s)" % label)

    # App Transport Security globally disabled — strong signal; legitimate major
    # apps rarely set this.
    ats = d.get("NSAppTransportSecurity") or {}
    if ats.get("NSAllowsArbitraryLoads"):
        score += 4
        flags.append("ATS disabled (cleartext HTTP to any host)")

    # Ad / tracking SDKs — context only, tiny weight (capped at 1).
    ad_sdks = []
    if d.get("GADApplicationIdentifier"):
        ad_sdks.append("AdMob")
    if d.get("FacebookClientToken") or d.get("FacebookAppID"):
        ad_sdks.append("Facebook")
    if ad_sdks:
        score += 1
        flags.append("ad SDKs: " + ", ".join(ad_sdks))
    track = d.get("NSPrivacyTrackingDomains")
    if track:
        flags.append("tracking domains: " + ", ".join(track))

    # Identity / name mismatch heuristic: a word in the bundle id that clearly
    # contradicts the display name (e.g. com.spycamera.app named "Network Scanner").
    suspicious_tokens = ("spy", "hack", "crack", "fake", "spoof", "stalk")
    low_bid = bid.lower()
    low_name = name.lower()
    for tok in suspicious_tokens:
        if tok in low_bid and tok not in low_name:
            score += 5
            flags.append("identity mismatch: bundle id contains '%s' but app is named '%s'"
                         % (tok, name))
            break

    return {
        "name": name,
        "bundle_id": bid,
        "version": ver,
        "score": score,
        "permissions": perms,
        "flags": flags,
    }


def risk_band(score):
    if score >= 8:
        return "HIGH"
    if score >= 4:
        return "MEDIUM"
    if score >= 1:
        return "LOW"
    return "OK"


def main():
    as_json = "--json" in sys.argv[1:]
    try:
        arr = plistlib.loads(sys.stdin.buffer.read())
    except Exception as e:
        sys.stderr.write("Could not parse plist on stdin: %s\n" % e)
        sys.stderr.write("Pipe in: ideviceinstaller list --user --xml\n")
        return 1
    if not isinstance(arr, list):
        arr = [arr]

    results = [triage_app(d) for d in arr if isinstance(d, dict)]
    results.sort(key=lambda r: r["score"], reverse=True)

    if as_json:
        for r in results:
            r["risk"] = risk_band(r["score"])
        print(json.dumps(results, indent=2))
        return 0

    print("iOS app security triage — %d user apps\n" % len(results))
    print("%-5s %-7s %-34s %s" % ("RISK", "SCORE", "BUNDLE ID", "APP"))
    print("-" * 78)
    for r in results:
        print("%-5s %-7d %-34s %s" % (risk_band(r["score"]), r["score"],
                                      r["bundle_id"][:34], r["name"]))

    print("\n=== Details for flagged apps ===")
    any_flagged = False
    for r in results:
        if not r["flags"] and risk_band(r["score"]) == "OK":
            continue
        any_flagged = True
        print("\n### [%s] %s  (%s)  v%s" %
              (risk_band(r["score"]), r["name"], r["bundle_id"], r["version"]))
        for f in r["flags"]:
            print("    - " + f)
        for label, desc in r["permissions"].items():
            if label in SENSITIVE_PERMS:
                print("    perm %s: %r" % (label, desc))
    if not any_flagged:
        print("\nNothing flagged. All apps are clean at the metadata level.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
