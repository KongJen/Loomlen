// Enhanced TextAnnotationWidget

import 'package:flutter/material.dart';
import 'package:frontend/items/text_annotation_item.dart';

class TextAnnotationWidget extends StatefulWidget {
  final TextAnnotation annotation;
  final Function(String) onTextChanged;
  final Function(Offset) onPositionChanged;
  final VoidCallback onStartEditing;
  final VoidCallback onDelete;
  final VoidCallback onEditingComplete;
  final VoidCallback onTap;
  final Color? onColorChanged;
  final double? fontSize;
  final bool? isBold;
  final bool? isItalic;

  const TextAnnotationWidget({
    super.key,
    required this.annotation,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onStartEditing,
    required this.onDelete,
    required this.onEditingComplete,
    required this.onTap,
    this.onColorChanged,
    this.fontSize,
    this.isBold,
    this.isItalic,
  });

  @override
  State<TextAnnotationWidget> createState() => _TextAnnotationWidgetState();
}

class _TextAnnotationWidgetState extends State<TextAnnotationWidget> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  Offset _startDragPosition = Offset.zero;
  Offset _startAnnotationPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.annotation.text);
    _focusNode = FocusNode();

    // Request focus if the annotation is in editing mode
    if (widget.annotation.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.annotation.isEditing) {
      widget.onEditingComplete();
    }
  }

  @override
  void didUpdateWidget(TextAnnotationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.annotation.text != _textController.text) {
      _textController.text = widget.annotation.text;
    }

    if (widget.annotation.isEditing && !oldWidget.annotation.isEditing) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.annotation.position.dx,
      top: widget.annotation.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (details) {
          if (!widget.annotation.isEditing) {
            _startDragPosition = details.localPosition;
            _startAnnotationPosition = widget.annotation.position;
          }
        },
        onPanUpdate: (details) {
          if (!widget.annotation.isEditing) {
            final delta = details.localPosition - _startDragPosition;
            final newPosition = _startAnnotationPosition + delta;
            widget.onPositionChanged(newPosition);
          }
        },
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
          ),
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            border: widget.annotation.isSelected
                ? Border.all(color: Colors.blue, width: 1.0)
                : null,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.annotation.isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50, // Wider to accommodate more text
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: widget.onColorChanged == null
                              ? widget.annotation.color
                              : widget.onColorChanged,
                          fontSize: widget.fontSize == null
                              ? widget.annotation.fontSize
                              : widget.fontSize,
                          fontWeight: widget.isBold == null
                              ? widget.annotation.isBold
                                  ? FontWeight.bold
                                  : FontWeight.normal
                              : widget.isBold == true
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontStyle: widget.isItalic == null
                              ? widget.annotation.isItalic
                                  ? FontStyle.italic
                                  : FontStyle.normal
                              : widget.isItalic == true
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(4.0),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: null,
                        onChanged: widget.onTextChanged,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _focusNode.unfocus();
                        if (_textController.text.trim().isEmpty) {
                          widget.onDelete(); // Delete if text is empty
                        } else {
                          widget
                              .onEditingComplete(); // Otherwise, complete editing
                        }
                      },
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(4.0),
                  constraints: const BoxConstraints(
                    minWidth: 10, // Allow for minimum width
                    maxWidth: 300, // Maximum width constraint
                  ),
                  child: Text(
                    widget.annotation.text.isEmpty
                        ? ''
                        : widget.annotation.text,
                    style: TextStyle(
                      color: widget.annotation.color,
                      fontSize: widget.annotation.fontSize,
                      fontWeight: widget.annotation.isBold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: widget.annotation.isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              // Buttons appear AFTER the text when selected and not editing
              if (widget.annotation.isSelected && !widget.annotation.isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        widget.onStartEditing();
                        setState(() {
                          _focusNode.requestFocus();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDelete,
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
