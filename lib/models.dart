import 'dart:math' as math;

/// Bandiera emoji dal codice paese (IT → 🇮🇹). Codice non valido → 🌍
String flagEmoji(String code) {
  final c = code.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '🌍';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 65));
}

String _s(Object? v) => v == null ? '' : v.toString().trim();

int _i(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_s(v)) ?? 0;
}

double? _d(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v));
}

/// Una stazione radio.
class Station {
  final String id;
  final String name;
  final String url;
  final String favicon;
  final String country;
  final String countryCode;
  final String state;
  final String tags;
  final String language;
  final String languageCodes;
  final int clicks;
  final double? lat;
  final double? lng;
  final String homepage;

  const Station({
    required this.id,
    required this.name,
    required this.url,
    this.favicon = '',
    this.country = '',
    this.countryCode = '',
    this.state = '',
    this.tags = '',
    this.language = '',
    this.languageCodes = '',
    this.clicks = 0,
    this.lat,
    this.lng,
    this.homepage = '',
  });

  bool get hasGeo => lat != null && lng != null;
  String get flag => flagEmoji(countryCode);
  bool get hasLogo => favicon.startsWith('http');

  String get place {
    final parts = [if (state.isNotEmpty) state, if (country.isNotEmpty) country];
    return parts.isEmpty ? 'Mondo' : parts.join(', ');
  }

  /// Dal formato di Radio Browser. Ritorna null se i dati sono inutilizzabili.
  static Station? fromApi(Map<String, dynamic> j) {
    final id = _s(j['stationuuid']);
    final resolved = _s(j['url_resolved']);
    final url = resolved.startsWith('http') ? resolved : _s(j['url']);
    final name = _s(j['name']);
    if (id.isEmpty || name.isEmpty || !url.startsWith('http')) return null;
    double? lat = _d(j['geo_lat']);
    double? lng = _d(j['geo_long']);
    if (lat == null ||
        lng == null ||
        lat.isNaN ||
        lng.isNaN ||
        lat.abs() > 85 ||
        lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      lat = null;
      lng = null;
    }
    return Station(
      id: id,
      name: name,
      url: url,
      favicon: _s(j['favicon']),
      country: _s(j['country']),
      countryCode: _s(j['countrycode']).toUpperCase(),
      state: _s(j['state']),
      tags: _s(j['tags']),
      language: _s(j['language']),
      languageCodes: _s(j['languagecodes']),
      clicks: _i(j['clickcount']) + _i(j['votes']),
      lat: lat,
      lng: lng,
      homepage: _s(j['homepage']),
    );
  }

  /// Formato compatto per il salvataggio sul telefono.
  List<Object?> toCompact() => [
        id, name, url, favicon, country, countryCode, state, tags, language, languageCodes,
        clicks, lat, lng, homepage,
      ];

  static Station? fromCompact(Object? o) {
    if (o is! List || o.length < 14) return null;
    final id = _s(o[0]), url = _s(o[2]);
    if (id.isEmpty || !url.startsWith('http')) return null;
    return Station(
      id: id,
      name: _s(o[1]),
      url: url,
      favicon: _s(o[3]),
      country: _s(o[4]),
      countryCode: _s(o[5]),
      state: _s(o[6]),
      tags: _s(o[7]),
      language: _s(o[8]),
      languageCodes: _s(o[9]),
      clicks: _i(o[10]),
      lat: _d(o[11]),
      lng: _d(o[12]),
      homepage: _s(o[13]),
    );
  }

  @override
  bool operator ==(Object other) => other is Station && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Un punto sulla mappa: una città/zona con una o più radio.
class Place {
  final double lat;
  final double lng;
  final String label;
  final String countryCode;
  final List<Station> stations;

  const Place(this.lat, this.lng, this.label, this.countryCode, this.stations);

  String get flag => flagEmoji(countryCode);
}

/// Raggruppa le stazioni vicine (circa 50 km) in un solo punto.
List<Place> buildPlaces(Iterable<Station> stations) {
  final groups = <String, List<Station>>{};
  for (final s in stations) {
    if (!s.hasGeo) continue;
    final key = '${(s.lat! * 2).round()}_${(s.lng! * 2).round()}';
    groups.putIfAbsent(key, () => []).add(s);
  }
  final places = <Place>[];
  for (final g in groups.values) {
    var lat = 0.0, lng = 0.0;
    for (final s in g) {
      lat += s.lat!;
      lng += s.lng!;
    }
    final first = g.first;
    final label = first.state.isNotEmpty && first.state != first.country
        ? '${first.state}, ${first.country}'
        : (first.country.isEmpty ? 'Mondo' : first.country);
    places.add(Place(lat / g.length, lng / g.length, label, first.countryCode, List.unmodifiable(g)));
  }
  places.sort((a, b) => a.stations.length.compareTo(b.stations.length));
  return places;
}

/// Colore allegro e sempre uguale per una radio senza logo.
int funColorFor(String id) {
  const colors = [0xFFFFCC00, 0xFFFF6B6B, 0xFF4ECDC4, 0xFF7C6CFF, 0xFFFF9F43, 0xFF2ED573, 0xFFFF6FB5];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return colors[h % colors.length];
}

double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
