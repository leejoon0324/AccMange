import 'package:flutter/material.dart';

import '../core/otp.dart';
import '../core/record.dart';
import '../core/vault_service.dart';
import 'theme.dart';

class EditorScreen extends StatefulWidget {
  final VaultService vault;
  final RecordKind kind;
  final VaultRecord? record;
  final OtpConfig? scanned;
  const EditorScreen({
    super.key,
    required this.vault,
    required this.kind,
    this.record,
    this.scanned,
  });
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _username,
      _secret,
      _password,
      _website,
      _note,
      _group,
      _period,
      _counter;
  late OtpAlgorithm _algorithm;
  late int _digits;
  late bool _hotp;
  bool _visible = false;
  bool _advanced = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final otp = widget.scanned ?? record?.otp;
    _title = TextEditingController(
      text: record?.title ??
          (otp?.issuer.isNotEmpty == true ? otp!.issuer : otp?.account),
    );
    _username = TextEditingController(text: record?.username ?? otp?.account);
    _secret = TextEditingController(text: otp?.secret);
    _password = TextEditingController(text: record?.password);
    _website = TextEditingController(text: record?.website);
    _note = TextEditingController(text: record?.note);
    _group = TextEditingController(text: record?.group);
    _period = TextEditingController(text: '${otp?.period ?? 30}');
    _counter = TextEditingController(text: '${otp?.counter ?? 0}');
    _algorithm = otp?.algorithm ?? OtpAlgorithm.sha1;
    _digits = otp?.digits ?? 6;
    _hotp = otp?.isHotp ?? false;
    _advanced = _hotp ||
        _digits != 6 ||
        _algorithm != OtpAlgorithm.sha1 ||
        (otp?.period ?? 30) != 30;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _username,
      _secret,
      _password,
      _website,
      _note,
      _group,
      _period,
      _counter,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      OtpConfig? otp;
      if (widget.kind == RecordKind.otp) {
        final raw = _secret.text.trim();
        if (raw.startsWith('otpauth:')) {
          otp = OtpConfig.parse(raw);
        } else {
          otp = OtpConfig(
            secret: raw,
            issuer: _title.text.trim(),
            account: _username.text.trim(),
            algorithm: _algorithm,
            digits: _digits,
            isHotp: _hotp,
            period: int.tryParse(_period.text) ?? 0,
            counter: int.tryParse(_counter.text) ?? -1,
          );
        }
        final duplicate = widget.vault.records.any(
          (r) => r.id != widget.record?.id && r.otp?.secret == otp!.secret,
        );
        if (duplicate &&
            mounted &&
            !await confirm(
              context,
              title: '已有相同密钥',
              message: '保险箱中已存在使用此密钥的账号，仍要添加吗？',
              action: '仍然添加',
            )) {
          return;
        }
      }
      final record = VaultRecord(
        id: widget.record?.id,
        kind: widget.kind,
        title: _title.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        website: _website.text.trim(),
        note: _note.text.trim(),
        group: _group.text.trim(),
        favorite: widget.record?.favorite ?? false,
        otp: otp,
      );
      await widget.vault.save(record);
      if (mounted) {
        Navigator.pop(context);
        toast(context, '已加密保存');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          maxLines: lines,
          keyboardType: keyboard,
          textInputAction:
              lines == 1 ? TextInputAction.next : TextInputAction.newline,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon == null ? null : Icon(icon),
          ),
          validator: required
              ? (value) => (value?.trim().isEmpty ?? true) ? '请填写$label' : null
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final otp = widget.kind == RecordKind.otp;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record != null
              ? '编辑账号'
              : otp
                  ? '添加验证账号'
                  : '添加密码',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (widget.scanned != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mint.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_scanner, color: mint),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '二维码已识别，请核对账号后保存。',
                              style: TextStyle(color: mint),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _field(
                    _title,
                    otp ? '服务名称' : '名称',
                    required: true,
                    icon: Icons.apps_rounded,
                  ),
                  _field(
                    _username,
                    '账号 / 邮箱',
                    icon: Icons.person_outline,
                    keyboard: TextInputType.emailAddress,
                  ),
                  if (otp) ...[
                    TextFormField(
                      controller: _secret,
                      obscureText: !_visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Base32 密钥或 otpauth 链接',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? '请输入密钥' : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _advanced = !_advanced),
                      icon: Icon(_advanced ? Icons.expand_less : Icons.tune),
                      label: const Text('高级认证设置'),
                    ),
                    if (_advanced) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<bool>(
                        value: _hotp,
                        decoration: const InputDecoration(labelText: '认证类型'),
                        items: const [
                          DropdownMenuItem(
                            value: false,
                            child: Text('TOTP · 按时间刷新'),
                          ),
                          DropdownMenuItem(
                            value: true,
                            child: Text('HOTP · 按计数器刷新'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _hotp = v!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<OtpAlgorithm>(
                              value: _algorithm,
                              decoration: const InputDecoration(
                                labelText: '算法',
                              ),
                              items: OtpAlgorithm.values
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a.name.toUpperCase()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _algorithm = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _digits,
                              decoration: const InputDecoration(
                                labelText: '位数',
                              ),
                              items: [6, 7, 8]
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text('$n 位'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _digits = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_hotp)
                        _field(
                          _counter,
                          '当前计数器',
                          keyboard: TextInputType.number,
                        )
                      else
                        _field(
                          _period,
                          '刷新周期（秒）',
                          keyboard: TextInputType.number,
                        ),
                    ],
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      controller: _password,
                      obscureText: !_visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.isEmpty ?? true) ? '请输入密码' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _password.text = generatePassword(),
                        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                        label: const Text('生成 20 位强密码'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _field(
                      _website,
                      '网站（可选）',
                      icon: Icons.language,
                      keyboard: TextInputType.url,
                    ),
                  ],
                  _field(
                    _group,
                    '分组（可选，例如：工作 / 个人）',
                    icon: Icons.folder_outlined,
                  ),
                  _field(_note, '备注（可选）', lines: 3),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('加密保存'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '数据仅加密保存在本机。建议定期导出加密备份。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
