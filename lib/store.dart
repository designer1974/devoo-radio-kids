import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'kids_filter.dart';
import 'models.dart';

/// Tutte le radio per bambini. Salvate sul telefono: l'app si apre subito,
/// e l'elenco si aggiorna da solo ogni 3 giorni.
class KidsStore extends ChangeNotifier {
  KidsStore._();
  static final i = KidsStore._();

  static const _maxAge = Duration(days: 3);

  List<Station> stations = const [];
  List<Place> places = const [];
  bool loading = false;
  double progress = 0;
  String? error;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/kids_stations_v1.json');
  }

  Future<void> init() async {
    var fresh = false;
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = await compute(_decode, await f.readAsString());
        if (list.isNotEmpty) {
          _set(list);
          fresh = DateTime.now().difference(await f.lastModified()) < _maxAge;
        }
      }
    } catch (_) {
      // cache rovinata: si riscarica
    }
    if (!fresh) unawaited(refresh());
  }

  void _set(List<Station> list) {
    stations = List.unmodifiable(list);
    places = buildPlaces(stations);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    progress = 0;
    notifyListeners();

    final jobs = <Future<List<Station>> Function()>[
      for (final (tag, exact) in kidTagQueries) () => RadioApi.i.search(tag: tag, tagExact: exact),
      for (final n in kidNameQueries) () => RadioApi.i.search(name: n, limit: 200),
    ];
    final found = <String, Station>{};
    var ok = 0;
    // 4 ricerche alla volta: veloce ma senza stressare i server
    for (var k = 0; k < jobs.length; k += 4) {
      final batch = jobs.skip(k).take(4).map((j) => j().then<List<Station>?>((v) => v, onError: (Object _) => null));
      for (final list in await Future.wait(batch)) {
        if (list == null) continue;
        ok++;
        for (final s in list) {
          if (isKidStation(s.name, s.tags)) found[s.id] = s;
        }
      }
      progress = (k + 4) / jobs.length;
      if (stations.isEmpty && found.isNotEmpty) _set(_sorted(found.values)); // si vedono subito
      notifyListeners();
    }

    final all = _sorted(found.values);
    if (ok == 0 && stations.isEmpty) {
      error = 'Nessuna connessione. Controlla internet e riprova.';
    } else if (all.length >= 10 || all.length >= stations.length) {
      _set(all);
      try {
        final f = await _file();
        await f.writeAsString(await compute(_encode, all), flush: true);
      } catch (_) {}
    }
    loading = false;
    progress = 1;
    notifyListeners();
  }

  static List<Station> _sorted(Iterable<Station> list) => list.toList()..sort((a, b) => b.clicks.compareTo(a.clicks));

  /// Le lingue che hanno almeno una radio.
  List<KidLang> get languages => [
        for (final l in kidLangs)
          if (stations.any((s) => speaks(l, s.languageCodes, s.language, s.countryCode))) l,
      ];

  List<Station> filtered({KidCategory cat = KidCategory.all, KidLang? lang, String query = ''}) {
    final q = query.trim().toLowerCase();
    return [
      for (final s in stations)
        if (inCategory(cat, s.name, s.tags) &&
            (lang == null || speaks(lang, s.languageCodes, s.language, s.countryCode)) &&
            (q.isEmpty ||
                s.name.toLowerCase().contains(q) ||
                s.country.toLowerCase().contains(q) ||
                s.tags.toLowerCase().contains(q)))
          s,
    ];
  }

  Station? random() {
    if (stations.isEmpty) return null;
    final pool = stations.length > 60 ? stations.sublist(0, 60) : stations;
    return pool[DateTime.now().microsecondsSinceEpoch % pool.length];
  }
}

List<Station> _decode(String text) {
  final data = jsonDecode(text);
  if (data is! List) return const [];
  return data.map(Station.fromCompact).whereType<Station>().toList();
}

String _encode(List<Station> list) => jsonEncode(list.map((s) => s.toCompact()).toList());

/// Preferiti e ascoltate di recente.
class Library extends ChangeNotifier {
  Library._();
  static final i = Library._();

  static const _kFav = 'favorites_v1';
  static const _kRecent = 'recents_v1';
  static const _maxRecent = 20;

  SharedPreferences? _prefs;
  List<Station> favorites = [];
  List<Station> recents = [];

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      favorites = _read(_kFav);
      recents = _read(_kRecent);
    } catch (_) {}
  }

  List<Station> _read(String key) {
    try {
      final raw = _prefs?.getString(key);
      if (raw == null) return [];
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return data.map(Station.fromCompact).whereType<Station>().toList();
    } catch (_) {
      return [];
    }
  }

  void _write(String key, List<Station> list) {
    try {
      _prefs?.setString(key, jsonEncode(list.map((s) => s.toCompact()).toList()));
    } catch (_) {}
  }

  /// Ultima lingua scelta nel filtro (vuoto = tutte).
  String get langCode => _prefs?.getString('lang_filter') ?? '';
  set langCode(String v) {
    _prefs?.setString('lang_filter', v);
  }

  bool isFavorite(Station s) => favorites.any((f) => f.id == s.id);

  void toggleFavorite(Station s) {
    if (isFavorite(s)) {
      favorites.removeWhere((f) => f.id == s.id);
    } else {
      favorites.insert(0, s);
    }
    _write(_kFav, favorites);
    notifyListeners();
  }

  void addRecent(Station s) {
    recents.removeWhere((r) => r.id == s.id);
    recents.insert(0, s);
    if (recents.length > _maxRecent) recents = recents.sublist(0, _maxRecent);
    _write(_kRecent, recents);
    notifyListeners();
  }
}
