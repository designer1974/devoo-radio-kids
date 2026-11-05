import 'package:flutter/material.dart';

import 'kids_filter.dart';
import 'player.dart';
import 'store.dart';
import 'widgets.dart';

/// La pagina principale: tutte le radio per bambini, con filtri grandi e semplici.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  KidCategory _cat = KidCategory.all;
  String _lang = Library.i.langCode;
  final _search = TextEditingController();
  String _q = '';

  static const _cats = {
    KidCategory.all: '⭐ Tutte',
    KidCategory.songs: '🎵 Canzoni',
    KidCategory.stories: '📖 Storie',
    KidCategory.sleep: '🌙 Nanna',
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: KidsStore.i,
        builder: (context, _) {
          final store = KidsStore.i;
          final langs = store.languages;
          final lang = langs.where((l) => l.code == _lang).firstOrNull;
          final list = store.filtered(cat: _cat, lang: lang, query: _q);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(store)),
              SliverToBoxAdapter(child: _searchBox()),
              SliverToBoxAdapter(
                child: _chipRow([
                  for (final e in _cats.entries)
                    FunChip(label: e.value, selected: _cat == e.key, onTap: () => setState(() => _cat = e.key)),
                ]),
              ),
              if (langs.isNotEmpty)
                SliverToBoxAdapter(
                  child: _chipRow([
                    FunChip(label: '🌍 Tutte le lingue', selected: lang == null, onTap: () => _setLang('')),
                    for (final l in langs)
                      FunChip(label: '${l.flag} ${l.label}', selected: lang == l, onTap: () => _setLang(l.code)),
                  ]),
                ),
              if (store.loading && store.stations.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: LinearProgressIndicator(color: yellow, backgroundColor: card, minHeight: 4),
                  ),
                ),
              if (store.stations.isEmpty && store.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: BigMessage(emoji: '🎈', text: 'Sto cercando le radio per bambini di tutto il mondo…'),
                )
              else if (store.stations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: BigMessage(
                    emoji: '📡',
                    text: store.error ?? 'Nessuna radio trovata.',
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: yellow, foregroundColor: navy),
                      onPressed: store.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                    ),
                  ),
                )
              else if (list.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: BigMessage(emoji: '🔍', text: 'Nessuna radio qui. Prova un altro filtro!'),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                    child: Text('${list.length} radio',
                        style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                  ),
                ),
                StationGrid(list),
              ],
            ],
          );
        },
      ),
    );
  }

  void _setLang(String code) {
    setState(() => _lang = code);
    Library.i.langCode = code;
  }

  Widget _header(KidsStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/logo.png', width: 48, height: 48),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Devoo Radio',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                SizedBox(height: 4),
                _KidsBadge(),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Una radio a sorpresa',
            iconSize: 30,
            onPressed: () {
              final s = store.random();
              if (s != null) RadioPlayer.i.play(s);
            },
            icon: const Text('🎲', style: TextStyle(fontSize: 28)),
          ),
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: store.loading ? null : store.refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _q = v),
        style: const TextStyle(color: Colors.white, fontSize: 17),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cerca una radio…',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: yellow),
          suffixIcon: _q.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () {
                    _search.clear();
                    setState(() => _q = '');
                  },
                ),
          filled: true,
          fillColor: card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: yellow, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        children: chips,
      ),
    );
  }
}

class _KidsBadge extends StatelessWidget {
  const _KidsBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: yellow, borderRadius: BorderRadius.circular(20)),
      child: const Text('KIDS',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
    );
  }
}
