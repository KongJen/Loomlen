import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend/items/text_annotation_item.dart';

class TextAnnotationWidget extends StatefulWidget {
  final TextAnnotation annotation;
  final double canvasWidth;
  final double canvasHeight;
  final Function(String) onTextChanged;
  final Function(Offset) onPositionChanged;
  final VoidCallback onStartEditing;
  final VoidCallback onDelete;
  final VoidCallback onEditingComplete;
  final VoidCallback onTap;
  final Color onColorChanged;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final GlobalKey settingsBarKey;

  const TextAnnotationWidget({
    Key? key,
    required this.annotation,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onStartEditing,
    required this.onDelete,
    required this.onEditingComplete,
    required this.onTap,
    required this.onColorChanged,
    required this.fontSize,
    required this.isBold,
    required this.isItalic,
    required this.settingsBarKey,
  }) : super(key: key);

  @override
  _TextAnnotationWidgetState createState() => _TextAnnotationWidgetState();
}

class _TextAnnotationWidgetState extends State<TextAnnotationWidget> {
  late TextEditingController _textController;
  FocusNode _focusNode = FocusNode();
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  Offset _positionStart = Offset.zero;

  // Add global pointer event handlers
  void _handleGlobalPointerEvent(PointerEvent event) {
    if (!_focusNode.hasFocus) return;

    final RenderBox? mainBox = context.findRenderObject() as RenderBox?;
    if (mainBox == null) return;

    final localPosition = mainBox.globalToLocal(event.position);
    final size = mainBox.size;

    final isInsideMainWidget = localPosition.dx >= 0 &&
        localPosition.dx <= size.width &&
        localPosition.dy >= 0 &&
        localPosition.dy <= size.height;

    // Check if click is inside the settings bar
    final RenderBox? settingsBox =
        widget.settingsBarKey.currentContext?.findRenderObject() as RenderBox?;

    bool isInsideSettingsBar = false;
    if (settingsBox != null) {
      final localToSettings = settingsBox.globalToLocal(event.position);
      final settingsSize = settingsBox.size;
      isInsideSettingsBar = localToSettings.dx >= 0 &&
          localToSettings.dx <= settingsSize.width &&
          localToSettings.dy >= 0 &&
          localToSettings.dy <= settingsSize.height;
    }

    if (!isInsideMainWidget && !isInsideSettingsBar) {
      widget.onEditingComplete();
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.annotation.text);

    // Add listeners for global pointer events
    GestureBinding.instance.pointerRouter
        .addGlobalRoute(_handleGlobalPointerEvent);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !widget.annotation.isEditing) {
        widget.onStartEditing();
      } else if (!_focusNode.hasFocus && widget.annotation.isEditing) {
        widget.onEditingComplete();
      }
    });
  }

  @override
  void didUpdateWidget(TextAnnotationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.annotation.text != _textController.text) {
      _textController.text = widget.annotation.text;
    }

    if (widget.annotation.isEditing && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    // Remove global event listeners
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute(_handleGlobalPointerEvent);

    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get text styling from annotation or current editing settings
    Color textColor = widget.annotation.isEditing && !widget.annotation.isBubble
        ? widget.onColorChanged
        : widget.annotation.color;

    double textFontSize =
        widget.annotation.isEditing && !widget.annotation.isBubble
            ? widget.fontSize
            : widget.annotation.fontSize;

    bool textBold = widget.annotation.isEditing && !widget.annotation.isBubble
        ? widget.isBold
        : widget.annotation.isBold;

    bool textItalic = widget.annotation.isEditing && !widget.annotation.isBubble
        ? widget.isItalic
        : widget.annotation.isItalic;

    // Calculate the bubble size based on text content
    double textWidth =
        _calculateTextWidth(widget.annotation.text, textFontSize);
    double textHeight = textFontSize * 1.5;

    // Determine if we should show controls (based on selection or editing)
    bool showControls =
        widget.annotation.isSelected || widget.annotation.isEditing;

    return Positioned(
      left: widget.annotation.position.dx,
      top: widget.annotation.position.dy,
      child: GestureDetector(
        onTap: () {
          widget.onTap();
        },
        onPanStart: (details) {
          if (!widget.annotation.isEditing) {
            _isDragging = true;
            _dragStart = details.localPosition;
            _positionStart = widget.annotation.position;
            widget.onTap(); // Select on drag start
          }
        },
        onPanUpdate: (details) {
          if (_isDragging && !widget.annotation.isEditing) {
            final newDx =
                _positionStart.dx + (details.localPosition.dx - _dragStart.dx);
            final newDy =
                _positionStart.dy + (details.localPosition.dy - _dragStart.dy);

            // Constrain to canvas boundaries
            final constrainedDx =
                newDx.clamp(0.0, widget.canvasWidth - textWidth);
            final constrainedDy =
                newDy.clamp(0.0, widget.canvasHeight - textHeight);

            widget.onPositionChanged(Offset(constrainedDx, constrainedDy));
          }
        },
        onPanEnd: (details) {
          _isDragging = false;
        },
        child: (widget.annotation.isBubble &&
                !widget.annotation.isSelected &&
                !widget.annotation.isEditing)
            ? Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.annotation.text.isNotEmpty
                      ? widget.annotation.text[0].toUpperCase()
                      : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0, // Fixed font size 16
                  ),
                ),
              )
            : Container(
                decoration: widget.annotation.isBubble
                    ? BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.black,
                          width: 1.0,
                        ),
                      )
                    : null,
                padding: widget.annotation.isBubble
                    ? EdgeInsets.all(8.0)
                    : EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.annotation.isEditing
                        ? widget.annotation.isBubble
                            ? SizedBox(
                                width: max(100, textWidth),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FontStyle.normal,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: null,
                                  onChanged: widget.onTextChanged,
                                  onEditingComplete: widget.onEditingComplete,
                                ),
                              )
                            : SizedBox(
                                width: max(100, textWidth),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: textFontSize,
                                    fontWeight: textBold
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontStyle: textItalic
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: null,
                                  onChanged: widget.onTextChanged,
                                  onEditingComplete: widget.onEditingComplete,
                                ),
                              )
                        : Text(
                            widget.annotation.text,
                            style: TextStyle(
                              color: widget.annotation.isBubble
                                  ? Colors.black
                                  : textColor,
                              fontSize: widget.annotation.isBubble
                                  ? 16.0
                                  : textFontSize,
                              fontWeight: widget.annotation.isBubble
                                  ? FontWeight.normal
                                  : (textBold
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              fontStyle: widget.annotation.isBubble
                                  ? FontStyle.normal
                                  : (textItalic
                                      ? FontStyle.italic
                                      : FontStyle.normal),
                            ),
                          ),
                    if (showControls) SizedBox(height: 8),
                    if (showControls)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Container(
                              padding: EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close,
                                  size: 16.0, color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          if (!widget.annotation.isEditing)
                            GestureDetector(
                              onTap: widget.onStartEditing,
                              child: Container(
                                padding: EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.edit,
                                    size: 16.0, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// Helper function to calculate text width
double _calculateTextWidth(String text, double fontSize) {
  if (text.isEmpty) return 0;

  // Basic calculation based on average character width
  final avgCharWidth =
      fontSize * 0.6; // Approximate width of an average character
  return text.length * avgCharWidth;
}
