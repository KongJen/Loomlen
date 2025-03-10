import 'package:flutter/material.dart';

class PdfExportDialog extends StatefulWidget {
  final String filename;
  final bool hasMultiplePages;

  const PdfExportDialog({
    Key? key,
    required this.filename,
    this.hasMultiplePages = false,
  }) : super(key: key);

  @override
  State<PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<PdfExportDialog> {
  String _filename = '';
  bool _includePdfBackgrounds = true;
  bool _includeAllPages = true;
  List<int> _selectedPageIndices = [];
  double _quality = 3.0; // Default quality

  @override
  void initState() {
    super.initState();
    _filename = widget.filename;
    if (widget.hasMultiplePages) {
      _selectedPageIndices = List.generate(
        10,
        (index) => index,
      ); // Default all pages selected
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export to PDF'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Filename',
                hintText: 'Enter filename without extension',
              ),
              initialValue: _filename,
              onChanged: (value) {
                setState(() => _filename = value);
              },
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Include PDF backgrounds'),
              subtitle: const Text('Include any imported PDF backgrounds'),
              value: _includePdfBackgrounds,
              onChanged: (value) {
                setState(() => _includePdfBackgrounds = value);
              },
            ),

            if (widget.hasMultiplePages) ...[
              SwitchListTile(
                title: const Text('Export all pages'),
                value: _includeAllPages,
                onChanged: (value) {
                  setState(() => _includeAllPages = value);
                },
              ),

              if (!_includeAllPages) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 16.0),
                  child: Text('Select pages to export:'),
                ),
                // Page selection would go here (simplified for this example)
                const SizedBox(
                  height: 100,
                  child: Center(child: Text('Page selection UI')),
                ),
              ],
            ],

            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Text('Export Quality:'),
            ),
            Slider(
              value: _quality,
              min: 1.0,
              max: 5.0,
              divisions: 4,
              label:
                  _quality == 1.0
                      ? 'Low'
                      : _quality == 3.0
                      ? 'Medium'
                      : 'High',
              onChanged: (value) {
                setState(() => _quality = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'filename': _filename,
              'includePdfBackgrounds': _includePdfBackgrounds,
              'includeAllPages': _includeAllPages,
              'selectedPageIndices': _selectedPageIndices,
              'quality': _quality,
            });
          },
          child: const Text('Export'),
        ),
      ],
    );
  }
}
