import 'package:flutter/material.dart';
import 'package:frontend/model/drawingpoint.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as ml_kit;

class Paper extends StatefulWidget {
  const Paper({super.key});

  @override
  State<Paper> createState() => _PaperState();
}

class _PaperState extends State<Paper> {
  List<DrawingPoint> drawingPoints = [];
  List<DrawingPoint> historyDrawingPoints = [];
  DrawingPoint? currentDrawingPoint;

  Color selectedColor = Colors.black;
  double selectedWidth = 2.0;

  // Digital Ink Recognition related variables
  final ml_kit.DigitalInkRecognizer _digitalInkRecognizer =
      ml_kit.DigitalInkRecognizer(languageCode: 'en');
  final ml_kit.DigitalInkRecognizerModelManager _modelManager =
      ml_kit.DigitalInkRecognizerModelManager();
  final ml_kit.Ink _ink = ml_kit.Ink();
  List<ml_kit.StrokePoint> _strokePoints = [];
  String recognizedText = '';
  bool _modelDownloaded = false;
  var _language = 'en';

  @override
  void initState() {
    super.initState();
    _downloadModel();
  }

  Future<void> _downloadModel() async {
    try {
      final bool response = await _modelManager.downloadModel(_language);
      setState(() {
        _modelDownloaded = response;
      });
      if (response) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model downloaded successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading model: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _digitalInkRecognizer.close();
    super.dispose();
  }

  Future<void> _recognizeText() async {
    if (!_modelDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the model to download'),
        ),
      );
      return;
    }

    if (_ink.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something first'),
        ),
      );
      return;
    }

    try {
      setState(() {
        recognizedText = 'Recognizing...';
      });

      final List<ml_kit.RecognitionCandidate> candidates =
          await _digitalInkRecognizer.recognize(_ink);

      if (candidates.isNotEmpty) {
        setState(() {
          recognizedText = candidates.first.text;
          print('Recognized text: $recognizedText'); // For debugging
        });
      } else {
        setState(() {
          recognizedText = 'No text recognized';
        });
      }
    } catch (e) {
      setState(() {
        recognizedText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recognizing text: $e')),
        );
      }
    }
  }

  void _addNewStroke(Offset point, int timestamp) {
    // Convert drawing point to StrokePoint for ML Kit
    final ml_kit.StrokePoint strokePoint = ml_kit.StrokePoint(
      x: point.dx,
      y: point.dy,
      t: timestamp,
    );
    _strokePoints.add(strokePoint);
  }

  void _finishStroke() {
    if (_strokePoints.isNotEmpty) {
      final stroke = ml_kit.Stroke()..points = _strokePoints;
      _ink.strokes.add(stroke);
      _strokePoints = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Paper'),
        actions: [
          if (!_modelDownloaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: CircularProgressIndicator(),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _modelDownloaded ? _recognizeText : null,
            tooltip: _modelDownloaded ? 'Recognize Text' : 'Loading model...',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                drawingPoints.clear();
                historyDrawingPoints.clear();
                _ink.strokes.clear();
                _strokePoints.clear();
                recognizedText = '';
              });
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.only(bottom: 20),
              minScale: 1,
              maxScale: 3.0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        currentDrawingPoint = DrawingPoint(
                          id: DateTime.now().microsecondsSinceEpoch,
                          offsets: [details.localPosition],
                          color: selectedColor,
                          width: selectedWidth,
                        );
                        if (currentDrawingPoint == null) return;
                        drawingPoints.add(currentDrawingPoint!);
                        historyDrawingPoints = List.of(drawingPoints);

                        // Add point for ML Kit recognition
                        _addNewStroke(
                          details.localPosition,
                          DateTime.now().millisecondsSinceEpoch,
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        if (currentDrawingPoint == null) return;

                        currentDrawingPoint = currentDrawingPoint?.copyWith(
                          offsets: currentDrawingPoint!.offsets
                            ..add(details.localPosition),
                        );
                        drawingPoints.last = currentDrawingPoint!;
                        historyDrawingPoints = List.of(drawingPoints);

                        // Add point for ML Kit recognition
                        _addNewStroke(
                          details.localPosition,
                          DateTime.now().millisecondsSinceEpoch,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      currentDrawingPoint = null;
                      _finishStroke(); // Finish the stroke for ML Kit
                    },
                    child: Container(
                      width: 210 * 3,
                      height: 297 * 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            offset: const Offset(0, 3),
                            blurRadius: 5,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRect(
                        child: CustomPaint(
                          painter: DrawingPainter(drawingPoints: drawingPoints),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Display recognized text
          if (recognizedText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.grey.shade200,
              child: Text(
                'Recognized Text: $recognizedText',
                style: const TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> drawingPoints;

  DrawingPainter({required this.drawingPoints});

  @override
  void paint(Canvas canvas, Size size) {
    for (var drawingPoint in drawingPoints) {
      final paint = Paint()
        ..color = drawingPoint.color
        ..isAntiAlias = true
        ..strokeWidth = drawingPoint.width
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < drawingPoint.offsets.length; i++) {
        var notLastOffset = i != drawingPoint.offsets.length - 1;

        if (notLastOffset) {
          final current = drawingPoint.offsets[i];
          final next = drawingPoint.offsets[i + 1];
          canvas.drawLine(current, next, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
