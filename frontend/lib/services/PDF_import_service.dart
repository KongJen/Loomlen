// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/items/template_item.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PdfService {
  final Function(String message) showError;
  final Function(String message) showSuccess;
  final Function(String fileId, String name) onImportComplete;
  final Function() showLoading;
  final Function() hideLoading;

  const PdfService({
    required this.showError,
    required this.showSuccess,
    required this.onImportComplete,
    required this.showLoading,
    required this.hideLoading,
  });

  Future<void> importPDF({
    required String parentId,
    required bool isInFolder,
    required Function(String, {String? parentFolderId, String? roomId}) addFile,
    required Function(
      PaperTemplate,
      int,
      List<Map<String, dynamic>>?,
      String,
      double,
      double,
      String,
    )
    addPaper,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String pdfPath = result.files.single.path!;
        String pdfName = result.files.single.name;
        debugPrint('Selected PDF: $pdfPath');

        PdfDocument pdfDoc = await PdfDocument.openFile(pdfPath);
        int pageCount = pdfDoc.pageCount;
        debugPrint('PDF has $pageCount pages');

        String fileId;
        if (isInFolder) {
          fileId = addFile(pdfName, parentFolderId: parentId);
        } else {
          fileId = addFile(pdfName, roomId: parentId);
        }

        showLoading();

        await _processPdfPages(pdfDoc, pdfName, fileId, addPaper);

        hideLoading();
        pdfDoc.dispose();

        showSuccess('PDF "$pdfName" imported as $pageCount pages');
        onImportComplete(fileId, pdfName);
      }
    } catch (e) {
      debugPrint('Error importing PDF: $e');
      showError('Error importing PDF: $e');
    }
  }

  Future<void> _processPdfPages(
    PdfDocument pdfDoc,
    String pdfName,
    String fileId,
    Function(
      PaperTemplate,
      int,
      List<Map<String, dynamic>>?,
      String,
      double,
      double,
      String,
    )
    addPaper,
  ) async {
    for (int i = 1; i <= pdfDoc.pageCount; i++) {
      PdfPage page = await pdfDoc.getPage(i);
      double pdfWidth = page.width;
      double pdfHeight = page.height;

      PdfPageImage? pageImage = await page.render(
        width: (page.width * 2).toInt(),
        height: (page.height * 2).toInt(),
      );

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        order: img.ChannelOrder.rgba,
      );
      final pngBytes = img.encodePng(image, level: 6);

      final directory = await getApplicationDocumentsDirectory();
      String imagePath = '${directory.path}/${pdfName}_page_$i.png';
      File imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      addPaper(
        PaperTemplate(id: 'plain', name: 'Plain Paper', spacing: 30.0),
        i,
        null,
        imagePath,
        pdfWidth,
        pdfHeight,
        fileId,
      );

      pageImage.dispose();
    }
  }
}
