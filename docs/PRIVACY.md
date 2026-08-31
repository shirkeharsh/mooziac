# 🔒 Privacy Policy for Mooziac

*Last Updated: August 2026*

Mooziac ("we", "our", or "the app") is designed from the ground up with a **local-first, privacy-respecting architecture**. We believe your music listening habits and personal data belong to you and nobody else.

---

## 1. No Data Collection or Telemetry
- Mooziac does **not** collect, store, transmit, or sell any personal data, usage metrics, crash telemetry, or tracking identifiers.
- There are no third-party tracking SDKs, analytics frameworks (e.g. Google Analytics, Firebase, Mixpanel), or advertising networks bundled in the app.

---

## 2. Local Storage
- **Library & Playlists**: All your custom playlists, listening history, liked songs, and downloaded tracks are stored locally on your device in an encrypted/private SQLite database located in your macOS Application Support directory (`~/Library/Application Support/Mooziac/`).
- **Audio Files**: Downloaded audio and artwork files remain strictly on your local disk in your chosen storage directory.

---

## 3. YouTube Music Integration & Cookies
- When you choose to sign in to YouTube Music within Mooziac, your session cookies and authentication credentials are handled exclusively by Apple's secure `WKWebView` cookie store on your machine.
- Mooziac communicates directly with YouTube Music's servers (`music.youtube.com` and `youtube.com`) solely to stream audio and fetch your account playlists/liked songs. Your credentials never touch any intermediate server.

---

## 4. Discord Rich Presence
- If Discord Rich Presence is enabled, Mooziac transmits only the currently playing track title, artist name, and album artwork URL over a local IPC socket to the Discord desktop client running on your Mac. No account details or private listening history are shared.

---

## 5. Contact
If you have any questions regarding privacy or the app's local data handling, please open an issue on our [GitHub repository](https://github.com/shirkeharsh/mooziac).
