import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/gopher_item.dart';

class GopherException implements Exception {
  final String message;
  GopherException(this.message);

  @override
  String toString() => 'GopherException: $message';
}

/// Owns a socket so navigation can cancel an obsolete request.
class GopherRequest {
  Socket? _socket;
  bool _cancelled = false;

  void attach(Socket socket) {
    if (_cancelled) {
      socket.destroy();
      throw GopherException('Request cancelled');
    }
    _socket = socket;
  }

  void cancel() {
    _cancelled = true;
    _socket?.destroy();
  }

  void check() {
    if (_cancelled) throw GopherException('Request cancelled');
  }
}

/// Direct TCP transport for native platforms.
class GopherClient {
  final Duration timeout;
  final int maxResponseBytes;

  GopherClient({
    this.timeout = const Duration(seconds: 30),
    this.maxResponseBytes = 8 * 1024 * 1024,
  });

  Future<List<int>> _read(
    GopherAddress address,
    GopherRequest request, {
    required bool framed,
  }) async {
    Socket? socket;
    final stopwatch = Stopwatch()..start();
    try {
      request.check();
      final host = address.host.replaceAll(RegExp(r'^\[|\]$'), '');
      socket = await Socket.connect(host, address.port, timeout: timeout);
      request.attach(socket);
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Connection timed out');
      }
      socket.write('${address.request}\r\n');
      final connection = socket;
      return await (() async {
        await connection.flush();
        final bytes = BytesBuilder(copy: false);
        var lineStart = true;
        var dot = false;
        var dotCr = false;
        await for (final chunk in connection) {
          request.check();
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw GopherException('Response exceeds the size limit');
          }
          if (framed) {
            // A standalone period may be split across TCP chunks.
            for (var i = 0; i < chunk.length; i++) {
              final byte = chunk[i];
              if ((dot || dotCr) && byte == 10) {
                bytes.add(chunk.sublist(0, i + 1));
                return bytes.takeBytes();
              }
              if (dot && byte == 13) {
                dot = false;
                dotCr = true;
              } else {
                dot = lineStart && byte == 46;
                dotCr = false;
              }
              lineStart = byte == 10;
            }
          }
          bytes.add(chunk);
        }
        request.check();
        return bytes.takeBytes();
      })().timeout(remaining);
    } on SocketException catch (e) {
      throw GopherException('Connection failed: ${e.message}');
    } on TimeoutException {
      throw GopherException('Connection timed out');
    } on GopherException {
      rethrow;
    } catch (e) {
      throw GopherException('Could not read the response: $e');
    } finally {
      socket?.destroy();
    }
  }

  Future<String> fetch(GopherAddress address, {GopherRequest? request}) async {
    final bytes = await _read(
      address,
      request ?? GopherRequest(),
      framed: true,
    );
    // UTF-8 first; Latin-1 preserves bytes in older Gopher documents.
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  Future<String> fetchText(
    GopherAddress address, {
    GopherRequest? request,
  }) async {
    final content = await fetch(address, request: request);
    final lines = content.split('\n');
    final result = <String>[];
    for (var line in lines) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line == '.') break;
      if (line.startsWith('..')) line = line.substring(1);
      result.add(line);
    }
    return result.join('\n');
  }

  Future<List<GopherItem>> fetchMenu(
    GopherAddress address, {
    GopherRequest? request,
  }) async => parseMenu(await fetch(address, request: request));

  List<GopherItem> parseMenu(String content) {
    final items = <GopherItem>[];
    for (var line in content.split('\n')) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line == '.') break;
      if (line.isEmpty) continue;
      try {
        final item = GopherItem.fromLine(line);
        if (item.isNavigable) item.address;
        items.add(item);
      } on FormatException {
        continue;
      } on ArgumentError {
        continue;
      }
    }
    return items;
  }

  Future<List<int>> fetchBinary(
    GopherAddress address, {
    GopherRequest? request,
  }) => _read(address, request ?? GopherRequest(), framed: false);

  Future<List<GopherItem>> search(
    GopherAddress address,
    String query, {
    GopherRequest? request,
  }) => fetchMenu(
    GopherAddress(
      host: address.host,
      port: address.port,
      selector: address.selector,
      type: GopherItemType.search,
      query: query,
    ),
    request: request,
  );
}
