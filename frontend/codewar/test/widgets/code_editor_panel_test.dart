import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewar/widgets/code_editor_panel.dart';

/// Simulates real, incremental typing (one character per platform update),
/// which is what makes `_AutoIndentFormatter`'s single-character-insertion
/// detection actually engage - a single `enterText` call replacing the
/// whole string at once would look like a multi-character paste, not a
/// keystroke, and the formatter deliberately ignores those.
Future<void> typeIncrementally(WidgetTester tester, Finder field, String text) async {
  var soFar = '';
  for (final ch in text.split('')) {
    soFar += ch;
    await tester.enterText(field, soFar);
    await tester.pump();
  }
}

Future<void> pumpEditor(
  WidgetTester tester, {
  String initialCode = '',
  required ValueChanged<String> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CodeEditorPanel(
          filename: 'SOLUTION.PY',
          initialCode: initialCode,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

TextEditingController controllerOf(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField)).controller!;
}

void main() {
  testWidgets('Enter after a line ending in ":" adds one indent level', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    await typeIncrementally(tester, field, 'def solve():\n');

    expect(last, 'def solve():\n    ');
    expect(controllerOf(tester).selection.baseOffset, last.length);
  });

  testWidgets('Enter after a plain line keeps the same indent (no extra level)', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    await typeIncrementally(tester, field, 'def solve():\n    x = 1\n');

    expect(last, 'def solve():\n    x = 1\n    ');
  });

  testWidgets('Enter on an unindented line stays unindented', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    await typeIncrementally(tester, field, 'x = 1\ny = 2\n');

    expect(last, 'x = 1\ny = 2\n');
  });

  testWidgets('nested blocks accumulate indent one level at a time', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    await typeIncrementally(tester, field, 'def solve():\n    if True:\n        pass\n');

    // Third Enter (after "        pass", no colon) should NOT add another
    // level - it should stay at the same 8-space depth.
    expect(last, 'def solve():\n    if True:\n        pass\n        ');
  });

  testWidgets('dedent after Enter respects a manually-outdented line', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    // User types the block, then a bare "return x" at 4-space depth (no
    // colon) - the next Enter must match THAT line's indent, not re-derive
    // it from the def line.
    await typeIncrementally(tester, field, 'def solve():\n    return x\n');

    expect(last, 'def solve():\n    return x\n    ');
  });

  testWidgets('pasting multi-line text is left untouched by the formatter', (tester) async {
    var last = '';
    await pumpEditor(tester, onChanged: (v) => last = v);
    final field = find.byType(TextField);

    // A paste arrives as a single multi-character update, not a
    // one-character insertion - the formatter must not try to reformat it.
    await tester.enterText(field, 'def solve():\n  already indented weird\n');
    await tester.pump();

    expect(last, 'def solve():\n  already indented weird\n');
  });

  testWidgets('Tab inserts 4 spaces at the cursor (collapsed selection)', (tester) async {
    var last = '';
    await pumpEditor(tester, initialCode: 'x = 1', onChanged: (v) => last = v);
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();

    final controller = controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(last, '    x = 1');
    expect(controller.selection.baseOffset, 4);
  });

  testWidgets('Shift+Tab removes up to 4 leading spaces from the current line', (tester) async {
    var last = '';
    await pumpEditor(tester, initialCode: '        x = 1', onChanged: (v) => last = v);
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();

    final controller = controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 8);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(last, '    x = 1');
  });

  testWidgets('Shift+Tab on an already-unindented line is a no-op', (tester) async {
    var last = '';
    await pumpEditor(tester, initialCode: 'x = 1', onChanged: (v) => last = v);
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();

    final controller = controllerOf(tester);
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(last, 'x = 1');
  });

  testWidgets('Tab with a multi-line selection indents every selected line', (tester) async {
    var last = '';
    const code = 'def solve():\nline_a\nline_b';
    await pumpEditor(tester, initialCode: code, onChanged: (v) => last = v);
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();

    final controller = controllerOf(tester);
    // Select from the start of "line_a" to the end of "line_b".
    final start = code.indexOf('line_a');
    controller.selection = TextSelection(baseOffset: start, extentOffset: code.length);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(last, 'def solve():\n    line_a\n    line_b');
  });

  testWidgets('Shift+Tab with a multi-line selection outdents every selected line', (tester) async {
    var last = '';
    const code = 'def solve():\n    line_a\n    line_b';
    await pumpEditor(tester, initialCode: code, onChanged: (v) => last = v);
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();

    final controller = controllerOf(tester);
    final start = code.indexOf('    line_a');
    controller.selection = TextSelection(baseOffset: start, extentOffset: code.length);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(last, 'def solve():\nline_a\nline_b');
  });

  testWidgets('line-number gutter grows live as newlines are typed', (tester) async {
    await pumpEditor(tester, onChanged: (_) {});
    final field = find.byType(TextField);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);

    await typeIncrementally(tester, field, 'a\nb\n');

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
