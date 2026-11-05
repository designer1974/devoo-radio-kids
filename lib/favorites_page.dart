import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';

/// Le radio col cuore, e quelle ascoltate di recente.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Library.i,
        builder: (context, _) {
          final fav = Library.i.favorites;
          final rec = Library.i.recents.where((r) => !Library.i.isFavorite(r)).take(10).toList();
          if (fav.isEmpty && rec.isEmpty) {
            return const BigMessage(
              emoji: '❤️',
              text: 'Tocca il cuore sulle radio che ti piacciono: le ritrovi tutte qui!',
            );
          }
          return CustomScrollView(
            slivers: [
              if (fav.isNotEmpty) ...[
                const _Title('❤️ Le mie radio'),
                StationGrid(fav),
              ],
              if (rec.isNotEmpty) ...[
                const _Title('🕒 Ascoltate da poco'),
                StationGrid(rec),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}
