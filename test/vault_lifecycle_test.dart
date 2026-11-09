import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:twinlock/core/record.dart';
import 'package:twinlock/core/vault_codec.dart';
import 'package:twinlock/core/vault_service.dart';
import 'package:twinlock/storage/key_store.dart';
import 'package:twinlock/storage/store.dart';

class MemoryStore extends VaultStore {
  String? data;
  String? legacy;
  bool failWrites = false;
  MemoryStore({this.data, this.legacy});
  @override
  Future<String?> read() async => data;
  @override
  Future<String?> readLegacy() async => legacy;
  @override
  Future<void> write(String text) async {
    if (failWrites) throw StateError('disk full');
    data = text;
  }
}

class MemoryKeys extends VaultKeyStore {
  String? data;
  bool failWrites = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String key) async {
    if (failWrites) throw StateError('key storage unavailable');
    data = key;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'first launch creates a random key and relaunch restores encrypted records',
      () async {
    final store = MemoryStore();
    final keys = MemoryKeys();
    final vault = VaultService(store: store, keyStore: keys);
    await Future.wait([vault.boot(), vault.boot()]);
    expect(vault.ready, isTrue);
    expect(base64Decode(keys.data!).length, 32);
    final originalKey = keys.data;
    await vault.save(VaultRecord(
        kind: RecordKind.password, title: 'Mail', password: 'private-value'));
    expect(store.data, isNot(contains('private-value')));
    vault.dispose();
    final reopened = VaultService(store: store, keyStore: keys);
    await reopened.boot();
    expect(reopened.bootError, isNull);
    expect(reopened.records.single.password, 'private-value');
    expect(keys.data, originalKey);
    reopened.dispose();
    final otherKeys = MemoryKeys();
    final other = VaultService(store: MemoryStore(), keyStore: otherKeys);
    await other.boot();
    expect(otherKeys.data, isNot(originalKey));
    other.dispose();
  });

  test('missing or wrong device key never overwrites saved data', () async {
    final store = MemoryStore();
    final keys = MemoryKeys();
    final first = VaultService(store: store, keyStore: keys);
    await first.boot();
    await first.save(VaultRecord(kind: RecordKind.password, title: 'Keep me'));
    final originalData = store.data;
    final originalKey = keys.data;
    first.dispose();
    for (final invalidKey in [
      null,
      base64Encode(List.filled(32, 99)),
      'bad-key'
    ]) {
      keys.data = invalidKey;
      final vault = VaultService(store: store, keyStore: keys);
      await vault.boot();
      expect(vault.ready, isFalse);
      expect(vault.bootError, isNotNull);
      expect(store.data, originalData);
      expect(keys.data, invalidKey);
      keys.data = originalKey;
      await vault.boot();
      expect(vault.records.single.title, 'Keep me');
      vault.dispose();
    }
  });

  test('key storage failure does not create unreadable data and can retry',
      () async {
    final store = MemoryStore();
    final keys = MemoryKeys()..failWrites = true;
    final vault = VaultService(store: store, keyStore: keys);
    await vault.boot();
    expect(vault.bootError, isNotNull);
    expect(store.data, isNull);
    keys.failWrites = false;
    await vault.boot();
    expect(vault.ready, isTrue);
    expect(vault.bootError, isNull);
    vault.dispose();
  });

  test(
      'legacy encrypted data never blocks startup and merges without data loss',
      () async {
    final legacy = await VaultCodec().backup([
      VaultRecord(
          kind: RecordKind.password, title: 'Legacy', password: 'old-secret'),
    ], 'old-password-123');
    final store = MemoryStore(legacy: legacy);
    final keys = MemoryKeys();
    final vault = VaultService(store: store, keyStore: keys);
    await vault.boot();
    expect(vault.ready, isTrue);
    expect(vault.legacyAvailable, isTrue);
    expect(store.legacy, legacy);
    await vault.save(VaultRecord(kind: RecordKind.password, title: 'New'));
    await expectLater(vault.importLegacy('wrong-password'), throwsA(anything));
    expect(vault.records.single.title, 'New');
    expect(store.legacy, legacy);
    expect(await vault.importLegacy('old-password-123'), 1);
    expect(vault.records.map((r) => r.title), containsAll(['New', 'Legacy']));
    expect(store.legacy, legacy);
    vault.dispose();
    final reopened = VaultService(store: store, keyStore: keys);
    await reopened.boot();
    expect(reopened.records.length, 2);
    expect(reopened.records.last.password, 'old-secret');
    reopened.dispose();
  });

  test('queued saves retain all records and failed writes can retry', () async {
    final store = MemoryStore();
    final vault = VaultService(store: store, keyStore: MemoryKeys());
    await vault.boot();
    await Future.wait(List.generate(
        12,
        (i) => vault.save(
            VaultRecord(kind: RecordKind.password, title: 'Account $i'))));
    expect(vault.records.length, 12);
    final persisted = store.data;
    store.failWrites = true;
    await expectLater(vault.remove(vault.records.first.id), throwsStateError);
    expect(vault.records.length, 12);
    expect(store.data, persisted);
    store.failWrites = false;
    await vault.remove(vault.records.first.id);
    expect(vault.records.length, 11);
    vault.dispose();
  });
}
