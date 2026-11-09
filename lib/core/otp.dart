import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum OtpAlgorithm { sha1, sha256, sha512 }

class OtpConfig {
  final String secret;
  final String issuer;
  final String account;
  final OtpAlgorithm algorithm;
  final int digits;
  final int period;
  final bool isHotp;
  final int counter;

  OtpConfig({
    required String secret,
    this.issuer = '',
    this.account = '',
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.isHotp = false,
    this.counter = 0,
  }) : secret = normalizeSecret(secret) {
    if (decodeBase32(this.secret).length < 10) {
      throw const FormatException('密钥至少需要 16 个 Base32 字符。');
    }
    if (digits != 6 && digits != 7 && digits != 8) {
      throw const FormatException('验证码位数须为 6、7 或 8。');
    }
    if (period < 1 || period > 300) {
      throw const FormatException('周期须为 1–300 秒。');
    }
    if (counter < 0 || counter > 9007199254740991) {
      throw const FormatException('计数器须为 0–9007199254740991。');
    }
  }

  factory OtpConfig.parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'otpauth' ||
        !['totp', 'hotp'].contains(uri.host.toLowerCase())) {
      if (raw.startsWith('otpauth-migration:')) {
        throw const FormatException('暂不支持 Google 批量迁移二维码，请逐个导出标准 otpauth 二维码。');
      }
      throw const FormatException('请扫描认证器的 otpauth 二维码。');
    }
    final query = uri.queryParameters;
    for (final key in [
      'secret',
      'algorithm',
      'digits',
      'period',
      'counter',
      'issuer',
    ]) {
      if ((uri.queryParametersAll[key]?.length ?? 0) > 1) {
        throw FormatException('二维码包含重复的 $key 参数。');
      }
    }
    final label = uri.pathSegments.join('/');
    final colon = label.indexOf(':');
    final labelIssuer = colon < 0 ? '' : label.substring(0, colon).trim();
    final issuer = (query['issuer'] ?? labelIssuer).trim();
    if (labelIssuer.isNotEmpty && issuer.isNotEmpty && issuer != labelIssuer) {
      throw const FormatException('二维码中的服务名称不一致，请核对来源。');
    }
    final account = (colon < 0 ? label : label.substring(colon + 1)).trim();
    final algorithmName = (query['algorithm'] ?? 'SHA1').toUpperCase();
    final algorithm = switch (algorithmName) {
      'SHA1' => OtpAlgorithm.sha1,
      'SHA256' => OtpAlgorithm.sha256,
      'SHA512' => OtpAlgorithm.sha512,
      _ => throw const FormatException('仅支持 SHA1、SHA256 和 SHA512。'),
    };
    int integer(String key, int fallback) {
      if (!query.containsKey(key)) return fallback;
      return int.tryParse(query[key]!) ??
          (throw FormatException('$key 必须是整数。'));
    }

    final isHotp = uri.host.toLowerCase() == 'hotp';
    if (isHotp && !query.containsKey('counter')) {
      throw const FormatException('HOTP 二维码缺少 counter 参数。');
    }
    return OtpConfig(
      secret: query['secret'] ?? '',
      issuer: issuer,
      account: account,
      algorithm: algorithm,
      digits: integer('digits', 6),
      period: integer('period', 30),
      isHotp: isHotp,
      counter: integer('counter', 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'secret': secret,
        'issuer': issuer,
        'account': account,
        'algorithm': algorithm.name,
        'digits': digits,
        'period': period,
        'isHotp': isHotp,
        'counter': counter,
      };

  factory OtpConfig.fromJson(Map<String, dynamic> json) => OtpConfig(
        secret: json['secret'] as String,
        issuer: json['issuer'] as String? ?? '',
        account: json['account'] as String? ?? '',
        algorithm: OtpAlgorithm.values.byName(
          json['algorithm'] as String? ?? 'sha1',
        ),
        digits: json['digits'] as int? ?? 6,
        period: json['period'] as int? ?? 30,
        isHotp: json['isHotp'] as bool? ?? false,
        counter: json['counter'] as int? ?? 0,
      );

  OtpConfig nextCounter() =>
      OtpConfig.fromJson({...toJson(), 'counter': counter + 1});

  String codeAt(DateTime time) => hotp(
        secret,
        isHotp
            ? counter
            : time.toUtc().millisecondsSinceEpoch ~/ (period * 1000),
        algorithm: algorithm,
        digits: digits,
      );

  int secondsLeft(DateTime time) =>
      period - (time.millisecondsSinceEpoch ~/ 1000 % period);
}

String normalizeSecret(String secret) =>
    secret.replaceAll(RegExp(r'\s'), '').toUpperCase();

Uint8List decodeBase32(String input) {
  final value = normalizeSecret(input);
  if (!RegExp(r'^[A-Z2-7]+={0,6}$').hasMatch(value)) {
    throw const FormatException('密钥只能包含 Base32 字符 A–Z 和 2–7。');
  }
  final unpadded = value.replaceAll('=', '');
  final remainder = unpadded.length % 8;
  if (![0, 2, 4, 5, 7].contains(remainder)) {
    throw const FormatException('Base32 密钥长度无效。');
  }
  if (value.contains('=') &&
      (value.length % 8 != 0 ||
          value.length - unpadded.length != (8 - remainder) % 8)) {
    throw const FormatException('Base32 补位无效。');
  }
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final bytes = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final rune in unpadded.runes) {
    buffer = (buffer << 5) | alphabet.indexOf(String.fromCharCode(rune));
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 255);
      buffer &= (1 << bits) - 1;
    }
  }
  if (buffer != 0) throw const FormatException('Base32 密钥的末尾补位无效。');
  return Uint8List.fromList(bytes);
}

String encodeBase32(List<int> bytes) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final output = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      output.write(alphabet[(buffer >> bits) & 31]);
      buffer &= (1 << bits) - 1;
    }
  }
  if (bits > 0) output.write(alphabet[(buffer << (5 - bits)) & 31]);
  return output.toString();
}

String hotp(
  String secret,
  int counter, {
  OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  int digits = 6,
}) {
  if (counter < 0 || counter > 9007199254740991 || digits < 6 || digits > 8) {
    throw const FormatException('无效的 OTP 参数。');
  }
  // ByteData.setUint64 is unavailable in dart2js. Division also avoids JS's
  // 32-bit shift truncation when the HOTP counter exceeds 2^32.
  final message = Uint8List(8);
  var remaining = counter;
  for (var i = 7; i >= 0; i--) {
    message[i] = remaining % 256;
    remaining ~/= 256;
  }
  final hash = switch (algorithm) {
    OtpAlgorithm.sha1 => sha1,
    OtpAlgorithm.sha256 => sha256,
    OtpAlgorithm.sha512 => sha512,
  };
  final digest = Hmac(
    hash,
    decodeBase32(secret),
  ).convert(message).bytes;
  final offset = digest.last & 15;
  final binary = ((digest[offset] & 127) << 24) |
      (digest[offset + 1] << 16) |
      (digest[offset + 2] << 8) |
      digest[offset + 3];
  final modulus = switch (digits) {
    6 => 1000000,
    7 => 10000000,
    _ => 100000000,
  };
  return (binary % modulus).toString().padLeft(digits, '0');
}

String formatCode(String code) =>
    '${code.substring(0, code.length ~/ 2)} ${code.substring(code.length ~/ 2)}';
