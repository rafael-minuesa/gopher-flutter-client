import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

const hostName = 'org.gopherclient.reader';
const chromiumId = 'hionbnafppomnooihjbamcfbojjoakcg';
const firefoxId = 'gopher-reader@rafael-minuesa.github.io';
const companionPort = 7070;
const maxMessageBytes = 4 * 1024 * 1024;

/// Native messaging uses a native-endian length, followed by UTF-8 JSON.
class FrameReader {
  final StreamIterator<List<int>> _input;
  List<int> _chunk = [];
  int _offset = 0;
  FrameReader(Stream<List<int>> input) : _input = StreamIterator(input);

  Future<Uint8List?> _read(int size, {bool eofAllowed = false}) async {
    final bytes = Uint8List(size);
    var count = 0;
    while (count < size) {
      if (_offset == _chunk.length) {
        if (!await _input.moveNext()) {
          if (count == 0 && eofAllowed) return null;
          throw const FormatException('Incomplete message');
        }
        _chunk = _input.current;
        _offset = 0;
      }
      final available = _chunk.length - _offset;
      final take = available < size - count ? available : size - count;
      bytes.setRange(count, count + take, _chunk, _offset);
      count += take;
      _offset += take;
    }
    return bytes;
  }

  Future<Map<String, dynamic>?> next() async {
    final header = await _read(4, eofAllowed: true);
    if (header == null) return null;
    final size = ByteData.sublistView(header).getUint32(0, Endian.host);
    if (size == 0 || size > maxMessageBytes) {
      throw const FormatException('Message exceeds the size limit');
    }
    final value = jsonDecode(utf8.decode((await _read(size))!));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return value;
  }

  Future<void> close() => _input.cancel();
}

List<int> encodeFrame(Map<String, dynamic> message) {
  final body = utf8.encode(jsonEncode(message));
  if (body.length > maxMessageBytes) {
    throw const FormatException('Message exceeds the size limit');
  }
  final header = ByteData(4)..setUint32(0, body.length, Endian.host);
  return [...header.buffer.asUint8List(), ...body];
}
