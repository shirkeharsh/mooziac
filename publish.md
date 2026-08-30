# 🚀 Mooziac Product Release & Distribution Audit (`publish.md`)

> **Comprehensive Product Readiness Report & Release Checklist**  
> *Target Platform: macOS 13.0+ (Apple Silicon & Intel)*  
> *Date: August 2026*

---

## Executive Summary

Mooziac has a high-performance, feature-rich Core Audio & WebKit engine with trackpad gestures, local playback, and YouTube Music synchronization. However, transitioning from a local development build to a **polished, consumer-facing commercial/open-source product** requires addressing several critical packaging, metadata, styling, security, and distribution gaps.

This document details every missing component across **7 core pillars**, complete with actionable implementation blueprints.

---

## 1. DMG Installer & Packaging Presentation (Visual Branding)

Currently, `mooziac.sh` generates a plain DMG via raw `hdiutil create`. When users open it, Finder displays a plain white folder with default icon layout.

### What is Missing:
- [ ] **Branded DMG Background Artwork**: High-resolution 2x Retina background image (`.background/background.png`, 660×400px) with custom typography, the Mooziac logo, and a visual installer arrow pointing to `/Applications`.
- [ ] **Finder Window Layout Configuration (`.DS_Store`)**:
  - Pre-configured window dimensions (660×400).
  - Fixed icon positions: `Mooziac.app` at `(180, 220)` and `Applications` symlink at `(480, 220)`.
  - Icon size set to `128×128`.
  - Toolbar, status bar, and sidebar hidden on mount.
- [ ] **Custom DMG Volume Icon**: Custom `.VolumeIcon.icns` so the mounted disk displays the Mooziac icon on the Desktop.
- [ ] **Automated Script**: Integrate `create-dmg` or an AppleScript-driven Finder styler into `mooziac.sh`.

---

## 2. Application Bundle Metadata (`Info.plist`)

The current `Info.plist` contains only minimal development fields.

### What is Missing:
- [ ] **Production Bundle Identifier**: Replace `com.local.Mooziac` with a production domain (e.g. `app.mooziac.mac` or `com.harshshirke.mooziac`).
- [ ] **Build Number (`CFBundleVersion`)**: Add `1` (or `100`), distinct from `CFBundleShortVersionString` (`1.0.0`).
- [ ] **Copyright String (`NSHumanReadableCopyright`)**: e.g., `Copyright © 2026 ThreeTen. All rights reserved.`
- [ ] **Application Category (`LSApplicationCategoryType`)**: `public.app-category.music`.
- [ ] **Minimum OS Requirement (`LSMinimumSystemVersion`)**: `13.0`.
- [ ] **Human-Readable Version String (`CFBundleGetInfoString`)**: `Mooziac 1.0.0, Copyright © 2026`.
- [ ] **Principal Class (`NSPrincipalClass`)**: `NSApplication`.
- [ ] **App Transport Security / Privacy Keys**: If any external streaming, RPC, or sidecars require explicit permissions.

---

## 3. Code Signing, Hardened Runtime & Apple Notarization

Currently, the app uses ad-hoc or local development signing (`Apple Development`). On other users' Macs, macOS Gatekeeper blocks execution with *"Unidentified Developer"* or *"Malicious Software"* warnings.

### What is Missing:
- [ ] **Hardened Runtime Entitlements (`Mooziac.entitlements`)**:
  - `com.apple.security.cs.allow-jit` (required for WKWebView JavaScript engine).
  - `com.apple.security.cs.allow-unsigned-executable-memory` (required for WebKit audio / DSP).
  - `com.apple.security.network.client` (outbound web streaming and download access).
  - `com.apple.security.automation.apple-events` (for system media controls if needed).
- [ ] **Developer ID Signing**:
  - Sign with `Developer ID Application: <Developer Name> (<TEAM_ID>)` using `--options runtime`.
- [ ] **Apple Notarization Pipeline**:
  - Automated `xcrun notarytool submit` to Apple's notarization servers.
  - Automated `xcrun stapler staple` to attach the notarization ticket to the `.dmg` and `.app`.
- [ ] **Gatekeeper Fallback Instructions**:
  - Clear user-facing documentation for non-notarized open-source builds (`xattr -cr` or Right-Click $\to$ Open).

---

## 4. Git & Version Control Automation (CI/CD)

Currently, releases are built manually on the local machine.

### What is Missing:
- [ ] **Git Semantic Version Tagging**: Git tag `v1.0.0` aligned with `Package.swift` and `Info.plist`.
- [ ] **GitHub Actions Automated Build & Release (`.github/workflows/release.yml`)**:
  - Trigger on tag push (`git push origin v1.0.0`).
  - Build on `macos-14` (Apple Silicon & Intel universal binary).
  - Assemble DMG and ZIP.
  - Create a GitHub Release with auto-generated release notes and attached assets.
- [ ] **Changelog Maintenance (`CHANGELOG.md`)**: Comprehensive changelog entry detailing all v1.0.0 launch features.

---

## 5. In-App Auto-Updates (Sparkle Framework)

Users who download `Mooziac.dmg` currently have no way to receive updates without manually revisiting the website/repo.

### What is Missing:
- [ ] **Sparkle 2 Integration**: Add Sparkle SPM package to `Package.swift`.
- [ ] **Appcast Feed URL (`SUFeedURL`)**: Host `appcast.xml` on GitHub Pages / AWS S3 / Cloudflare R2.
- [ ] **"Check for Updates..." Menu Item**: Located in the main menu bar context menu.
- [ ] **EdDSA Key Signing**: Public update signing key in `Info.plist` (`SUPublicEDKey`).

---

## 6. Marketing, Branding & Visual Assets

### What is Missing:
- [ ] **Multi-Resolution App Icon Set (`AppIcon.icns`)**:
  - Verify inclusion of 16×16, 32×32, 64×64, 128×128, 256×256, 512×512, and 1024×1024 (@1x and @2x).
- [ ] **Project `README.md` Modernization**:
  - Hero banner, feature showcase GIF/video, gesture cheat sheet, installation guide, and badge bar.
- [ ] **Product Screenshots**: High-definition screenshots of Dynamic Island Player, Glass Mode, Dark Mode, Lyrics Overlay, and Offline Library.
- [ ] **Landing Page / Website (Optional)**: Single-page showcase with direct DMG download button.

---

## 7. Legal, Privacy & Compliance Documents

### What is Missing:
- [ ] **Privacy Policy (`docs/PRIVACY.md`)**:
  - Transparency document explaining that Mooziac stores library data locally, does not collect analytics or sell user data, and accesses YouTube Music directly through the user's browser session.
- [ ] **Third-Party Disclaimer & Trademark Notice (`docs/DISCLAIMER.md`)**:
  - Clarify that Mooziac is an independent third-party client and not affiliated with Google or YouTube Music.
- [ ] **Open Source License Verification**: Ensure `LICENSE` (MIT) and third-party dependency attributions are bundled.
- [ ] **GitHub Issue & PR Templates**:
  - `.github/ISSUE_TEMPLATE/bug_report.md`
  - `.github/ISSUE_TEMPLATE/feature_request.md`

---

## 📋 Comprehensive Release Checklist

| # | Item | Status | Priority |
| :--- | :--- | :---: | :---: |
| 1 | Complete `Info.plist` with copyright, build number, category, min OS | ⚠️ Needs Update | **High** |
| 2 | Create `Mooziac.entitlements` with Hardened Runtime capabilities | ⚠️ Missing | **High** |
| 3 | Create branded DMG background graphic & styled `.DS_Store` layout | ⚠️ Missing | **High** |
| 4 | Update `mooziac.sh` to build styled DMG with custom volume icon | ⚠️ Needs Update | **High** |
| 5 | Setup GitHub Actions workflow (`.github/workflows/release.yml`) | ⚠️ Missing | **Medium** |
| 6 | Create Privacy Policy (`docs/PRIVACY.md`) & Legal Disclaimer | ⚠️ Missing | **Medium** |
| 7 | Create GitHub Issue & Feature templates | ⚠️ Missing | **Low** |
| 8 | Add Sparkle Framework for 1-click in-app auto updates | 💡 Future | **Medium** |

---

## Recommended Execution Plan

1. **Phase 1: Metadata & Security Foundation**
   - Update `Info.plist` with complete production metadata and bundle identifier.
   - Create `Mooziac.entitlements` for Hardened Runtime.
2. **Phase 2: Premium DMG Installer Packaging**
   - Design a branded 660×400 DMG installer background.
   - Upgrade `mooziac.sh` with AppleScript Finder layout styling and custom volume icon.
3. **Phase 3: Legal & GitHub Presentation**
   - Create `docs/PRIVACY.md` and `docs/DISCLAIMER.md`.
   - Setup GitHub Actions CI/CD release workflow.
