# Google Chrome integration and distribution policy

Google's official Linux download flow offers an amd64 Debian package, states that downloading Chrome constitutes agreement to the Google Terms of Service and Chrome/ChromeOS Additional Terms, and states that installation adds Google's package repository for automatic updates. The published terms govern use of Google's software/services but do not clearly grant AtlasOS permission to redistribute the proprietary Chrome binary inside a third-party ISO. AtlasOS therefore uses the conservative distribution path: Chrome is not selected or embedded in the ISO.

The AtlasOS `Web Tarayıcısı` launcher prefers `google-chrome-stable` and `google-chrome` when already installed. If no supported browser is available, the launcher presents official terms links and waits for an explicit user action before requesting administrator authorization. The helper downloads only the official stable amd64 `.deb` over HTTPS, checks its package name, architecture, and version metadata, then installs it through APT. Chrome's own use terms are not accepted by AtlasOS; the user remains responsible for reviewing and accepting any terms presented by Google. The official package may configure Google's signed APT source for subsequent updates.

The included installer does not add Google's repository during image construction, does not bundle Chrome, does not use a mirror, and does not contain credentials or signing keys. The downloaded package is not locally signature-verified as a standalone artifact; its transport uses HTTPS to Google's official host, and post-install update trust follows the repository configuration installed by Google's package. This is a documented technical trust boundary, not a legal opinion or a claim that Google has endorsed AtlasOS.

Official references:

- [Google Chrome for Linux download and terms notice](https://www.google.com/chrome/)
- [Google Terms of Service](https://policies.google.com/terms)
- [Chrome and ChromeOS Additional Terms](https://www.google.com/chrome/terms/)
- [Chrome deployment on Linux](https://support.google.com/chrome/a/answer/9025903)

## Live-session privilege boundary

The installer uses a dedicated Polkit action bound to the exact helper path. Its default policy continues to require administrator authentication; the narrowly scoped rule grants authorization only to the local, active AtlasOS Live user session. The rule also requires boot=casper in /proc/cmdline and verifies that /rofs is a read-only squashfs mount. The helper independently checks both Live signals, requires root, and rejects every command-line argument before downloading or installing anything. If either Live signal is absent or cannot be verified, installation stops.

No root password, sudo group membership, or general passwordless administration is added. The browser launcher does not pass its requested page URL or other user input into the helper. Browser logs redact requested URLs to avoid recording query strings or other potentially sensitive URL data.
