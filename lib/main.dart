import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bench_store.dart';

void main() => runApp(const BenchSpotApp());

const _berry = Color(0xFF854442);
const _cocoa = Color(0xFF4B3832);
const _cream = Color(0xFFFFF4E6);
const _paper = _cream;
const _latte = Color(0xFFBE9B7B);
const _latteWash = Color(0x2EBE9B7B);
const _ink = Color(0xFF3C2F2F);

class BenchSpotApp extends StatefulWidget {
  const BenchSpotApp({super.key, BenchStore? store}) : _providedStore = store;

  final BenchStore? _providedStore;

  @override
  State<BenchSpotApp> createState() => _BenchSpotAppState();
}

class _BenchSpotAppState extends State<BenchSpotApp> {
  late final BenchStore _store = widget._providedStore ?? BenchStore();
  late Future<void> _loading = _store.load();
  ExploreArea? _area;
  LatLng? _deviceLocation;

  @override
  void dispose() {
    if (widget._providedStore == null) _store.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation(BuildContext context) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on Location Services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception(
            'Location permission was denied. You can still browse cities.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is disabled for Bench Spot. Enable it in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _deviceLocation = LatLng(position.latitude, position.longitude);
        _area = ExploreArea('Nearby benches', _deviceLocation);
      });
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location: $error')),
      );
    }
  }

  void _selectArea(ExploreArea area) {
    setState(() {
      _area = area;
      _deviceLocation = null;
    });
  }

  void _changeArea() {
    setState(() {
      _area = null;
      _deviceLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bench Spot',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _berry,
          primary: _berry,
          surface: _paper,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _cream,
          foregroundColor: _berry,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _latte.withValues(alpha: 0.55)),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadErrorScreen(
              error: snapshot.error!,
              onRetry: () => setState(() => _loading = _store.load()),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_area == null) {
            return _WelcomeScreen(
              onSelectArea: _selectArea,
              onUseLocation: () => _useCurrentLocation(context),
            );
          }
          return _MapScreen(
            key: ValueKey('${_area!.name}-${_deviceLocation?.latitude}'),
            store: _store,
            area: _area!,
            deviceLocation: _deviceLocation,
            onChangeArea: _changeArea,
            onUseLocation: () => _useCurrentLocation(context),
          );
        },
      ),
    );
  }
}

class ExploreArea {
  const ExploreArea(this.name, this.center);

  final String name;
  final LatLng? center;
}

const _areas = [
  ExploreArea('Explore all Belgium', null),
  ExploreArea('Brussels', LatLng(50.8503, 4.3517)),
  ExploreArea('Antwerp', LatLng(51.2194, 4.4025)),
  ExploreArea('Ghent', LatLng(51.0543, 3.7174)),
  ExploreArea('Charleroi', LatLng(50.4108, 4.4446)),
  ExploreArea('Liège', LatLng(50.6326, 5.5797)),
  ExploreArea('Leuven', LatLng(50.8798, 4.7005)),
  ExploreArea('Bruges', LatLng(51.2093, 3.2247)),
  ExploreArea('Namur', LatLng(50.4674, 4.8718)),
  ExploreArea('Mons', LatLng(50.4542, 3.9563)),
  ExploreArea('Mechelen', LatLng(51.0259, 4.4776)),
  ExploreArea('Hasselt', LatLng(50.9307, 5.3325)),
  ExploreArea('Tournai', LatLng(50.6056, 3.3878)),
  ExploreArea('Kortrijk', LatLng(50.8278, 3.2650)),
  ExploreArea('Ostend', LatLng(51.2300, 2.9110)),
  ExploreArea('La Louvière', LatLng(50.4782, 4.1873)),
  ExploreArea('Louvain-la-Neuve', LatLng(50.6680, 4.6110)),
];

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 44, color: _cocoa),
                const SizedBox(height: 12),
                const Text(
                  'Bench Spot could not open its saved data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({
    required this.onSelectArea,
    required this.onUseLocation,
  });

  final ValueChanged<ExploreArea> onSelectArea;
  final VoidCallback onUseLocation;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/autumn-bench.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x293C2F2F), Color(0x423C2F2F)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/benchspot-icon.png',
                            width: 36,
                            height: 36,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'bench spot',
                          style: TextStyle(
                            color: _cream,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                color: Color(0x993C2F2F),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'BENCH SPOT · BELGIUM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cream,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  fontSize: 11,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xF23C2F2F),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 9),
                              const Text(
                                'Find your little pause.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cream,
                                  fontSize: 38,
                                  height: 1.05,
                                  letterSpacing: -1.3,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xF23C2F2F),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 9),
                              const Text(
                                'Choose a city and discover a place to sit, slow down, and stay awhile.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cream,
                                  fontSize: 14,
                                  height: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xF23C2F2F),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: const Color(0xF0FFF4E6),
                                  border: Border.all(
                                    color: const Color(0xBDFFF4E6),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x473C2F2F),
                                      blurRadius: 40,
                                      offset: Offset(0, 18),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Choose a city to explore',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final selected =
                                              await showModalBottomSheet<
                                                  ExploreArea>(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            backgroundColor: _cream,
                                            builder: (_) =>
                                                const _CityPickerSheet(),
                                          );
                                          if (selected != null) {
                                            onSelectArea(selected);
                                          }
                                        },
                                        icon: const Icon(Icons.location_city),
                                        label: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          child: Text('Choose a city'),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _cocoa,
                                          side: const BorderSide(color: _latte),
                                          backgroundColor: _cream,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Or find places close to you',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: _ink),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: onUseLocation,
                                        icon: const Icon(Icons.my_location),
                                        label: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                          child: Text('Use my location'),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _berry,
                                          foregroundColor: _cream,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Your location is only used to find nearby benches.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _cocoa,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No rush. Your next quiet moment is waiting.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _cream,
                                  fontSize: 12,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xF23C2F2F),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _areas
        .where((area) => area.name.toLowerCase().contains(query))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a city',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search Belgian cities',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final area = filtered[index];
                  return ListTile(
                    leading: Icon(
                      area.center == null ? Icons.map_outlined : Icons.place,
                      color: _berry,
                    ),
                    title: Text(area.name),
                    onTap: () => Navigator.pop(context, area),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapScreen extends StatefulWidget {
  const _MapScreen({
    super.key,
    required this.store,
    required this.area,
    required this.deviceLocation,
    required this.onChangeArea,
    required this.onUseLocation,
  });

  final BenchStore store;
  final ExploreArea area;
  final LatLng? deviceLocation;
  final VoidCallback onChangeArea;
  final VoidCallback onUseLocation;

  @override
  State<_MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<_MapScreen> {
  final MapController _mapController = MapController();
  bool _adding = false;
  int _nearbyRadius = 10;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _openAddForm(LatLng point) {
    setState(() => _adding = false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _cream,
      builder: (_) => _AddSpotSheet(
        store: widget.store,
        location: point,
        areaName: widget.area.name,
      ),
    );
  }

  void _openDetails(Bench bench) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: _cream,
      builder: (_) => _BenchQuickSheet(
        store: widget.store,
        bench: bench,
      ),
    );
  }

  void _openLibrary() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _cream,
      builder: (_) => _LibrarySheet(
        store: widget.store,
        area: widget.area,
        deviceLocation: widget.deviceLocation,
        radiusKm: _nearbyRadius,
        onRadiusChanged: (value) => setState(() => _nearbyRadius = value),
        onSelectBench: (bench) {
          _mapController.move(LatLng(bench.lat, bench.lng), 17);
          _openDetails(bench);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          widget.area.center ?? const LatLng(50.85, 4.35),
                      initialZoom: widget.area.center == null ? 8 : 13,
                      onTap: (_, point) => _openAddForm(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'be.benchspot.app',
                      ),
                      MarkerLayer(
                        markers: [
                          for (final bench in widget.store.benches)
                            Marker(
                              point: LatLng(bench.lat, bench.lng),
                              width: 48,
                              height: 56,
                              child: GestureDetector(
                                onTap: () => _openDetails(bench),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: bench.isSample ? _cocoa : _berry,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _paper,
                                          width: 3,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.chair_alt,
                                        color: _paper,
                                        size: 23,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.deviceLocation != null)
                            Marker(
                              point: widget.deviceLocation!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: _MapTopBar(
                    areaName: widget.area.name,
                    onUseLocation: widget.onUseLocation,
                    onChangeArea: widget.onChangeArea,
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() => _adding = !_adding);
                            if (_adding) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Tap the map to place your bench.'),
                                ),
                              );
                            }
                          },
                          icon: Icon(_adding ? Icons.close : Icons.add),
                          label: Text(_adding ? 'Cancel' : 'Spot a bench'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: _berry,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _openLibrary,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Library'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 15,
                          ),
                          backgroundColor: _paper,
                          foregroundColor: _berry,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_adding)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 78,
                    child: IgnorePointer(
                      child: Center(
                        child: Chip(
                          avatar: const Icon(Icons.place, color: _berry),
                          label: const Text('Tap anywhere on the map'),
                          backgroundColor: _paper,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.areaName,
    required this.onUseLocation,
    required this.onChangeArea,
  });

  final String areaName;
  final VoidCallback onUseLocation;
  final VoidCallback onChangeArea;

  @override
  Widget build(BuildContext context) => Material(
        color: _paper,
        elevation: 3,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              const Icon(Icons.circle, color: _berry, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  areaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _berry,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Use my location',
                onPressed: onUseLocation,
                icon: const Icon(Icons.my_location, color: _berry),
              ),
              IconButton(
                tooltip: 'Change city',
                onPressed: onChangeArea,
                icon: const Icon(Icons.location_city, color: _berry),
              ),
            ],
          ),
        ),
      );
}

class _LibrarySheet extends StatefulWidget {
  const _LibrarySheet({
    required this.store,
    required this.area,
    required this.deviceLocation,
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.onSelectBench,
  });

  final BenchStore store;
  final ExploreArea area;
  final LatLng? deviceLocation;
  final int radiusKm;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<Bench> onSelectBench;

  @override
  State<_LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends State<_LibrarySheet> {
  late int _radiusKm = widget.radiusKm;

  List<(Bench, double?)> _results() {
    final center = widget.deviceLocation ?? widget.area.center;
    final results = <(Bench, double?)>[];
    for (final bench in widget.store.benches) {
      final distance = center == null
          ? null
          : _distance(center, LatLng(bench.lat, bench.lng));
      if (widget.deviceLocation != null && distance! > _radiusKm) continue;
      if (widget.deviceLocation == null &&
          widget.area.center != null &&
          distance! > 12) {
        continue;
      }
      results.add((bench, distance));
    }
    if (widget.deviceLocation != null) {
      results.sort((first, second) => first.$2!.compareTo(second.$2!));
    } else {
      results.sort(
          (first, second) => second.$1.createdAt.compareTo(first.$1.createdAt));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .4,
        maxChildSize: .92,
        builder: (context, scrollController) => Material(
          color: _cream,
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final results = _results();
              final nearby = widget.deviceLocation != null;
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nearby ? 'Nearby places' : 'The library',
                                style: const TextStyle(
                                  color: _berry,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${widget.area.name} · ${results.length} ${results.length == 1 ? 'spot' : 'spots'}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        if (nearby)
                          DropdownButton<int>(
                            value: _radiusKm,
                            underline: const SizedBox.shrink(),
                            items: const [1, 5, 10, 25]
                                .map((radius) => DropdownMenuItem(
                                      value: radius,
                                      child: Text('$radius km'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _radiusKm = value);
                              widget.onRadiusChanged(value);
                            },
                          ),
                        IconButton(
                          tooltip: 'Close library',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(26),
                              child: Text(
                                nearby
                                    ? 'No benches within $_radiusKm km yet.'
                                    : 'No benches in the library for ${widget.area.name} yet.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _ink),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 66),
                            itemBuilder: (context, index) {
                              final (bench, distance) = results[index];
                              final where = nearby
                                  ? '${_formatDistance(distance!)} away'
                                  : bench.isSample
                                      ? 'Sample location'
                                      : _formatDate(bench.createdAt);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      bench.isSample ? _cocoa : _latteWash,
                                  child: Icon(
                                    Icons.chair_alt,
                                    color: bench.isSample ? _paper : _berry,
                                  ),
                                ),
                                title: Text(
                                  bench.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _berry,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${bench.kind} · $where\n${_reviewSummary(bench)}',
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onSelectBench(bench);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _AddSpotSheet extends StatefulWidget {
  const _AddSpotSheet({
    required this.store,
    required this.location,
    required this.areaName,
  });

  final BenchStore store;
  final LatLng location;
  final String areaName;

  @override
  State<_AddSpotSheet> createState() => _AddSpotSheetState();
}

class _AddSpotSheetState extends State<_AddSpotSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _author = TextEditingController();
  final _review = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  String _kind = 'Bench';
  String _nameStatus = 'A nearby place name will be suggested if available.';
  int _rating = 5;
  bool _saving = false;
  bool _showNote = false;
  bool _showReview = false;
  bool _editedName = false;
  bool _settingSuggestedName = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (!_settingSuggestedName) _editedName = true;
    });
    _suggestName();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _author.dispose();
    _review.dispose();
    super.dispose();
  }

  Future<void> _suggestName() async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': widget.location.latitude.toString(),
        'lon': widget.location.longitude.toString(),
        'zoom': '18',
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'BenchSpot/0.1.0'
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw HttpException(
            'Place lookup returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      final label = decoded is Map<String, dynamic>
          ? (decoded['name'] as String? ??
              (decoded['display_name'] as String?)?.split(',').first)
          : null;
      if (!mounted) return;
      if (label != null && label.trim().isNotEmpty) {
        if (!_editedName) {
          _settingSuggestedName = true;
          _name.text = label.trim();
          _settingSuggestedName = false;
        }
        setState(() {
          _nameStatus = _editedName
              ? 'Nearby place found. Your name is unchanged.'
              : 'Suggested from the nearby place. You can edit it.';
        });
      } else {
        setState(() =>
            _nameStatus = 'No nearby place name found; enter one if you like.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _nameStatus = 'Nearby name lookup failed: $error');
    }
  }

  Future<void> _pickPhotos({required bool camera}) async {
    try {
      final remaining = 3 - _photos.length;
      if (remaining <= 0) {
        _showMessage('You can add up to 3 photos.');
        return;
      }
      final List<XFile> picked;
      if (camera) {
        final photo = await _picker.pickImage(source: ImageSource.camera);
        picked = photo == null ? [] : [photo];
      } else {
        picked = await _picker.pickMultiImage(limit: remaining);
      }
      final selected = picked.take(remaining);
      setState(() => _photos.addAll(selected));
    } catch (error) {
      _showMessage('Could not select photos: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _name.text.trim().isEmpty
          ? 'Bench near ${widget.areaName}'
          : _name.text.trim();
      await widget.store.addBench(
        name: name,
        kind: _kind,
        note: _note.text.trim(),
        lat: widget.location.latitude,
        lng: widget.location.longitude,
        rating: _rating,
        author: _author.text,
        review: _review.text,
        photos: _photos,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save this bench: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  title: 'Spot a bench',
                  subtitle: 'Confirm the location and rate your spot.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: 'Spot name (optional)',
                    helperText: _nameStatus,
                    helperMaxLines: 2,
                  ),
                ),
                const Text(
                  'Your rating',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                _RatingPicker(
                    value: _rating,
                    onChanged: (v) => setState(() => _rating = v)),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Choose place type',
                      onSelected: (value) => setState(() => _kind = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'Bench', child: Text('Bench')),
                        PopupMenuItem(
                          value: 'Picnic table',
                          child: Text('Picnic table'),
                        ),
                        PopupMenuItem(
                          value: 'Other seat',
                          child: Text('Other seat'),
                        ),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.chair_alt, size: 18),
                        label: Text(_kind),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _showNote = !_showNote),
                      icon: Icon(_showNote ? Icons.close : Icons.notes),
                      label: Text(_showNote ? 'Hide note' : 'Add a note'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showReview = !_showReview),
                      icon: Icon(
                        _showReview ? Icons.close : Icons.rate_review_outlined,
                      ),
                      label:
                          Text(_showReview ? 'Hide review' : 'Write a review'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickPhotos(camera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _photos.isEmpty ? 'Add photos' : 'Add more photos',
                      ),
                    ),
                    if (_photos.isEmpty)
                      IconButton(
                        tooltip: 'Take a photo',
                        onPressed: () => _pickPhotos(camera: true),
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                  ],
                ),
                if (_showNote) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _note,
                    maxLength: 180,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Shade, step-free access, a nice view…',
                    ),
                  ),
                ],
                if (_showReview) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _author,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Your name (optional)',
                      hintText: 'Anonymous by default',
                    ),
                  ),
                  TextFormField(
                    controller: _review,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Written review (optional)',
                      hintText: 'Comfort, surroundings, accessibility…',
                    ),
                  ),
                ],
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PhotoActions(
                    photoCount: _photos.length,
                    photos: _photos,
                    onGallery: () => _pickPhotos(camera: false),
                    onCamera: () => _pickPhotos(camera: true),
                    onRemove: (photo) => setState(() => _photos.remove(photo)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Pin: ${widget.location.latitude.toStringAsFixed(5)}, ${widget.location.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_location_alt),
                    label: Text(_saving ? 'Saving…' : 'Add spot'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _BenchQuickSheet extends StatelessWidget {
  const _BenchQuickSheet({required this.store, required this.bench});

  final BenchStore store;
  final Bench bench;

  Future<void> _openDirections(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${bench.lat},${bench.lng}',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No map app could open this location.');
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open directions: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final averageRating = bench.averageRating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bench.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _berry,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: _berry, size: 21),
                const SizedBox(width: 4),
                Text(
                  averageRating == null
                      ? 'Not rated yet'
                      : '${averageRating.toStringAsFixed(1)} / 5',
                  style: const TextStyle(
                    color: _cocoa,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (bench.reviews.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· ${bench.reviews.length} ${bench.reviews.length == 1 ? 'review' : 'reviews'}',
                    style: const TextStyle(color: _cocoa),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: _cream,
                    builder: (_) => _BenchDetailsSheet(
                      store: store,
                      benchId: bench.id,
                    ),
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Reviews'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: _cream,
                    builder: (_) => _BenchPhotoSheet(
                      store: store,
                      benchId: bench.id,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Photos'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDirections(context),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: _cream,
                    builder: (_) => _ReviewSheet(
                      store: store,
                      benchId: bench.id,
                    ),
                  ),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Write a review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenchPhotoSheet extends StatelessWidget {
  const _BenchPhotoSheet({required this.store, required this.benchId});

  final BenchStore store;
  final String benchId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final bench = store.benches.firstWhere((item) => item.id == benchId);
          final photos = bench.reviews
              .expand((review) => review.photos)
              .toList(growable: false);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .58,
            minChildSize: .35,
            maxChildSize: .9,
            builder: (context, controller) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  _SheetHeader(
                    title: 'Photos',
                    subtitle: bench.name,
                  ),
                  Expanded(
                    child: photos.isEmpty
                        ? const Center(
                            child: Text(
                              'No photos yet. Add one with a review.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _cocoa),
                            ),
                          )
                        : GridView.builder(
                            controller: controller,
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: photos.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _showPhoto(context, photos[index]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(photos[index]),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: _latteWash,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: _berry,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _BenchDetailsSheet extends StatelessWidget {
  const _BenchDetailsSheet({required this.store, required this.benchId});

  final BenchStore store;
  final String benchId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final bench = store.benches.firstWhere((item) => item.id == benchId);
          final reviews = [...bench.reviews]..sort(
              (first, second) => second.createdAt.compareTo(first.createdAt));
          final photos = reviews.expand((review) => review.photos).toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .8,
              minChildSize: .55,
              maxChildSize: .95,
              builder: (context, controller) => ListView(
                controller: controller,
                children: [
                  _SheetHeader(
                    title: bench.name,
                    subtitle:
                        '${bench.isSample ? 'Sample location · ' : ''}${bench.kind} · ${bench.isSample ? 'Starter data' : 'Spotted ${_formatDate(bench.createdAt)}'}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _reviewSummary(bench),
                    style: const TextStyle(
                      color: _berry,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (bench.note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(bench.note, style: const TextStyle(color: _ink)),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Community photos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _PhotoThumbnail(
                          path: photos[index],
                          onTap: () => _showPhoto(context, photos[index]),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reviews',
                          style: TextStyle(
                            color: _berry,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: _cream,
                          builder: (_) => _ReviewSheet(
                            store: store,
                            benchId: bench.id,
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Write a review'),
                      ),
                    ],
                  ),
                  if (reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No written reviews yet. Be the first to share how this spot was.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    for (final review in reviews)
                      _ReviewCard(
                        review: review,
                        onPhotoTap: (path) => _showPhoto(context, path),
                      ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        },
      );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.store, required this.benchId});

  final BenchStore store;
  final String benchId;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _author = TextEditingController();
  final _text = TextEditingController();
  final _photos = <XFile>[];
  final _picker = ImagePicker();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _author.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool camera}) async {
    try {
      final remaining = 3 - _photos.length;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 3 photos.')),
        );
        return;
      }
      if (camera) {
        final photo = await _picker.pickImage(source: ImageSource.camera);
        if (photo != null && mounted) setState(() => _photos.add(photo));
      } else {
        final photos = await _picker.pickMultiImage(limit: remaining);
        if (mounted) setState(() => _photos.addAll(photos.take(remaining)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photos: $error')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.store.addReview(
        benchId: widget.benchId,
        rating: _rating,
        author: _author.text,
        text: _text.text,
        photos: _photos,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your review: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHeader(
                title: 'Write a review',
                subtitle: 'Your review is anonymous unless you add your name.',
              ),
              const SizedBox(height: 18),
              const Text(
                'Your rating',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _RatingPicker(
                value: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
              TextField(
                controller: _author,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Your name (optional)',
                  hintText: 'Anonymous by default',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'How was this bench? (optional)',
                  hintText: 'Comfort, surroundings, accessibility…',
                ),
              ),
              const SizedBox(height: 12),
              _PhotoActions(
                photoCount: _photos.length,
                photos: _photos,
                onGallery: () => _pick(camera: false),
                onCamera: () => _pick(camera: true),
                onRemove: (photo) => setState(() => _photos.remove(photo)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_saving ? 'Saving…' : 'Save review'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _berry,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      );
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var rating = 1; rating <= 5; rating++)
            IconButton(
              tooltip: '$rating star${rating == 1 ? '' : 's'}',
              onPressed: () => onChanged(rating),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                rating <= value
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 32,
                color: _berry,
              ),
            ),
          const SizedBox(width: 6),
          Text('$value / 5', style: const TextStyle(color: Colors.black54)),
        ],
      );
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({
    required this.photoCount,
    required this.photos,
    required this.onGallery,
    required this.onCamera,
    required this.onRemove,
  });

  final int photoCount;
  final List<XFile> photos;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos (optional)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: photoCount < 3 ? onGallery : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photos'),
              ),
              OutlinedButton.icon(
                onPressed: photoCount < 3 ? onCamera : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
            ],
          ),
          Text(
            '$photoCount of 3 photos selected. Images are resized before saving.',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(photos[index].path),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 76,
                          height: 76,
                          child: Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        onPressed: () => onRemove(photos[index]),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onPhotoTap});

  final BenchReview review;
  final ValueChanged<String> onPhotoTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    review.author,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${'★' * review.rating}${'☆' * (5 - review.rating)}',
                  style: const TextStyle(color: _berry),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _formatDate(review.createdAt),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.text),
            ],
            if (review.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _PhotoThumbnail(
                    path: review.photos[index],
                    onTap: () => onPhotoTap(review.photos[index]),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 96,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 96,
              height: 90,
              color: _latteWash,
              child: const Icon(Icons.broken_image_outlined, color: _berry),
            ),
          ),
        ),
      );
}

void _showPhoto(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: InteractiveViewer(
        child: Image.file(
          File(path),
          errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This photo is no longer available.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

double _distance(LatLng first, LatLng second) {
  const earthRadiusKm = 6371.0;
  final lat1 = first.latitude * pi / 180;
  final lat2 = second.latitude * pi / 180;
  final deltaLat = (second.latitude - first.latitude) * pi / 180;
  final deltaLng = (second.longitude - first.longitude) * pi / 180;
  final a = pow(sin(deltaLat / 2), 2) +
      cos(lat1) * cos(lat2) * pow(sin(deltaLng / 2), 2);
  return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String _formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

String _formatDate(DateTime date) =>
    '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}';

String _reviewSummary(Bench bench) {
  if (bench.reviews.isEmpty) return 'No reviews yet';
  final average = bench.averageRating!;
  final count = bench.reviews.length;
  return '★ ${average.toStringAsFixed(1)} · $count ${count == 1 ? 'review' : 'reviews'}';
}
