import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class BenchReview {
  BenchReview({
    required this.id,
    required this.author,
    required this.rating,
    required this.text,
    required this.createdAt,
    required this.photos,
  });

  final String id;
  final String author;
  final int rating;
  final String text;
  final DateTime createdAt;
  final List<String> photos;

  factory BenchReview.fromJson(Map<String, dynamic> json) => BenchReview(
        id: json['id'] as String? ?? '',
        author: json['author'] as String? ?? 'Anonymous',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        photos: (json['photos'] as List<dynamic>? ?? []).cast<String>(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author,
        'rating': rating,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'photos': photos,
      };
}

class Bench {
  Bench({
    required this.id,
    required this.name,
    required this.kind,
    required this.note,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.isSample,
    required this.reviews,
  });

  final String id;
  final String name;
  final String kind;
  final String note;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final bool isSample;
  final List<BenchReview> reviews;

  double? get averageRating {
    if (reviews.isEmpty) return null;
    return reviews.fold<int>(0, (total, review) => total + review.rating) /
        reviews.length;
  }

  factory Bench.fromJson(Map<String, dynamic> json) => Bench(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Bench',
        kind: json['kind'] as String? ?? 'Bench',
        note: json['note'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isSample: json['isSample'] as bool? ?? false,
        reviews: (json['reviews'] as List<dynamic>? ?? [])
            .map((item) => BenchReview.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'note': note,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'isSample': isSample,
        'reviews': reviews.map((review) => review.toJson()).toList(),
      };
}

class BenchStore extends ChangeNotifier {
  BenchStore({Directory? documentsDirectory})
      : _memoryOnly = false,
        _documentsDirectory = documentsDirectory;

  BenchStore.inMemory() : _memoryOnly = true;

  final bool _memoryOnly;
  Directory? _documentsDirectory;
  final List<Bench> _benches = [];
  final Random _random = Random();

  List<Bench> get benches => List.unmodifiable(_benches);

  Future<void> load() async {
    if (_memoryOnly) {
      _benches
        ..clear()
        ..addAll(_sampleBenches());
      return;
    }

    _documentsDirectory ??= await getApplicationDocumentsDirectory();
    final database = File('${_documentsDirectory!.path}/benches.json');
    if (await database.exists()) {
      final decoded = jsonDecode(await database.readAsString());
      if (decoded is! List) {
        throw const FormatException('The saved bench database is not a list.');
      }
      _benches
        ..clear()
        ..addAll(decoded.map(
            (item) => Bench.fromJson(Map<String, dynamic>.from(item as Map))));
    } else {
      _benches
        ..clear()
        ..addAll(_sampleBenches());
      await _persist();
    }
  }

  Future<void> addBench({
    required String name,
    required String kind,
    required String note,
    required double lat,
    required double lng,
    required int rating,
    required String author,
    required String review,
    required List<XFile> photos,
  }) async {
    final id = _newId();
    final photoPaths = await _savePhotos(id, photos);
    final bench = Bench(
      id: id,
      name: name,
      kind: kind,
      note: note,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now(),
      isSample: false,
      reviews: [
        BenchReview(
          id: _newId(),
          author: author.trim().isEmpty ? 'Anonymous' : author.trim(),
          rating: rating,
          text: review.trim(),
          createdAt: DateTime.now(),
          photos: photoPaths,
        ),
      ],
    );

    _benches.add(bench);
    try {
      await _persist();
    } catch (_) {
      _benches.removeWhere((item) => item.id == id);
      await _removePhotos(photoPaths);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> addReview({
    required String benchId,
    required int rating,
    required String author,
    required String text,
    required List<XFile> photos,
  }) async {
    final bench = _benches.firstWhere((item) => item.id == benchId);
    final photoPaths = await _savePhotos(benchId, photos);
    final review = BenchReview(
      id: _newId(),
      author: author.trim().isEmpty ? 'Anonymous' : author.trim(),
      rating: rating,
      text: text.trim(),
      createdAt: DateTime.now(),
      photos: photoPaths,
    );
    bench.reviews.add(review);
    try {
      await _persist();
    } catch (_) {
      bench.reviews.remove(review);
      await _removePhotos(photoPaths);
      rethrow;
    }
    notifyListeners();
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}';

  Future<List<String>> _savePhotos(String ownerId, List<XFile> photos) async {
    if (photos.isEmpty) return [];
    if (_memoryOnly) return photos.map((photo) => photo.path).toList();

    final directory = Directory(
      '${_documentsDirectory!.path}${Platform.pathSeparator}bench_photos',
    );
    await directory.create(recursive: true);
    final savedPaths = <String>[];
    try {
      for (var index = 0; index < photos.length; index++) {
        final bytes = await photos[index].readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw const FormatException('A selected photo could not be decoded.');
        }
        final scale = min(1.0, 1280 / max(decoded.width, decoded.height));
        final resized = scale < 1
            ? img.copyResize(
                decoded,
                width: (decoded.width * scale).round(),
                height: (decoded.height * scale).round(),
              )
            : decoded;
        final path =
            '${directory.path}${Platform.pathSeparator}$ownerId-$index.jpg';
        await File(path).writeAsBytes(img.encodeJpg(resized, quality: 82));
        savedPaths.add(path);
      }
      return savedPaths;
    } catch (_) {
      await _removePhotos(savedPaths);
      rethrow;
    }
  }

  Future<void> _removePhotos(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _persist() async {
    if (_memoryOnly) return;
    final file = File('${_documentsDirectory!.path}/benches.json');
    await file.writeAsString(
      jsonEncode(_benches.map((bench) => bench.toJson()).toList()),
      flush: true,
    );
  }

  List<Bench> _sampleBenches() {
    final createdAt = DateTime.utc(2026, 11, 13, 9);
    return [
      Bench(
        id: 'sample-bench-lake',
        name: 'Sample spot by the lake',
        kind: 'Bench',
        note: 'Demo location; please verify the bench exists before reviewing.',
        lat: 50.6659,
        lng: 4.6092,
        createdAt: createdAt,
        isSample: true,
        reviews: [],
      ),
      Bench(
        id: 'sample-bench-park',
        name: 'Sample park bench',
        kind: 'Bench',
        note: 'Demo location; please verify the bench exists before reviewing.',
        lat: 50.6711,
        lng: 4.6141,
        createdAt: createdAt,
        isSample: true,
        reviews: [],
      ),
      Bench(
        id: 'sample-bench-woods',
        name: 'Sample woodland seat',
        kind: 'Other seat',
        note: 'Demo location; please verify the seat exists before reviewing.',
        lat: 50.6742,
        lng: 4.6172,
        createdAt: createdAt,
        isSample: true,
        reviews: [],
      ),
      Bench(
        id: 'sample-bench-square',
        name: 'Sample square bench',
        kind: 'Bench',
        note: 'Demo location; please verify the bench exists before reviewing.',
        lat: 50.6681,
        lng: 4.6114,
        createdAt: createdAt,
        isSample: true,
        reviews: [],
      ),
      Bench(
        id: 'sample-bench-campus',
        name: 'Sample campus seat',
        kind: 'Bench',
        note: 'Demo location; please verify the seat exists before reviewing.',
        lat: 50.6672,
        lng: 4.6154,
        createdAt: createdAt,
        isSample: true,
        reviews: [],
      ),
    ];
  }
}
