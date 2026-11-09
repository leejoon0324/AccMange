import 'dart:math';

import 'otp.dart';

enum RecordKind { otp, password }

class VaultRecord {
  final String id;
  final RecordKind kind;
  final String title;
  final String username;
  final String password;
  final String website;
  final String note;
  final String group;
  final bool favorite;
  final DateTime updatedAt;
  final OtpConfig? otp;

  VaultRecord({
    String? id,
    required this.kind,
    required this.title,
    this.username = '',
    this.password = '',
    this.website = '',
    this.note = '',
    this.group = '',
    this.favorite = false,
    DateTime? updatedAt,
    this.otp,
  })  : id = id ?? randomId(),
        updatedAt = updatedAt ?? DateTime.now().toUtc() {
    if (title.trim().isEmpty || (kind == RecordKind.otp && otp == null)) {
      throw const FormatException('账号名称或密钥无效。');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'username': username,
        'password': password,
        'website': website,
        'note': note,
        'group': group,
        'favorite': favorite,
        'updatedAt': updatedAt.toIso8601String(),
        'otp': otp?.toJson(),
      };

  factory VaultRecord.fromJson(Map<String, dynamic> json) => VaultRecord(
        id: json['id'] as String,
        kind: RecordKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        website: json['website'] as String? ?? '',
        note: json['note'] as String? ?? '',
        group: json['group'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        otp: json['otp'] == null
            ? null
            : OtpConfig.fromJson(Map<String, dynamic>.from(json['otp'] as Map)),
      );

  VaultRecord copyWith({bool? favorite, OtpConfig? otp}) =>
      VaultRecord.fromJson({
        ...toJson(),
        'favorite': favorite ?? this.favorite,
        'otp': (otp ?? this.otp)?.toJson(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
}

String randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String generatePassword({int length = 20}) {
  if (length < 12 || length > 128) throw ArgumentError('密码长度须为 12–128。');
  const groups = [
    'ABCDEFGHJKLMNPQRSTUVWXYZ',
    'abcdefghijkmnopqrstuvwxyz',
    '23456789',
    '!@#\$%&*-_+=?',
  ];
  final random = Random.secure();
  final chars = groups.map((g) => g[random.nextInt(g.length)]).toList();
  final alphabet = groups.join();
  while (chars.length < length) {
    chars.add(alphabet[random.nextInt(alphabet.length)]);
  }
  for (var i = chars.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = chars[i];
    chars[i] = chars[j];
    chars[j] = temp;
  }
  return chars.join();
}
