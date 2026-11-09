// The web preview keeps both data and its key in memory only.
class VaultKeyStore {
  String? _key;
  Future<String?> read() async => _key;
  Future<void> write(String key) async {
    _key = key;
  }
}
