import 'dart:io';
import '../companion/client.dart';

class NativeCompanion {
  static bool get supported => Platform.isLinux;
  static CompanionClient get client => CompanionClient(
    CompanionPaths.current(),
    '${File(Platform.resolvedExecutable).parent.path}/gopher_reader_companion',
  );

  static Future<void> resume() async {
    if (!supported) return;
    if (await File('${CompanionPaths.current().root}/enabled').exists()) {
      await client.request({'action': 'status'}, start: true);
    }
  }
}
