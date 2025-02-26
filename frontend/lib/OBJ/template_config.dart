import 'package:frontend/OBJ/object.dart'; // Import the template.dart file for PaperTemplate and TemplateType

// Constants and configurations for templates
class TemplateConfig {
  static const List<PaperTemplate> availableTemplates = [
    PaperTemplate(
      id: 'plain',
      name: 'Plain Paper',
      templateType: TemplateType.plain,
    ),
    PaperTemplate(
      id: 'lined',
      name: 'Lined Paper',
      templateType: TemplateType.lined,
      spacing: 30.0,
    ),
    PaperTemplate(
      id: 'grid',
      name: 'Grid Paper',
      templateType: TemplateType.grid,
      spacing: 30.0,
    ),
    PaperTemplate(
      id: 'dotted',
      name: 'Dotted Paper',
      templateType: TemplateType.dotted,
      spacing: 30.0,
    ),
  ];

  // Utility method to get the default template (optional, if you want to provide a helper)
  static PaperTemplate getDefaultTemplate() => availableTemplates.first;
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}
