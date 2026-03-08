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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .toLowerCase()
        .trim();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      if (widget.controller.text.isNotEmpty) {
        _updateSuggestions(widget.controller.text);
        _showOverlay();
      }
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: suggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('لا يوجد نتائج متطابقة', textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return ListTile(
                          title: Text(suggestion),
                          onTap: () {
                            final selectedValue = suggestion.split('|')[0].trim();
                            widget.controller.text = selectedValue;
                            if (widget.onSelected != null) {
                              widget.onSelected!(selectedValue);
                            }
                            // نقوم بإخفاء الـ overlay قبل إلغاء التركيز أو الانتقال
                            _hideOverlay();
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _updateSuggestions(String value) {
    if (!mounted) return;
    
    setState(() {
      final originalResults = widget.onSearch(value);
      final normalizedQuery = _normalizeArabic(value);

      if (normalizedQuery.isEmpty) {
        suggestions = [];
        _hideOverlay();
      } else {
        suggestions = originalResults.where((item) {
          return _normalizeArabic(item).contains(normalizedQuery);
        }).toList();
        
        if (_focusNode.hasFocus) _showOverlay();
      }
    });
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        enabled: widget.enabled,
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.search),
        ),
        onChanged: _updateSuggestions,
        onTap: () {
          if (widget.controller.text.isNotEmpty) {
            _updateSuggestions(widget.controller.text);
          }
        },
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
