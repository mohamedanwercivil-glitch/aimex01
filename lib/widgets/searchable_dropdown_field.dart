import 'package:flutter/material.dart';

class SearchableDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> Function(String) onSearch;

  const SearchableDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.onSearch,
  });

  @override
  State<SearchableDropdownField> createState() =>
      _SearchableDropdownFieldState();
}

class _SearchableDropdownFieldState
    extends State<SearchableDropdownField> {
  final FocusNode _focusNode = FocusNode();
  List<String> suggestions = [];

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
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onChanged: _updateSuggestions,
        ),
        if (_focusNode.hasFocus && suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(suggestions[index]),
                  onTap: () {
                    widget.controller.text =
                    suggestions[index];
                    setState(() {
                      suggestions.clear();
                    });
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
