// The browser build is an ephemeral UI preview. Mobile builds use an encrypted file.
class VaultStore {
  String? _data;
  Future<String?> read() async => _data;
  Future<String?> readLegacy() async => null;
  Future<void> write(String data) async {
    _data = data;
  }
}
