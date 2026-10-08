# Gopher Flutter Client

A native Gopher browser with a consistent text interface, typed menus and documents, search, bookmarks, and browsing history.

Current native app version: **1.0.1+2**. See [CHANGELOG.md](CHANGELOG.md) for release changes.

The standalone **Gopher Reader extension 1.0.0** converts a loaded web page into a local text-and-links view in one click. See [extension installation and usage](extension/README.md) for Chromium and Firefox packages.

## Install and use on Linux

The first validated build target is Linux x86-64. The package contains the application, Flutter runtime libraries, and assets; Flutter is not needed to run it. A graphical Linux desktop with GTK 3 is required. Builds use Flutter 3.32.7; portable compatibility across Linux distributions still needs validation.

When a Linux release package is available, extract `gopher-client-<version>-linux-x86_64.tar.gz` and either run `bundle/gopher_flutter_client` directly or run:

```bash
./install.sh
```

The installer copies the complete bundle into your user data directory, adds Gopher Client to the application menu, and registers `gopher://` links when `xdg-mime` is available. It does not require administrator access. Use `./install.sh --no-register` to keep your existing default Gopher handler. Applications install under `${XDG_DATA_HOME:-$HOME/.local/share}/gopher-client/<version>`.

There is no published release from this change yet. Developers can generate the package with the command below; the Linux CI workflow also uploads build artifacts.

Open the app and enter a Gopher URL or bare hostname. The starting screen includes example destinations. Text pages support selection, copying, and a working wrap toggle; menus provide directory, text, search, and web-link actions. Bookmark and history selections return you to Browse. Back, Forward, Reload, and Retry preserve the resource type and search query.

Standard URLs include the resource type immediately after the first slash:

```text
gopher://gopher.floodgap.com                 root menu
gopher://example.org/1/docs                  menu with selector /docs
gopher://example.org/0/readme.txt            text with selector /readme.txt
gopher://example.org/7search%09two%20words    search selector search, query two words
```

Selectors are opaque; the app does not guess parent directories. An explicit port is supported, including local servers. Gopher is a plain TCP protocol. Text responses use UTF-8, with Latin-1 fallback for legacy bytes; this fallback does not detect other legacy character sets.

## Develop and test

Use Flutter **3.32.7**, the version recorded in `.flutter-version`, and its bundled Dart 3.8.1. The application's resolved dependencies are committed in `pubspec.lock`. Native platform build tools are also required; `flutter doctor` describes missing prerequisites.

```bash
git clone https://github.com/rafael-minuesa/gopher-flutter-client.git
cd gopher-flutter-client
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d linux
```

The tests use a local Gopher fixture server rather than public servers. They cover URL round trips, protocol framing, text encoding, search requests, response bounds and deadlines, cancellation, typed navigation, stale responses, persistence recovery, and the search/bookmark/wrap UI.

Validated on 2026-10-08 with Flutter 3.32.7: all 32 regression tests passed, analysis and formatting checks passed, and the Linux release package built successfully. The package was installed into a temporary user data directory (including spaces and a percent sign), its desktop entry was validated, and the installed app was launched on a virtual display and fetched a text document from a local Gopher server. The merged upstream web download page also builds successfully and renders at the GitHub Pages base path in a local headless browser. Public-server connectivity, CI execution, and other native platforms were not tested.

The app also accepts a Gopher URL as a native command-line argument:

```bash
./build/linux/x64/release/bundle/gopher_flutter_client 'gopher://example.org/0/readme.txt'
```

## Build packages

```bash
dev-tools/package-linux.sh
```

This builds Linux in release mode and writes the complete archive and SHA-256 checksum into `dist/`. Set `FLUTTER_BIN` to select a particular SDK. Do not distribute the executable by itself: it requires the accompanying `lib/` and `data/` directories. `.github/workflows/checks.yml` checks formatting, analyzes, tests, builds, and uploads the Linux package without publishing a release.

Native runner projects are also present for Android, iOS, Windows, and macOS. Android has release network permission; macOS has outgoing-network sandbox entitlements. Their builds and OS link integration have not been validated in this Linux environment:

```bash
flutter build apk --release
flutter build ios --release
flutter build windows --release
flutter build macos --release
```

Use the appropriate host toolchain for each target. Android currently uses Flutter's generated development signing setup; configure release signing before public distribution. iOS and macOS distribution require their respective signing configuration.

The web target preserves the download landing page and GitHub Pages deployment. It does not browse Gopher: a browser client needs a separate HTTPS/WebSocket gateway transport for direct TCP resources. The standalone HTML-to-text extension is implemented in [extension/](extension/README.md). The optional native companion remains a later phase described in [REVIEW.md](REVIEW.md).

## Supported content

| Resource | Behavior |
| --- | --- |
| Type `1`: menu | Parsed list of typed links and information |
| Type `0`: text | Selectable document with protocol framing removed |
| Type `7`: search | Query dialog and navigable results; query preserved in URLs/history |
| Type `h`: external `URL:http(s)` link | Opens the system web browser |
| Type `h`: Gopher-hosted HTML | Displays HTML source as text |
| Information and error rows | Displayed without navigation |
| Binary, images, Telnet, and other types | Listed as unsupported for reading; no download UI |

Connections have a 30-second total deadline and an 8 MiB response limit. A new visit cancels the previous connection and ignores obsolete results. Saved-data failures leave browsing available; damaged JSON is preserved under recovery keys and valid entries remain usable.

## Layout

```text
lib/models/      Typed addresses and menu items
lib/services/    TCP client, navigation state, persistence
lib/screens/     Browse, bookmarks, history
lib/widgets/     Address, menu and text controls
test/            Protocol, state, storage and UI regression tests
dev-tools/       Linux packaging and user installation
```

Licensed under [MIT](LICENSE). Protocol references: [RFC 1436](https://www.rfc-editor.org/rfc/rfc1436) and [RFC 4266](https://www.rfc-editor.org/rfc/rfc4266).
