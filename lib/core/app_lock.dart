import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional app lock: 4-digit PIN + fingerprint (Android) / Face ID (iPhone).
class AppLock {
  AppLock._();

  static final enabled = ValueNotifier<bool>(false);
  static final biometric = ValueNotifier<bool>(false);
  static final _auth = LocalAuthentication();

  static String get bioName => Platform.isIOS ? 'Face ID' : 'البصمة';

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    enabled.value = (p.getBool('lock_on') ?? false) && p.getString('lock_pin') != null;
    biometric.value = p.getBool('lock_bio') ?? false;
  }

  static Future<String> _digest(String pin) async {
    final h = await Sha256().hash(utf8.encode('cashbook-lock|$pin'));
    return base64.encode(h.bytes);
  }

  /// Saves a new PIN and turns the lock on.
  static Future<void> setPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lock_pin', await _digest(pin));
    await p.setBool('lock_on', true);
    enabled.value = true;
  }

  static Future<bool> check(String pin) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('lock_pin') == await _digest(pin);
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('lock_on', false);
    enabled.value = false;
  }

  static Future<void> setBiometric(bool v) async {
    biometric.value = v;
    (await SharedPreferences.getInstance()).setBool('lock_bio', v);
  }

  static Future<bool> bioAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> bioUnlock({String reason = 'افتح كاش بوك'}) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}
