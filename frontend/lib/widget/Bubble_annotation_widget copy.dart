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

  const TextAnnotationWidget({
    super.key,
    required this.annotation,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onStartEditing,
    required this.onDelete,
    required this.onEditingComplete,
    required this.onTap,
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
          constraints: BoxConstraints(
            maxWidth: 300,
          ),
          decoration: BoxDecoration(
            border: widget.annotation.isSelected
                ? Border.all(color: Colors.blue, width: 1.0)
                : null,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.annotation.isSelected && !widget.annotation.isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        widget.onStartEditing();
                        setState(() {
                          _focusNode.requestFocus();
                          // You might also call a method like widget.onEditModeChanged(true);
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              if (widget.annotation.isEditing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: widget.annotation.color,
                          fontSize: widget.annotation.fontSize,
                        ),
                        decoration: InputDecoration(
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
                      icon: Icon(Icons.check, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        _focusNode.unfocus();
                        widget.onEditingComplete();
                        // You might need to call widget.onEditModeChanged(false) here too.
                      },
                    ),
                  ],
                )
              else if (widget.annotation.isSelected &&
                  !widget.annotation.isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Text(
                    widget.annotation.text,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: widget.annotation.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.annotation.text.isNotEmpty
                        ? widget.annotation.text[0].toUpperCase()
                        : '...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.annotation.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
