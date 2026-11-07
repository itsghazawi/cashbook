import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline licensing.
///
/// Device code  = Crockford-Base32 of SHA-256("CASHBOOK-DEVICE|<hardware id>")[0..10]
/// Activation   = Base64Url( Ed25519.sign( "CASHBOOK|LIC|v1|<device code>" ) )
///
/// Only the developer's activator app holds the private key, so codes
/// cannot be produced from this app.
class License {
  License._();
  static final License I = License._();

  // Public half of the developer's signing key.
  static const _pub = '9PmFNpg+f5IzpG/82gz8+ncbId8m/oMMMT4bb0rwGnE=';
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static const devWhatsApp = '963992589583';
  static const devWhatsAppLocal = '0992589583';
  static const devTelegram = 'itsghazawi';
  static const devEmail = 'ayham@alghazawi.me';
  static const devSite = 'alghazawi.me';

  String? _deviceCode;
  bool activated = false;

  Future<String> deviceCode() async {
    if (_deviceCode != null) return _deviceCode!;
    final raw = await _hardwareId();
    final hash = await Sha256().hash(utf8.encode('CASHBOOK-DEVICE|$raw'));
    final code = _base32(hash.bytes.sublist(0, 10));
    _deviceCode = '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}-${code.substring(12, 16)}';
    return _deviceCode!;
  }

  Future<String> _hardwareId() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (Platform.isAndroid) {
        final id = await const AndroidId().getId();
        if (id != null && id.isNotEmpty) return 'a:$id';
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final id = info.identifierForVendor;
        if (id != null && id.isNotEmpty) return 'i:$id';
      }
    } catch (_) {}
    // Fallback: random id kept on this install.
    var f = prefs.getString('fallback_id');
    if (f == null) {
      final r = Random.secure();
      f = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString('fallback_id', f);
    }
    return 'f:$f';
  }

  String _base32(List<int> bytes) {
    var bits = 0, value = 0;
    final out = StringBuffer();
    for (final b in bytes) {
      value = (value << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(value >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }
    if (bits > 0) out.write(_alphabet[(value << (5 - bits)) & 31]);
    return out.toString();
  }

  static String normalizeCode(String c) => c.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  Future<bool> verify(String activation) async {
    try {
      final device = normalizeCode(await deviceCode());
      final clean = activation.replaceAll(RegExp(r'\s'), '');
      final sig = base64Url.decode(base64Url.normalize(clean));
      if (sig.length != 64) return false;
      final pub = SimplePublicKey(base64.decode(_pub), type: KeyPairType.ed25519);
      return await Ed25519().verify(
        utf8.encode('CASHBOOK|LIC|v1|$device'),
        signature: Signature(sig, publicKey: pub),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> check() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('license');
    activated = saved != null && await verify(saved);
    return activated;
  }

  Future<bool> activate(String code) async {
    final ok = await verify(code);
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license', code.replaceAll(RegExp(r'\s'), ''));
      activated = true;
    }
    return ok;
  }
}
