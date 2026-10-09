import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewar/ui/app_card.dart';
import 'package:codewar/ui/app_scaffold.dart';
import 'package:codewar/ui/neon_button.dart';
import 'package:codewar/ui/segmented_tabs.dart';
import 'package:codewar/ui/stat_tile.dart';
import 'package:codewar/utils/theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: Center(child: child)));

void main() {
  group('NeonButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(NeonButton(label: 'Go', onPressed: () => taps++)));
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('ignores taps when disabled', (tester) async {
      await tester.pumpWidget(_wrap(const NeonButton(label: 'Go', onPressed: null)));
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('loading shows a spinner, hides the label and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(NeonButton(label: 'Go', loading: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(NeonButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('meets the 48dp minimum tap height', (tester) async {
      await tester.pumpWidget(_wrap(NeonButton(label: 'Go', compact: true, expanded: false, onPressed: () {})));
      expect(tester.getSize(find.byType(AnimatedContainer).first).height, greaterThanOrEqualTo(44));
    });
  });

  group('SegmentedTabs', () {
    testWidgets('reports the tapped option', (tester) async {
      String selected = 'a';
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 300,
          child: SegmentedTabs<String>(
            options: const {'a': 'Easy', 'b': 'Medium', 'c': 'Hard'},
            value: selected,
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
      )));
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      expect(selected, 'c');
    });

    testWidgets('segments have equal width', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 300,
        child: SegmentedTabs<int>(options: const {1: 'One', 2: 'A much longer label', 3: 'x'}, value: 1, onChanged: (_) {}),
      )));
      final w1 = tester.getSize(find.ancestor(of: find.text('One'), matching: find.byType(Expanded)).first).width;
      final w2 = tester.getSize(find.ancestor(of: find.text('x'), matching: find.byType(Expanded)).first).width;
      expect(w1, w2);
    });
  });

  testWidgets('StatTile shows value and upper-cased label', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(width: 160, child: StatTile(value: '1,250', label: 'Rating'))));
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('RATING'), findsOneWidget);
  });

  testWidgets('AppCard onTap works and SectionTitle upper-cases', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(Column(mainAxisSize: MainAxisSize.min, children: [
      const SectionTitle('Badges'),
      AppCard(onTap: () => taps++, child: const Text('card')),
    ])));
    expect(find.text('BADGES'), findsOneWidget);
    await tester.tap(find.text('card'));
    expect(taps, 1);
  });

  testWidgets('AppScaffold constrains content width on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const AppScaffold(body: SizedBox.expand(key: Key('content'))),
    ));
    expect(tester.getSize(find.byKey(const Key('content'))).width, AppSpace.maxContentWidth);
  });
}
