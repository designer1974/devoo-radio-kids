import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'player.dart';
import 'update.dart' show appChannel;

String two(int n) => n.toString().padLeft(2, '0');

String fmtDur(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtSize(int b) =>
    b >= 1024 * 1024 ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB' : '${(b / 1024).toStringAsFixed(0)} KB';

String fmtDate(DateTime d) => '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtLen(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? (h == 1 ? '1 ora' : '$h ore') : '$h h $m min';
}

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'oggi';
  if (diff == 1) return 'domani';
  return '${two(d.day)}/${two(d.month)}';
}

/// Nome di file sicuro (niente / : * ? ecc.)
String cleanName(String s) =>
    s.replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Qualità fissa: AAC 64 kbps stereo, file .m4a che si apre ovunque (anche WhatsApp e iPhone).
/// Bella per la musica e le storie, circa 28 MB all'ora.
const recBitrate = 64000;
const recChannels = 2;
const recHe = true;

/// Ponte verso il registratore Android (Kotlin).
class Recorder {
  static Future<void> streamStart({required String url, required String dir, required String name, required String dst}) =>
      appChannel.invokeMethod('streamStart', {
        'url': url,
        'dir': dir,
        'name': name,
        'dst': dst,
        'bitrate': recBitrate,
        'outCh': recChannels,
        'he': recHe,
      });

  static Future<Map<String, dynamic>> streamStatus() async {
    final m = await appChannel.invokeMethod<Map>('streamStatus');
    return Map<String, dynamic>.from(m ?? const {});
  }

  /// Ferma e salva. Ritorna il file M4A, o null se vuoto.
  static Future<String?> streamStop() => appChannel.invokeMethod<String>('streamStop');

  /// Registrazioni interrotte da uno spegnimento: le ricompone.
  static Future<List<String>> recover(String dir) async =>
      ((await appChannel.invokeMethod<List>('recover', {'dir': dir})) ?? const []).cast<String>();

  static Future<int> durationMs(String path) async =>
      (await appChannel.invokeMethod<int>('duration', {'path': path})) ?? 0;
}

/// Una registrazione salvata.
class RecFile {
  final File file;
  final String name;
  final DateTime date;
  final int size;
  Duration? duration;

  RecFile(this.file, this.name, this.date, this.size);
}

/// Elenco delle registrazioni nella cartella dell'app.
class Recordings extends ChangeNotifier {
  Recordings._();
  static final i = Recordings._();

  List<RecFile> items = [];
  Directory? _dir;

  Future<Directory> dir() async {
    final d = _dir ?? Directory('${(await getApplicationDocumentsDirectory()).path}/recordings');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<void> reload() async {
    try {
      final d = await dir();
      final list = <RecFile>[];
      for (final e in d.listSync()) {
        if (e is! File) continue;
        final base = e.path.split('/').last;
        if (base.startsWith('.')) continue; // file temporanei
        final dot = base.lastIndexOf('.');
        if (dot <= 0) continue;
        final st = e.statSync();
        list.add(RecFile(e, base.substring(0, dot), st.modified, st.size));
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      final old = {for (final r in items) r.file.path: r.duration};
      for (final r in list) {
        r.duration = old[r.file.path];
      }
      items = list;
      notifyListeners();
      for (final r in list.where((r) => r.duration == null)) {
        try {
          r.duration = Duration(milliseconds: await Recorder.durationMs(r.file.path));
        } catch (_) {
          r.duration = Duration.zero;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<String> uniquePath(String name, String ext, {String? except}) async {
    final d = await dir();
    var base = cleanName(name);
    if (base.isEmpty) base = 'Registrazione';
    var p = '${d.path}/$base.$ext';
    var n = 2;
    while (p != except && File(p).existsSync()) {
      p = '${d.path}/$base ($n).$ext';
      n++;
    }
    return p;
  }

  Future<void> rename(RecFile r, String name) async {
    final ext = r.file.path.split('.').last;
    final p = await uniquePath(name, ext, except: r.file.path);
    if (p != r.file.path) await r.file.rename(p);
    await reload();
  }

  Future<void> delete(RecFile r) async {
    try {
      await r.file.delete();
    } catch (_) {}
    await reload();
  }
}

/// Registrazione della radio in ascolto (direttamente dallo stream, qualità originale).
class RecController extends ChangeNotifier {
  RecController._() {
    RadioPlayer.i.addListener(_onPlayer);
    // registrazioni programmate: le segue anche se partono ad app chiusa
    _watch = Timer.periodic(const Duration(seconds: 1), (_) => _watchNative());
    RadioPlayer.i.errors.listen((_) {
      if (_pending != null) {
        _pending = null;
        notifyListeners();
      }
    });
  }
  static final i = RecController._();

  Station? station;
  DateTime? startedAt;
  int bytes = 0;
  bool saving = false;
  Timer? _poll;

  final _messages = StreamController<String>.broadcast();
  Stream<String> get messages => _messages.stream;

  bool get recording => station != null && !saving;

  // ---- registrazione programmata in corso (fatta dal servizio Android) ----
  // ignore: unused_field
  Timer? _watch;
  String? extId;
  String extName = '';
  String extFlag = '';
  String extUrl = '';
  DateTime? extStart;
  DateTime? extEnd;
  int extBytes = 0;
  bool extStopping = false;
  bool extSaving = false;

  bool get external => extId != null;

  /// C'è una registrazione qualsiasi (manuale o programmata).
  bool get busy => station != null || external;
  bool get anyRecording => recording || (external && !extStopping && !extSaving);
  bool get anySaving => saving || extStopping || extSaving;

  String get recName => station?.name ?? '${extFlag.isEmpty ? '' : '$extFlag '}$extName';
  int get recBytes => station != null ? bytes : extBytes;

  Duration get elapsed {
    final st = startedAt ?? extStart;
    return st == null ? Duration.zero : DateTime.now().difference(st);
  }

  bool isRecording(Station s) => station?.id == s.id || (external && extUrl.isNotEmpty && s.url == extUrl);

  /// Ferma quella in corso, manuale o programmata.
  Future<void> stopAny() async {
    if (recording) return stopAndSave();
    if (!external || extStopping) return;
    extStopping = true;
    notifyListeners();
    await Schedules.i.stopRunning();
  }

  Future<void> _watchNative() async {
    if (station != null) return; // la manuale si controlla da sola
    try {
      final st = await Recorder.streamStatus();
      final id = st['schedId'] as String?;
      if (id != null && st['busy'] == true) {
        final first = extId != id;
        extId = id;
        extName = (st['schedName'] as String?) ?? '';
        extFlag = (st['schedFlag'] as String?) ?? '';
        extUrl = (st['url'] as String?) ?? '';
        final t = (st['startedAt'] as num?)?.toInt() ?? 0;
        extStart = t > 0 ? DateTime.fromMillisecondsSinceEpoch(t) : DateTime.now();
        final e = (st['schedEnd'] as num?)?.toInt() ?? 0;
        extEnd = e > 0 ? DateTime.fromMillisecondsSinceEpoch(e) : null;
        extBytes = (st['bytes'] as num?)?.toInt() ?? 0;
        extSaving = st['running'] == false;
        if (first) unawaited(Schedules.i.reload());
        notifyListeners();
        // sicurezza: ora di fine passata ma ancora attiva -> si ferma
        final end = extEnd;
        if (end != null && !extStopping && !extSaving && DateTime.now().isAfter(end.add(const Duration(seconds: 8)))) {
          unawaited(stopAny());
        }
      } else if (extId != null) {
        extId = null;
        extStopping = false;
        extSaving = false;
        extBytes = 0;
        notifyListeners();
        _messages.add('Registrazione programmata salvata in Registrate 🎙️');
        unawaited(Recordings.i.reload());
        unawaited(Schedules.i.reload());
      }
    } catch (_) {}
  }

  Station? _pending; // radio da registrare appena parte

  /// Accende la radio (se serve) e registra appena è in onda.
  void recordStation(Station s) {
    if (busy) {
      _messages.add('C\'è già una registrazione in corso');
      return;
    }
    final p = RadioPlayer.i;
    if (p.isCurrent(s) && p.isPlaying && !p.isBuffering) {
      start();
      return;
    }
    _pending = s;
    notifyListeners();
    if (!p.isCurrent(s) || !p.isPlaying) p.play(s);
  }

  bool isPending(Station s) => _pending?.id == s.id;

  // Se la radio si ferma o si cambia stazione, la registrazione si salva da sola
  void _onPlayer() {
    final p = RadioPlayer.i;
    final pend = _pending;
    if (pend != null) {
      if (!p.isCurrent(pend)) {
        _pending = null;
        notifyListeners();
      } else if (p.isPlaying && !p.isBuffering && !busy) {
        _pending = null;
        start();
      }
    }
    if (!recording) return;
    if (p.current?.id != station!.id) {
      stopAndSave();
    } else if (!p.wantsPlay) {
      stopAndSave(why: 'La radio si è fermata, registrazione salvata');
    }
  }

  Future<void> start() async {
    final s = RadioPlayer.i.current;
    if (external) {
      _messages.add('C\'è già una registrazione programmata in corso');
      return;
    }
    if (s == null || busy) return;
    final now = DateTime.now();
    try {
      final d = await Recordings.i.dir();
      final flag = s.flag == '🌍' ? '' : s.flag;
      final name = '$flag ${s.name} ${two(now.day)}-${two(now.month)} ${two(now.hour)}.${two(now.minute)}';
      final dst = await Recordings.i.uniquePath(name.trim(), 'm4a');
      await Recorder.streamStart(url: s.url, dir: d.path, name: '.rec_${now.millisecondsSinceEpoch}', dst: dst);
    } catch (e) {
      _messages.add('Questa radio non si può registrare');
      return;
    }
    station = s;
    startedAt = now;
    bytes = 0;
    notifyListeners();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  /// All'avvio: ricompone le registrazioni interrotte (telefono spento, batteria finita).
  Future<void> recoverInterrupted() async {
    try {
      final d = await Recordings.i.dir();
      final got = await Recorder.recover(d.path);
      if (got.isNotEmpty) {
        _messages.add(got.length == 1
            ? 'Registrazione interrotta recuperata ✔'
            : '${got.length} registrazioni interrotte recuperate ✔');
      }
    } catch (_) {}
    await Recordings.i.reload();
  }

  Future<void> _check() async {
    if (!recording) return;
    try {
      final st = await Recorder.streamStatus();
      bytes = (st['bytes'] as num?)?.toInt() ?? bytes;
      if (st['running'] == false) {
        await stopAndSave(why: (st['error'] as String?) ?? 'La radio ha chiuso il collegamento');
        return;
      }
    } catch (_) {}
    notifyListeners();
  }

  /// [why]: perché si è fermata da sola, mostrato al posto di «troppo corta».
  Future<void> stopAndSave({String? why}) async {
    if (!recording) return;
    _poll?.cancel();
    saving = true;
    notifyListeners();
    try {
      final path = await Recorder.streamStop();
      final f = path == null ? null : File(path);
      if (f == null || !f.existsSync() || f.lengthSync() < 2000) {
        _messages.add(why ?? 'Registrazione troppo corta, non salvata');
      } else {
        _messages.add('${why == null ? '' : '$why · '}Salvata in Registrate 🎙️');
      }
    } catch (_) {
      _messages.add('Registrazione non salvata');
    } finally {
      station = null;
      startedAt = null;
      saving = false;
      bytes = 0;
      notifyListeners();
      unawaited(Recordings.i.reload());
    }
  }
}

/// Una registrazione programmata.
class Schedule {
  final String id;
  final String name;
  final String flag;
  final String url;
  final DateTime start;
  final DateTime end;
  final bool daily;
  final bool running;

  const Schedule(this.id, this.name, this.flag, this.url, this.start, this.end, this.daily, this.running);

  Duration get length => end.difference(start);

  static Schedule? from(Map m) {
    try {
      return Schedule(
        '${m['id']}',
        '${m['name'] ?? ''}',
        '${m['flag'] ?? ''}',
        '${m['url'] ?? ''}',
        DateTime.fromMillisecondsSinceEpoch((m['start'] as num).toInt()),
        DateTime.fromMillisecondsSinceEpoch((m['end'] as num).toInt()),
        m['daily'] == true,
        m['running'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Registrazioni programmate: le fa il servizio Android, anche ad app chiusa e schermo spento.
class Schedules extends ChangeNotifier {
  Schedules._();
  static final i = Schedules._();

  List<Schedule> items = [];

  Future<void> reload() async {
    try {
      final l = await appChannel.invokeMethod<List>('schedList') ?? const [];
      items = l.whereType<Map>().map(Schedule.from).whereType<Schedule>().toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add(Station s, DateTime start, DateTime end, bool daily) async {
    final dir = await Recordings.i.dir();
    await appChannel.invokeMethod('schedAdd', {
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'name': s.name,
      'flag': s.flag == '🌍' ? '' : s.flag,
      'url': s.url,
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
      'daily': daily,
      'dir': dir.path,
      'bitrate': recBitrate,
      'outCh': recChannels,
      'he': recHe,
    });
    await reload();
  }

  Future<void> remove(Schedule s) async {
    try {
      await appChannel.invokeMethod('schedRemove', {'id': s.id});
    } catch (_) {}
    await reload();
  }

  Future<void> stopRunning() async {
    try {
      await appChannel.invokeMethod('schedStop');
    } catch (_) {}
  }

  /// Programmi che si sovrappongono a questo orario.
  List<Schedule> overlapping(DateTime start, DateTime end) =>
      items.where((x) => x.start.isBefore(end) && start.isBefore(x.end)).toList();

  Future<bool> _ask(String m, bool fallback) async {
    try {
      return await appChannel.invokeMethod<bool>(m) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> exactOk() => _ask('schedExactOk', true);
  Future<bool> batteryOk() => _ask('batteryOk', true);
  Future<bool> isHuawei() => _ask('isHuawei', false);
  Future<void> batteryAsk() => _ask('batteryAsk', true);
  Future<void> openAutostart() => _ask('openAutostart', true);
  Future<void> openExactSettings() => _ask('schedExactSettings', true);
}
