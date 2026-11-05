import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'player.dart';
import 'recording.dart';
import 'schedule_page.dart';
import 'widgets.dart';

/// Le registrazioni: quelle programmate e quelle salvate, da riascoltare quando vuoi.
class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});
  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  final _audio = AudioPlayer();
  String? _playing; // file in ascolto
  Duration _pos = Duration.zero;
  Duration _len = Duration.zero;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_audio.onPlayerComplete.listen((_) => setState(() => _playing = null)))
      ..add(_audio.onPositionChanged.listen((p) => setState(() => _pos = p)))
      ..add(_audio.onDurationChanged.listen((d) => setState(() => _len = d)));
    // la radio riparte: la registrazione in ascolto si ferma
    RadioPlayer.i.addListener(_radioChanged);
    Recordings.i.reload();
    Schedules.i.reload();
  }

  void _radioChanged() {
    if (_playing != null && RadioPlayer.i.wantsPlay) {
      _audio.stop();
      setState(() => _playing = null);
    }
  }

  @override
  void dispose() {
    RadioPlayer.i.removeListener(_radioChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggle(RecFile r) async {
    if (_playing == r.file.path) {
      await _audio.stop();
      setState(() => _playing = null);
      return;
    }
    if (RecController.i.recording) {
      _snack('Stai registrando: ferma prima la registrazione');
      return;
    }
    await RadioPlayer.i.stop(); // una cosa alla volta
    try {
      await _audio.stop();
      setState(() {
        _playing = r.file.path;
        _pos = Duration.zero;
        _len = r.duration ?? Duration.zero;
      });
      await _audio.play(DeviceFileSource(r.file.path));
    } catch (_) {
      setState(() => _playing = null);
      _snack('Non riesco ad aprire questa registrazione');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)));

  Future<void> _rename(RecFile r) async {
    final c = TextEditingController(text: r.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: navy2,
        title: const Text('✏️ Nuovo nome', style: TextStyle(color: Colors.white)),
        content: TextField(controller: c, autofocus: true, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Salva')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.trim().isEmpty || name.trim() == r.name) return;
    if (_playing == r.file.path) {
      await _audio.stop();
      setState(() => _playing = null);
    }
    await Recordings.i.rename(r, name);
  }

  Future<void> _delete(RecFile r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: navy2,
        title: const Text('🗑️ Eliminare?', style: TextStyle(color: Colors.white)),
        content: Text('«${r.name}» sarà cancellata.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF4D6D), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_playing == r.file.path) {
      await _audio.stop();
      setState(() => _playing = null);
    }
    await Recordings.i.delete(r);
  }

  Future<void> _share(RecFile r) async {
    try {
      await Share.shareXFiles([XFile(r.file.path, mimeType: 'audio/mp4')], text: r.name);
    } catch (_) {
      _snack('Condivisione non riuscita');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([Recordings.i, Schedules.i]),
        builder: (context, _) {
          final recs = Recordings.i.items;
          final sched = Schedules.i.items;
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Text('🎙️ Registrate',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: navy,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      onPressed: () => openScheduleEditor(context, station: RadioPlayer.i.current),
                      icon: const Icon(Icons.alarm_add_rounded, size: 26),
                      label: const Text('Programma una registrazione'),
                    ),
                  ),
                ),
              ),
              if (sched.isNotEmpty) ...[
                const _Title('⏰ Programmate'),
                SliverList.builder(
                  itemCount: sched.length,
                  itemBuilder: (_, i) => _ScheduleTile(sched[i]),
                ),
              ],
              const _Title('🎧 Le mie registrazioni'),
              if (recs.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 30),
                    child: Text(
                      'Ancora niente qui. Mentre ascolti una radio tocca il pulsante rosso ● per registrarla, '
                      'oppure programmala per un\'ora precisa ⏰.',
                      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.4),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 20),
                  sliver: SliverList.builder(
                    itemCount: recs.length,
                    itemBuilder: (_, i) => _recTile(recs[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _recTile(RecFile r) {
    final on = _playing == r.file.path;
    final total = on && _len > Duration.zero ? _len : (r.duration ?? Duration.zero);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: on ? yellow : card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Material(
                  color: on ? navy : yellow,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _toggle(r),
                    child: Icon(on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: on ? yellow : navy, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: on ? navy : Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(
                      '${fmtDate(r.date)} · ${total == Duration.zero ? '…' : fmtDur(total)} · ${fmtSize(r.size)}',
                      style: TextStyle(color: on ? navy.withValues(alpha: 0.75) : Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                iconColor: on ? navy : Colors.white70,
                color: navy2,
                onSelected: (v) => switch (v) {
                  'share' => _share(r),
                  'rename' => _rename(r),
                  _ => _delete(r),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: Text('📤 Condividi', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'rename', child: Text('✏️ Rinomina', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'delete', child: Text('🗑️ Elimina', style: TextStyle(color: Colors.white))),
                ],
              ),
            ],
          ),
          if (on && total > Duration.zero)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Text(fmtDur(_pos), style: const TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Slider(
                      value: _pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                      max: total.inMilliseconds.toDouble(),
                      activeColor: navy,
                      inactiveColor: navy.withValues(alpha: 0.25),
                      thumbColor: navy,
                      onChanged: (v) => _audio.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(fmtDur(total), style: const TextStyle(color: navy, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile(this.s);
  final Schedule s;

  @override
  Widget build(BuildContext context) {
    final when = s.daily
        ? 'ogni giorno ${hhmm(s.start)} – ${hhmm(s.end)}'
        : '${dayLabel(s.start)} ${hhmm(s.start)} – ${hhmm(s.end)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: s.running ? Border.all(color: const Color(0xFFFF4D6D), width: 2) : null,
      ),
      child: Row(
        children: [
          Text(s.running ? '🔴' : '⏰', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.flag.isEmpty ? '' : '${s.flag} '}${s.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 2),
                Text(s.running ? 'Sto registrando · fino alle ${hhmm(s.end)}' : '$when · ${fmtLen(s.length)}',
                    style: TextStyle(color: s.running ? const Color(0xFFFF8FA3) : yellowSoft, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: s.running ? 'Ferma e salva' : 'Elimina',
            icon: Icon(s.running ? Icons.stop_circle_rounded : Icons.delete_outline_rounded,
                color: s.running ? const Color(0xFFFF4D6D) : Colors.white60, size: 28),
            onPressed: () => s.running ? RecController.i.stopAny() : Schedules.i.remove(s),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );
}
