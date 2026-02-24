import 'package:flutter/material.dart';

class SelectableTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const SelectableTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<SelectableTextField> createState() => _SelectableTextFieldState();
}

class _SelectableTextFieldState extends State<SelectableTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      // Use a post-frame callback to ensure the field is rendered before selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.controller.text.length,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      enabled: widget.enabled,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
