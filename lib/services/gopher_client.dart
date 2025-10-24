import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/gopher_item.dart';

/// Exception thrown when Gopher operations fail
class GopherException implements Exception {
  final String message;
  GopherException(this.message);

  @override
  String toString() => 'GopherException: $message';
}

/// Gopher protocol client
class GopherClient {
  static const Duration _timeout = Duration(seconds: 30);

  /// Fetch content from a Gopher server
  Future<String> fetch(GopherAddress address) async {
    Socket? socket;

    try {
      // Connect to the Gopher server
      socket = await Socket.connect(
        address.host,
        address.port,
        timeout: _timeout,
      );

      // Send the selector followed by CRLF
      socket.write('${address.selector}\r\n');
      await socket.flush();

      // Read the response
      final response = await socket
          .timeout(_timeout)
          .transform(utf8.decoder)
          .join();

      return response;
    } on SocketException catch (e) {
      throw GopherException('Connection failed: ${e.message}');
    } on TimeoutException {
      throw GopherException('Connection timed out');
    } catch (e) {
      throw GopherException('Error fetching content: $e');
    } finally {
      socket?.close();
    }
  }

  /// Fetch and parse a Gopher menu
  Future<List<GopherItem>> fetchMenu(GopherAddress address) async {
    final content = await fetch(address);
    return parseMenu(content);
  }

  /// Parse Gopher menu content into items
  List<GopherItem> parseMenu(String content) {
    final lines = content.split('\n');
    final items = <GopherItem>[];

    for (var line in lines) {
      // Remove carriage return if present
      line = line.replaceAll('\r', '');

      // Skip empty lines and terminator
      if (line.isEmpty || line == '.') continue;

      try {
        final item = GopherItem.fromLine(line);
        items.add(item);
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    return items;
  }

  /// Download binary content
  Future<List<int>> fetchBinary(GopherAddress address) async {
    Socket? socket;

    try {
      socket = await Socket.connect(
        address.host,
        address.port,
        timeout: _timeout,
      );

      socket.write('${address.selector}\r\n');
      await socket.flush();

      final chunks = <int>[];
      await for (var chunk in socket) {
        chunks.addAll(chunk);
      }

      return chunks;
    } on SocketException catch (e) {
      throw GopherException('Connection failed: ${e.message}');
    } on TimeoutException {
      throw GopherException('Connection timed out');
    } catch (e) {
      throw GopherException('Error downloading file: $e');
    } finally {
      socket?.close();
    }
  }

  /// Search on a Gopher search server
  Future<List<GopherItem>> search(
    GopherAddress address,
    String query,
  ) async {
    final searchAddress = GopherAddress(
      host: address.host,
      port: address.port,
      selector: '${address.selector}\t$query',
    );

    return fetchMenu(searchAddress);
  }
}
