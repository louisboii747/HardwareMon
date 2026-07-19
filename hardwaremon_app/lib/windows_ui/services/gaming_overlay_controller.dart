import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Owns HardwareMon's desktop game overlay and its system-wide shortcuts.
///
/// This deliberately uses a normal, non-injected always-on-top window. It is
/// compatible with borderless/windowed games and does not tamper with a game's
/// renderer or anti-cheat process. Exclusive fullscreen applications may hide
/// it; the UI exposes that limitation instead of claiming unsupported capture.
class GamingOverlayController extends ChangeNotifier {
  GamingOverlayController._();
  static final instance = GamingOverlayController._();

  static const toggleShortcutLabel = 'Ctrl + Shift + O';
  static const interactionShortcutLabel = 'Ctrl + Shift + I';
  static const _enabledKey = 'gaming_overlay_enabled_v1';
  static const _compactKey = 'gaming_overlay_compact_v1';

  final HotKey _toggleHotKey = HotKey(
    key: PhysicalKeyboardKey.keyO,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );
  final HotKey _interactionHotKey = HotKey(
    key: PhysicalKeyboardKey.keyI,
    modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
    scope: HotKeyScope.system,
  );

  bool enabled = true;
  bool visible = false;
  bool compact = true;
  bool interactionMode = false;
  bool registered = false;
  String? registrationError;
  Size? _previousSize;
  Offset? _previousPosition;

  bool get desktopSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    enabled = preferences.getBool(_enabledKey) ?? true;
    compact = preferences.getBool(_compactKey) ?? true;
    if (!desktopSupported) return;
    try {
      await hotKeyManager.register(
        _toggleHotKey,
        keyDownHandler: (_) => toggle(),
      );
      await hotKeyManager.register(
        _interactionHotKey,
        keyDownHandler: (_) => setInteractionMode(!interactionMode),
      );
      registered = true;
    } catch (error) {
      registrationError = error.toString();
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (!value && visible) await hide();
    notifyListeners();
  }

  Future<void> setCompact(bool value) async {
    compact = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_compactKey, value);
    if (visible) {
      await windowManager.setSize(
        value ? const Size(410, 164) : const Size(640, 230),
      );
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (!enabled || !desktopSupported) return;
    if (visible) {
      await hide();
    } else {
      await show();
    }
  }

  Future<void> show() async {
    if (!enabled || !desktopSupported || visible) return;
    _previousSize = await windowManager.getSize();
    _previousPosition = await windowManager.getPosition();
    visible = true;
    interactionMode = false;
    notifyListeners();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(
      compact ? const Size(410, 164) : const Size(640, 230),
    );
    await windowManager.setAlignment(Alignment.topRight);
    await windowManager.show();
    await windowManager.setIgnoreMouseEvents(true, forward: true);
  }

  Future<void> hide() async {
    if (!visible) return;
    visible = false;
    interactionMode = false;
    notifyListeners();
    await windowManager.setIgnoreMouseEvents(false);
    await windowManager.setAlwaysOnTop(false);
    if (_previousSize != null) await windowManager.setSize(_previousSize!);
    if (_previousPosition != null) {
      await windowManager.setPosition(_previousPosition!);
    }
  }

  Future<void> setInteractionMode(bool value) async {
    if (!visible) return;
    interactionMode = value;
    await windowManager.setIgnoreMouseEvents(!value, forward: !value);
    if (value) await windowManager.focus();
    notifyListeners();
  }

  Future<void> disposeHotKeys() async {
    if (!desktopSupported) return;
    await hotKeyManager.unregister(_toggleHotKey);
    await hotKeyManager.unregister(_interactionHotKey);
  }
}
