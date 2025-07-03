import 'package:flutter/material.dart';
import 'package:frontend/items/template_item.dart';

class TemplateSelectionDialog extends StatefulWidget {
  const TemplateSelectionDialog({Key? key}) : super(key: key);

  @override
  State<TemplateSelectionDialog> createState() =>
      _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends State<TemplateSelectionDialog> {
  late PaperTemplate _selectedTemplate;
  late List<PaperTemplate> _availableTemplates;

  @override
  void initState() {
    super.initState();
    // Get all available templates
    _availableTemplates = PaperTemplateFactory.getAllTemplates();
    // Set default selected template
    _selectedTemplate = _availableTemplates.first;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'Select Template',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: -15,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            // Template Selection Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Paper Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Template Selection Container
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _availableTemplates[index];
                        final isSelected = template.id == _selectedTemplate.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTemplate = template;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                    child: CustomPaint(
                                      painter: TemplateThumbnailPainter(
                                        template: template,
                                      ),
                                      size: const Size(100, 80),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4.0,
                                  ),
                                  child: Text(
                                    template.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, _selectedTemplate.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'SELECT',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// You need to ensure this class is available or included in your TemplateSelectionDialog file
class TemplateThumbnailPainter extends CustomPainter {
  final PaperTemplate template;

  TemplateThumbnailPainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    template.paintTemplate(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
