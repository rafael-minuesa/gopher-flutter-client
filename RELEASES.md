# Release Guide

This document explains how to create and publish releases for the Gopher Flutter Client.

## Automatic Releases via GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds releases for all platforms.

### Creating a Release

1. **Tag your commit:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions will automatically:**
   - Build Android APK
   - Build Windows executable
   - Build macOS app
   - Build Linux binary
   - Create a GitHub Release with all artifacts

3. **Access the release:**
   - Go to: `https://github.com/rafael-minuesa/gopher-flutter-client/releases`
   - The latest release will contain downloadable files for all platforms

### Manual Trigger

You can also manually trigger the build workflow:
1. Go to Actions tab on GitHub
2. Select "Build Releases" workflow
3. Click "Run workflow"

## Platform-Specific Builds

### Android

**Automated via GitHub Actions:**
- Builds release APK on every tag push
- Output: `app-release.apk`

**Manual build:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Installation:**
- Users download the APK
- Enable "Install from Unknown Sources" on Android
- Tap the APK to install

**Publishing to Google Play:**
1. Build App Bundle:
   ```bash
   flutter build appbundle --release
   ```
2. Create a Google Play Console account ($25 one-time fee)
3. Upload the AAB file from `build/app/outputs/bundle/release/`
4. Fill in app details and screenshots
5. Submit for review

### Windows

**Automated via GitHub Actions:**
- Builds on Windows runner
- Output: `gopher-flutter-client-windows-x64.zip`

**Manual build:**
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

**Distribution:**
- Users extract the ZIP and run the .exe file
- No installation required (portable app)

**Microsoft Store (Optional):**
- Requires Windows Developer account ($19/year)
- Package with MSIX
- Submit via Partner Center

### macOS

**Automated via GitHub Actions:**
- Builds on macOS runner
- Output: `gopher-flutter-client-macos.zip`

**Manual build:**
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/gopher_flutter_client.app
```

**Distribution:**
- Users extract the ZIP and drag the .app to Applications
- May need to allow the app in System Preferences > Security

**App Store (Optional):**
- Requires Apple Developer account ($99/year)
- Code signing required
- Submit via App Store Connect

### Linux

**Automated via GitHub Actions:**
- Builds on Ubuntu runner
- Output: `gopher-flutter-client-linux-x64.tar.gz`

**Manual build:**
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

**Distribution:**
- Users extract the tarball and run the executable
- May need to install GTK dependencies:
  ```bash
  sudo apt-get install libgtk-3-0
  ```

**Package Managers (Optional):**
- **Snap Store:** Create a snapcraft.yaml
- **Flathub:** Create a Flatpak manifest
- **AppImage:** Package as AppImage for universal compatibility

### iOS

**Requirements:**
- macOS with Xcode
- Apple Developer account ($99/year)

**Manual build:**
```bash
flutter build ios --release
```

**Distribution:**
1. **TestFlight** (Beta testing):
   - Open Xcode
   - Archive the app
   - Upload to App Store Connect
   - Invite testers

2. **App Store:**
   - Build and archive in Xcode
   - Submit via App Store Connect
   - Fill in app details and screenshots
   - Wait for Apple review (typically 1-3 days)

**Note:** iOS builds are not included in the automated workflow because they require macOS, Xcode, and Apple Developer credentials.

## Version Management

### Updating Version Number

Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # version+buildNumber
```

- First number (1.0.1): Version name shown to users
- Second number (+2): Build number (must increase with each release)

### Versioning Strategy

Follow [Semantic Versioning](https://semver.org/):
- **Major (1.0.0)**: Breaking changes
- **Minor (1.1.0)**: New features, backwards compatible
- **Patch (1.0.1)**: Bug fixes, backwards compatible

## Release Checklist

Before creating a release:

- [ ] Update version in `pubspec.yaml`
- [ ] Update CHANGELOG.md with release notes
- [ ] Test on at least one platform
- [ ] Commit all changes
- [ ] Create and push git tag
- [ ] Wait for GitHub Actions to complete
- [ ] Verify all artifacts in the release
- [ ] Test downloaded artifacts
- [ ] Update README.md if needed

## Download Statistics

You can view download statistics for your releases:
- Go to Insights → Traffic → Releases
- Or use GitHub API: `https://api.github.com/repos/rafael-minuesa/gopher-flutter-client/releases`

## Troubleshooting

### Build Failures

**Android:**
- Check Java version (requires JDK 17)
- Verify gradle wrapper is correct
- Clear gradle cache: `./gradlew clean`

**Windows:**
- Ensure Visual Studio 2022 is installed
- Check Windows SDK is available

**macOS:**
- Verify Xcode Command Line Tools: `xcode-select --install`
- Check code signing settings

**Linux:**
- Install dependencies: GTK, pkg-config, ninja-build
- Verify DISPLAY environment variable

### Release Upload Failures

- Check GitHub token permissions
- Verify tag follows semantic versioning
- Ensure artifacts are generated correctly
- Check workflow logs in Actions tab

## Support

For issues with releases:
1. Check the [GitHub Actions logs](https://github.com/rafael-minuesa/gopher-flutter-client/actions)
2. Review Flutter documentation
3. Open an issue on GitHub
