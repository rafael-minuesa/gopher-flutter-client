import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'client.dart';
import 'library.dart';
import 'protocol.dart';

class CompanionServer {
  final CompanionPaths paths;
  final PageLibrary library;
  ServerSocket? _gopher;
  ServerSocket? _control;
  RandomAccessFile? _lock;
  Future<void> _queue = Future.value();
  int _readers = 0;
  final Set<Socket> _connections = {};
  final Completer<void> done = Completer<void>();
  CompanionServer(this.paths) : library = PageLibrary(paths.root);

  Future<void> start() async {
    await privateDirectory(paths.root);
    await privateDirectory(File(paths.socket).parent.path);
    _lock = await File('${paths.root}/server.lock').open(mode: FileMode.append);
    await _lock!.lock(FileLock.exclusive);
    try {
      await library.load();
      _gopher = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        companionPort,
      );
      final stale = File(paths.socket);
      if (await stale.exists()) await stale.delete();
      _control = await ServerSocket.bind(
        InternetAddress(paths.socket, type: InternetAddressType.unix),
        0,
      );
      await File('${paths.root}/enabled').writeAsString('1', flush: true);
      _gopher!.listen(_readGopher);
      _control!.listen(_readControl);
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _readGopher(Socket socket) {
    if (_readers >= 16) {
      socket.destroy();
      return;
    }
    _readers++;
    _connections.add(socket);
    unawaited(() async {
      try {
        final bytes = <int>[];
        await for (final chunk in socket.timeout(const Duration(seconds: 5))) {
          final end = chunk.indexOf(10);
          bytes.addAll(end < 0 ? chunk : chunk.sublist(0, end));
          if (bytes.length > 4096) {
            throw const FormatException('Selector too long');
          }
          if (end < 0) continue;
          if (bytes.isNotEmpty && bytes.last == 13) bytes.removeLast();
          final selector = utf8.decode(bytes);
          if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(selector)) {
            throw const FormatException('Invalid selector');
          }
          socket.add(utf8.encode(library.response(selector)));
          await socket.flush();
          break;
        }
      } catch (_) {
        // Invalid selectors and disconnected clients do not affect the library.
      } finally {
        socket.destroy();
        _connections.remove(socket);
        _readers--;
      }
    }());
  }

  void _readControl(Socket socket) {
    if (_connections.length >= 32) {
      socket.destroy();
      return;
    }
    _connections.add(socket);
    unawaited(() async {
      final reader = FrameReader(socket);
      var stop = false;
      try {
        final message = await reader.next().timeout(const Duration(seconds: 8));
        final result = Completer<Map<String, dynamic>>();
        _queue = _queue.then((_) async {
          try {
            result.complete(await handle(message));
          } catch (error) {
            result.complete({'ok': false, 'error': error.toString()});
          }
        });
        final response = await result.future;
        stop = response['stopping'] == true;
        socket.add(encodeFrame(response));
        await socket.flush();
      } catch (_) {
        // Never log document bodies or untrusted input.
      } finally {
        await reader.close();
        socket.destroy();
        _connections.remove(socket);
        if (stop) await close();
      }
    }());
  }

  Future<Map<String, dynamic>> handle(Map<String, dynamic>? message) async {
    if (message?['protocolVersion'] != 1) {
      throw const FormatException('Unsupported companion protocol version');
    }
    switch (message!['action']) {
      case 'status':
        return {
          'ok': true,
          'url': library.rootUrl,
          'count': library.pages.length,
        };
      case 'list':
        return {
          'ok': true,
          'url': library.rootUrl,
          'pages': [
            ...library.pages.entries.toList().reversed.map(
              (entry) => {
                'id': entry.key,
                'title': entry.value['title'],
                'source': entry.value['url'],
                'capturedAt': entry.value['capturedAt'],
                'url': library.pageUrl(entry.key),
              },
            ),
            ...library.unreadable.map(
              (id) => {
                'id': id,
                'title': 'Unreadable saved copy',
                'source': '',
                'url': null,
              },
            ),
          ],
        };
      case 'import':
        final id = checkedString(message['id'], 36);
        await library.save(id, message['page']);
        return {
          'ok': true,
          'url': library.pageUrl(id),
          'title': library.pages[id]!['title'],
        };
      case 'remove':
        await library.remove(checkedString(message['id'], 36));
        return {'ok': true};
      case 'stop':
        final enabled = File('${paths.root}/enabled');
        if (await enabled.exists()) await enabled.delete();
        return {'ok': true, 'stopping': true};
      default:
        throw const FormatException('Unsupported companion action');
    }
  }

  Future<void> close() async {
    await _gopher?.close();
    await _control?.close();
    for (final socket in _connections.toList()) {
      socket.destroy();
    }
    if (_control != null && await File(paths.socket).exists()) {
      await File(paths.socket).delete();
    }
    await _lock?.close();
    _gopher = null;
    _control = null;
    _lock = null;
    if (!done.isCompleted) done.complete();
  }
}
