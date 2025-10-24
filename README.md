# Gopher Flutter Client

A modern, cross-platform Gopher protocol client built with Flutter.

## Features

- **Full Gopher Protocol Support**: Browse Gopher servers with support for directories, text files, search servers, and more
- **Modern UI**: Clean, Material Design 3 interface with dark mode support
- **Navigation**: Back/forward buttons, history tracking, and bookmarks
- **Cross-Platform**: Runs on Android, iOS, Web, Windows, macOS, and Linux
- **Bookmarks**: Save your favorite Gopher sites
- **History**: Keep track of recently visited pages
- **Search Support**: Search-enabled Gopher servers

## What is Gopher?

Gopher is a protocol for distributing, searching, and retrieving documents over the Internet. It was designed at the University of Minnesota in 1991 and preceded the World Wide Web. While largely superseded by HTTP, Gopher servers still exist and offer a unique, text-focused browsing experience.

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/gopher-flutter-client.git
cd gopher-flutter-client
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

1. Enter a Gopher URL in the address bar (e.g., `gopher://gopher.floodgap.com`)
2. Click "Go" or press Enter
3. Navigate through directories by clicking on items
4. Use the back/forward buttons to navigate
5. Bookmark your favorite sites
6. View your browsing history

## Example Gopher Servers

Try these popular Gopher servers:

- `gopher://gopher.floodgap.com` - Floodgap Systems
- `gopher://gopher.quux.org` - Quux.org
- `gopher://gopherpedia.com` - Gopherpedia (Wikipedia mirror)
- `gopher://gopher.club` - Gopher Club

## Architecture

The app is structured as follows:

```
lib/
├── models/          # Data models (GopherItem, GopherAddress)
├── services/        # Business logic (GopherClient, StorageService, AppState)
├── screens/         # Full-page screens
├── widgets/         # Reusable UI components
└── main.dart        # App entry point
```

### Key Components

- **GopherClient**: Handles TCP socket connections and Gopher protocol communication
- **AppState**: State management using Provider pattern
- **StorageService**: Persistent storage for bookmarks and history using SharedPreferences
- **GopherItem**: Parses and represents Gopher menu items

## Gopher Protocol Support

The client supports the following Gopher item types:

| Type | Code | Description | Supported |
|------|------|-------------|-----------|
| Text File | 0 | Plain text document | ✅ |
| Directory | 1 | Menu/submenu | ✅ |
| Search | 7 | Search server | ✅ |
| Binary | 9 | Binary file | ⚠️ Display only |
| GIF | g | GIF image | ⚠️ Display only |
| Image | I | Image file | ⚠️ Display only |
| HTML | h | HTML document | ⚠️ Display only |
| Info | i | Informational text | ✅ |
| Error | 3 | Error message | ✅ |

## Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Desktop (Windows/macOS/Linux)
```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The Gopher protocol specification (RFC 1436)
- The Flutter team for the excellent framework
- The Gopher community for keeping the protocol alive

## Resources

- [Gopher Protocol (RFC 1436)](https://tools.ietf.org/html/rfc1436)
- [Gopher Wikipedia](https://en.wikipedia.org/wiki/Gopher_(protocol))
- [Flutter Documentation](https://flutter.dev/docs)
