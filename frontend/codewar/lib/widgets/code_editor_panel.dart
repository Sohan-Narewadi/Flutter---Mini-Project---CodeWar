import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';

/// Index of the first character of the line containing [offset] (0 if
/// [offset] is on the first line). Deliberately never calls
/// `String.lastIndexOf` with a negative start index - `offset == 0` (cursor
/// on the very first character, no line break before it anywhere) is a real,
/// common case (e.g. pressing Tab/Shift+Tab/Enter as the first keystroke),
/// and `''.lastIndexOf('\n', -1)` throws a RangeError.
int _lineStartBefore(String text, int offset) {
  if (offset <= 0) return 0;
  return text.lastIndexOf('\n', offset - 1) + 1;
}

/// Auto-indents on Enter like a real code editor: the new line matches the
/// previous line's leading whitespace, plus one extra 4-space level if the
/// previous line (trimmed of trailing whitespace) opens a block with `:`.
///
/// Implemented as a [TextInputFormatter] rather than reacting in `onChanged`
/// so it runs as part of the same edit transaction the platform delivers -
/// no reentrancy, no risk of fighting IME composition. It only ever acts on
/// a plain single-character insertion (real typing); anything else (paste,
/// delete, selection replace) passes through untouched.
class _AutoIndentFormatter extends TextInputFormatter {
  const _AutoIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (newText.length != oldText.length + 1) return newValue;

    var insertAt = 0;
    while (insertAt < oldText.length && oldText[insertAt] == newText[insertAt]) {
      insertAt++;
    }
    // Confirm this is a pure single-char insertion at insertAt (everything
    // after the inserted char still matches the old text unchanged) - if
    // not, this was some other kind of edit (e.g. autocorrect); bail out.
    if (newText.substring(insertAt + 1) != oldText.substring(insertAt)) return newValue;
    if (newText[insertAt] != '\n') return newValue;

    final lineStart = _lineStartBefore(oldText, insertAt);
    final previousLine = oldText.substring(lineStart, insertAt);
    final currentIndent = RegExp(r'^[ \t]*').firstMatch(previousLine)?.group(0) ?? '';
    final opensBlock = previousLine.trimRight().endsWith(':');
    final indent = opensBlock ? '$currentIndent    ' : currentIndent;

    if (indent.isEmpty) return newValue;

    final finalText = newText.substring(0, insertAt + 1) + indent + newText.substring(insertAt + 1);
    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: insertAt + 1 + indent.length),
    );
  }
}

class _IndentIntent extends Intent {
  const _IndentIntent();
}

class _OutdentIntent extends Intent {
  const _OutdentIntent();
}

/// Simple line-numbered monospace code editor panel. Not a full syntax
/// highlighter — a TextField styled to match the IDE mockup, which is
/// enough for the demo's "edit and submit" flow. Supports auto-indent on
/// Enter (see [_AutoIndentFormatter]) and Tab/Shift+Tab to indent/outdent
/// (Tab otherwise just shifts focus in Flutter, which is wrong for a code
/// editor) so writing code here feels like a real IDE, not a plain textbox.
///
/// This widget owns its `TextEditingController` for its whole lifetime and
/// never resyncs it from `initialCode` after construction - the parent
/// screen rebuilds this widget every second (its countdown timer), and
/// `initialCode` is fed from the same state this widget's own `onChanged`
/// writes into, so comparing "did initialCode change" on every rebuild was
/// true right after every keystroke, forcing the field's text/cursor back
/// to the caret-at-end position each second while typing. The parent must
/// instead pass a `key` that changes only when the code should genuinely
/// reset (new battle, language switch) - see `CodingBattleScreen`.
class CodeEditorPanel extends StatefulWidget {
  const CodeEditorPanel({
    super.key,
    required this.initialCode,
    required this.onChanged,
    required this.filename,
    this.minHeight = 180,
    this.maxHeight = 360,
  });

  final double minHeight;
  final double maxHeight;
  final String initialCode;
  final ValueChanged<String> onChanged;
  final String filename;

  @override
  State<CodeEditorPanel> createState() => _CodeEditorPanelState();
}

class _CodeEditorPanelState extends State<CodeEditorPanel> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode);
    // Keep the line-number gutter live as the user types/adds lines, rather
    // than only refreshing whenever the parent happens to rebuild.
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Manual value assignment bypasses [TextField.onChanged] (that callback
  /// only fires for edits coming through the real text-input pipeline), so
  /// every direct `_controller.value = ...` write here reports back to the
  /// parent explicitly.
  void _setValue(String text, TextSelection selection) {
    _controller.value = TextEditingValue(text: text, selection: selection);
    widget.onChanged(text);
  }

  void _indent() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      final newText = text.replaceRange(sel.start, sel.start, '    ');
      _setValue(newText, TextSelection.collapsed(offset: sel.start + 4));
      return;
    }

    final blockStart = _lineStartBefore(text, sel.start);
    final nextNewline = text.indexOf('\n', sel.end);
    final blockEnd = nextNewline == -1 ? text.length : nextNewline;
    final block = text.substring(blockStart, blockEnd);
    final indented = block.split('\n').map((l) => '    $l').join('\n');
    final newText = text.replaceRange(blockStart, blockEnd, indented);
    _setValue(newText, TextSelection(baseOffset: blockStart, extentOffset: blockStart + indented.length));
  }

  void _outdent() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;

    final blockStart = _lineStartBefore(text, sel.start);
    final nextNewline = text.indexOf('\n', sel.isCollapsed ? sel.start : sel.end);
    final blockEnd = nextNewline == -1 ? text.length : nextNewline;
    final block = text.substring(blockStart, blockEnd);

    var firstLineRemoved = 0;
    final lines = block.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var removed = 0;
      if (line.startsWith('\t')) {
        line = line.substring(1);
        removed = 1;
      } else {
        while (removed < 4 && line.startsWith(' ')) {
          line = line.substring(1);
          removed++;
        }
      }
      if (i == 0) firstLineRemoved = removed;
      lines[i] = line;
    }
    final outdented = lines.join('\n');
    final newText = text.replaceRange(blockStart, blockEnd, outdented);

    final newSelection = sel.isCollapsed
        ? TextSelection.collapsed(offset: (sel.start - firstLineRemoved).clamp(blockStart, newText.length))
        : TextSelection(baseOffset: blockStart, extentOffset: blockStart + outdented.length);
    _setValue(newText, newSelection);
  }

  static const double _fontSize = 13.5;
  static const double _lineHeight = 21;

  TextStyle get _codeStyle =>
      AppTheme.mono(fontSize: _fontSize, color: AppColors.text)
          .copyWith(height: _lineHeight / _fontSize, letterSpacing: 0);

  /// Width of one monospace character at the code font size.
  double get _charWidth {
    final tp = TextPainter(text: TextSpan(text: '0', style: _codeStyle), textDirection: TextDirection.ltr)..layout();
    return tp.width;
  }

  double _textWidth(String line) {
    final tp = TextPainter(text: TextSpan(text: line, style: _codeStyle), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _controller.text.split('\n');
    final lineCount = lines.length;
    final longest = lines.fold<String>('', (m, l) => l.length > m.length ? l : m);
    final gutterWidth = 14.0 + (lineCount.toString().length * _charWidth) + 10;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.surfaceHigh,
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(widget.filename, style: AppTheme.mono(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$lineCount ${lineCount == 1 ? 'line' : 'lines'}', style: AppTheme.mono(fontSize: 11, color: AppColors.textFaint)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight, minHeight: widget.minHeight),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: gutterWidth,
                    padding: const EdgeInsets.only(top: 12, bottom: 12, right: 10),
                    color: AppColors.surfaceLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        lineCount,
                        (i) => SizedBox(
                          height: _lineHeight,
                          child: Text('${i + 1}', style: AppTheme.mono(fontSize: 12, color: AppColors.textFaint).copyWith(height: _lineHeight / 12)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        // Never wrap: long lines scroll sideways so the line
                        // numbers always match what is on screen.
                        final width = (_textWidth(longest) + 56).clamp(c.maxWidth, double.infinity);
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: width,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              child: Shortcuts(
                                shortcuts: <ShortcutActivator, Intent>{
                                  LogicalKeySet(LogicalKeyboardKey.tab): const _IndentIntent(),
                                  LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.tab): const _OutdentIntent(),
                                },
                                child: Actions(
                                  actions: <Type, Action<Intent>>{
                                    _IndentIntent: CallbackAction<_IndentIntent>(onInvoke: (_) => _indent()),
                                    _OutdentIntent: CallbackAction<_OutdentIntent>(onInvoke: (_) => _outdent()),
                                  },
                                  child: TextField(
                                    controller: _controller,
                                    onChanged: widget.onChanged,
                                    inputFormatters: const [_AutoIndentFormatter()],
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    cursorColor: AppColors.accent,
                                    style: _codeStyle,
                                    strutStyle: const StrutStyle(fontSize: _fontSize, height: _lineHeight / _fontSize, forceStrutHeight: true),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
