import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_flutter_client/models/gopher_item.dart';
import 'package:gopher_flutter_client/services/gopher_client.dart';

void main() {
  late ServerSocket server;
  late StreamSubscription<Socket> connections;
  final sockets = <Socket>[];
  late GopherAddress address;

  Future<void> serve(Future<void> Function(Socket, String) respond) async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    address = GopherAddress(
      host: '127.0.0.1',
      port: server.port,
      selector: '/hello',
      type: GopherItemType.file,
    );
    connections = server.listen((socket) {
      sockets.add(socket);
      socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .then((request) => respond(socket, request));
    });
    addTearDown(() async {
      for (final socket in sockets) {
        socket.destroy();
      }
      sockets.clear();
      await connections.cancel();
      await server.close();
    });
  }

  test(
    'menu parsing stops at terminator and ignores malformed destinations',
    () {
      final rows = GopherClient().parseMenu(
        'iWelcome\r\n1Docs\t/docs\texample.org\t70\r\n'
        '1Missing fields\r\n1Bad port\t/\texample.org\t0\r\n'
        '.\r\n0After terminator\t/late\texample.org\t70\r\n',
      );
      expect(rows.map((row) => row.displayText), ['Welcome', 'Docs']);
    },
  );

  test(
    'text sends only selector, unstuffs periods and stops before socket close',
    () async {
      await serve((socket, request) async {
        expect(request, '/hello');
        for (final byte in utf8.encode('Hello\r\n..leading period\r\n.\r\n')) {
          socket.add([byte]);
          await socket.flush();
        }
        // Deliberately leave open; a framed response should finish immediately.
      });
      final text = await GopherClient(
        timeout: const Duration(seconds: 2),
      ).fetchText(address);
      expect(text, 'Hello\n.leading period');
    },
  );

  test('search sends a tab-delimited query', () async {
    await serve((socket, request) async {
      expect(request, '/hello\ttwo words');
      socket.write('0Result\t/readme\texample.org\t70\r\n.\r\n');
      await socket.flush();
    });
    final rows = await GopherClient().search(address, 'two words');
    expect(rows.single.displayText, 'Result');
  });

  test('legacy text decoding preserves non-UTF8 bytes', () async {
    await serve((socket, request) async {
      socket.add([0x63, 0x61, 0x66, 0xe9, 13, 10, 46, 13, 10]);
      await socket.flush();
    });
    expect(await GopherClient().fetchText(address), 'café');
  });

  test('binary content preserves dot sequences', () async {
    final bytes = [0, 255, 13, 10, 46, 13, 10, 1];
    await serve((socket, request) async {
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    });
    expect(await GopherClient().fetchBinary(address), bytes);
  });

  test('binary reads have an absolute response deadline', () async {
    await serve((socket, request) async {});
    final client = GopherClient(timeout: const Duration(milliseconds: 200));
    await expectLater(
      client.fetchBinary(address),
      throwsA(
        isA<GopherException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });

  test('oversized responses fail without unbounded buffering', () async {
    await serve((socket, request) async {
      socket.write('A response too large\r\n.\r\n');
      await socket.flush();
    });
    await expectLater(
      GopherClient(maxResponseBytes: 8).fetchText(address),
      throwsA(
        isA<GopherException>().having(
          (e) => e.message,
          'message',
          contains('size limit'),
        ),
      ),
    );
  });

  test('cancellation closes an in-flight connection', () async {
    final started = Completer<void>();
    await serve((socket, request) async {
      started.complete();
    });
    final request = GopherRequest();
    final response = GopherClient().fetchBinary(address, request: request);
    final assertion = expectLater(response, throwsA(isA<GopherException>()));
    await started.future;
    request.cancel();
    await assertion;
  });
}
