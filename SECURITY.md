# Security Policy

The Mooziac development team takes the security and privacy of our users very seriously. As an open-source, native macOS application, we are committed to maintaining high security standards and addressing vulnerabilities promptly.

---

## 🛡️ Supported Versions

We actively provide security patches and updates for the following versions:

| Version | Supported          | Status             |
| ------- | ------------------ | ------------------ |
| 1.0.x   | :white_check_mark: | Currently Supported |
| < 1.0.0 | :x:                | Unsupported        |

We strongly encourage all users to stay updated with the latest release available on [GitHub Releases](https://github.com/shirkeharsh/mooziac/releases).

---

## 🔒 Security & Privacy Architecture

Mooziac is designed with a **privacy-first, local-first** security model:

1. **Zero Telemetry & Tracking**  
   Mooziac does not collect, track, or transmit any analytics, crash logs, or user metrics to third-party servers. All application state, playlist data, and listening history reside exclusively on your local machine in `~/Library/Application Support/Mooziac/`.

2. **WebKit & Authentication Isolation**  
   YouTube Music integration runs through an embedded macOS `WKWebView`. Authentication is handled directly between your client and Google/YouTube via native WebKit cookies. Mooziac does not harvest, log, or store your passwords or Google account credentials.

3. **Subprocess & IPC Safety**  
   All background tasks (such as audio processing via `ffmpeg` or helper tools) use structured `Process` argument arrays rather than raw shell execution to prevent command injection. Discord Rich Presence communicates over standard local UNIX domain sockets (`/tmp/discord-ipc-0`).

4. **Hardened Runtime**  
   Production binaries are signed with Hardened Runtime enabled, restricting unauthorized memory access and dynamic library hijacking.

---

## 🚨 Reporting a Vulnerability

If you discover a security vulnerability or potential exploit in Mooziac, please help us protect our users by following responsible disclosure practices.

### How to Report:
* **GitHub Private Advisory (Preferred):** Open a [Private Security Advisory](https://github.com/shirkeharsh/mooziac/security/advisories/new) on GitHub.
* **Direct Contact:** If GitHub Private Advisory is unavailable, please open a confidential report or contact the maintainer directly via GitHub profile details.

### Please Include in Your Report:
- Detailed description of the vulnerability and its potential impact.
- Step-by-step instructions or a minimal Proof of Concept (PoC) to reproduce the issue.
- Affected Mooziac version(s) and macOS version (e.g., macOS Sonoma, macOS Sequoia).
- Any proposed remediation or suggested patch (if available).

### Response SLA & Process:
- **Acknowledgment:** We aim to acknowledge receipt of vulnerability reports within **48 hours**.
- **Assessment & Triage:** We will assess the severity, reproduce the issue, and provide regular updates on progress.
- **Fix & Disclosure:** Once a fix is verified, a patched release will be published. We will coordinate public disclosure with you to ensure users have adequate time to upgrade.

---

## 🎯 Scope

### In Scope:
* Arbitrary code execution or local privilege escalation.
* WebKit sandbox escapes or insecure JavaScript bridge bindings.
* Insecure handling of custom URL schemes (`mooziac://`).
* Sensitive data or credential leakage from local storage.
* Vulnerabilities in the auto-update mechanism.

### Out of Scope:
* Attacks requiring physical access to an unlocked Mac workstation.
* Vulnerabilities in third-party web services (e.g., YouTube Music infrastructure).
* Security issues in deprecated, modified, or unofficial forks of Mooziac.
* Non-security bugs or feature requests (please use [GitHub Issues](https://github.com/shirkeharsh/mooziac/issues) instead).

---

Thank you for helping keep Mooziac and the open-source community safe! 🎵
