import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/vault_service.dart';
import 'theme.dart';

class UnlockScreen extends StatefulWidget {
  final VaultService vault;
  const UnlockScreen({super.key, required this.vault});
  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _visible = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit({bool biometric = false}) async {
    if (_busy || (!biometric && !(_form.currentState?.validate() ?? false))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (biometric) {
        await widget.vault.unlockBiometric();
      } else if (widget.vault.exists) {
        await widget.vault.unlock(_password.text);
      } else {
        await widget.vault.create(_password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.vault.exists;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        BrandMark(),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '双钥',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'T W I N L O C K',
                              style: TextStyle(color: muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 58),
                    Text(
                      existing ? '欢迎回来。' : '安全，都在\n你手中。',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existing
                          ? '解锁你的动态验证码与密码保险箱。'
                          : '一处保存动态验证码和账号密码。\n离线可用，只属于你。',
                      style: const TextStyle(
                        color: muted,
                        height: 1.7,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (kIsWeb) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: mint.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '浏览器仅供界面体验：数据刷新后清除。请在手机安装版中保存真实账号。',
                          style: TextStyle(color: mint, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _password,
                      obscureText: !_visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: existing ? '主密码' : '创建主密码（至少 8 个字符）',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? '请输入主密码'
                          : (!existing &&
                                  (value!.length < 8 || value.length > 256))
                              ? '请使用 8–256 个字符'
                              : null,
                    ),
                    if (!existing) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '再次输入主密码',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        validator: (value) =>
                            value != _password.text ? '两次输入的密码不一致' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '请牢记主密码。没有云端找回；更换或卸载应用前，请导出加密备份。',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : () => _submit(),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(existing ? '解锁保险箱' : '创建我的保险箱'),
                      ),
                    ),
                    if (existing && widget.vault.biometricEnabled) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          onPressed:
                              _busy ? null : () => _submit(biometric: true),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('使用指纹 / Face ID'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gpp_good_outlined, size: 16, color: mint),
                        SizedBox(width: 8),
                        Text(
                          '本机加密  ·  无需注册  ·  无广告',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
