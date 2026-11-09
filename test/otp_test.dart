import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:twinlock/core/otp.dart';

void main() {
  test(
      'HOTP counters beyond 32 bits match independently generated HMAC vectors',
      () {
    final secret = encodeBase32(utf8.encode('12345678901234567890'));
    expect(hotp(secret, 4294967296), '999456');
    expect(hotp(secret, 9007199254740991), '891307');
    expect(() => hotp(secret, 9007199254740992), throwsFormatException);
  });
  test('RFC 4226 HOTP published vectors', () {
    const expected = [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ];
    final secret = encodeBase32(utf8.encode('12345678901234567890'));
    for (var i = 0; i < expected.length; i++) {
      expect(hotp(secret, i), expected[i]);
    }
  });
  test('RFC 6238 TOTP SHA1 / SHA256 / SHA512 published vectors', () {
    const times = [
      59,
      1111111109,
      1111111111,
      1234567890,
      2000000000,
      20000000000,
    ];
    const expected = [
      ['94287082', '07081804', '14050471', '89005924', '69279037', '65353130'],
      ['46119246', '68084774', '67062674', '91819424', '90698825', '77737706'],
      ['90693936', '25091201', '99943326', '93441116', '38618901', '47863826'],
    ];
    const secrets = [
      '12345678901234567890',
      '12345678901234567890123456789012',
      '1234567890123456789012345678901234567890123456789012345678901234',
    ];
    for (var algorithm = 0; algorithm < 3; algorithm++) {
      final config = OtpConfig(
        secret: encodeBase32(utf8.encode(secrets[algorithm])),
        algorithm: OtpAlgorithm.values[algorithm],
        digits: 8,
      );
      for (var i = 0; i < times.length; i++) {
        expect(
          config.codeAt(
            DateTime.fromMillisecondsSinceEpoch(times[i] * 1000, isUtc: true),
          ),
          expected[algorithm][i],
        );
      }
    }
  });
  test('otpauth handles encoded labels, issuer, algorithm and period', () {
    final config = OtpConfig.parse(
      'otpauth://totp/My%20Service:alice%40example.com?'
      'secret=JBSWY3DPEHPK3PXP&issuer=My%20Service&algorithm=SHA256&digits=8&period=60',
    );
    expect(config.issuer, 'My Service');
    expect(config.account, 'alice@example.com');
    expect(config.algorithm, OtpAlgorithm.sha256);
    expect(config.digits, 8);
    expect(config.period, 60);
    expect(config.secondsLeft(DateTime.fromMillisecondsSinceEpoch(60000)), 60);
    expect(config.secondsLeft(DateTime.fromMillisecondsSinceEpoch(119000)), 1);
    expect(OtpConfig.fromJson(config.toJson()).toJson(), config.toJson());
  });
  test('HOTP preserves counter and only advances explicitly', () {
    final config = OtpConfig.parse(
      'otpauth://hotp/Example:alice?secret=JBSWY3DPEHPK3PXP&counter=7',
    );
    expect(config.isHotp, true);
    expect(config.counter, 7);
    expect(config.nextCounter().counter, 8);
    expect(config.codeAt(DateTime(2020)), config.codeAt(DateTime(2030)));
  });
  test('invalid / unsupported QR parameters are rejected', () {
    for (final uri in [
      'https://example.com',
      'otpauth-migration://offline?data=123',
      'otpauth://totp/Example?secret=12345678',
      'otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP&period=0',
      'otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP&digits=9',
      'otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP&algorithm=MD5',
      'otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP&period=abc',
      'otpauth://hotp/Example?secret=JBSWY3DPEHPK3PXP',
      'otpauth://hotp/Example?secret=JBSWY3DPEHPK3PXP&counter=-1',
      'otpauth://totp/A:alice?secret=JBSWY3DPEHPK3PXP&issuer=B',
      'otpauth://totp/A?secret=JBSWY3DPEHPK3PXP&secret=JBSWY3DPEHPK3PXP',
    ]) {
      expect(() => OtpConfig.parse(uri), throwsFormatException, reason: uri);
    }
  });
  test('Base32 encoding, normalization and padding', () {
    for (final plain in ['f', 'fo', 'foo', 'foob', 'fooba', 'foobar']) {
      final encoded = encodeBase32(utf8.encode(plain));
      expect(utf8.decode(decodeBase32(encoded)), plain);
      final padded = encoded.padRight(((encoded.length + 7) ~/ 8) * 8, '=');
      expect(utf8.decode(decodeBase32(padded.toLowerCase())), plain);
    }
    expect(() => decodeBase32('MZ'), throwsFormatException);
    expect(() => decodeBase32('ABC'), throwsFormatException);
    expect(() => decodeBase32('MY='), throwsFormatException);
  });
}
