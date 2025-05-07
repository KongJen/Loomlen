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
  // Add parameters for canvas constraints
  final double canvasWidth;
  final double canvasHeight;

  const TextAnnotationWidget({
    super.key,
    required this.annotation,
    required this.onTextChanged,
    required this.onPositionChanged,
    required this.onStartEditing,
    required this.onDelete,
    required this.onEditingComplete,
    required this.onTap,
    required this.canvasWidth,
    required this.canvasHeight,
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
  bool _wasEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.annotation.text);
    _focusNode = FocusNode();
    _wasEditing = widget.annotation.isEditing;

    // Request focus if the annotation is in editing mode
    if (widget.annotation.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // When focus is lost and we were editing, complete the edit
    if (!_focusNode.hasFocus && widget.annotation.isEditing) {
      // Small delay to allow other UI interactions to complete
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && widget.annotation.isEditing) {
          widget.onEditingComplete();
        }
      });
    }
  }

  @override
  void didUpdateWidget(TextAnnotationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update text if it changed externally
    if (widget.annotation.text != _textController.text) {
      _textController.text = widget.annotation.text;
    }

    // Request focus when entering edit mode
    if (widget.annotation.isEditing && !_wasEditing) {
      _focusNode.requestFocus();
      _wasEditing = true;
    } else if (!widget.annotation.isEditing && _wasEditing) {
      _wasEditing = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  // Helper method to constrain position within canvas bounds
  Offset _constrainPosition(Offset position) {
    // Calculate width and height of the annotation
    double annotationWidth = widget.annotation.isBubble
        ? (widget.annotation.isEditing || widget.annotation.isSelected
            ? 300
            : 30)
        : 300; // Use maxWidth as a conservative estimate
    double annotationHeight = widget.annotation.isBubble
        ? (widget.annotation.isEditing || widget.annotation.isSelected
            ? 50
            : 30)
        : 50; // Estimate height based on content

    // Constrain x coordinate
    double x = position.dx;
    if (x < 0) x = 0;
    if (x > widget.canvasWidth - annotationWidth)
      x = widget.canvasWidth - annotationWidth;

    // Constrain y coordinate
    double y = position.dy;
    if (y < 0) y = 0;
    if (y > widget.canvasHeight - annotationHeight)
      y = widget.canvasHeight - annotationHeight;

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    // Constrain the position within canvas bounds
    final constrainedPosition = _constrainPosition(widget.annotation.position);

    if (widget.annotation.isBubble) {
      return Positioned(
        left: constrainedPosition.dx,
        top: constrainedPosition.dy,
        child: GestureDetector(
          onTap: widget.annotation.isEditing || widget.annotation.isSelected
              ? null
              : () {
                  widget.onTap(); // triggers selection
                  setState(() {});
                },
          child: widget.annotation.isEditing || widget.annotation.isSelected
              ? _buildFullTextBubble()
              : _buildBubblePreview(),
        ),
      );
    } else {
      return _buildStandardTextAnnotation();
    }
  }

  Widget _buildBubblePreview() {
    return Container(
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
        ),
      ),
    );
  }

  Widget _buildFullTextBubble() {
    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.0),
      ),
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  minLines: 1,
                  maxLines: null,
                  onChanged: widget.onTextChanged,
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) {
                      widget.onDelete();
                    } else {
                      widget.onEditingComplete();
                    }
                  },
                ),
              ),
              if (widget.annotation.isEditing)
                IconButton(
                  icon: const Icon(Icons.check, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _focusNode.unfocus();
                    if (_textController.text.trim().isEmpty) {
                      widget.onDelete();
                    } else {
                      widget.onEditingComplete();
                    }
                  },
                ),
            ],
          ),
          if (!widget.annotation.isEditing && widget.annotation.isSelected)
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
    );
  }

  Widget _buildStandardTextAnnotation() {
    return Positioned(
      left: widget.annotation.position.dx,
      top: widget.annotation.position.dy,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.annotation.isEditing ? null : widget.onTap,
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
              // Add a subtle background when editing or selected to improve visibility
              color: widget.annotation.isEditing || widget.annotation.isSelected
                  ? Colors.white.withOpacity(0.3)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.annotation.isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 50,
                          maxWidth: 250,
                        ),
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
                          // Handle enter key to complete editing
                          onSubmitted: (value) {
                            if (value.trim().isEmpty) {
                              widget.onDelete();
                            } else {
                              widget.onEditingComplete();
                            }
                          },
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
                if (widget.annotation.isSelected &&
                    !widget.annotation.isEditing)
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
      ),
    );
  }
}
