import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'store.dart';
import 'widgets.dart';

const _esri = 'https://server.arcgisonline.com/ArcGIS/rest/services';

/// La mappa del mondo con le radio per bambini: un pallino giallo per ogni città.
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KidsStore.i,
      builder: (context, _) {
        final places = KidsStore.i.places;
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(38, 12),
                initialZoom: 3,
                minZoom: 2,
                maxZoom: 14,
                backgroundColor: navy,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate: '$_esri/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.designer1974.devoo_radio_kids',
                  maxNativeZoom: 18,
                ),
                TileLayer(
                  urlTemplate: '$_esri/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.designer1974.devoo_radio_kids',
                  maxNativeZoom: 18,
                ),
                MarkerLayer(
                  markers: [
                    for (final p in places)
                      Marker(
                        point: LatLng(p.lat, p.lng),
                        width: _size(p),
                        height: _size(p),
                        child: GestureDetector(
                          onTap: () => _openPlace(context, p),
                          child: Container(
                            decoration: BoxDecoration(
                              color: yellow,
                              shape: BoxShape.circle,
                              border: Border.all(color: navy, width: 2.5),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${p.stations.length}',
                              style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌍', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          KidsStore.i.loading && places.isEmpty
                              ? 'Cerco le radio…'
                              : 'Tocca un pallino giallo!',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _size(Place p) => (30 + p.stations.length * 2).clamp(30, 48).toDouble();

  void _openPlace(BuildContext context, Place p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: navy2,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => CustomScrollView(
          controller: scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text('${p.flag} ${p.label}',
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            StationGrid(p.stations),
          ],
        ),
      ),
    );
  }
}
