import 'dart:async';

import 'package:flutter/services.dart';

class ClipboardGuard {
  static Timer? _timer;
  static String? _owned;
  static Future<void> copy(String text) async {
    _timer?.cancel();
    _owned = text;
    await Clipboard.setData(ClipboardData(text: text));
    _timer = Timer(const Duration(seconds: 30), clear);
  }

  static Future<void> clear() async {
    _timer?.cancel();
    final text = _owned;
    _owned = null;
    if (text == null) return;
    try {
      if ((await Clipboard.getData(Clipboard.kTextPlain))?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {
      /* Clipboard may be unavailable while the device is locked. */
    }
  }
}
