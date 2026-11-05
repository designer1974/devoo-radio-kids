/// Quali radio sono per bambini, di che tipo e in che lingua.
/// Tutto qui è logica pura (senza Flutter), così si può provare con i test.
library;

/// Le ricerche fatte su Radio Browser per trovare le radio per bambini.
/// (tag, esatto?) – i tag non esatti trovano anche le parole più lunghe:
/// "kinder" trova "kinderradio", "kindermusik"...
const kidTagQueries = <(String, bool)>[
  ('kids', false),
  ('kidz', false),
  ('kid', true),
  ('children', false),
  ('kinder', false),
  ('enfant', false),
  ('bambin', false),
  ('infantil', false),
  ('niños', false),
  ('crianças', false),
  ('lullab', false),
  ('nursery', false),
  ('berceuse', false),
  ('comptine', false),
  ('märchen', false),
  ('детск', false),
  ('çocuk', false),
  ('dzieci', false),
  ('أطفال', false),
];

/// Ricerche per nome della radio.
const kidNameQueries = <String>['kids', 'kidz', 'kinder', 'children', 'enfant', 'bambin', 'infantil', 'детск'];

/// Parole che indicano una radio per bambini (nel nome o nei tag).
const _kidWords = <String>[
  'kids', 'kidz', 'children', 'childrens', 'kinder', 'enfant', 'bambin', 'infantil',
  'niños', 'ninos', 'crianças', 'criancas', 'lullab', 'nursery', 'berceuse', 'comptine',
  'märchen', 'maerchen', 'ninna nanna', 'ninnenanne', 'fiab', 'favol', 'cuento', 'детск',
  'çocuk', 'cocuk', 'dzieci', 'أطفال', 'lasten', 'barnradio', 'barnmusik', 'kinderliedjes',
];

/// Parole che escludono subito una radio (non adatta ai bambini, o falso amico).
const _blockWords = <String>[
  'adult', 'sexy', 'xxx', 'erot', 'porn', '18+', 'explicit', 'nsfw', 'kid rock', 'kid cudi',
  'kid ink', 'kid laroi', 'hardcore', 'metal', 'gangsta', 'horror', 'drinking', 'dating',
  'kindergeld', 'casino', 'betting',
];

String _norm(String s) => s.toLowerCase();

/// È una radio per bambini? Serve almeno una parola "bambini" e nessuna parola vietata.
bool isKidStation(String name, String tags) {
  final n = _norm(name);
  final t = _norm(tags);
  final all = '$n,$t';
  for (final b in _blockWords) {
    if (all.contains(b)) return false;
  }
  final tagList = t.split(',').map((e) => e.trim()).toList();
  if (tagList.contains('sex') || n.split(RegExp(r'\W+')).contains('sex')) return false;
  if (tagList.contains('kid')) return true;
  for (final w in _kidWords) {
    if (all.contains(w)) return true;
  }
  return false;
}

/// Tipo di radio, per i filtri in alto.
enum KidCategory { all, songs, stories, sleep }

const _sleepWords = <String>[
  'lullab', 'berceuse', 'ninna', 'nanna', 'sleep', 'schlaf', 'canción de cuna', 'cuna',
  'slaap', 'колыбел', 'baby', 'bébé', 'bebe', 'relax', 'calm',
];
const _storyWords = <String>[
  'stor', 'fairy', 'märchen', 'maerchen', 'contes', 'cuento', 'fiab', 'favol', 'hörspiel',
  'horspiel', 'audiobook', 'audiolibr', 'histoire', 'sprookje', 'сказк', 'masal', 'bajk',
  'talk', 'parole', 'story',
];

bool _any(String text, List<String> words) => words.any(text.contains);

/// Una radio può stare in più tipi: le storie e la nanna si riconoscono dalle parole,
/// tutte le altre sono "canzoni".
bool inCategory(KidCategory c, String name, String tags) {
  final all = _norm('$name,$tags');
  switch (c) {
    case KidCategory.all:
      return true;
    case KidCategory.sleep:
      return _any(all, _sleepWords);
    case KidCategory.stories:
      return _any(all, _storyWords);
    case KidCategory.songs:
      return !_any(all, _storyWords) || all.contains('music') || all.contains('song');
  }
}

/// Una lingua del filtro.
class KidLang {
  final String code; // iso 639-1
  final String label;
  final String flag;
  final List<String> names; // come le scrive Radio Browser (in inglese)
  final List<String> countries; // paesi dove si parla di solito, se la lingua manca
  const KidLang(this.code, this.label, this.flag, this.names, this.countries);
}

const kidLangs = <KidLang>[
  KidLang('it', 'Italiano', '🇮🇹', ['italian', 'italiano'], ['IT', 'SM', 'VA']),
  KidLang('en', 'English', '🇬🇧', ['english'], ['GB', 'US', 'IE', 'AU', 'NZ', 'CA']),
  KidLang('fr', 'Français', '🇫🇷', ['french', 'français', 'francais'], ['FR', 'BE', 'LU', 'MC', 'SN', 'CI']),
  KidLang('es', 'Español', '🇪🇸', ['spanish', 'español', 'espanol'], ['ES', 'MX', 'AR', 'CO', 'CL', 'PE', 'VE']),
  KidLang('ar', 'العربية', '🇲🇦', ['arabic', 'العربية'], ['MA', 'DZ', 'TN', 'EG', 'SA', 'AE', 'JO', 'LB', 'IQ']),
  KidLang('de', 'Deutsch', '🇩🇪', ['german', 'deutsch'], ['DE', 'AT']),
  KidLang('nl', 'Nederlands', '🇳🇱', ['dutch', 'nederlands'], ['NL']),
  KidLang('pt', 'Português', '🇵🇹', ['portuguese', 'português', 'portugues'], ['PT', 'BR']),
  KidLang('tr', 'Türkçe', '🇹🇷', ['turkish', 'türkçe'], ['TR']),
  KidLang('ru', 'Русский', '🇷🇺', ['russian', 'русский'], ['RU', 'BY']),
  KidLang('pl', 'Polski', '🇵🇱', ['polish', 'polski'], ['PL']),
];

/// La radio parla questa lingua? Prima i codici lingua, poi il nome della lingua,
/// e solo se la radio non dice niente, il paese.
bool speaks(KidLang l, String languageCodes, String language, String countryCode) {
  final codes = _norm(languageCodes).split(RegExp(r'[,;\s]+')).where((e) => e.isNotEmpty).toList();
  final lang = _norm(language);
  if (codes.contains(l.code)) return true;
  if (l.names.any(lang.contains)) return true;
  if (codes.isEmpty && lang.trim().isEmpty) {
    return l.countries.contains(countryCode.toUpperCase());
  }
  return false;
}
