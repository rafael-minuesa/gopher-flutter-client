# Changelog

## Gopher Reader extension 1.0.0 — 2026-10-08

- Add one-click local HTML conversion for Chromium and Firefox desktop, with Article, Full page, and numbered Links views.
- Preserve headings, lists, code, tables, language/direction, and image descriptions; exclude scripts, hidden content, editable regions, and form values.
- Add find, font size, wrapping, appearance, local bookmarks, UTF-8 text export, and explicit source-tab refresh.
- Keep reading bodies in bounded session storage, preserve them across worker restarts, and remove them when reader tabs close. Persist only settings and explicit bookmark metadata.
- Package separate browser manifests with bundled Mozilla Readability, generated icons, checksums, instructions, and browser CI checks.
- Verify actual shortcut activation and reader controls in Chromium and Firefox, plus extraction and background-state regression cases.

The extension has a separate version; the native app remains at `1.0.1+2`. Store publication, signing, continuous conversion across sites, and the native companion are later phases.

## 1.0.1+2 — 2026-10-08

- Fix compile errors and parse standard Gopher URLs with resource types, escaped selectors, and search queries.
- Preserve menu, text, and search navigation through Back, Forward, bookmarks, history, Reload, and Retry.
- Implement search and word wrap; open HTTP/HTTPS menu links in the system browser.
- Bound responses, apply connection/response deadlines, cancel obsolete requests, and handle text framing and legacy encoding.
- Recover valid saved entries from damaged JSON while preserving the original data; keep reading available when persistence fails.
- Add native platform runners, network permissions, dependency locking, a pinned Flutter SDK, and Linux build checks.
- Preserve the upstream web download page and deployment workflows; update their Flutter SDK, web bootstrap, and release package paths.
- Package the complete Linux app with a user installer and Gopher link registration.
- Add 32 protocol, navigation, persistence, and UI regression tests, plus installation and architecture documentation.

Validated with Flutter 3.32.7: tests, analysis, formatting, Linux release build, a temporary installation launched against a local Gopher server, and a local browser check of the web download page. Other native platforms and the CI workflow remain unverified. The browser extension is a proposed next phase.

## 1.0.0+1

- Initial Flutter client prototype.
