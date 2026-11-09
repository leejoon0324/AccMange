import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'record.dart';

class VaultCodec {
  static const iterations = 210000;
  static const maxBytes = 10 * 1024 * 1024;
  final AesGcm cipher = AesGcm.with256bits();

  List<int> newSalt() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256));
  }

  Future<SecretKey> deriveKey(String password, List<int> salt) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Map<String, dynamic> envelope(String text) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('备份超过 10 MB。');
    }
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> ||
        json['format'] != 'twinlock' ||
        json['version'] != 1 ||
        json['iterations'] != iterations) {
      throw const FormatException('文件不是支持的双钥加密备份。');
    }
    final salt = base64Decode(json['salt'] as String);
    final nonce = base64Decode(json['nonce'] as String);
    final mac = base64Decode(json['mac'] as String);
    if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('备份文件参数无效。');
    }
    return json;
  }

  List<int> saltOf(String text) =>
      base64Decode(envelope(text)['salt'] as String);

  List<int> aad(List<int> salt) =>
      utf8.encode('twinlock:1:$iterations:${base64Encode(salt)}');

  Future<String> encrypt(
    List<VaultRecord> records,
    SecretKey key,
    List<int> salt,
  ) async {
    final payload = utf8.encode(
      jsonEncode({
        'version': 1,
        'records': records.map((r) => r.toJson()).toList(),
      }),
    );
    if (payload.length > maxBytes ~/ 2) {
      throw const FormatException('保险箱容量超过安全限制。');
    }
    final box = await cipher.encrypt(payload, secretKey: key, aad: aad(salt));
    return jsonEncode({
      'format': 'twinlock',
      'version': 1,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<List<VaultRecord>> decrypt(String text, SecretKey key) async {
    final json = envelope(text);
    final box = SecretBox(
      base64Decode(json['ciphertext'] as String),
      nonce: base64Decode(json['nonce'] as String),
      mac: Mac(base64Decode(json['mac'] as String)),
    );
    final bytes = await cipher.decrypt(
      box,
      secretKey: key,
      aad: aad(base64Decode(json['salt'] as String)),
    );
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (payload['version'] != 1 || payload['records'] is! List) {
      throw const FormatException('保险箱数据版本不受支持。');
    }
    final records = (payload['records'] as List)
        .map((r) => VaultRecord.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    if (records.map((r) => r.id).toSet().length != records.length) {
      throw const FormatException('备份中存在重复的记录编号。');
    }
    return records;
  }

  Future<String> backup(List<VaultRecord> records, String password) async {
    validatePassword(password);
    final salt = newSalt();
    return encrypt(records, await deriveKey(password, salt), salt);
  }

  Future<List<VaultRecord>> restore(String text, String password) async =>
      decrypt(text, await deriveKey(password, saltOf(text)));

  static void validatePassword(String password) {
    if (password.length < 8 || password.length > 256) {
      throw const FormatException('主密码须为 8–256 个字符，建议使用较长的密码短语。');
    }
  }
}

List<VaultRecord> mergeRecords(
  List<VaultRecord> current,
  List<VaultRecord> incoming,
) {
  final merged = {for (final record in current) record.id: record};
  for (final record in incoming) {
    final old = merged[record.id];
    if (old == null || record.updatedAt.isAfter(old.updatedAt)) {
      merged[record.id] = record;
    }
  }
  return merged.values.toList();
}
