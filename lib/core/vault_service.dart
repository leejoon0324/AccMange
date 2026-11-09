import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../storage/store.dart';
import 'record.dart';
import 'vault_codec.dart';

class VaultService extends ChangeNotifier {
  final VaultStore store;
  VaultService({VaultStore? store}) : store = store ?? VaultStore();
  final codec = VaultCodec();
  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  final _auth = LocalAuthentication();
  SecretKey? _key;
  List<int>? _salt;
  List<VaultRecord> _records = [];
  Future<void> _queue = Future.value();
  int _epoch = 0;
  bool initialized = false;
  bool exists = false;
  bool biometricEnabled = false;
  bool biometricAvailable = false;
  String? bootError;
  int externalDepth = 0;
  int _failures = 0;
  DateTime? _cooldown;
  bool get unlocked => _key != null;
  List<VaultRecord> get records => List.unmodifiable(_records);

  Future<void> boot() async {
    bootError = null;
    try {
      exists = await store.read() != null;
      if (!kIsWeb) {
        biometricEnabled = await _secure.containsKey(key: 'biometric-key');
        biometricAvailable =
            await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
      }
    } catch (_) {
      bootError = '无法读取本机保险箱，请检查设备存储后重新打开应用。';
    }
    initialized = true;
    notifyListeners();
  }

  Future<T> external<T>(Future<T> Function() operation) async {
    externalDepth++;
    try {
      return await operation();
    } finally {
      externalDepth--;
    }
  }

  Future<void> create(String password) async {
    if (exists) throw StateError('保险箱已存在。');
    final epoch = _epoch;
    VaultCodec.validatePassword(password);
    final salt = codec.newSalt();
    final key = await codec.deriveKey(password, salt);
    await store.write(await codec.encrypt([], key, salt));
    // iOS Keychain can survive reinstall; never reuse an old biometric key.
    if (!kIsWeb) await _secure.delete(key: 'biometric-key');
    biometricEnabled = false;
    exists = true;
    if (epoch != _epoch) {
      notifyListeners();
      throw const FormatException('保险箱已创建，请返回应用后重新解锁。');
    }
    _key = key;
    _salt = salt;
    _records = [];
    notifyListeners();
  }

  Future<void> unlock(String password) async {
    final epoch = _epoch;
    if (_cooldown != null && DateTime.now().isBefore(_cooldown!)) {
      throw const FormatException('尝试次数过多，请 30 秒后重试。');
    }
    await _queue;
    final text = await store.read();
    if (text == null) throw const FormatException('本机保险箱文件不存在。');
    final salt = codec.saltOf(text);
    final key = await codec.deriveKey(password, salt);
    try {
      final records = await codec.decrypt(text, key);
      if (epoch != _epoch) throw const FormatException('解锁已取消，请重新输入主密码。');
      _key = key;
      _salt = salt;
      _records = records;
      _failures = 0;
      _cooldown = null;
      notifyListeners();
    } on SecretBoxAuthenticationError {
      _failures++;
      if (_failures >= 5) {
        _cooldown = DateTime.now().add(const Duration(seconds: 30));
        _failures = 0;
      }
      throw const FormatException('主密码错误，或保险箱文件已损坏。');
    }
  }

  Future<void> unlockBiometric() async {
    if (kIsWeb || !biometricEnabled) return;
    final epoch = _epoch;
    final authenticated = await _auth.authenticate(
      localizedReason: '解锁双钥保险箱',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!authenticated) return;
    await _queue;
    final encoded = await _secure.read(key: 'biometric-key');
    final text = await store.read();
    if (encoded == null || text == null) {
      throw const FormatException('请使用主密码解锁。');
    }
    try {
      final key = SecretKey(base64Decode(encoded));
      final records = await codec.decrypt(text, key);
      if (epoch != _epoch) throw const FormatException('解锁已取消，请重新验证。');
      _key = key;
      _salt = codec.saltOf(text);
      _records = records;
      notifyListeners();
    } on SecretBoxAuthenticationError {
      await _secure.delete(key: 'biometric-key');
      biometricEnabled = false;
      throw const FormatException('生物识别密钥已失效，请使用主密码。');
    }
  }

  Future<void> setBiometric(bool enabled) async {
    if (!unlocked || kIsWeb) throw const FormatException('请先解锁本机保险箱。');
    if (enabled) {
      final key = _key!;
      final epoch = _epoch;
      if (!await _auth.authenticate(
        localizedReason: '开启保险箱生物识别解锁',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      )) {
        return;
      }
      if (epoch != _epoch) throw const FormatException('保险箱已锁定，请重新解锁后开启。');
      await _secure.write(
        key: 'biometric-key',
        value: base64Encode(await key.extractBytes()),
      );
    } else {
      await _secure.delete(key: 'biometric-key');
    }
    biometricEnabled = enabled;
    notifyListeners();
  }

  void lock() {
    _epoch++;
    _key = null;
    _salt = null;
    _records = [];
    notifyListeners();
  }

  Future<void> _mutate(
    List<VaultRecord> Function(List<VaultRecord>) transform,
  ) {
    final operation = _queue.then((_) async {
      if (!unlocked) throw const FormatException('保险箱已锁定，请重新解锁。');
      final key = _key!;
      final salt = _salt!;
      final epoch = _epoch;
      final next = transform(_records);
      await store.write(await codec.encrypt(next, key, salt));
      if (epoch == _epoch) {
        _records = next;
        notifyListeners();
      }
    });
    _queue = operation.then((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> save(VaultRecord record) => _mutate(
        (records) => [...records.where((r) => r.id != record.id), record],
      );
  Future<void> remove(String id) =>
      _mutate((records) => records.where((r) => r.id != id).toList());
  Future<void> toggleFavorite(String id) => _mutate(
        (records) => records
            .map((r) => r.id == id ? r.copyWith(favorite: !r.favorite) : r)
            .toList(),
      );
  Future<void> advanceCounter(String id) => _mutate(
        (records) => records
            .map(
              (r) => r.id == id && r.otp?.isHotp == true
                  ? r.copyWith(otp: r.otp!.nextCounter())
                  : r,
            )
            .toList(),
      );
  Future<String> exportBackup(String password) async {
    if (!unlocked) throw const FormatException('请先解锁。');
    await _queue;
    return codec.backup(records, password);
  }

  Future<int> importBackup(String text, String password) async {
    final incoming = await codec.restore(text, password);
    await _mutate((records) => mergeRecords(records, incoming));
    return incoming.length;
  }
}
