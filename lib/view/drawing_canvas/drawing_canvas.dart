import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/main.dart';
import 'package:flutter_drawing_board/view/drawing_canvas/models/drawing_mode.dart';
import 'package:flutter_drawing_board/view/drawing_canvas/models/sketch.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DrawingCanvas extends HookWidget {
  final double height;
  final double width;
  final ValueNotifier<Color> selectedColor;
  final ValueNotifier<double> strokeSize;
  final ValueNotifier<double> eraserSize;
  final ValueNotifier<DrawingMode> drawingMode;
  final AnimationController sideBarController;
  final ValueNotifier<Sketch?> currentSketch;
  final ValueNotifier<Sketch?> removedSketch;
  final ValueNotifier<List<Sketch>> allSketches;
  final GlobalKey canvasGlobalKey;

  const DrawingCanvas({
    Key? key,
    required this.height,
    required this.width,
    required this.selectedColor,
    required this.strokeSize,
    required this.eraserSize,
    required this.drawingMode,
    required this.sideBarController,
    required this.currentSketch,
    required this.removedSketch,
    required this.allSketches,
    required this.canvasGlobalKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    void onPointerDown(PointerDownEvent details) {
      final box = context.findRenderObject() as RenderBox;
      final offset = box.globalToLocal(details.position);
      currentSketch.value = Sketch.fromDrawingMode(
        Sketch(
          points: [offset],
          size: drawingMode.value == DrawingMode.eraser
              ? eraserSize.value
              : strokeSize.value,
          color: drawingMode.value == DrawingMode.eraser
              ? kCanvasColor
              : selectedColor.value,
        ),
        drawingMode.value,
      );
    }

    void onPointerMove(PointerMoveEvent details) {
      // close sidebar if open
      if (sideBarController.value == 1) sideBarController.reverse();
      // clear removed sketch to disable 'redo' button
      removedSketch.value = null;
      final box = context.findRenderObject() as RenderBox;
      final offset = box.globalToLocal(details.position);
      final points = List<Offset>.from(currentSketch.value?.points ?? [])
        ..add(offset);
      currentSketch.value = Sketch.fromDrawingMode(
        Sketch(
          points: points,
          size: drawingMode.value == DrawingMode.eraser
              ? eraserSize.value
              : strokeSize.value,
          color: drawingMode.value == DrawingMode.eraser
              ? kCanvasColor
              : selectedColor.value,
        ),
        drawingMode.value,
      );
    }

    void onPointerUp(PointerUpEvent details) {
      allSketches.value = List<Sketch>.from(allSketches.value)
        ..add(currentSketch.value!);
    }

    buildAllSketches() {
      return SizedBox(
        height: height,
        width: width,
        child: ValueListenableBuilder<List<Sketch>>(
          valueListenable: allSketches,
          builder: (context, sketches, _) {
            // Clipping makes sure the painting doesnt leave the canvas
            return RepaintBoundary(
              key: canvasGlobalKey,
              child: SizedBox(
                height: height,
                width: width,
                child: CustomPaint(
                  painter: SketchPainter(
                    sketches: sketches,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    Widget buildCurrentPath() {
      return Listener(
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        child: ValueListenableBuilder(
          valueListenable: currentSketch,
          builder: (context, sketch, child) {
            return RepaintBoundary(
              child: SizedBox(
                height: height,
                width: width,
                child: CustomPaint(
                  painter: SketchPainter(
                    sketches: sketch == null ? [] : [sketch],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Stack(
      children: [
        buildAllSketches(),
        buildCurrentPath(),
      ],
    );
  }
}

class SketchPainter extends CustomPainter {
  final List<Sketch> sketches;

  const SketchPainter({Key? key, required this.sketches});

  @override
  void paint(Canvas canvas, Size size) {
    for (Sketch sketch in sketches) {
      final points = sketch.points;
      if (points.isEmpty) return;

      final path = Path();

      path.moveTo(points[0].dx, points[0].dy);
      if (points.length < 2) {
        // If the path only has one line, draw a dot.
        path.addOval(
          Rect.fromCircle(
            center: Offset(points[0].dx, points[0].dy),
            radius: 1,
          ),
        );
      }

      for (int i = 1; i < points.length - 1; ++i) {
        final p0 = points[i];
        final p1 = points[i + 1];
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }

      Paint paint = Paint()
        ..color = sketch.color
        ..strokeCap = StrokeCap.round;

      if (!sketch.filled) {
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = sketch.size;
      }

      // create rect for rect and circle
      Rect rect = Rect.fromPoints(
        Offset(sketch.points.first.dx, sketch.points.first.dy),
        Offset(sketch.points.last.dx, sketch.points.last.dy),
      );

      if (sketch.type == SketchType.scribble) {
        // if the sketch type is [SketchType.scribble] then draw the path created above
        // path.close();
        canvas.drawPath(path, paint);
      } else if (sketch.type == SketchType.square) {
        // if the type is [SketchType.square] the draw a Rounded rectangle
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          paint,
        );
      } else if (sketch.type == SketchType.line) {
        canvas.drawLine(
          Offset(sketch.points.first.dx, sketch.points.first.dy),
          Offset(sketch.points.last.dx, sketch.points.last.dy),
          paint,
        );
      } else if (sketch.type == SketchType.circle) {
        // if the type is [SketchType.circle] the draw an oval
        canvas.drawOval(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) {
    return oldDelegate.sketches != sketches;
  }
}
