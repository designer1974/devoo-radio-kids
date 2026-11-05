import 'package:devoo_radio_kids/recording.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durate e nomi dei file', () {
    expect(fmtLen(const Duration(minutes: 45)), '45 min');
    expect(fmtLen(const Duration(minutes: 60)), '1 ora');
    expect(fmtLen(const Duration(minutes: 90)), '1 h 30 min');
    expect(fmtDur(const Duration(minutes: 3, seconds: 7)), '03:07');
    expect(cleanName('🇮🇹 Radio: Bimbi/Ok?'), '🇮🇹 Radio Bimbi Ok');
  });

  test('programma letto dal telefono', () {
    final s = Schedule.from({'id': 'x', 'name': 'Kids', 'url': 'http://a', 'start': 0, 'end': 3600000, 'daily': true})!;
    expect(s.length, const Duration(hours: 1));
    expect(s.daily, isTrue);
    expect(Schedule.from({'id': 'x'}), isNull);
  });
}
