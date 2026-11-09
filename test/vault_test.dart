import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twinlock/core/otp.dart';
import 'package:twinlock/core/record.dart';
import 'package:twinlock/core/vault_codec.dart';

void main() {
  final codec = VaultCodec();
  final records = [
    VaultRecord(
      kind: RecordKind.password,
      title: '测试密码',
      username: 'alice@example.com',
      password: 'secret-password-123!',
    ),
    VaultRecord(
      kind: RecordKind.otp,
      title: '测试认证',
      otp: OtpConfig(secret: 'JBSWY3DPEHPK3PXP'),
    ),
  ];
  test(
    'AES-GCM round trip keeps records encrypted with unique nonces',
    () async {
      final salt = codec.newSalt();
      final key = SecretKey(List.generate(32, (i) => i));
      final first = await codec.encrypt(records, key, salt);
      final second = await codec.encrypt(records, key, salt);
      expect(first, isNot(contains('secret-password')));
      expect(first, isNot(contains('JBSWY3')));
      expect(jsonDecode(first)['nonce'], isNot(jsonDecode(second)['nonce']));
      final decoded = await codec.decrypt(first, key);
      expect(
        decoded.map((r) => r.toJson()).toList(),
        records.map((r) => r.toJson()).toList(),
      );
      await expectLater(
        codec.decrypt(first, SecretKey(List.filled(32, 99))),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test('encrypted backup restores with password; tampering fails', () async {
    final text = await codec.backup(records, 'correct horse battery staple');
    final restored = await codec.restore(text, 'correct horse battery staple');
    expect(restored.length, 2);
    expect(restored.first.password, records.first.password);
    await expectLater(
      codec.restore(text, 'wrong password'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    final tampered = jsonDecode(text) as Map<String, dynamic>;
    final bytes = base64Decode(tampered['ciphertext'] as String);
    bytes[0] ^= 1;
    tampered['ciphertext'] = base64Encode(bytes);
    await expectLater(
      codec.restore(jsonEncode(tampered), 'correct horse battery staple'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    tampered['iterations'] = 999999999;
    expect(() => codec.envelope(jsonEncode(tampered)), throwsFormatException);
  });
  test('restore merge preserves unrelated records and latest edits', () {
    final old = VaultRecord(
      id: 'same',
      kind: RecordKind.password,
      title: '旧',
      password: 'old',
      updatedAt: DateTime(2020),
    );
    final newer = VaultRecord(
      id: 'same',
      kind: RecordKind.password,
      title: '新',
      password: 'new',
      updatedAt: DateTime(2021),
    );
    final other = VaultRecord(
      kind: RecordKind.password,
      title: 'other',
      password: 'other',
    );
    final merged = mergeRecords([newer, other], [old]);
    expect(merged.length, 2);
    expect(merged.first.password, 'new');
    expect(mergeRecords([old], [newer]).single.password, 'new');
  });
  test(
    'strong password generator uses secure random with all character classes',
    () {
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        final password = generatePassword();
        expect(password.length, 20);
        expect(password, matches(RegExp('[A-Z]')));
        expect(password, matches(RegExp('[a-z]')));
        expect(password, matches(RegExp('[2-9]')));
        expect(password, matches(RegExp(r'[^A-Za-z0-9]')));
        seen.add(password);
      }
      expect(seen.length, 100);
    },
  );
}
