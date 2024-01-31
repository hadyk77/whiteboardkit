import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whiteboardkit/whiteboardkit.dart';

import 'draw_chunker.dart';
import 'toolbox_options.dart';

class DrawingController extends WhiteboardController {
  bool _newLine = true;
  DateTime? lastPan;
  DateTime? firstPointTime;

  double brushSize = 20.0;
  Color brushColor = Colors.blue;
  bool erase = false;
  double eraserSize = 20.0;

  final _chunkController = StreamController<DrawChunk>.broadcast();
  DrawChunker? _chunker;
  final bool enableChunk;

  DrawingController({required WhiteboardDraw draw, this.enableChunk = false})
      : super(
            readonly: false,
            toolbox: true,
            toolboxOptions: ToolboxOptions(undo: !enableChunk)) {
    this.draw = draw.copyWith();
    streamController.sink.add(this.draw.copyWith());

    //chunker
    if (enableChunk) Timer.periodic(Duration(seconds: 5), (_) => _flushChunk());
  }

  @override
  close() {
    _chunkController.close();
    return super.close();
  }

  @override
  initializeSize(double width, double height) {
    super.initializeSize(width, height);
  }

  onPanUpdate(Offset position) {
    if (_newLine && lastPan != null) {
      if (DateTime.now().difference(lastPan!).inMilliseconds <
              (_chunker?.durationInMilliseconds ?? 0) &&
          (this.draw.lines.length == 0 || this.draw.lines.last.wipe != true)) {
        this.draw.lines.add(new Line(
              points: [],
              color: Colors.white,
              width: 0,
              duration: DateTime.now().difference(lastPan!).inMilliseconds,
            ));
      }

      this.draw.lines.add(new Line(
          points: [],
          color: erase ? Colors.white : brushColor,
          width: erase ? eraserSize : brushSize,
          duration: 0));
      _newLine = false;
      firstPointTime = DateTime.now();
    }

    if ((this.draw.lines.last.points.length) > 2 &&
        ((lastPan?.millisecond ?? 0) - DateTime.now().millisecond) < 100) {
      var a1 = position.dx - (this.draw.lines.last.points.last.x);
      var a2 = position.dy - (this.draw.lines.last.points.last.y);
      var a3 = sqrt(pow(a1, 2) + pow(a2, 2));

      if (a3 < 5) return;
    }

    if (this.draw.lines.last.points.length == 0 ||
        position != this.draw.lines.last.points.last.toOffset()) {
      this.draw.lines.last.points = new List.from(this.draw.lines.last.points)
        ..add(Point.fromOffset(position));
      this.draw.lines.last.duration =
          DateTime.now().difference(firstPointTime!).inMilliseconds;
      lastPan = DateTime.now();
    }
    streamController.sink.add(this.draw.copyWith());
  }

  onPanEnd() {
    _newLine = true;
    this.draw.lines.last.duration =
        DateTime.now().difference(firstPointTime!).inMilliseconds;

    if (this.draw.lines.length > 0 && this.draw.lines.last.points.length == 1) {
      var secondPoint = new Offset(this.draw.lines.last.points.last.x + 1,
          this.draw.lines.last.points.last.y + 1);
      this.draw.lines.last.points.add(Point.fromOffset(secondPoint));
    }
    if (this.draw.lines.length > 0 && this.draw.lines.last.points.length == 0) {
      this.draw.lines.removeLast();
    }
    streamController.sink.add(this.draw.copyWith());
  }

  undo() {
    if (this.draw.lines.length > 0) this.draw.lines.removeLast();
    streamController.sink.add(this.draw.copyWith());
  }

  wipe() {
    this.draw.lines.add(new Line(points: [], wipe: true));
    streamController.sink.add(this.draw.copyWith());
  }

  Future<void> _flushChunk() async {
    if (!_chunkController.hasListener) return;
    var chunk = _chunker?.next();
    if (chunk != null) _chunkController.sink.add(chunk);
  }

  Stream<DrawChunk> onChunk() {
    return _chunkController.stream;
  }
}
