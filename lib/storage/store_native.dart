import 'dart:io';

import 'package:path_provider/path_provider.dart';

class VaultStore {
  Future<File> _file([String name = 'twinlock-device.vault']) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/$name');
  }

  Future<String?> read() async {
    return _read(await _file());
  }

  Future<String?> readLegacy() async => _read(await _file('twinlock.vault'));

  Future<String?> _read(File file) async {
    if (!await file.exists()) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw const FormatException('保险箱文件过大。');
    }
    return file.readAsString();
  }

  Future<void> write(String data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    await temp.rename(file.path);
  }
}
