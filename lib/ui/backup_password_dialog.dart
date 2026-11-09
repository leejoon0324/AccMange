import 'package:flutter/material.dart';

import 'theme.dart';

Future<String?> askBackupPassword(
  BuildContext context, {
  required bool importing,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _BackupPasswordDialog(importing: importing),
    );

class _BackupPasswordDialog extends StatefulWidget {
  final bool importing;
  const _BackupPasswordDialog({required this.importing});
  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.importing ? '解密备份' : '加密备份'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.importing
                      ? '输入导出此文件时设置的备份密码。记录将合并，同一记录保留较新版本。'
                      : '为备份设置独立密码。文件包含所有认证密钥和密码，请妥善保存文件与备份密码。',
                  style: const TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '备份密码'),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? '请输入备份密码'
                      : !widget.importing && (v!.length < 8 || v.length > 256)
                          ? '请使用 8–256 个字符'
                          : null,
                ),
                if (!widget.importing) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: '再次输入备份密码'),
                    validator: (v) => v != _password.text ? '两次输入不一致' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context, _password.text);
              }
            },
            child: Text(widget.importing ? '解密并导入' : '导出'),
          ),
        ],
      );
}
