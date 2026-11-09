import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twinlock/core/otp.dart';
import 'package:twinlock/core/record.dart';
import 'package:twinlock/core/vault_service.dart';
import 'package:twinlock/ui/editor_screen.dart';
import 'package:twinlock/ui/home_screen.dart';
import 'package:twinlock/ui/theme.dart';
import 'package:twinlock/main.dart';

import 'vault_lifecycle_test.dart' show MemoryStore, MemoryKeys;

class TestVault extends VaultService {
  final List<VaultRecord> items;
  TestVault([this.items = const []]);
  VaultRecord? saved;
  @override
  List<VaultRecord> get records => items;
  @override
  bool get ready => true;
  @override
  Future<void> save(VaultRecord record) async {
    saved = record;
  }
}

Widget host(Widget child) => MaterialApp(
    theme: appTheme(),
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('zh', 'CN')],
    home: child);

void main() {
  testWidgets(
      'launch, background return and idle time keep the home screen without a password prompt',
      (tester) async {
    final vault = VaultService(store: MemoryStore(), keyStore: MemoryKeys());
    await tester.runAsync(vault.boot);
    await tester.pumpWidget(TwinlockApp(vault: vault));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byTooltip('立即锁定'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(vault.ready, isTrue);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.byTooltip('安全与备份'));
    await tester.pumpAndSettle();
    expect(find.text('打开即用'), findsOneWidget);
    expect(find.text('指纹 / Face ID 解锁'), findsNothing);
    expect(find.text('自动锁定'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
  });
  testWidgets(
      '360px dashboard searches and switches password vault without exposing password',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vault = TestVault([
      VaultRecord(
          kind: RecordKind.otp,
          title: 'GitHub',
          username: 'alice',
          otp: OtpConfig(secret: 'JBSWY3DPEHPK3PXP')),
      VaultRecord(
          kind: RecordKind.password,
          title: 'Mail',
          username: 'alice',
          password: 'NEVER-SHOW-IN-LIST'),
    ]);
    await tester.pumpWidget(host(HomeScreen(vault: vault)));
    await tester.pump();
    expect(find.text('GitHub'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'does-not-exist');
    await tester.pump();
    expect(find.text('没有匹配的账号'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('密码保险箱'));
    await tester.pump();
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('NEVER-SHOW-IN-LIST'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('scanned SHA512 and 8-digit settings survive editor save',
      (tester) async {
    final vault = TestVault();
    final otp = OtpConfig(
        secret: 'JBSWY3DPEHPK3PXP',
        issuer: 'Example',
        account: 'alice',
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        period: 60);
    await tester.pumpWidget(
        host(EditorScreen(vault: vault, kind: RecordKind.otp, scanned: otp)));
    await tester.scrollUntilVisible(find.text('加密保存'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('加密保存'));
    await tester.pumpAndSettle();
    expect(vault.saved?.otp?.algorithm, OtpAlgorithm.sha512);
    expect(vault.saved?.otp?.digits, 8);
    expect(vault.saved?.otp?.period, 60);
    expect(tester.takeException(), isNull);
  });
}
