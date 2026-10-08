# Changelog

## 1.0.1+2 — 2026-10-08

- Fix compile errors and parse standard Gopher URLs with resource types, escaped selectors, and search queries.
- Preserve menu, text, and search navigation through Back, Forward, bookmarks, history, Reload, and Retry.
- Implement search and word wrap; open HTTP/HTTPS menu links in the system browser.
- Bound responses, apply connection/response deadlines, cancel obsolete requests, and handle text framing and legacy encoding.
- Recover valid saved entries from damaged JSON while preserving the original data; keep reading available when persistence fails.
- Add native platform runners, network permissions, dependency locking, a pinned Flutter SDK, and Linux build checks.
- Package the complete Linux app with a user installer and Gopher link registration.
- Add 32 protocol, navigation, persistence, and UI regression tests, plus installation and architecture documentation.

Validated with Flutter 3.32.7: tests, analysis, formatting, Linux release build, and a temporary installation launched against a local Gopher server. Other native platforms and the CI workflow remain unverified. The browser extension is a proposed next phase.

## 1.0.0+1

- Initial Flutter client prototype.
