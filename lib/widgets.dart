import 'package:flutter/material.dart';

import 'models.dart';
import 'player.dart';
import 'store.dart';

/// Colori di devoo.it: blu notte molto scuro, con il giallo dei bambini.
const navy = Color(0xFF060A16);
const navy2 = Color(0xFF0E1530);
const card = Color(0xFF151E40);
const yellow = Color(0xFFFFCC00);
const yellowSoft = Color(0xFFFFE680);

final tabIndex = ValueNotifier<int>(0);

/// Logo della radio, o un cerchio colorato con una nota se il logo manca.
class StationLogo extends StatelessWidget {
  const StationLogo(this.station, {super.key, this.size = 56, this.radius = 16});
  final Station station;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = Color(funColorFor(station.id));
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: Text(
        station.name.characters.isEmpty ? '🎵' : station.name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w900, color: navy),
      ),
    );
    if (!station.hasLogo) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          station.favicon,
          width: size,
          height: size,
          fit: BoxFit.contain,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

/// Riquadro grande di una radio, facile da toccare per i bambini.
class StationCard extends StatelessWidget {
  const StationCard(this.station, {super.key});
  final Station station;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([RadioPlayer.i, Library.i]),
      builder: (context, _) {
        final current = RadioPlayer.i.isCurrent(station);
        final playing = current && RadioPlayer.i.isPlaying;
        final fav = Library.i.isFavorite(station);
        return Material(
          color: current ? yellow : card,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => current ? RadioPlayer.i.toggle() : RadioPlayer.i.play(station),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (_, c) => Center(
                              child: StationLogo(station, size: c.biggest.shortestSide, radius: 20),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _RoundIcon(
                            icon: fav ? Icons.favorite : Icons.favorite_border,
                            color: fav ? const Color(0xFFFF4D6D) : Colors.white,
                            onTap: () => Library.i.toggleFavorite(station),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: current ? navy : yellow,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                            ),
                            child: current && RadioPlayer.i.isBuffering
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(strokeWidth: 3, color: yellow),
                                  )
                                : Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                    color: current ? yellow : navy, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    station.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.15,
                      color: current ? navy : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${station.flag} ${station.country.isEmpty ? 'Mondo' : station.country}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: current ? navy.withValues(alpha: 0.75) : Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, color: color, size: 22)),
      ),
    );
  }
}

/// Griglia di radio che si adatta allo schermo (telefono, tablet).
class StationGrid extends StatelessWidget {
  const StationGrid(this.stations, {super.key, this.padding = const EdgeInsets.fromLTRB(14, 6, 14, 20)});
  final List<Station> stations;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.74,
        ),
        itemCount: stations.length,
        itemBuilder: (_, i) => StationCard(stations[i]),
      ),
    );
  }
}

/// Lettore in basso: giallo, grande, con lo spegnimento per la nanna.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RadioPlayer.i,
      builder: (context, _) {
        final p = RadioPlayer.i;
        final s = p.current;
        if (s == null) return const SizedBox.shrink();
        final sub = p.isBuffering
            ? 'Mi collego…'
            : (p.nowPlaying ?? '${s.flag} ${s.place}');
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: yellow,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              StationLogo(s, size: 50, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: navy.withValues(alpha: 0.75), fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Spegni dopo…',
                onPressed: () => showSleepSheet(context),
                icon: Icon(p.sleepAt == null ? Icons.bedtime_outlined : Icons.bedtime, color: navy),
              ),
              SizedBox(
                width: 54,
                height: 54,
                child: Material(
                  color: navy,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: p.toggle,
                    child: p.isBuffering
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(strokeWidth: 3, color: yellow),
                          )
                        : Icon(p.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: yellow, size: 34),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showSleepSheet(BuildContext context) {
  final p = RadioPlayer.i;
  String left() {
    final at = p.sleepAt;
    if (at == null) return '';
    final m = at.difference(DateTime.now()).inMinutes + 1;
    return 'Si spegne tra $m min';
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: navy2,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🌙 Spegni la radio dopo…',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            if (p.sleepAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(left(), style: const TextStyle(color: yellowSoft)),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in const [10, 20, 30, 45, 60])
                  ActionChip(
                    label: Text('$m min'),
                    labelStyle: const TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 16),
                    backgroundColor: yellow,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: () {
                      p.setSleep(Duration(minutes: m));
                      Navigator.pop(c);
                    },
                  ),
                if (p.sleepAt != null)
                  ActionChip(
                    label: const Text('Annulla'),
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    backgroundColor: card,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    onPressed: () {
                      p.setSleep(null);
                      Navigator.pop(c);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pillola colorata per i filtri.
class FunChip extends StatelessWidget {
  const FunChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? yellow : card,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(label,
                style: TextStyle(
                  color: selected ? navy : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                )),
          ),
        ),
      ),
    );
  }
}

/// Messaggio grande e simpatico (caricamento, errore, vuoto).
class BigMessage extends StatelessWidget {
  const BigMessage({super.key, required this.emoji, required this.text, this.action});
  final String emoji;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
