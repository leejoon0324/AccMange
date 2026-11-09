import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/clipboard_guard.dart';
import 'core/vault_service.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TwinlockApp());
}

class TwinlockApp extends StatefulWidget {
  final VaultService? vault;
  const TwinlockApp({super.key, this.vault});
  @override
  State<TwinlockApp> createState() => _TwinlockAppState();
}

class _TwinlockAppState extends State<TwinlockApp> with WidgetsBindingObserver {
  late final VaultService vault;
  bool _covered = false;
  @override
  void initState() {
    super.initState();
    vault = widget.vault ?? VaultService();
    WidgetsBinding.instance.addObserver(this);
    vault.addListener(_changed);
    vault.boot();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _covered = false);
    }
    if (state == AppLifecycleState.inactive) setState(() => _covered = true);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ClipboardGuard.clear();
    }
  }

  @override
  void dispose() {
    vault.removeListener(_changed);
    if (widget.vault == null) vault.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '双钥 · Twinlock',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (_, child) => Stack(
          children: [
            child!,
            if (_covered)
              const Positioned.fill(
                child: ColoredBox(
                  color: ink,
                  child: Center(child: BrandMark(size: 68)),
                ),
              ),
          ],
        ),
        home: !vault.initialized
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : vault.bootError != null
                ? Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(vault.bootError!),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: vault.boot,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : HomeScreen(vault: vault),
      );
}
