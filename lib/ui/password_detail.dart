import 'package:flutter/material.dart';

import '../core/clipboard_guard.dart';
import '../core/record.dart';
import 'theme.dart';

class PasswordDetail extends StatefulWidget {
  final VaultRecord record;
  const PasswordDetail({super.key, required this.record});
  @override
  State<PasswordDetail> createState() => _PasswordDetailState();
}

class _PasswordDetailState extends State<PasswordDetail> {
  bool _visible = false;
  Future<void> _copy(String text) async {
    await ClipboardGuard.copy(text);
    if (mounted) toast(context, '已复制，30 秒后清除剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            if (r.group.isNotEmpty)
              Text(r.group, style: const TextStyle(color: muted)),
            const SizedBox(height: 24),
            const Text('账号', style: TextStyle(color: muted)),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    r.username.isEmpty ? '未填写' : r.username,
                  ),
                ),
                IconButton(
                  tooltip: '复制账号',
                  onPressed:
                      r.username.isEmpty ? null : () => _copy(r.username),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('密码', style: TextStyle(color: muted)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _visible ? r.password : '••••••••••••',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 20,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _visible ? '隐藏密码' : '显示密码',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                IconButton(
                  tooltip: '复制密码',
                  onPressed: () => _copy(r.password),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            if (r.website.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('网站', style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              SelectableText(r.website),
            ],
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('备注', style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              SelectableText(r.note),
            ],
            const SizedBox(height: 24),
            Text(
              '更新于 ${r.updatedAt.toLocal().toString().substring(0, 16)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
