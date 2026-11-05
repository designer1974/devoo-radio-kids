import 'package:flutter/material.dart';

import 'models.dart';
import 'recording.dart';
import 'store.dart';
import 'widgets.dart';

const _weekdays = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

Future<void> openScheduleEditor(BuildContext context, {Station? station}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScheduleEditor(station: station)));

/// Programma una registrazione: radio, giorno, ora, durata, ogni giorno.
class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({super.key, this.station});
  final Station? station;
  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  Station? _station;
  int _day = 0; // 0 = oggi, 1 = domani…
  late TimeOfDay _time;
  int _durMin = 60;
  bool _daily = false;
  bool _saving = false;

  bool _exactOk = true;
  bool _batteryOk = true;
  bool _huawei = false;

  static const _durations = [15, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    // proposta: il prossimo quarto d'ora
    final now = DateTime.now();
    final next = ((now.hour * 60 + now.minute) ~/ 15 + 1) * 15;
    if (next >= 24 * 60) {
      _day = 1;
      _time = TimeOfDay(hour: (next - 24 * 60) ~/ 60, minute: next % 60);
    } else {
      _time = TimeOfDay(hour: next ~/ 60, minute: next % 60);
    }
    _checkPhone();
  }

  Future<void> _checkPhone() async {
    final e = await Schedules.i.exactOk();
    final b = await Schedules.i.batteryOk();
    final h = await Schedules.i.isHuawei();
    if (!mounted) return;
    setState(() {
      _exactOk = e;
      _batteryOk = b;
      _huawei = h;
    });
  }

  DateTime _dayBase(int d) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(Duration(days: d));
  }

  DateTime get _start {
    final b = _dayBase(_day);
    return DateTime(b.year, b.month, b.day, _time.hour, _time.minute);
  }

  DateTime get _end => _start.add(Duration(minutes: _durMin));

  String _dayName(int d) {
    if (d == 0) return 'Oggi';
    if (d == 1) return 'Domani';
    final b = _dayBase(d);
    final w = _weekdays[b.weekday - 1];
    return '${w[0].toUpperCase()}${w.substring(1)} ${b.day}';
  }

  String _durName(int m) => fmtLen(Duration(minutes: m));

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'A che ora inizia?',
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickStation() async {
    final s = await showStationPicker(context);
    if (s != null) setState(() => _station = s);
  }

  Future<void> _save() async {
    final s = _station;
    if (s == null) {
      _snack('Scegli prima la radio 📻');
      return;
    }
    var start = _start;
    final now = DateTime.now();
    if (_end.isBefore(now)) {
      _snack('Questo orario è già passato: scegli un\'ora più avanti');
      return;
    }
    if (start.isBefore(now)) start = now; // già iniziato: registra da adesso
    final over = Schedules.i.overlapping(start, _end);
    if (over.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: navy2,
          title: const Text('⚠️ Orario occupato', style: TextStyle(color: Colors.white)),
          content: Text(
            'A quest\'ora è già programmata «${over.first.name}». Si può registrare una sola radio alla volta: '
            'quella che inizia dopo verrà saltata.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cambia orario')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salva lo stesso')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _saving = true);
    try {
      await Schedules.i.add(s, start, _end, _daily);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('⏰ Programmata: ${s.name}, ${dayLabel(start)} alle ${hhmm(start)}'),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Non sono riuscito a programmarla. Riprova.');
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = _station;
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('⏰ Programma registrazione', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const _Label('📻 Radio'),
          Material(
            color: card,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _pickStation,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (s != null)
                      StationLogo(s, size: 54)
                    else
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.add_rounded, color: navy, size: 32),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s?.name ?? 'Scegli la radio',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
          const _Label('📅 Giorno'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 0; d < 7; d++) _Pick(_dayName(d), _day == d, () => setState(() => _day = d)),
            ],
          ),
          const _Label('🕒 Inizio'),
          Material(
            color: yellow,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _pickTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    '${two(_time.hour)}:${two(_time.minute)}',
                    style: const TextStyle(color: navy, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ),
              ),
            ),
          ),
          const _Label('⏳ Quanto dura'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _durations) _Pick(_durName(m), _durMin == m, () => setState(() => _durMin = m)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22)),
            child: SwitchListTile(
              value: _daily,
              onChanged: (v) => setState(() => _daily = v),
              activeThumbColor: navy,
              activeTrackColor: yellow,
              title: const Text('🔁 Ogni giorno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              subtitle: const Text('Registra alla stessa ora tutti i giorni', style: TextStyle(color: Colors.white60)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s == null
                ? ''
                : 'Registrerò «${s.name}» ${_daily ? 'ogni giorno' : dayLabel(_start)} '
                    'dalle ${hhmm(_start)} alle ${hhmm(_end)}. Funziona anche con l\'app chiusa e lo schermo spento.',
            style: const TextStyle(color: yellowSoft, fontSize: 15, height: 1.35),
          ),
          if (!_exactOk)
            _Warn(
              text: 'Per partire all\'ora giusta, permetti a Devoo Radio Kids di usare «Sveglie e promemoria».',
              button: 'Permetti',
              onTap: () async {
                await Schedules.i.openExactSettings();
                await Future<void>.delayed(const Duration(seconds: 2));
                _checkPhone();
              },
            ),
          if (!_batteryOk)
            _Warn(
              text: 'Il risparmio batteria potrebbe fermare la registrazione. Lascia lavorare l\'app senza limiti.',
              button: 'Consenti',
              onTap: () async {
                await Schedules.i.batteryAsk();
                await Future<void>.delayed(const Duration(seconds: 2));
                _checkPhone();
              },
            ),
          if (_huawei)
            _Warn(
              text: 'Sui telefoni Huawei/Honor attiva «Avvio app → Gestisci manualmente» per Devoo Radio Kids.',
              button: 'Apri',
              onTap: Schedules.i.openAutostart,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 60,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: navy,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.alarm_add_rounded, size: 28),
              label: const Text('Programma'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      );
}

class _Pick extends StatelessWidget {
  const _Pick(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? yellow : card,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(label,
                style: TextStyle(color: selected ? navy : Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      );
}

class _Warn extends StatelessWidget {
  const _Warn({required this.text, required this.button, required this.onTap});
  final String text;
  final String button;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3A2A00),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: yellow.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, height: 1.3))),
            TextButton(onPressed: onTap, child: Text(button, style: const TextStyle(color: yellow, fontWeight: FontWeight.w900))),
          ],
        ),
      );
}

/// Scegli una radio: prima i preferiti, poi tutte, con la ricerca.
Future<Station?> showStationPicker(BuildContext context) {
  return showModalBottomSheet<Station>(
    context: context,
    backgroundColor: navy2,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => const _StationPicker(),
  );
}

class _StationPicker extends StatefulWidget {
  const _StationPicker();
  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final fav = Library.i.favorites;
    final seen = <String>{};
    final all = [
      for (final s in [...fav, ...Library.i.recents, ...KidsStore.i.stations])
        if (seen.add(s.id) && (_q.isEmpty || s.name.toLowerCase().contains(_q.toLowerCase()))) s,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cerca una radio…',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search_rounded, color: yellow),
                filled: true,
                fillColor: card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: all.length,
              itemBuilder: (_, i) {
                final s = all[i];
                return ListTile(
                  leading: StationLogo(s, size: 44, radius: 12),
                  title: Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text('${s.flag} ${s.country}', style: const TextStyle(color: Colors.white60)),
                  trailing: Library.i.isFavorite(s) ? const Icon(Icons.favorite, color: Color(0xFFFF4D6D)) : null,
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
