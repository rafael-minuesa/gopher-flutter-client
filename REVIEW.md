# Project review and proposed direction

Update on 2026-10-08: the native client fixes below have been implemented, with typed URLs and navigation, working search/wrap, explicit web-link handling, bounded/cancellable transport, persistence recovery, and native platform runners. Linux release packaging, a user installer, and build checks are now present. See README.md for current supported behavior and installation. Gopher Reader extension 1.0.0 now implements the standalone local conversion phase for Chromium and Firefox, with production-manifest browser tests and installable development packages. The native companion remains proposed. The remainder of this review records the original findings and design roadmap.

Reviewed on 2026-10-07. This is a review and implementation proposal; the application and extension have not been changed or built as part of it.

Update on 2026-10-09: the Linux native companion is implemented in app 1.1.0+3 and extension 1.1.0. Open in Gopher app saves explicitly selected snapshots, serves type 0 text and type 1 menus over loopback TCP, and opens the app's existing window. The installer registers the bundled native host; the app library provides removal and serving controls. See [native/README.md](native/README.md) for implementation and remaining platform limits. The roadmap below retains the original review for context.

The strongest product direction is a consistent text browser: native Gopher documents and converted web pages should share the same reading controls, link presentation, bookmarks, and navigation. Keep Flutter for the installed client and add a small browser extension for one-click conversion of an already loaded web page. The extension should work independently; installing the app should unlock additional capabilities.

The existing code is a small, understandable foundation. Protocol access, application state, persistence, and widgets are separate, and selectable text, bookmarks, history, and system light/dark themes already have implementations. It is currently a prototype rather than an installable, verified cross-platform release.

**Findings to fix before distributing the app**

Locations below refer to the source as reviewed.

| Priority | Finding and user impact | Evidence | Proposed change |
| --- | --- | --- | --- |
| Blocking | The menu references a getter that does not exist on `GopherItem`. The UI cannot compile as written. | `lib/widgets/menu_view.dart:68–69`; the getter at line 173 belongs to the widget, while the model exposes `item.type.isNavigable`. A standalone Dart compilation reproduced the missing getter. | Use the enum getter consistently, or expose a forwarding getter on the model. |
| Blocking | The socket stream and UTF-8 decoder have incompatible types under the installed Dart 3.8.1 SDK. | `lib/services/gopher_client.dart:36–39`; standalone compilation reported `Utf8Decoder` cannot be assigned to `StreamTransformer<Uint8List, dynamic>`. | Widen the socket stream to `Stream<List<int>>` before applying the decoder; verify against the selected release SDK. |
| Blocking | Platform runner projects are absent. The documented Android, iOS, desktop, and web build commands are not ready to use from this checkout. | The tracked files contain `lib/` and configuration, but no `android/`, `ios/`, `linux/`, `macos/`, `windows/`, or `web/`. | Generate and commit runners for the first supported platforms, configure network access and application identifiers, and verify real release builds. |
| High | Standard Gopher URLs request the wrong selector; generated URLs omit resource type. | `lib/models/gopher_item.dart:87–89,112–132`. Parsing `gopher://example.org/0/readme.txt` produces `0/readme.txt`, although the selector is `/readme.txt`. A text item generates `gopher://example.org:70//readme.txt` rather than `gopher://example.org:70/0/readme.txt`. | Model item type, selector, and search query explicitly; implement type-aware parsing and serialization with correct escaping. Preserve selectors as opaque data. |
| High | Back destroys forward history and appends a duplicate entry. | `lib/services/app_state.dart:145–160` calls `navigate()`, which truncates and appends at lines 58–65. With visits A → B → C, Back yields A → B → B. | Separate loading a location from recording a new visit. Move the history cursor only after a successful traversal, or restore it on failure. |
| High | Text documents do not enter the navigation stack, and reopening a text bookmark or history entry treats it as a menu. | `viewFile()` does not update `_navigationHistory`; `navigate()` always calls `fetchMenu()`. `GopherAddress` has no type field. | Route every visit through one loader that dispatches by resource type and records the complete location. |
| High | Search appears available but does not search. | `lib/widgets/menu_view.dart:164–169` displays a snackbar. `GopherClient.search()` exists but is unused by the UI. | Connect the query dialog to application state, load results, and retain the query for history and retry. |
| High | HTML items appear clickable but have no navigation behavior. | The enum includes HTML in `isNavigable`; `AppState.navigateToItem()` handles only directory, file, and search. | Implement explicit web-link handling, or label unsupported items clearly until it exists. |
| Medium | Concurrent navigations can finish out of order, replacing the newest page with an older response. | `navigate()` and `viewFile()` have no request ownership or cancellation. | Use request identifiers and cancel the previous socket when a new navigation begins; commit state only for the current request. |
| Medium | Response handling is incomplete. Text retains protocol framing; menu parsing skips a terminator instead of stopping; strict UTF-8 can reject older text; binary reads have no response timeout or size limit. | `lib/services/gopher_client.dart:20–137`. | Add type-specific framing, text dot unescaping, an explicit encoding policy, cancellation, deadlines, and bounded reads. Keep binary bytes separate from text decoding. |
| Medium | Several controls are unfinished or make browsing awkward. | Word wrap has an empty callback in `lib/widgets/text_view.dart:45–49`. Bookmark/history taps load a page without selecting Browse. | Finish wrap, switch to Browse after opening a saved page, and add retry and reload. |
| Medium | Stored data errors can interrupt startup, and persistence failures can be reported as navigation failures. | Storage JSON decoding is unguarded; `init()` is launched without an error handler; history writes share the navigation `try` block. | Handle storage failures independently, preserve recoverable data, and show a usable startup state. |

The URL behavior above was reproduced using the existing model directly. Encoded spaces and `%09` search separators also remain encoded in the selector. [RFC 4266](https://www.rfc-editor.org/rfc/rfc4266) defines the URL type field, default port, and encoded search separator. [RFC 1436](https://www.rfc-editor.org/rfc/rfc1436) defines the wire request and response framing. Use these as compatibility references rather than relying only on live servers.

**Make installation a product feature**

Ordinary users should download the app and open it; they should not install Flutter, clone a repository, or run dependency commands.

1. Pick an initial desktop platform and publish a complete package for it. Linux is a practical starting point for this workspace; verify the intended audience before choosing further targets. Produce a package containing Flutter's runtime assets and native libraries. Evaluate AppImage, a distribution package, or Flatpak against the supported systems; a loose executable is insufficient.
2. Add Windows and macOS packages after their release builds are verified. Bundle the complete Windows runner; use signing and macOS notarization for public distribution where applicable. Start Android with a release APK and move to store distribution when ready. Treat iOS as a separate signing and release effort.
3. Pin the Flutter toolchain used for releases, commit the application's dependency lockfile, and automate analysis, meaningful tests, builds, and packaged artifacts. The README's Flutter 3.0 minimum should be reconciled with its Dart 3 requirement and the SDK actually tested.
4. Give the README separate instructions for downloading a release and developing from source. Replace the placeholder GitHub clone URL. State platform support only after validation.
5. Register `gopher://` links with the operating system. A link from a browser should open the correct menu, text document, or search in the app. Provide an ordinary copy/paste fallback.

The current web claim needs correction: the implementation imports `dart:io` and uses `Socket.connect()`. Flutter's [web FAQ](https://docs.flutter.dev/platform-integration/web/faq) documents the restriction on `dart:io` networking in browsers. A web client needs a separate HTTPS/WebSocket-to-Gopher gateway transport. Define a transport interface and keep direct TCP for native platforms. Treat a hosted gateway as an optional later service with its own operation and privacy requirements.

**Make everyday use match the reason for choosing Gopher**

Use one quiet layout everywhere: a small navigation bar, readable text, and predictable links. Offer a plain list with type labels such as `[Menu]`, `[Text]`, and `[Search]`, reduced decoration, consistent spacing, adjustable font size and line width, working wrap, and system/light/dark appearance. Preserve code and ASCII art with an unwrapped option. Keep headings and link labels available to screen readers.

Make the first screen useful immediately with named starting points and a short explanation of menus, documents, and search. Accept a bare hostname, trim pasted whitespace, and show understandable connection errors with Retry. Add keyboard navigation and familiar shortcuts for location, Back, Forward, reload, and find-in-page. Avoid guessing a selector's parent path: Gopher selectors are opaque, so Back and server root are reliable navigation concepts.

Store titles, resource types, search queries, and scroll positions in navigation entries. Add bookmark export/import and explicitly saved offline documents after the core navigation works. Choose bounded caching and an optional no-history mode. Further features should preserve a fast route from opening the app to reading text.

**The extension: one click to read a page as text and links**

An extension can extract a loaded page and present its content in a Gopher-like interface. Generating that representation does not itself change the page's network protocol: actual Gopher access also requires a TCP-speaking client or server. The legacy `chrome.sockets` documentation concerns [Chrome Apps](https://developer.chrome.com/docs/apps/app_network), not a portable modern WebExtension transport. Use a native companion for TCP access when required.

Proposed first-release flow:

1. The user installs the extension and clicks **Read as text** on an ordinary web page.
2. A content script clones the page DOM and extracts title, source URL, headings, paragraphs, lists, code, tables, image descriptions, and links. Conversion happens locally. Capture the rendered content already available in the browser, including accessible text on a signed-in page, without transferring browser cookies to another service.
3. Open an extension-owned reader tab containing the same navigation and reading controls for every source. Keep the original tab available. Render text and validated links into a fixed template; do not insert arbitrary source HTML or execute source scripts.
4. Offer **Article**, **Full page**, and **Links** views. Use [Mozilla Readability](https://github.com/mozilla/readability) for article extraction from the clone, then a structured DOM fallback for pages it cannot extract. Readability modifies its input, which is why cloning matters. Preserve paragraph boundaries, heading order, code whitespace, language, and reading direction. Resolve relative links against the source document's base URL and retain fragments.
5. Offer find, readable font controls, local bookmarks, and explicit text export. Start with a small shared document schema for text blocks and links, so both the extension and Flutter app can render equivalent content. Share conversion fixtures and behavior rather than attempting to put Flutter inside the content script.

For the initial Chromium manifest, use `activeTab` and `scripting`, with storage only for saved settings or bookmarks. Chrome documents [temporary page access after a user action](https://developer.chrome.com/docs/extensions/develop/concepts/activeTab). Adapt background configuration and test separately for Firefox.

Following a link to another origin revokes that temporary access. The initial extension should open the source page and let the user invoke conversion again. Seamless conversion across websites is a later optional mode requiring permissions for the relevant sites. Do not silently request access to every site just to make the first conversion work.

Define the coverage honestly: articles, documentation, blogs, and ordinary content pages are good candidates. Text extraction cannot preserve every interaction in dashboards, forms, maps, games, or video applications. Capture only loaded content; offer refresh extraction for dynamic pages. Privileged browser pages and some browser-controlled documents are restricted; see Mozilla's [content script restrictions](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Content_scripts). Show a helpful unsupported-page state rather than an empty reader.

Converting after a page loads removes distractions from the reader view, but the original page has already loaded its scripts and resources. Preventing that initial loading would be a different feature requiring a fetch/proxy strategy and separate compatibility work.

**Optional companion: actual Gopher conversion**

Once the standalone extension and native client work, add **Open in Gopher app**. The app installer can register a small native messaging host; the extension passes the extracted document through [browser native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging). This avoids asking users to configure a local HTTP service or install a separate interpreter. The host must implement the browser's message framing and restrict access to the intended extension IDs; a normal Flutter GUI process is not automatically a native messaging host.

The app can render the imported document directly. For compatibility with independent Gopher clients, optionally expose explicitly selected saved documents through a loopback Gopher server on an unprivileged port, for example `127.0.0.1:7070`. Give each document a stable opaque identifier. Serve its body as type `0` and a page menu containing title, source, document entry, and links as type `1`. A link to another converted document points to its menu or text selector. A web link that has not been converted remains an explicit external destination; changing `https://` to `gopher://` is not conversion.

The server should bind to loopback, start only when enabled, and expose only the documents selected for that purpose. Loopback Gopher provides no per-user access control against other local processes; private browsing snapshots should remain in the reader unless deliberately shared. Serialize menu fields and text framing correctly, including tabs/newlines, terminators, and leading periods. Send large native messages in bounded pieces if needed. Leave public publishing and a general web-fetching gateway for a later, separate design.

**Recommended order and acceptance checks**

| Step | Deliverable | Completion check |
| --- | --- | --- |
| 1 | Reliable native Gopher core | Compile successfully; validate URL round trips, typed documents, actual search, text framing, A → B → C → Back → Forward, text bookmarks, timeouts, and stale-response handling. Use a small local fixture server so tests do not depend on public-server availability. |
| 2 | Installable app on one platform | Install and launch on a clean supported machine without Flutter; verify a complete package, TCP network access, persisted settings, and operating-system Gopher links. |
| 3 | Standalone extension | Install the packaged extension; convert article, documentation, link-directory, and dynamic-page fixtures; preserve meaningful structure and links; handle restricted pages; confirm conversion requires no remote processing. |
| 4 | Companion integration | Verify host registration and removal, extension identity restrictions, imports, missing-host recovery, message size handling, and optional interoperability with another Gopher client. |
| 5 | More platforms and optional continuous reading | Validate each platform and browser separately; add permissions and services only for features that need them. |

Validation performed for this review: read all tracked Dart source and configuration; inspected repository contents; reproduced URL parsing/serialization with Dart 3.8.1; reproduced the missing getter and socket-decoder compile errors using standalone Dart entry points. A full Flutter analysis or build was not performed: the Flutter launcher failed while trying to update `bin/cache/engine.stamp` in the read-only SDK installation. The navigation, persistence, and remaining UI findings are source-level findings, not results from running the app. No public Gopher server connectivity or installer behavior was verified.
