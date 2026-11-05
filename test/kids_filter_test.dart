import 'package:devoo_radio_kids/kids_filter.dart';
import 'package:devoo_radio_kids/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('riconosce le radio per bambini', () {
    expect(isKidStation('Radio Bambini', ''), isTrue);
    expect(isKidStation('Kinderradio Würzburg', 'kinder,music'), isTrue);
    expect(isKidStation('Some FM', 'kids,pop'), isTrue);
    expect(isKidStation('Some FM', 'kid'), isTrue);
    expect(isKidStation('Radio Enfants', 'comptines'), isTrue);
  });

  test('esclude le radio non adatte e i falsi amici', () {
    expect(isKidStation('Kid Rock Radio', 'kid rock,rock'), isFalse);
    expect(isKidStation('Kids FM', 'kids,adult contemporary'), isFalse);
    expect(isKidStation('Heart Sussex', 'pop'), isFalse);
    expect(isKidStation('Rock FM', 'rock,pop'), isFalse);
  });

  test('tipi: nanna, storie, canzoni', () {
    expect(inCategory(KidCategory.sleep, 'Baby Lullabies', 'kids,lullaby'), isTrue);
    expect(inCategory(KidCategory.stories, 'Märchenradio', 'kinder,märchen'), isTrue);
    expect(inCategory(KidCategory.songs, 'Kids Hits', 'kids,pop'), isTrue);
    expect(inCategory(KidCategory.stories, 'Kids Hits', 'kids,pop'), isFalse);
    expect(inCategory(KidCategory.stories, 'Kids FM', 'kids,contemporary'), isFalse);
  });

  test('lingua: codici, nome e paese', () {
    final it = kidLangs.firstWhere((l) => l.code == 'it');
    final ar = kidLangs.firstWhere((l) => l.code == 'ar');
    expect(speaks(it, 'it', '', 'CH'), isTrue);
    expect(speaks(it, '', 'italian', 'US'), isTrue);
    expect(speaks(it, '', '', 'IT'), isTrue);
    expect(speaks(it, 'en', 'english', 'IT'), isFalse);
    expect(speaks(ar, 'ar,fr', '', 'MA'), isTrue);
  });

  test('salvataggio compatto', () {
    const s = Station(id: 'a', name: 'Kids', url: 'http://x', language: 'italian', clicks: 5, lat: 41.9, lng: 12.5);
    final back = Station.fromCompact(s.toCompact())!;
    expect(back.name, 'Kids');
    expect(back.language, 'italian');
    expect(back.clicks, 5);
    expect(back.lat, 41.9);
    expect(buildPlaces([s, back]).length, 1);
  });
}
