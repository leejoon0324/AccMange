import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/clipboard_guard.dart';
import '../core/otp.dart';
import '../core/record.dart';
import '../core/vault_service.dart';
import '../storage/backup_transport.dart';
import 'backup_password_dialog.dart';
import 'editor_screen.dart';
import 'password_detail.dart';
import 'scanner_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  final VaultService vault;
  const HomeScreen({super.key, required this.vault});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  RecordKind _kind = RecordKind.otp;
  String _group = '';
  bool _favoritesOnly = false;
  bool _busy = false;
  late final Timer _clock;
  DateTime _now = DateTime.now();
  VaultService get vault => widget.vault;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _search.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(
      {VaultRecord? record, OtpConfig? scanned, RecordKind? kind}) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => EditorScreen(
                vault: vault,
                kind: record?.kind ?? kind ?? _kind,
                record: record,
                scanned: scanned)));
  }

  Future<void> _scan() async {
    final config = await Navigator.push<OtpConfig>(
        context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (config != null && mounted && vault.unlocked) {
      await _edit(scanned: config, kind: RecordKind.otp);
    }
  }

  Future<void> _copy(String text) async {
    await ClipboardGuard.copy(text);
    if (mounted) toast(context, '已复制，30 秒后清除剪贴板');
  }

  Future<void> _export() async {
    final password = await askBackupPassword(context, importing: false);
    if (password == null || !mounted) return;
    await _run(() async {
      final data = await vault.exportBackup(password);
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox;
      await vault.external(
          () => shareBackup(data, box.localToGlobal(Offset.zero) & box.size));
      if (mounted) toast(context, '已打开分享菜单，请将备份保存到安全位置');
    });
  }

  Future<void> _import() async {
    await _run(() async {
      final data = await vault.external(pickBackup);
      if (data == null || !mounted) return;
      vault.codec.envelope(data);
      final password = await askBackupPassword(context, importing: true);
      if (password == null || !mounted) return;
      try {
        final count = await vault.importBackup(data, password);
        if (mounted) toast(context, '已读取并合并 $count 条记录');
      } catch (e) {
        if (mounted) toast(context, '导入失败：备份密码错误或文件损坏。');
      }
    });
  }

  void _addMenu() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: surface,
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      leading: const Icon(Icons.qr_code_scanner, color: mint),
                      title: const Text('扫描二维码'),
                      subtitle: const Text('打开相机，添加验证账号'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _scan();
                      }),
                  ListTile(
                      leading: const Icon(Icons.key_outlined, color: mint),
                      title: const Text('手动添加验证账号'),
                      subtitle: const Text('输入密钥或粘贴 otpauth 链接'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _edit(kind: RecordKind.otp);
                      }),
                  ListTile(
                      leading: const Icon(Icons.lock_outline, color: mint),
                      title: const Text('保存账号密码'),
                      subtitle: const Text('添加密码，或生成强密码'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _edit(kind: RecordKind.password);
                      }),
                ]))));
  }

  void _settings() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: surface,
        builder: (sheet) => SafeArea(
            child: ListenableBuilder(
                listenable: vault,
                builder: (_, __) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('安全与备份',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)))),
                      SwitchListTile(
                          title: const Text('指纹 / Face ID 解锁'),
                          subtitle: Text(vault.biometricAvailable
                              ? '使用设备生物识别快速解锁'
                              : '此设备尚未配置可用的生物识别'),
                          secondary: const Icon(Icons.fingerprint),
                          value: vault.biometricEnabled,
                          onChanged: vault.biometricAvailable
                              ? (enabled) async {
                                  try {
                                    await vault.external(
                                        () => vault.setBiometric(enabled));
                                  } catch (e) {
                                    if (sheet.mounted) {
                                      toast(sheet, friendlyError(e));
                                    }
                                  }
                                }
                              : null),
                      ListTile(
                          leading: const Icon(Icons.file_upload_outlined),
                          title: const Text('导出加密备份'),
                          subtitle: const Text('备份全部验证码与密码'),
                          onTap: () {
                            Navigator.pop(sheet);
                            _export();
                          }),
                      ListTile(
                          leading: const Icon(Icons.file_download_outlined),
                          title: const Text('导入加密备份'),
                          subtitle: const Text('恢复或合并 .twinlock 文件'),
                          onTap: () {
                            Navigator.pop(sheet);
                            _import();
                          }),
                      const Divider(indent: 16, endIndent: 16),
                      const ListTile(
                          leading: Icon(Icons.timer_outlined),
                          title: Text('自动锁定'),
                          subtitle: Text(
                              '离开应用立即锁定；无操作 5 分钟锁定。\n系统文件选择与分享期间最多宽限 2 分钟。')),
                      const ListTile(
                          leading: Icon(Icons.schedule),
                          title: Text('验证码时间'),
                          subtitle: Text('验证码依赖手机时间，请开启系统自动设置日期与时间。')),
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              '双钥 1.0.0\nAES-256-GCM 本机加密 · 不上传账号数据\n主密码无法找回，请定期导出备份。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: muted, fontSize: 12, height: 1.7))),
                    ])))));
  }

  Future<void> _recordAction(String action, VaultRecord record) async {
    if (action == 'edit') {
      await _edit(record: record);
      return;
    }
    if (action == 'delete' &&
        await confirm(context,
            title: '删除 ${record.title}？',
            message: '这条记录将从本机移除。删除前，请确认已经保存备份或其他登录方式。',
            action: '删除',
            danger: true)) {
      await _run(() => vault.remove(record.id));
    }
  }

  List<VaultRecord> _filtered(List<VaultRecord> records) {
    final query = _search.text.trim().toLowerCase();
    final selected = records
        .where((r) =>
            r.kind == _kind &&
            (!_favoritesOnly || r.favorite) &&
            (_group.isEmpty || r.group == _group) &&
            '${r.title} ${r.username} ${r.group} ${r.website}'
                .toLowerCase()
                .contains(query))
        .toList();
    selected.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    final records = vault.records;
    final filtered = _filtered(records);
    final otpCount = records.where((r) => r.kind == RecordKind.otp).length;
    final groups = records
        .where((r) => r.kind == _kind && r.group.isNotEmpty)
        .map((r) => r.group)
        .toSet()
        .toList()
      ..sort();
    return Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const BrandMark(size: 40),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                        child: Text('双钥',
                                            style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800))),
                                    IconButton(
                                        tooltip: '立即锁定',
                                        onPressed: vault.lock,
                                        icon: const Icon(
                                            Icons.lock_outline_rounded,
                                            color: muted)),
                                    IconButton(
                                        tooltip: '安全与备份',
                                        onPressed: _settings,
                                        icon: const Icon(Icons.tune_rounded,
                                            color: muted))
                                  ]),
                                  const SizedBox(height: 32),
                                  const Text('你的数字生活，\n多一重守护。',
                                      style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                          letterSpacing: -.7)),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                            color: mint,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('保险箱已解锁  ·  ${records.length} 个账号',
                                        style: const TextStyle(
                                            fontSize: 12, color: muted)),
                                    const Spacer(),
                                    const Icon(Icons.cloud_off_outlined,
                                        color: muted, size: 16),
                                    const SizedBox(width: 6),
                                    const Text('离线',
                                        style: TextStyle(
                                            color: muted, fontSize: 12))
                                  ]),
                                  if (kIsWeb) ...[
                                    const SizedBox(height: 16),
                                    const Text('界面预览 · 刷新后清除数据，请勿保存真实账号',
                                        style: TextStyle(
                                            color: mint, fontSize: 12))
                                  ],
                                  const SizedBox(height: 28),
                                  Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                          color: surface,
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      child: Row(children: [
                                        Expanded(
                                            child: _tab(RecordKind.otp, '动态验证码',
                                                otpCount)),
                                        Expanded(
                                            child: _tab(
                                                RecordKind.password,
                                                '密码保险箱',
                                                records.length - otpCount))
                                      ])),
                                  const SizedBox(height: 20),
                                  TextField(
                                      controller: _search,
                                      decoration: InputDecoration(
                                          hintText: '搜索名称、账号或分组',
                                          prefixIcon: const Icon(
                                              Icons.search_rounded,
                                              color: muted),
                                          suffixIcon: _search.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: '清除搜索',
                                                  onPressed: _search.clear,
                                                  icon: const Icon(
                                                      Icons.close)))),
                                  const SizedBox(height: 16),
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(children: [
                                        FilterChip(
                                            label: const Text('收藏'),
                                            avatar: const Icon(
                                                Icons.star_outline_rounded,
                                                size: 17),
                                            selected: _favoritesOnly,
                                            onSelected: (v) => setState(
                                                () => _favoritesOnly = v)),
                                        const SizedBox(width: 8),
                                        ...[
                                          '',
                                          ...groups
                                        ].map((group) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                                label: Text(group.isEmpty
                                                    ? '全部'
                                                    : group),
                                                selected: _group == group,
                                                onSelected: (_) => setState(
                                                    () => _group = group))))
                                      ])),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Text(
                                        _kind == RecordKind.otp
                                            ? '验证账号'
                                            : '已保存密码',
                                        style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text('${filtered.length} 项',
                                        style: const TextStyle(
                                            color: muted, fontSize: 12))
                                  ]),
                                  const SizedBox(height: 12),
                                ]))),
                    if (filtered.isEmpty)
                      SliverToBoxAdapter(child: _empty(records))
                    else
                      SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _card(filtered[i]))),
                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ])))),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : _addMenu,
          backgroundColor: mint,
          foregroundColor: ink,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ink))
              : const Icon(Icons.add_rounded),
          label: const Text('添加账号',
              style: TextStyle(fontWeight: FontWeight.w700))),
    );
  }

  Widget _tab(RecordKind kind, String label, int count) => Material(
      color: _kind == kind ? mint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
                _kind = kind;
                _group = '';
              }),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label,
                    style: TextStyle(
                        color: _kind == kind ? ink : muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(width: 8),
                Text('$count',
                    style: TextStyle(
                        color:
                            _kind == kind ? ink.withValues(alpha: .6) : muted,
                        fontSize: 12))
              ]))));

  Widget _empty(List<VaultRecord> records) {
    final searching =
        _search.text.isNotEmpty || _favoritesOnly || _group.isNotEmpty;
    return Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
        child: Column(children: [
          Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: mint.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(28)),
              child: Icon(
                  searching
                      ? Icons.search_off
                      : _kind == RecordKind.otp
                          ? Icons.qr_code_2
                          : Icons.lock_outline_rounded,
                  size: 38,
                  color: mint)),
          const SizedBox(height: 20),
          Text(
              searching
                  ? '没有匹配的账号'
                  : _kind == RecordKind.otp
                      ? '添加你的第一个验证账号'
                      : '让密码有个安全的家',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
              searching
                  ? '试试其他关键词，或调整筛选条件。'
                  : _kind == RecordKind.otp
                      ? '扫描服务提供的认证二维码，\n或手动输入密钥，即可开始使用。'
                      : '保存账号密码，或生成一个强密码。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.7, fontSize: 13)),
          const SizedBox(height: 22),
          if (!searching)
            OutlinedButton.icon(
                onPressed: _kind == RecordKind.otp ? _scan : () => _edit(),
                icon: Icon(_kind == RecordKind.otp
                    ? Icons.qr_code_scanner
                    : Icons.add),
                label: Text(_kind == RecordKind.otp ? '扫描二维码' : '添加密码')),
        ]));
  }

  Widget _card(VaultRecord record) {
    final otp = record.otp;
    final colors = [
      mint,
      const Color(0xFFACB8F8),
      const Color(0xFFF4BB93),
      const Color(0xFF86CDEC)
    ];
    final color =
        colors[record.title.runes.fold(0, (a, b) => a + b) % colors.length];
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF263241))),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text(
                        String.fromCharCode(record.title.runes.first)
                            .toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 20))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          record.username.isNotEmpty
                              ? record.username
                              : '未填写账号',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12))
                    ])),
                IconButton(
                    tooltip: record.favorite ? '取消收藏' : '收藏',
                    onPressed: () =>
                        _run(() => vault.toggleFavorite(record.id)),
                    icon: Icon(
                        record.favorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color:
                            record.favorite ? const Color(0xFFF4BB93) : muted,
                        size: 21)),
                PopupMenuButton<String>(
                    tooltip: '账号操作',
                    onSelected: (v) => _recordAction(v, record),
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除'))
                        ]),
              ]),
              const SizedBox(height: 20),
              if (otp != null)
                Row(children: [
                  Expanded(
                      child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _copy(otp.codeAt(DateTime.now())),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(formatCode(otp.codeAt(_now)),
                                      style: const TextStyle(
                                          color: mint,
                                          fontFamily: 'monospace',
                                          fontSize: 34,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 3)))))),
                  tooltipCopy(() => _copy(otp.codeAt(DateTime.now()))),
                  const SizedBox(width: 8),
                  if (otp.isHotp)
                    IconButton(
                        tooltip: '下一个验证码',
                        onPressed: () async {
                          if (await confirm(context,
                              title: '使用下一个验证码？',
                              message: '仅在当前验证码已经使用后推进计数器，避免与服务端不同步。',
                              action: '推进计数器')) {
                            await _run(() => vault.advanceCounter(record.id));
                          }
                        },
                        icon: const Icon(Icons.skip_next_rounded, color: mint))
                  else
                    SizedBox(
                        width: 38,
                        height: 38,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                              value: otp.secondsLeft(_now) / otp.period,
                              strokeWidth: 3,
                              color: otp.secondsLeft(_now) <= 5
                                  ? const Color(0xFFF4BB93)
                                  : mint,
                              backgroundColor: const Color(0xFF344152)),
                          Text('${otp.secondsLeft(_now)}',
                              style:
                                  const TextStyle(color: muted, fontSize: 11))
                        ])),
                  const SizedBox(width: 12),
                ])
              else
                Row(children: [
                  const Expanded(
                      child: Text('•••• •••• ••••',
                          style: TextStyle(
                              color: muted, fontSize: 25, letterSpacing: 2))),
                  IconButton(
                      tooltip: '查看密码',
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          backgroundColor: surface,
                          isScrollControlled: true,
                          builder: (_) => PasswordDetail(record: record)),
                      icon:
                          const Icon(Icons.visibility_outlined, color: muted)),
                  tooltipCopy(() => _copy(record.password)),
                  const SizedBox(width: 8)
                ]),
              if (record.group.isNotEmpty || otp?.isHotp == true) ...[
                const SizedBox(height: 12),
                Text(
                    [
                      if (record.group.isNotEmpty) record.group,
                      if (otp?.isHotp == true) 'HOTP · 计数 ${otp!.counter}'
                    ].join('  ·  '),
                    style: const TextStyle(fontSize: 11, color: muted))
              ],
            ])));
  }

  Widget tooltipCopy(VoidCallback onCopy) => IconButton(
      tooltip: '复制',
      onPressed: onCopy,
      icon: const Icon(Icons.copy_outlined, size: 19, color: muted));
}
