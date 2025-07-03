// ignore: duplicate_ignore
// ignore: file_names
// ignore_for_file: file_names, use_build_context_synchronously

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/items/drawingpoint_item.dart';
import 'package:frontend/items/template_item.dart' as template_model;
import 'package:frontend/items/template_item.dart';
import 'package:frontend/model/tools.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/widget/export_dialog.dart';
import 'package:frontend/widget/overlay_loading.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

class PDFDBExportResult {
  final bool success;
  final String? filePath;

  PDFDBExportResult({required this.success, this.filePath});
}

class PDFDBExportService {
  Future<PDFDBExportResult> exportNotesDBToPdf({
    required BuildContext context,
    required String fileName,
    required List<String> pageIds,
    required Map<String, template_model.PaperTemplate> paperTemplates,
    required Map<String, List<DrawingPoint>> pageDrawingPoints,
    required PaperDBProvider paperDBProvider,
  }) async {
    // Show loading indicator
    final loadingOverlay = LoadingOverlay(
      context: context,
      message: 'Preparing to export PDF',
      subMessage: 'Please wait while we export your file',
    );

    try {
      // Prepare initial values for the dialog
      final initialFileName = fileName.replaceAll(' ', '_');
      final hasMultiplePages = pageIds.length > 1;

      // Show dialog to get export options from user
      final Map<String, dynamic>? exportOptions =
          await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return PdfExportDialog(
            filename: initialFileName,
            hasMultiplePages: hasMultiplePages,
          );
        },
      );

      // If user cancelled the dialog, return
      if (exportOptions == null) {
        return PDFDBExportResult(success: false);
      }

      // Show loading overlay
      loadingOverlay.show();

      // Extract options from dialog result
      String outputFileName = exportOptions['filename'] as String;
      final bool includePdfBackgrounds =
          exportOptions['includePdfBackgrounds'] as bool;
      final bool includeAllPages = exportOptions['includeAllPages'] as bool;
      final List<int> selectedPageIndices =
          exportOptions['selectedPageIndices'] as List<int>;
      final double quality = 2.0; // Fixed quality value

      // Ensure filename has .pdf extension
      if (!outputFileName.toLowerCase().endsWith('.pdf')) {
        outputFileName = '$outputFileName.pdf';
      }

      // Create PDF document
      final pdf = pw.Document();
      final screenshotController = ScreenshotController();
      int count = 0;

      // Determine which pages to process
      List<String> pagesToProcess = [];
      if (!hasMultiplePages || includeAllPages) {
        pagesToProcess = List.from(pageIds);
      } else {
        // Only include selected pages
        for (int index in selectedPageIndices) {
          if (index < pageIds.length) {
            pagesToProcess.add(pageIds[index]);
          }
        }
      }

      // Process each selected page
      for (final paperId in pagesToProcess) {
        final paperData = paperDBProvider.getPaperDBById(paperId);

        final double paperWidth = paperData['width'] as double? ?? 595.0;
        final double paperHeight = paperData['height'] as double? ?? 842.0;

        // Get the template for this page
        final template = paperTemplates[paperId] ??
            template_model.PaperTemplate(id: 'plain', name: 'Plain Paper');

        // Create a widget for this specific page
        final pageWidget = SizedBox(
          width: paperWidth,
          height: paperHeight,
          child: Stack(
            children: [
              // Background template
              CustomPaint(
                painter: TemplatePainter(template: template),
                size: Size(paperWidth, paperHeight),
              ),
              // PDF image if exists and should be included
              if (includePdfBackgrounds && paperData['background_image'] != '')
                Image.network(
                  paperData['background_image'],
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error: $error');
                    return Center(child: Text('Failed to load image'));
                  },
                ),
              // Drawings
              CustomPaint(
                painter: DrawingPainter(
                  drawingPoints: pageDrawingPoints[paperId] ?? [],
                ),
                size: Size(paperWidth, paperHeight),
              ),
            ],
          ),
        );

        // Capture screenshot of this page with the selected quality
        final Uint8List imageBytes =
            await screenshotController.captureFromWidget(
          pageWidget,
          pixelRatio: quality,
          targetSize: Size(paperWidth.toDouble(), paperHeight.toDouble()),
          context: context,
        );

        // Add the captured image to the PDF
        final image = pw.MemoryImage(imageBytes);

        // Add page to PDF with the correct dimensions
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(paperWidth, paperHeight),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.SizedBox(
                    width: paperWidth,
                    height: paperHeight,
                    child: pw.Image(image, fit: pw.BoxFit.contain),
                  ),
                ),
              );
            },
          ),
        );
        count++;
        if (kDebugMode) {
          print("Page: $count");
        }
      }

      // Get bytes of the PDF
      final pdfBytes = await pdf.save();

      // Save PDF to appropriate location based on platform
      String? filePath =
          await _savePdfToDeviceWithPicker(outputFileName, pdfBytes);

      // Hide loading overlay
      loadingOverlay.hide();

      return PDFDBExportResult(success: true, filePath: filePath);
    } catch (e, stackTrace) {
      // Hide loading overlay in case of error
      loadingOverlay.hide();
      debugPrint('Error exporting PDF: $e\n$stackTrace');
      rethrow; // Let the caller handle the exception
    }
  }

  Future<String?> _savePdfToDeviceWithPicker(
      String fileName, Uint8List pdfBytes) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        // User cancelled the picker
        return null;
      }

      // Ensure .pdf extension
      String nameWithoutExt =
          fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      String fullPath = '$selectedDirectory/$nameWithoutExt.pdf';
      int counter = 1;

      // Check if file exists and add (1), (2), etc.
      while (await File(fullPath).exists()) {
        fullPath = '$selectedDirectory/$nameWithoutExt ($counter).pdf';
        counter++;
      }

      final file = File(fullPath);
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error saving file with picker: $e');
      return null;
    }
  }
}
