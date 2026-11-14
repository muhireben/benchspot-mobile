import 'dart:io';

import 'package:benchspot/bench_store.dart';
import 'package:benchspot/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves benches and reviews between app launches', () async {
    final directory = await Directory.systemTemp.createTemp('benchspot-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = BenchStore(documentsDirectory: directory);
    addTearDown(store.dispose);
    await store.load();
    await store.addBench(
      name: 'Test garden bench',
      kind: 'Bench',
      note: 'Quiet in the afternoon',
      lat: 50.67,
      lng: 4.61,
      rating: 4,
      author: 'Anonymous',
      review: 'A pleasant place to pause.',
      photos: [],
    );

    final reloadedStore = BenchStore(documentsDirectory: directory);
    addTearDown(reloadedStore.dispose);
    await reloadedStore.load();
    final savedBench = reloadedStore.benches
        .singleWhere((bench) => bench.name == 'Test garden bench');
    expect(savedBench.reviews.single.rating, 4);
    expect(savedBench.reviews.single.text, 'A pleasant place to pause.');
  });

  testWidgets('shows the welcome screen and searchable city picker',
      (tester) async {
    final store = BenchStore.inMemory();
    addTearDown(store.dispose);
    await tester.pumpWidget(BenchSpotApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Find your little pause.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/autumn-bench.png',
      ),
      findsOneWidget,
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.colorScheme.primary, const Color(0xFF854442));
    await tester.tap(find.text('Choose a city'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Louvain-la-Neuve');
    await tester.pumpAndSettle();
    expect(find.text('Louvain-la-Neuve'), findsNWidgets(2));
    await tester.tap(find.text('Louvain-la-Neuve').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Spot a bench'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chair_alt).first);
    await tester.pumpAndSettle();
    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
  });
}
