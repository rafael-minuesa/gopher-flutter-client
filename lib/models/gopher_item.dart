/// Represents a Gopher menu item type
enum GopherItemType {
  file('0'),              // Text file
  directory('1'),         // Directory/menu
  ccso('2'),             // CCSO nameserver
  error('3'),            // Error
  binhex('4'),           // BinHex file
  dos('5'),              // DOS binary archive
  uuencoded('6'),        // UUencoded file
  search('7'),           // Index-Search server
  telnet('8'),           // Telnet session
  binary('9'),           // Binary file
  redundant('+'),        // Redundant server
  tn3270('T'),           // TN3270 session
  gif('g'),              // GIF image
  image('I'),            // Image file
  info('i'),             // Informational message
  html('h'),             // HTML file
  unknown('?');          // Unknown type

  final String code;
  const GopherItemType(this.code);

  static GopherItemType fromCode(String code) {
    for (var type in GopherItemType.values) {
      if (type.code == code) return type;
    }
    return GopherItemType.unknown;
  }

  bool get isNavigable =>
      this == GopherItemType.directory ||
      this == GopherItemType.file ||
      this == GopherItemType.search ||
      this == GopherItemType.html;

  bool get isDownloadable =>
      this == GopherItemType.binary ||
      this == GopherItemType.gif ||
      this == GopherItemType.image ||
      this == GopherItemType.binhex ||
      this == GopherItemType.dos;
}

/// Represents a Gopher menu item
class GopherItem {
  final GopherItemType type;
  final String displayText;
  final String selector;
  final String host;
  final int port;

  GopherItem({
    required this.type,
    required this.displayText,
    required this.selector,
    required this.host,
    required this.port,
  });

  /// Parse a Gopher menu line
  /// Format: <type><display text><TAB><selector><TAB><host><TAB><port>
  factory GopherItem.fromLine(String line) {
    if (line.isEmpty) {
      return GopherItem(
        type: GopherItemType.info,
        displayText: '',
        selector: '',
        host: '',
        port: 70,
      );
    }

    final type = GopherItemType.fromCode(line[0]);
    final parts = line.substring(1).split('\t');

    return GopherItem(
      type: type,
      displayText: parts.isNotEmpty ? parts[0] : '',
      selector: parts.length > 1 ? parts[1] : '',
      host: parts.length > 2 ? parts[2] : '',
      port: parts.length > 3 ? int.tryParse(parts[3]) ?? 70 : 70,
    );
  }

  /// Convert to a Gopher URL
  String toUrl() {
    if (host.isEmpty) return '';
    return 'gopher://$host:$port/$selector';
  }

  @override
  String toString() {
    return 'GopherItem(type: $type, text: $displayText, host: $host:$port, selector: $selector)';
  }
}

/// Represents a Gopher address
class GopherAddress {
  final String host;
  final int port;
  final String selector;

  GopherAddress({
    required this.host,
    this.port = 70,
    this.selector = '',
  });

  /// Parse a Gopher URL
  /// Format: gopher://host:port/selector
  factory GopherAddress.fromUrl(String url) {
    final uri = Uri.parse(url);

    if (uri.scheme != 'gopher') {
      throw ArgumentError('Invalid Gopher URL: must start with gopher://');
    }

    String selector = uri.path;
    if (selector.startsWith('/')) {
      selector = selector.substring(1);
    }

    return GopherAddress(
      host: uri.host,
      port: uri.port != 0 ? uri.port : 70,
      selector: selector,
    );
  }

  String toUrl() {
    return 'gopher://$host:$port/$selector';
  }

  @override
  String toString() => toUrl();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GopherAddress &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          selector == other.selector;

  @override
  int get hashCode => host.hashCode ^ port.hashCode ^ selector.hashCode;
}
