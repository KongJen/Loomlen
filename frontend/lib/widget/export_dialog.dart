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
  late String _filename;
  bool _includePdfBackgrounds = true;
  bool _includeAllPages = true;
  List<int> _selectedPageIndices = [];
  bool _showFilenameError = false;

  @override
  void initState() {
    super.initState();
    // Remove .pdf extension if it exists for cleaner display
    _filename =
        widget.filename.toLowerCase().endsWith('.pdf')
            ? widget.filename.substring(0, widget.filename.length - 4)
            : widget.filename;

    if (widget.hasMultiplePages) {
      _selectedPageIndices = List.generate(
        10,
        (index) => index,
      ); // Default all pages selected
    }
  }

  bool _validateFilename() {
    if (_filename.trim().isEmpty) {
      setState(() {
        _showFilenameError = true;
      });
      return false;
    }
    return true;
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
              decoration: InputDecoration(
                labelText: 'Filename',
                hintText: 'Enter filename',
                errorText:
                    _showFilenameError ? 'Please enter a valid filename' : null,
                suffixText: '.pdf', // Show .pdf extension as suffix
              ),
              initialValue: _filename,
              onChanged: (value) {
                setState(() {
                  _filename = value;
                  if (value.trim().isNotEmpty) {
                    _showFilenameError = false;
                  }
                });
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Extension .pdf will be added automatically',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
            if (_validateFilename()) {
              Navigator.of(context).pop({
                'filename': _filename,
                'includePdfBackgrounds': _includePdfBackgrounds,
                'includeAllPages': _includeAllPages,
                'selectedPageIndices': _selectedPageIndices,
              });
            }
          },
          child: const Text('Export'),
        ),
      ],
    );
  }
}
