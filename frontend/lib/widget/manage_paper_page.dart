import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/items/template_item.dart';
import 'package:frontend/widget/drawing_point_preview.dart';
import 'package:frontend/providers/paper_provider.dart';
import 'package:frontend/providers/paperdb_provider.dart';
import 'package:frontend/widget/select_template.dart'
    show TemplateSelectionDialog;
import 'package:provider/provider.dart';

class ManagePaperPage extends StatefulWidget {
  final String fileId;
  final PaperProvider paperProvider;

  const ManagePaperPage({
    Key? key,
    required this.fileId,
    required this.paperProvider,
  }) : super(key: key);

  @override
  State<ManagePaperPage> createState() => _ManagePaperPageState();
}

class _ManagePaperPageState extends State<ManagePaperPage>
    with SingleTickerProviderStateMixin {
  int? _draggingIndex;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paperIds = widget.paperProvider.getPaperIdsByFileId(widget.fileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Papers"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add page at end',
            onPressed: () => _addNewPage(context, paperIds.length),
          ),
        ],
      ),
      body: paperIds.isEmpty
          ? _buildEmptyState(context)
          : _buildPageList(context, paperIds),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.note_add, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No pages found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Add your first page to get started'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add First Page'),
            onPressed: () => _addNewPage(context, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildPageList(BuildContext context, List<String> paperIds) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      itemCount: paperIds.length,
      proxyDecorator: (child, index, animation) {
        // Enhanced drag visual feedback
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevationValue = Curves.easeInOut.transform(
                  animation.value,
                ) *
                20;

            return Material(
              elevation: elevationValue,
              color: Colors.transparent,
              shadowColor: Colors.black54,
              child: Transform.scale(
                scale: 1.03,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorderStart: (index) {
        setState(() {
          _draggingIndex = index;
        });
        // Provide haptic feedback
        HapticFeedback.mediumImpact();
        _animationController.forward();
      },
      onReorderEnd: (index) {
        setState(() {
          _draggingIndex = null;
        });
        _animationController.reverse();
      },
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        _movePaper(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final paperId = paperIds[index];
        final paper = widget.paperProvider.getPaperById(paperId);
        if (paper == null) return const SizedBox.shrink();

        final double width = paper['width'] ?? 595.0;
        final double height = paper['height'] ?? 842.0;
        final double scaleFactor = 0.3;
        final template = PaperTemplateFactory.getTemplate(paper['templateId']);

        return Column(
          key: ValueKey(paperId),
          children: [
            // Insert button above the first item
            if (index == 0) _buildInsertButton(context, index),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                elevation: _draggingIndex == index ? 8 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _draggingIndex == index
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: _draggingIndex == index ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page ${paper['PageNumber']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Paper preview with drop shadow
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Container(
                          width: width * scaleFactor,
                          height: height * scaleFactor,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.white,
                          ),
                          child: Stack(
                            children: [
                              CustomPaint(
                                painter: TemplateThumbnailPainter(
                                  template: template,
                                  scaleFactor: scaleFactor,
                                ),
                                size: Size(
                                    width * scaleFactor, height * scaleFactor),
                              ),
                              if (paper['pdfPath'] != null)
                                Image.file(
                                  File(paper['pdfPath']),
                                  width: width * scaleFactor,
                                  height: height * scaleFactor,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint(
                                        'Failed to load image for $paperId: $error');
                                    return const Center(
                                        child: Text('Failed to load PDF'));
                                  },
                                ),
                              CustomPaint(
                                painter: DrawingThumbnailPainter(
                                  drawingPoints: widget.paperProvider
                                      .getDrawingPointsForPage(paperId),
                                  scaleFactor: scaleFactor,
                                ),
                                size: Size(
                                    width * scaleFactor, height * scaleFactor),
                              ),
                              // Overlay indicator for dragging
                              if (_draggingIndex == index)
                                Container(
                                  width: width * scaleFactor,
                                  height: height * scaleFactor,
                                  color: Colors.black.withOpacity(0.1),
                                  child: Center(
                                    child: Icon(
                                      Icons.swap_vert,
                                      size: 40,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _showDeleteConfirmation(context, paperId),
                            tooltip: 'Delete page',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Insert button after each item
            _buildInsertButton(context, index + 1),
          ],
        );
      },
    );
  }

  Widget _buildInsertButton(BuildContext context, int position) {
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: InkWell(
          onTap: () => _addNewPage(context, position),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, size: 16),
                SizedBox(width: 4),
                Text('Insert page here', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _movePaper(int fromIndex, int toIndex) {
    widget.paperProvider.swapPaperOrder(widget.fileId, fromIndex, toIndex);
  }

  void _showDeleteConfirmation(BuildContext context, String paperId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('Are you sure you want to delete this page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePaper(context, paperId);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _deletePaper(BuildContext context, String paperId) {
    widget.paperProvider.deletePaper(paperId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Page deleted')),
    );
  }

  Future<void> _addNewPage(BuildContext context, int position) async {
    // Show template selection dialog
    final String? selectedTemplateId = await showDialog<String>(
      context: context,
      builder: (context) => const TemplateSelectionDialog(),
    );

    // If user cancelled the dialog
    if (selectedTemplateId == null) {
      return;
    }

    // Get the selected template
    final template = PaperTemplateFactory.getTemplate(selectedTemplateId);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Insert the new page
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.paperProvider.insertPaperAt(
        widget.fileId,
        position,
        template,
        null, // No PDF path
        595.0, // Default width (A4)
        842.0, // Default height (A4)
      );

      // Hide loading indicator
      Navigator.of(context).pop();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New ${template.name} page inserted')),
      );
    });
  }
}
