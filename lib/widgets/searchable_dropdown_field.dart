import 'package:flutter/material.dart';

class SearchableDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> Function(String) onSearch;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSelected;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const SearchableDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.onSearch,
    this.enabled = true,
    this.focusNode,
    this.onSelected,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<SearchableDropdownField> createState() =>
      _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState
    extends State<SearchableDropdownField> {
  late final FocusNode _focusNode;
  List<String> suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          suggestions = [];
        });
      }
    });
  }

  void _updateSuggestions(String value) {
    setState(() {
      suggestions = widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          enabled: widget.enabled,
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onChanged: _updateSuggestions,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
        ),
        if (_focusNode.hasFocus && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                
                // البحث عن معلومات إضافية بين قوسين (مثال: "اسم الصنف (متاح: 10)")
                final hasExtraInfo = suggestion.contains('(');
                String mainText = suggestion;
                String extraInfo = '';
                
                if (hasExtraInfo) {
                  final parts = suggestion.split('(');
                  mainText = parts[0].trim();
                  extraInfo = '(' + parts.sublist(1).join('(');
                }

                return ListTile(
                  dense: true,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          mainText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasExtraInfo)
                        Text(
                          extraInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    // نضع النص الأساسي فقط في الـ Controller
                    widget.controller.text = mainText;
                    setState(() {
                      suggestions.clear();
                    });
                    _focusNode.unfocus();
                    if (widget.onSelected != null) {
                      widget.onSelected!(mainText);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
