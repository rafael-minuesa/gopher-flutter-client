# Linux native companion

The Linux package installs `gopher_reader_companion` alongside the Flutter app. It implements browser native messaging, a private Unix socket for library control, and a Gopher server bound exclusively to IPv4 loopback port 7070. The browser launches short-lived hosts; a separate daemon keeps the library available independently of those connections.

The host accepts only the registered Chromium extension ID `hionbnafppomnooihjbamcfbojjoakcg` or Firefox ID `gopher-reader@rafael-minuesa.github.io`. The Chromium build includes a public manifest key so unpacked installs have a stable ID. Store publication must reconcile the store-assigned ID with host registration; there is no store release yet.

The versioned import message contains a reader snapshot ID, source metadata, article/full-page plain text, and numbered links. The background script builds it from its own stored copy; web/content-script messages cannot invoke the host. The daemon validates and bounds messages, IDs, URLs, text and library size before atomically saving a copy. Repeated handoffs of one reading copy update the same document and Gopher address. Creating a new reading copy creates another saved snapshot.

Gopher selectors:

| Selector | Response |
| --- | --- |
| `/` | Type 1 saved-page library menu |
| `/page/<uuid>` | Type 1 page menu and links |
| `/text/<uuid>/article` | Type 0 article text |
| `/text/<uuid>/page` | Type 0 full-page text |

Menu fields cannot inject tabs/newlines; text uses CRLF, dot escaping and the Gopher terminator. Saved link targets are resolved at request time, so converting a destination later makes existing page menus point locally. Fragments resolve to the destination page; native Gopher text does not provide HTML anchor scrolling. External Gopher links preserve their resource type and selector; search destinations prompt for a query in the app.

Storage is `${XDG_DATA_HOME:-$HOME/.local/share}/gopher-reader`, with mode 0700 directories, opaque document filenames, a server lock, and bounded JSON files. The control socket is under `${XDG_RUNTIME_DIR}/gopher-reader` when set, otherwise in the library directory. Long Unix socket paths require a shorter `XDG_RUNTIME_DIR`. Corrupt or oversized saved files remain on disk for recovery and appear as unreadable copies when possible. Only the app library's explicit Remove action deletes them. Library limits are 100 snapshots and 64 MiB.

The server starts on handoff or library opening. It stays alive after browser/app closure; Stop serving removes the restart marker, closes the sockets, and keeps copies. Opening the app resumes a previously enabled library. No login service, public listener, HTTP gateway, or remote fetching is installed. Port 7070 is fixed to preserve bookmarks and must be available. Loopback Gopher has no authentication against other local processes; only explicitly sent copies belong in the library.

From an installed bundle:

```bash
./gopher_reader_companion --status   # inspect an already running server
./gopher_reader_companion --library  # start serving and list saved copies
./gopher_reader_companion --stop     # stop serving, keep saved copies
./gopher_reader_companion --install-browser-hosts
```

The installer registers Chrome, Chrome for Testing, Chromium and Edge manifests under `${XDG_CONFIG_HOME:-$HOME/.config}` and Firefox under `~/.mozilla/native-messaging-hosts`. `GOPHER_FIREFOX_HOST_DIR` can override the Firefox manifest directory for a custom browser environment. Stock Firefox does not discover this override automatically. Snap/Flatpak browser integration needs platform-specific portal/setup work. Only Chromium and Firefox desktop have been tested.

Build with `dev-tools/package-linux.sh`. The helper uses Flutter's bundled Dart SDK to compile an AOT executable and has no runtime package dependencies. Protocol/library tests live in `test/companion_test.dart`. Real-browser tests install the complete package into temporary XDG directories, leave HOME unchanged, and exercise native messaging, TCP delivery and existing-window navigation under a private D-Bus session.
