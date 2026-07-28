import 'package:flutter/material.dart';

import 'text_style_catalog.dart';

/// Searchable picker for Civil / Drive Support text styles.
Future<String?> showTextStylePickerSheet({
  required BuildContext context,
  required TextStyleCatalog catalog,
  required String selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF141814),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.62,
    ),
    builder: (ctx) {
      return _TextStylePickerBody(
        catalog: catalog,
        selectedId: selectedId,
      );
    },
  );
}

class _TextStylePickerBody extends StatefulWidget {
  const _TextStylePickerBody({
    required this.catalog,
    required this.selectedId,
  });

  final TextStyleCatalog catalog;
  final String selectedId;

  @override
  State<_TextStylePickerBody> createState() => _TextStylePickerBodyState();
}

class _TextStylePickerBodyState extends State<_TextStylePickerBody> {
  late final TextEditingController _filter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter = TextEditingController();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final styles = [
      for (final s in widget.catalog.styles)
        if (q.isEmpty ||
            s.name.toLowerCase().contains(q) ||
            s.font.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q) ||
            s.flutterFamily.toLowerCase().contains(q))
          s,
    ];
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Text style (${widget.catalog.styles.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _filter,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Filter by name or font…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: styles.length,
                itemBuilder: (context, i) {
                  final s = styles[i];
                  final selected = s.id == widget.selectedId;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    title: Text(
                      s.name,
                      style: TextStyle(
                        fontFamily: s.flutterFamily,
                        fontWeight: s.flutterWeight,
                        fontStyle: s.flutterStyle,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      s.font,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: Color(0xFFE4572E))
                        : null,
                    onTap: () => Navigator.of(context).pop(s.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
