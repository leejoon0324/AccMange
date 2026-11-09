import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../storage/key_store.dart';
import '../storage/store.dart';
import 'record.dart';
import 'vault_codec.dart';

class VaultService extends ChangeNotifier {
  final VaultStore store;
  final VaultKeyStore keyStore;
  VaultService({VaultStore? store, VaultKeyStore? keyStore})
      : store = store ?? VaultStore(),
        keyStore = keyStore ?? VaultKeyStore();

  final codec = VaultCodec();
  SecretKey? _key;
  List<int>? _salt;
  List<VaultRecord> _records = [];
  Future<void> _queue = Future.value();
  Future<void>? _booting;
  bool _disposed = false;
  bool initialized = false;
  bool legacyAvailable = false;
  String? bootError;
  bool get ready => _key != null;
  List<VaultRecord> get records => List.unmodifiable(_records);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> boot() =>
      _booting ??= _open().whenComplete(() => _booting = null);

  Future<void> _open() async {
    if (ready) return;
    initialized = false;
    bootError = null;
    _changed();
    try {
      final text = await store.read();
      late SecretKey key;
      late List<int> salt;
      late List<VaultRecord> records;
      if (text == null) {
        key = await codec.cipher.newSecretKey();
        salt = codec.newSalt();
        records = [];
        // Persist the key first so a failed key write cannot strand a vault.
        await keyStore.write(base64Encode(await key.extractBytes()));
        await store.write(await codec.encrypt(records, key, salt));
      } else {
        final encodedKey = await keyStore.read();
        if (encodedKey == null) {
          throw const FormatException('设备加密密钥不可用，原有数据已保留。');
        }
        final bytes = base64Decode(encodedKey);
        if (bytes.length != 32) throw const FormatException('设备加密密钥格式错误。');
        key = SecretKey(bytes);
        salt = codec.saltOf(text);
        records = await codec.decrypt(text, key);
      }
      if (_disposed) return;
      _key = key;
      _salt = salt;
      _records = records;
      // Keep the password-protected legacy file intact and import it only
      // when requested from the home screen, without blocking startup.
      try {
        legacyAvailable = await store.readLegacy() != null;
      } catch (_) {
        legacyAvailable = false;
      }
    } catch (_) {
      bootError = '无法读取本机加密数据或设备密钥，原有数据已保留。请解锁手机后重试。';
    } finally {
      initialized = true;
      _changed();
    }
  }

  Future<void> _mutate(
    List<VaultRecord> Function(List<VaultRecord>) transform,
  ) {
    final operation = _queue.then((_) async {
      if (!ready || _disposed) throw const FormatException('本机数据尚未就绪，请重试。');
      final next = transform(_records);
      await store.write(await codec.encrypt(next, _key!, _salt!));
      if (!_disposed) {
        _records = next;
        _changed();
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
            .map((r) => r.id == id && r.otp?.isHotp == true
                ? r.copyWith(otp: r.otp!.nextCounter())
                : r)
            .toList(),
      );

  Future<String> exportBackup(String password) async {
    await _queue;
    if (!ready || _disposed) throw const FormatException('本机数据尚未就绪。');
    return codec.backup(records, password);
  }

  Future<int> importBackup(String text, String password) async {
    final incoming = await codec.restore(text, password);
    await _mutate((records) => mergeRecords(records, incoming));
    return incoming.length;
  }

  Future<int> importLegacy(String password) async {
    final text = await store.readLegacy();
    if (text == null) throw const FormatException('未找到旧版保险箱。');
    final count = await importBackup(text, password);
    legacyAvailable = false;
    _changed();
    return count;
  }

  @override
  void dispose() {
    _disposed = true;
    _key = null;
    _salt = null;
    _records = [];
    super.dispose();
  }
}
