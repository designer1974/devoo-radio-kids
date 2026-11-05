import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'widgets.dart';

/// Numero della versione, messo da GitHub quando compila l'APK.
const appBuild = int.fromEnvironment('BUILD');
const _repo = 'designer1974/devoo-radio-kids';
const appChannel = MethodChannel('kids/app');

/// C'è una versione più nuova su GitHub? Se sì, propone di scaricarla.
Future<void> checkForUpdate(BuildContext context) async {
  if (appBuild <= 0) return;
  try {
    final r = await http.get(Uri.https('api.github.com', '/repos/$_repo/releases', {'per_page': '10'}),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'DevooRadioKids'}).timeout(
        const Duration(seconds: 15));
    if (r.statusCode != 200) return;
    final list = jsonDecode(r.body);
    if (list is! List) return;
    var is64 = true;
    try {
      is64 = await appChannel.invokeMethod<bool>('is64') ?? true;
    } catch (_) {}
    final want = is64 ? 'DevooRadioKids.apk' : 'DevooRadioKids-telefoni-vecchi.apk';
    var best = appBuild;
    String? url;
    for (final rel in list) {
      if (rel is! Map) continue;
      final tag = '${rel['tag_name']}';
      if (!tag.startsWith('build-')) continue;
      final n = int.tryParse(tag.substring(6)) ?? 0;
      if (n <= best) continue;
      for (final a in (rel['assets'] as List? ?? const [])) {
        if (a is Map && a['name'] == want) {
          best = n;
          url = '${a['browser_download_url']}';
        }
      }
    }
    if (url == null || !context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: navy2,
        title: const Text('🎉 Nuova versione!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('È pronta una versione nuova di Devoo Radio Kids. Vuoi scaricarla?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Dopo')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: yellow, foregroundColor: navy),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Scarica'),
          ),
        ],
      ),
    );
    if (go == true) await appChannel.invokeMethod<bool>('openUrl', {'url': url});
  } catch (_) {
    // senza internet si riprova al prossimo avvio
  }
}
