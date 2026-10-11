# Google Chrome integration and distribution policy

Google's official Linux download flow offers an amd64 Debian package, states that downloading Chrome constitutes agreement to the Google Terms of Service and Chrome/ChromeOS Additional Terms, and states that installation adds Google's package repository for automatic updates. The published terms govern use of Google's software/services but do not clearly grant AtlasOS permission to redistribute the proprietary Chrome binary inside a third-party ISO. AtlasOS therefore uses the conservative distribution path: Chrome is not selected or embedded in the ISO.

The AtlasOS `Web Tarayıcısı` launcher prefers `google-chrome-stable` and `google-chrome` when already installed. If no supported browser is available, the launcher presents official terms links and waits for an explicit user action before requesting administrator authorization. The helper downloads only the official stable amd64 `.deb` over HTTPS, checks its package name, architecture, and version metadata, then installs it through APT. Chrome's own use terms are not accepted by AtlasOS; the user remains responsible for reviewing and accepting any terms presented by Google. The official package may configure Google's signed APT source for subsequent updates.

The included installer does not add Google's repository during image construction, does not bundle Chrome, does not use a mirror, and does not contain credentials or signing keys. The downloaded package is not locally signature-verified as a standalone artifact; its transport uses HTTPS to Google's official host, and post-install update trust follows the repository configuration installed by Google's package. This is a documented technical trust boundary, not a legal opinion or a claim that Google has endorsed AtlasOS.

Official references:

- [Google Chrome for Linux download and terms notice](https://www.google.com/chrome/)
- [Google Terms of Service](https://policies.google.com/terms)
- [Chrome and ChromeOS Additional Terms](https://www.google.com/chrome/terms/)
- [Chrome deployment on Linux](https://support.google.com/chrome/a/answer/9025903)
