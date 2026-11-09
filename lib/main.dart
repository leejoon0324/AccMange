import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/clipboard_guard.dart';
import 'core/vault_service.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';
import 'ui/unlock_screen.dart';

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
  const TwinlockApp({super.key});
  @override
  State<TwinlockApp> createState() => _TwinlockAppState();
}

class _TwinlockAppState extends State<TwinlockApp> with WidgetsBindingObserver {
  final vault = VaultService();
  final _navigator = GlobalKey<NavigatorState>();
  Timer? _lockTimer;
  bool _covered = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vault.addListener(_changed);
    vault.boot();
  }

  void _changed() {
    if (!vault.unlocked) {
      _lockTimer?.cancel();
      ClipboardGuard.clear();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navigator.currentState?.popUntil((r) => r.isFirst),
      );
    } else {
      _touch();
    }
    if (mounted) setState(() {});
  }

  void _touch() {
    if (!vault.unlocked) return;
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(minutes: 5), vault.lock);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _covered = false);
      _touch();
    }
    if (state == AppLifecycleState.inactive) setState(() => _covered = true);
    if (state == AppLifecycleState.paused) {
      if (vault.externalDepth > 0) {
        _lockTimer?.cancel();
        _lockTimer = Timer(const Duration(minutes: 2), vault.lock);
      } else {
        vault.lock();
      }
    }
    if (state == AppLifecycleState.detached) vault.lock();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    vault.removeListener(_changed);
    vault.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '双钥 · Twinlock',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (_, child) => Listener(
          onPointerDown: (_) => _touch(),
          child: Stack(
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
                : vault.unlocked
                    ? HomeScreen(vault: vault)
                    : UnlockScreen(key: ValueKey(vault.exists), vault: vault),
      );
}
