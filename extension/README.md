# Gopher Reader browser extension

Version **1.1.0**. A standalone, one-click reader for Chromium browsers and Firefox desktop. It converts the page already loaded in your browser into a consistent text-and-links interface. Conversion happens locally; it does not require the Flutter app, an account, or a server. Installing the Linux app enables **Open in Gopher app** and actual local Gopher delivery.

## Install the Chromium package

1. Extract `gopher-reader-1.1.0-chromium.zip` into a folder you will keep.
2. Open `chrome://extensions` (or `edge://extensions` in Edge).
3. Enable **Developer mode**, choose **Load unpacked**, and select that folder.
4. Pin **Gopher Reader** to the toolbar, open a normal web page, and click its icon.

The ZIP root contains `manifest.json`; select that root folder rather than its parent. This development installation requires Chromium 112 or newer. Chrome and Edge packaging share the Chromium manifest; the automated browser test uses Playwright's bundled Chromium.

## Try the Firefox package

1. Extract `gopher-reader-1.1.0-firefox.zip`.
2. Open `about:debugging#/runtime/this-firefox`.
3. Choose **Load Temporary Add-on** and select the extracted `manifest.json`.
4. Pin **Gopher Reader** to the toolbar and click it on a web page.

Requires Firefox desktop 142 or newer. Temporary installation lasts until Firefox restarts. Normal permanent installation requires Mozilla signing; this first package is unsigned and has not been submitted to an extension store.

## Read a page

Click the toolbar icon, or press **Alt+Shift+G**, to open a reading copy in a new tab. The original page remains available. Browser shortcut assignments can be changed in the browser's extension settings if another extension uses the same keys.

- **Article** extracts the main writing. When no article is detected, it uses the page's readable text.
- **Full page** keeps readable navigation, sidebars, and other page text.
- **Links** lists unique web and Gopher destinations with stable numbers.
- **Find** searches the displayed text. `/` opens Find, Enter moves to the next match, Shift+Enter moves back, and Escape closes it. The browser's normal Ctrl+F/Cmd+F also works.
- **A− / A+**, **Wrap**, and **System / Light / Dark** control the reading layout and persist locally.
- **Save page** bookmarks its title and source URL. Saved pages open their original sites; click the extension there to convert again.
- **Export text** downloads the current view as a UTF-8 `.txt` file, including numbered link references.
- **Refresh text** recaptures the open source tab, including newly loaded text. If that tab has closed or moved to another page, invoke the extension on the new source instead.
- **Open in Gopher app** saves article/full-page text and numbered links in the installed Linux app's local library, then opens its Gopher menu. Repeating it for the same reading copy updates that saved snapshot; a newly converted reading tab creates another snapshot. This is separate from the extension's source-URL bookmarks.

Links open the original destination in another tab. Same-page fragments scroll inside the reader when the target was retained. A new website needs another user invocation to convert it. Continuous conversion across sites would require additional site permissions and is outside this first version.

## Data and permissions

The extension requests `activeTab`, `scripting`, `storage`, and `nativeMessaging`. Native messaging contacts only the installed Gopher companion when you choose Open in Gopher app. It has no blanket host permissions, browsing-history permission, cookies permission, analytics, remote scripts, or content-processing service. Capture runs in the isolated content-script world after you invoke the extension. It does not run source HTML in the reader or fetch source images.

Reading copies live in `storage.session`, survive background-worker restarts, and are removed when their reading tabs close or the browser session ends. Stored settings and explicitly saved bookmarks use `storage.local`; they contain settings, titles, URLs, and bookmark timestamps, not page bodies. Bookmarks are capped at 200; open reading copies have a shared conservative 8 MB budget.

Conversion captures loaded, readable DOM content. Scripts, hidden content, editable regions, and form values are excluded. The original page may already have loaded its own scripts or tracking resources before conversion. Browser-controlled pages, protected domains, PDFs, canvas-only applications, embedded frames, and content inside inaccessible shadow roots are not general-purpose conversion targets. Large pages are bounded and disclose shortening rather than creating unlimited snapshots.

The standalone reader provides a Gopher-style interface. **Open in Gopher app** additionally transfers an explicitly selected snapshot to the native companion, which serves it over actual TCP Gopher at `127.0.0.1:7070`. Use the native app's **Saved web pages** toolbar button to reopen/remove copies or stop serving. Copies remain on disk after the browser closes, unlike the extension's session snapshots. Other local processes can access the local Gopher library; nothing is published remotely.

Install the complete Linux app package and run its `install.sh` before using the handoff. Missing installations produce a readable error and leave the browser reader available. The Chromium package now has a stable unpacked ID: if upgrading from 1.0.0, remove the old installation and load the new package. Settings/bookmarks from the old path-derived Chromium ID are not migrated automatically. Firefox's ID remains unchanged. Browser integration is currently Linux-only, and Snap/Flatpak browsers can require additional native messaging portal setup. Signed extension store distribution remains future work.

## Build and validate

Use a supported Node.js release (22.22.2+, 24.15.0+, or 26+), npm, and `zip` for packaging:

```bash
cd extension
npm ci --ignore-scripts
npm run build
npm test
npm run lint
npm run package
```

`dist/chromium` and `dist/firefox` contain loadable extensions. `artifacts/` contains ZIP packages, SHA-256 checksums, and browser-test screenshots. Only source and dependency locks are committed. Mozilla Readability 0.6.0 is copied from the locked npm dependency into each package with its Apache 2.0 license; all extension scripts are bundled locally.

Actual-browser checks use Linux, Xvfb, and xdotool to send the real activation shortcut. They exercise the production manifests and temporary page permission rather than adding test host permissions:

```bash
npx playwright install chromium
xvfb-run -a npm run test:browser
GECKODRIVER=/absolute/path/to/geckodriver FIREFOX_BIN=/absolute/path/to/firefox \
  xvfb-run -a npm run test:firefox
```

Firefox automation uses geckodriver 0.37.1 and its explicit `--allow-system-access` flag to inspect extension pages in a fresh test profile. This affects the test driver only. The GitHub workflow downloads the driver from Mozilla's release repository.

To include complete Linux installation and native handoff checks, build `../dev-tools/package-linux.sh`, then set `GOPHER_NATIVE_PACKAGE` to its absolute archive path and run each browser test under `dbus-run-session -- xvfb-run -a`. Tests install into temporary XDG paths (including spaces and percent signs), exercise native messaging/TCP, and verify that a second handoff navigates the existing app window. Firefox's isolated test directory-service override affects only its disposable test process; HOME and real browser registrations remain untouched.

The Mozilla linter reports zero errors and two warnings in the unmodified Readability dependency. Both concern the library's internal `innerHTML` rewrites on an inactive cloned document. Forms/scripts are removed before extraction, and the extension's renderer uses DOM creation and text nodes rather than inserting extracted HTML. The warnings are retained for review; they are not suppressed.

Validated locally on 2026-10-09: 18 extraction/background regression cases, Chromium 148.0.7778.96 with Playwright 1.60.0, and Firefox 157.0.1 with geckodriver 0.37.1. Actual browser tests cover user activation, safe rendering, views, find, bookmarks, reload/refresh, source navigation, complete Linux installation, native messaging, TCP delivery, and existing-window app navigation. Chromium additionally covers worker restart, export, settings, session cleanup, and a narrow viewport. Dependency audits report zero vulnerabilities. Chrome/Edge retail builds, other operating systems, signing, store submission, and sandboxed browser portals remain unvalidated.

## Architecture

```text
src/core.js          Versioned text-block schema, URL validation and plain-text export
src/extract.js       DOM sanitization, article/full-page extraction and numbered links
src/background.js    User invocation, session snapshots, bookmarks and API message boundaries
src/reader.*         Fixed, accessible reader template and controls
scripts/build.mjs    Browser manifests, bundled dependency, generated icons and ZIP packaging
test/                Extraction and state regressions; actual Chromium/Firefox flows
```

The native app is `1.1.0+3`; the extension has its own version, `1.1.0`, in `package.json`, and packaging derives both manifests from it. The companion's handoff protocol is independently versioned as `1`.

References: [Chrome activeTab](https://developer.chrome.com/docs/extensions/develop/concepts/activeTab), [Firefox temporary installation](https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/), [session storage](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/API/storage/session), [Mozilla Readability](https://github.com/mozilla/readability), and [Playwright extension testing](https://playwright.dev/docs/chrome-extensions).
