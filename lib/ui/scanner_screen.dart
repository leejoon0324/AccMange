import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/otp.dart';
import 'theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: true,
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _found = false;
  bool _torch = false;
  String? _lastInvalid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && !_found) {
      _camera.start();
    }
    if (state == AppLifecycleState.inactive) {
      _camera.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_found) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw == _lastInvalid) continue;
      try {
        final config = OtpConfig.parse(raw);
        _found = true;
        _camera.stop();
        Navigator.pop(context, config);
        return;
      } catch (e) {
        _lastInvalid = raw;
        toast(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('扫描认证二维码'),
          actions: [
            IconButton(
              tooltip: '手电筒',
              onPressed: () async {
                await _camera.toggleTorch();
                if (mounted) setState(() => _torch = !_torch);
              },
              icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _detect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        size: 56,
                        color: muted,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '无法打开相机',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '请在系统设置中允许相机权限，或返回后手动输入密钥。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回手动添加'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: mint, width: 3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 42,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  '将二维码放入方框内\n支持标准 TOTP / HOTP 认证器二维码',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, height: 1.7),
                ),
              ),
            ),
          ],
        ),
      );
}
