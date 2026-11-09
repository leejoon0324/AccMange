import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultKeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _name = 'device-vault-key-v1';

  Future<String?> read() => _storage.read(key: _name);
  Future<void> write(String key) => _storage.write(key: _name, value: key);
}
