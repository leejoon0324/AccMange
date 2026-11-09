import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twinlock/core/record.dart';
import 'package:twinlock/core/vault_codec.dart';
import 'package:twinlock/core/vault_service.dart';
import 'package:twinlock/storage/store.dart';

class MemoryStore extends VaultStore {
  String? data;
  MemoryStore([this.data]);
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String text) async {
    data = text;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String fixture;
  setUpAll(() async {
    fixture = await VaultCodec().backup([
      VaultRecord(
          kind: RecordKind.password, title: 'Test', password: 'private-value'),
    ], 'test-password-123');
  });

  test('locking cancels an in-flight password unlock', () async {
    final vault = VaultService(store: MemoryStore(fixture));
    final pending = vault.unlock('test-password-123');
    vault.lock();
    await expectLater(pending, throwsFormatException);
    expect(vault.unlocked, false);
    expect(vault.records, isEmpty);
    vault.dispose();
  });

  test('lock removes plaintext records and rejects later writes', () async {
    final vault = VaultService(store: MemoryStore(fixture));
    await vault.unlock('test-password-123');
    expect(vault.records.single.password, 'private-value');
    vault.lock();
    expect(vault.records, isEmpty);
    expect(vault.unlocked, false);
    await expectLater(
        vault.save(VaultRecord(
            kind: RecordKind.password, title: 'new', password: 'new')),
        throwsFormatException);
    vault.dispose();
  });

  test('backgrounding during creation keeps persisted vault locked', () async {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final store = MemoryStore();
    final vault = VaultService(store: store);
    final pending = vault.create('test-password-123');
    vault.lock();
    await expectLater(pending, throwsFormatException);
    expect(vault.exists, true);
    expect(store.data, isNotNull);
    expect(vault.unlocked, false);
    expect(vault.records, isEmpty);
    vault.dispose();
  });
}
