// ignore_for_file: file_names

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/api/apiService.dart';
import 'package:frontend/items/template_item.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PdfDBService {
  final Function(String message) showError;
  final Function(String message) showSuccess;
  final Function(String fileId, String name) onImportComplete;
  final Function() showLoading;
  final Function() hideLoading;

  const PdfDBService({
    required this.showError,
    required this.showSuccess,
    required this.onImportComplete,
    required this.showLoading,
    required this.hideLoading,
  });

  Future<void> importPDFDB({
    required String parentId,
    required bool isInFolder,
    required String roomId,
    required Future<String> Function(
      String name, {
      required String roomId,
      required String parentFolderId,
    }) addFile,
    required Future<String> Function(
      PaperTemplate,
      int,
      double,
      double,
      String,
      String,
      String,
    ) addPaper,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String pdfPath = result.files.single.path!;
        String pdfName = result.files.single.name;
        print('Selected PDF: $pdfPath');

        PdfDocument pdfDoc = await PdfDocument.openFile(pdfPath);
        int pageCount = pdfDoc.pageCount;
        print('PDF has $pageCount pages');

        String fileId;
        if (isInFolder) {
          fileId =
              await addFile(pdfName, roomId: roomId, parentFolderId: parentId);
        } else {
          fileId =
              await addFile(pdfName, roomId: roomId, parentFolderId: 'Unknow');
        }

        showLoading();

        await _processPdfPages(pdfDoc, pdfName, fileId, roomId, addPaper);

        hideLoading();
        pdfDoc.dispose();

        showSuccess('PDF "$pdfName" imported as $pageCount pages');
        onImportComplete(fileId, pdfName);
      }
    } catch (e) {
      print('Error importing PDF: $e');
      showError('Error importing PDF: $e');
    }
  }

  Future<void> _processPdfPages(
    PdfDocument pdfDoc,
    String pdfName,
    String fileId,
    String roomId,
    Future<String> Function(
      PaperTemplate,
      int,
      double,
      double,
      String,
      String,
      String,
    ) addPaper,
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
      final Uint8List pngBytes = img.encodePng(image, level: 6);

      final ApiService _apiService = ApiService();

      final uuid = Uuid();
      final filename = '${uuid.v4()}_${pdfName}_page_$i.png';

      String imagePath =
          await _apiService.addImage(pngBytes, filename: filename);

      addPaper(
        PaperTemplate(id: 'plain', name: 'Plain Paper', spacing: 30.0),
        i,
        pdfWidth,
        pdfHeight,
        fileId,
        roomId,
        imagePath,
      );

      pageImage.dispose();
    }
  }
}
