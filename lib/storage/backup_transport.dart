import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

import '../core/vault_codec.dart';

Future<String?> pickBackup() async {
  final selection = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );
  if (selection == null) return null;
  final file = selection.files.single;
  if (file.size > VaultCodec.maxBytes || file.bytes == null) {
    throw const FormatException('请选择不超过 10 MB 的双钥加密备份。');
  }
  return utf8.decode(file.bytes!);
}

Future<void> shareBackup(String data, Rect origin) async {
  final now = DateTime.now();
  final name =
      'Twinlock-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.twinlock';
  await Share.shareXFiles(
    [
      XFile.fromData(
        utf8.encode(data),
        mimeType: 'application/octet-stream',
        name: name,
      ),
    ],
    fileNameOverrides: [name],
    subject: '双钥加密备份',
    sharePositionOrigin: origin,
  );
}
