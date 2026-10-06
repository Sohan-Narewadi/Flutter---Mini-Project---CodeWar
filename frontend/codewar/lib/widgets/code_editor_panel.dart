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
  });

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

  @override
  Widget build(BuildContext context) {
    final lineCount = _controller.text.split('\n').length;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.surfaceContainerHigh,
            child: Row(
              children: [
                const Icon(Icons.description, size: 14, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(widget.filename, style: AppTheme.mono(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, minHeight: 180),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        lineCount,
                        (i) => Text(
                          '${i + 1}',
                          style: AppTheme.mono(fontSize: 13, color: AppColors.outline),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                            style: AppTheme.mono(fontSize: 13, color: AppColors.onSurface),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
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
