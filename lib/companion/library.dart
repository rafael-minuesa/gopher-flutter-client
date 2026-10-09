import 'dart:convert';
import 'dart:io';
import '../models/gopher_item.dart';
import 'protocol.dart';

final pageIdPattern = RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
);

String cleanField(String value) =>
    value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');

String checkedString(dynamic value, int limit) {
  if (value is! String || value.length > limit || value.contains('\u0000')) {
    throw const FormatException('Invalid or oversized document field');
  }
  return value;
}

String checkedUrl(dynamic value) {
  final text = checkedString(value, 4096);
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !['http', 'https', 'gopher'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      RegExp(r'[\x00-\x20\x7f]').hasMatch(text)) {
    throw const FormatException('Unsupported document URL');
  }
  if (uri.scheme == 'gopher') GopherAddress.fromUrl(text);
  return text;
}

/// The wire format intentionally contains plain text rather than executable HTML.
Map<String, dynamic> checkedPage(dynamic value) {
  if (value is! Map) throw const FormatException('Missing document');
  final links = value['links'];
  if (links is! List || links.length > 2000) {
    throw const FormatException('Invalid document links');
  }
  final ids = <int>{};
  return {
    'url': checkedUrl(value['url']),
    'title': checkedString(value['title'], 2000),
    'capturedAt': checkedString(value['capturedAt'] ?? '', 100),
    'article': checkedString(value['article'], 600000),
    'page': checkedString(value['page'], 600000),
    'links': links.map((link) {
      if (link is! Map ||
          link['id'] is! int ||
          link['id'] < 1 ||
          link['id'] > 2000 ||
          !ids.add(link['id'])) {
        throw const FormatException('Invalid document link number');
      }
      return {
        'id': link['id'],
        'url': checkedUrl(link['url']),
        'label': checkedString(link['label'], 2000),
      };
    }).toList(),
  };
}

String sourceKey(String url) => Uri.parse(url).replace(fragment: '').toString();

class PageLibrary {
  final Directory directory;
  final Map<String, Map<String, dynamic>> pages = {};
  final List<String> unreadable = [];
  PageLibrary(String root) : directory = Directory('$root/pages');
  static const maxPages = 100;
  static const maxBytes = 64 * 1024 * 1024;

  Future<void> load() async {
    await directory.create(recursive: true);
    pages.clear();
    unreadable.clear();
    var bytes = 0;
    await for (final file in directory.list()) {
      final name = file.uri.pathSegments.last;
      if (file is! File || !name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - 5);
      if (!pageIdPattern.hasMatch(id)) continue;
      try {
        final size = await file.length();
        if (size > maxMessageBytes ||
            bytes + size > maxBytes ||
            pages.length >= maxPages) {
          throw const FormatException('Library size limit');
        }
        final page = checkedPage(jsonDecode(await file.readAsString()));
        pages[id] = page;
        bytes += size;
      } catch (_) {
        // Keep damaged files available for recovery; never silently overwrite them.
        unreadable.add(id);
      }
    }
  }

  Future<void> save(String id, dynamic value) async {
    if (!pageIdPattern.hasMatch(id)) {
      throw const FormatException('Invalid page ID');
    }
    if (unreadable.contains(id)) {
      throw const FormatException(
        'This saved copy is damaged. Remove it before saving again.',
      );
    }
    final page = checkedPage(value);
    if (!pages.containsKey(id) &&
        pages.length + unreadable.length >= maxPages) {
      throw const FormatException(
        'The library contains 100 pages. Remove a page and try again.',
      );
    }
    final body = jsonEncode(page);
    final size = utf8.encode(body).length;
    var total = size;
    await for (final file in directory.list()) {
      if (file is File &&
          file.path.endsWith('.json') &&
          file.path != '${directory.path}/$id.json') {
        total += await file.length();
      }
    }
    if (size > maxMessageBytes || total > maxBytes) {
      throw const FormatException(
        'The saved-page library is full. Remove a page and try again.',
      );
    }
    final temp = File('${directory.path}/$id.tmp');
    await temp.writeAsString(body, flush: true);
    await temp.rename('${directory.path}/$id.json');
    pages.remove(id);
    pages[id] = page;
  }

  Future<void> remove(String id) async {
    if (!pageIdPattern.hasMatch(id)) {
      throw const FormatException('Invalid page ID');
    }
    final file = File('${directory.path}/$id.json');
    if (await file.exists()) await file.delete();
    pages.remove(id);
    unreadable.remove(id);
  }

  String pageUrl(String id) => 'gopher://127.0.0.1:$companionPort/1/page/$id';
  String get rootUrl => 'gopher://127.0.0.1:$companionPort/1/';

  String _line(
    String type,
    String title,
    String selector, {
    String host = '127.0.0.1',
    int port = companionPort,
  }) => '$type${cleanField(title)}\t${cleanField(selector)}\t$host\t$port';
  String _info(String text) => _line('i', text, '');
  String _menu(List<String> lines) => '${lines.join('\r\n')}\r\n.\r\n';
  String _text(String value) =>
      '${value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n').map((line) => line.startsWith('.') ? '.$line' : line).join('\r\n')}\r\n.\r\n';

  String response(String selector) {
    if (selector.isEmpty || selector == '/') {
      return _menu([
        _info('Saved web pages'),
        _info('Local copies explicitly sent from Gopher Reader'),
        if (unreadable.isNotEmpty)
          _info(
            '${unreadable.length} unreadable copies: use the app library to remove them.',
          ),
        if (pages.isEmpty)
          _info('No pages saved yet. Use Open in Gopher app in the extension.'),
        ...pages.entries.toList().reversed.map(
          (entry) =>
              _line('1', entry.value['title'] as String, '/page/${entry.key}'),
        ),
      ]);
    }
    final parts = selector.split('/');
    if (parts.length >= 3 &&
        parts[0].isEmpty &&
        pageIdPattern.hasMatch(parts[2])) {
      final id = parts[2], page = pages[id];
      if (page != null) {
        if (parts.length == 4 &&
            parts[1] == 'text' &&
            ['article', 'page'].contains(parts[3])) {
          return _text(page[parts[3]] as String);
        }
        if (parts.length == 3 && parts[1] == 'page') {
          final converted = <String, String>{};
          for (final entry in pages.entries) {
            converted[sourceKey(entry.value['url'] as String)] = entry.key;
          }
          return _menu([
            _info(page['title'] as String),
            _info('Captured: ${page['capturedAt']}'),
            _line('0', 'Read article', '/text/$id/article'),
            _line('0', 'Read full page', '/text/$id/page'),
            _line('1', 'Saved web pages', '/'),
            _line('h', 'Original page (browser)', 'URL:${page['url']}'),
            _info('Links'),
            ...(page['links'] as List).map((dynamic link) {
              final url = link['url'] as String;
              final label = '[${link['id']}] ${link['label']}';
              final local = converted[sourceKey(url)];
              if (local != null) return _line('1', label, '/page/$local');
              if (Uri.parse(url).scheme == 'gopher') {
                final address = GopherAddress.fromUrl(url);
                return _line(
                  address.type.code,
                  label,
                  address.selector,
                  host: address.host,
                  port: address.port,
                );
              }
              return _line('h', '$label (browser)', 'URL:$url');
            }),
          ]);
        }
      }
    }
    return _menu([
      _line('3', 'This saved page is unavailable.', ''),
      _line('1', 'Saved web pages', '/'),
    ]);
  }
}
