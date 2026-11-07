import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

/// Web OAuth client ID from Google Cloud Console (needed for Drive on Android).
/// Leave empty until the Google Cloud project is configured.
const kGoogleServerClientId = '';

class DriveFile {
  final String id;
  final String name;
  final DateTime? modified;
  final int? size;
  DriveFile(this.id, this.name, this.modified, this.size);
}

class BackupService extends ChangeNotifier with WidgetsBindingObserver {
  BackupService._();
  static final BackupService I = BackupService._();

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  String? driveEmail;
  DateTime? lastDriveBackup;
  bool autoDrive = true;
  bool busy = false;
  GoogleSignInAccount? _account;
  bool _initDone = false;
  Timer? _debounce;

  bool get driveConfigured => kGoogleServerClientId.isNotEmpty;
  bool get driveConnected => driveEmail != null;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    driveEmail = p.getString('drive_email');
    autoDrive = p.getBool('drive_auto') ?? true;
    final t = p.getString('drive_last');
    lastDriveBackup = t == null ? null : DateTime.tryParse(t);
    AppStore.I.onDataChanged = _scheduleAuto;
    if (driveConnected) unawaited(_maybeDailyBackup());
    await _initDaily();
  }

  // ------------------------------------------------------------ daily file
  /// One backup file on the phone, refreshed every day at 12 midnight.
  static const dailyFileName = 'CashBook-Backup.json';
  String? dailyPath;
  DateTime? lastDaily;
  Timer? _midnight;
  bool _observing = false;

  Future<void> _initDaily() async {
    final p = await SharedPreferences.getInstance();
    dailyPath = p.getString('daily_path');
    final t = p.getString('daily_last');
    lastDaily = t == null ? null : DateTime.tryParse(t);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await _dailyIfDue();
    _armMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_dailyIfDue());
      _armMidnight();
    }
  }

  void _armMidnight() {
    _midnight?.cancel();
    final n = DateTime.now();
    final next = DateTime(n.year, n.month, n.day + 1);
    _midnight = Timer(next.difference(n) + const Duration(seconds: 2), () async {
      await writeDaily();
      _armMidnight();
    });
  }

  /// If the last daily copy was taken before today's midnight, take it now.
  Future<void> _dailyIfDue() async {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final l = lastDaily;
    if (l == null || l.isBefore(today) || dailyPath == null || !File(dailyPath!).existsSync()) {
      await writeDaily();
    }
  }

  Future<List<Directory>> _dailyDirs() async {
    final out = <Directory>[];
    if (Platform.isAndroid) {
      out.add(Directory('/storage/emulated/0/Download/CashBook'));
      final ext = await getExternalStorageDirectory();
      if (ext != null) out.add(Directory('${ext.path}/CashBook'));
    }
    final docs = await getApplicationDocumentsDirectory();
    out.add(Directory('${docs.path}/CashBook-Backup'));
    return out;
  }

  /// Writes the single daily backup file. Returns true on success.
  Future<bool> writeDaily() async {
    final data = AppStore.I.exportBackup();
    for (final d in await _dailyDirs()) {
      try {
        if (!await d.exists()) await d.create(recursive: true);
        final f = File('${d.path}/$dailyFileName');
        await f.writeAsString(data, flush: true);
        dailyPath = f.path;
        lastDaily = DateTime.now();
        final p = await SharedPreferences.getInstance();
        await p.setString('daily_path', dailyPath!);
        await p.setString('daily_last', lastDaily!.toIso8601String());
        notifyListeners();
        return true;
      } catch (_) {
        // try the next place
      }
    }
    return false;
  }

  /// Friendly description of where the daily file lives.
  String get dailyPlace {
    final path = dailyPath;
    if (path == null) return 'لم تُنشأ بعد';
    if (Platform.isIOS) return 'تطبيق الملفات ← على الـ iPhone ← كاش بوك ← CashBook-Backup';
    if (path.startsWith('/storage/emulated/0/Download/')) return 'مدير الملفات ← التنزيلات (Download) ← CashBook';
    return 'مدير الملفات ← Android/data/com.alghazawi.cashbook/files/CashBook';
  }

  /// Returns null on success or an error message.
  Future<String?> restoreDaily() async {
    final path = dailyPath;
    if (path == null || !File(path).existsSync()) return 'لا توجد نسخة يومية بعد';
    return AppStore.I.importBackup(await File(path).readAsString());
  }

  /// Sends the backup file to Google Drive through the share sheet (choose Drive).
  Future<void> shareToDrive() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${_fileName()}');
    await f.writeAsString(AppStore.I.exportBackup());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/json')],
      title: 'اختر Google Drive لحفظ النسخة',
      subject: 'نسخة احتياطية - كاش بوك',
    ));
  }

  // ------------------------------------------------------------ local files
  String _fileName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'cashbook-${n.year}-${two(n.month)}-${two(n.day)}-${two(n.hour)}${two(n.minute)}.json';
  }

  /// Lets the user choose where to save the backup file on the phone.
  Future<bool> saveToDevice({String title = 'حفظ النسخة الاحتياطية'}) async {
    final bytes = Uint8List.fromList(utf8.encode(AppStore.I.exportBackup()));
    final uri = await FilePicker.saveFile(
      fileName: _fileName(),
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: title,
    );
    return uri != null;
  }

  Future<void> shareBackup() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${_fileName()}');
    await f.writeAsString(AppStore.I.exportBackup());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/json')],
      title: 'نسخة احتياطية - كاش بوك',
    ));
  }

  /// Returns null on success, '' if cancelled, or an error message.
  Future<String?> restoreFromDevice() async {
    final f = await FilePicker.pickFile(dialogTitle: 'اختر ملف النسخة الاحتياطية');
    if (f == null) return '';
    final raw = await f.xFile.readAsString();
    return AppStore.I.importBackup(raw);
  }

  // ------------------------------------------------------------ Google Drive
  Future<void> _ensureInit() async {
    if (_initDone) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
    );
    _initDone = true;
  }

  Future<drive.DriveApi?> _api({bool interactive = false}) async {
    await _ensureInit();
    if (_account == null) {
      if (interactive) {
        _account = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      } else {
        _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      }
    }
    final acc = _account;
    if (acc == null) return null;
    var authz = await acc.authorizationClient.authorizationForScopes(_scopes);
    if (authz == null) {
      if (!interactive) return null;
      authz = await acc.authorizationClient.authorizeScopes(_scopes);
    }
    return drive.DriveApi(authz.authClient(scopes: _scopes));
  }

  /// Returns null on success, otherwise an Arabic error.
  Future<String?> connectDrive() async {
    if (!driveConfigured) return 'ربط Google Drive غير مُفعّل في هذه النسخة بعد';
    try {
      _setBusy(true);
      final api = await _api(interactive: true);
      if (api == null) return 'لم يتم تسجيل الدخول';
      driveEmail = _account?.email;
      final p = await SharedPreferences.getInstance();
      await p.setString('drive_email', driveEmail ?? '');
      await _upload(api);
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return 'تم الإلغاء';
      return 'تعذّر الربط مع Google: ${e.description ?? e.code.name}';
    } catch (e) {
      return 'تعذّر الربط مع Google Drive، تحقق من الإنترنت';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> disconnectDrive() async {
    try {
      await _ensureInit();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _account = null;
    driveEmail = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('drive_email');
    notifyListeners();
  }

  Future<void> setAuto(bool v) async {
    autoDrive = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool('drive_auto', v);
    notifyListeners();
  }

  Future<String?> backupNow() async {
    try {
      _setBusy(true);
      final api = await _api(interactive: true);
      if (api == null) return 'يرجى ربط حساب Google أولاً';
      await _upload(api);
      return null;
    } catch (e) {
      return 'فشل الرفع إلى Google Drive، تحقق من الإنترنت';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _upload(drive.DriveApi api) async {
    final bytes = utf8.encode(AppStore.I.exportBackup());
    final meta = drive.File()
      ..name = _fileName()
      ..parents = ['appDataFolder']
      ..mimeType = 'application/json';
    await api.files.create(meta, uploadMedia: drive.Media(Stream.value(bytes), bytes.length));
    // Keep the 15 most recent copies.
    final list = await _list(api);
    for (final f in list.skip(15)) {
      try {
        await api.files.delete(f.id);
      } catch (_) {}
    }
    lastDriveBackup = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setString('drive_last', lastDriveBackup!.toIso8601String());
    notifyListeners();
  }

  Future<List<DriveFile>> _list(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      orderBy: 'modifiedTime desc',
      pageSize: 50,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    return (res.files ?? [])
        .map((f) => DriveFile(f.id!, f.name ?? '', f.modifiedTime?.toLocal(), int.tryParse(f.size ?? '')))
        .toList();
  }

  Future<List<DriveFile>> listDriveBackups() async {
    final api = await _api(interactive: true);
    if (api == null) return [];
    return _list(api);
  }

  Future<String?> restoreFromDrive(DriveFile f) async {
    try {
      _setBusy(true);
      final api = await _api(interactive: true);
      if (api == null) return 'يرجى ربط حساب Google أولاً';
      final media = await api.files.get(f.id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final chunks = <int>[];
      await for (final c in media.stream) {
        chunks.addAll(c);
      }
      return await AppStore.I.importBackup(utf8.decode(chunks));
    } catch (e) {
      return 'تعذّر تنزيل النسخة من Google Drive';
    } finally {
      _setBusy(false);
    }
  }

  // Auto backup: a few seconds after changes, at most every 6 hours,
  // plus once a day on app start.
  void _scheduleAuto() {
    if (!driveConnected || !autoDrive) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () {
      final last = lastDriveBackup;
      if (last == null || DateTime.now().difference(last).inHours >= 6) {
        unawaited(_silentBackup());
      }
    });
  }

  Future<void> _maybeDailyBackup() async {
    if (!autoDrive) return;
    final last = lastDriveBackup;
    if (last == null || DateTime.now().difference(last).inHours >= 24) {
      await _silentBackup();
    }
  }

  Future<void> _silentBackup() async {
    try {
      final api = await _api();
      if (api != null) await _upload(api);
    } catch (e) {
      debugPrint('auto backup failed: $e');
    }
  }

  void _setBusy(bool v) {
    busy = v;
    notifyListeners();
  }
}
