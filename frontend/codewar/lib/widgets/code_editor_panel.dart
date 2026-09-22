import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Simple line-numbered monospace code editor panel. Not a full syntax
/// highlighter — a TextField styled to match the IDE mockup, which is
/// enough for the demo's "edit and submit" flow.
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
  }

  @override
  void didUpdateWidget(covariant CodeEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCode != widget.initialCode) {
      _controller.text = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      child: TextField(
                        controller: _controller,
                        onChanged: widget.onChanged,
                        maxLines: null,
                        style: AppTheme.mono(fontSize: 13, color: AppColors.onSurface),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
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
