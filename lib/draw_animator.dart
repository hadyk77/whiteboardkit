import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'whiteboard_draw.dart';

typedef void DrawChanged(WhiteboardDraw draw);
typedef void DrawCompleted();

class DrawAnimator {
  final DrawChanged onChange;
  final DrawCompleted onComplete;

  WhiteboardDraw finalDraw;

  @protected
  Queue<Line> queued = Queue<Line>();
  late int? _playId;

  bool _skip = false;

  skip() => _skip = true;

  Timer? playDelay;

  int? _resizeId;
  bool _resizeNeedResume = false;

  DrawAnimator(
      {required double width,
      required double height,
      required this.onChange,
      required this.onComplete})
      : finalDraw = WhiteboardDraw.empty(width: width, height: height) {
    queued = Queue.from([]);
    _playId = null;
  }

  updateSize(double width, double height) async {
    var resizeId = _resizeId = new Random().nextInt(1000);

    await pause();

    Future.delayed(Duration(milliseconds: 200), () {
      _updateSize(resizeId, width, height);
    });
  }

  _updateSize(int resizeId, double width, double height) async {
    if (_resizeId != resizeId) return;

    var queuedLinesList = queued.map((e) => e.clone()).toList();

    var scaledFromQueued = WhiteboardDraw(
            lines: queuedLinesList.toList(),
            width: finalDraw.width,
            height: finalDraw.height)
        .getScaled(width, height);

    Queue<Line> newQueue = Queue.from([]);

    for (var element in queuedLinesList) {
      newQueue.add(element);
    }

    if (_resizeId != resizeId) return;

    finalDraw.scale(width, height);

    queued.clear();
    queued.addAll(newQueue.toList());

    if (_resizeNeedResume) await play();
    _resizeNeedResume = false;
    _resizeId = null;
  }

  loadDraw(WhiteboardDraw draw) async {
    await pause();
    finalDraw.lines = [];
    var drawScaled = draw.getScaled(finalDraw.width, finalDraw.height);

    addLinesToQueue(drawScaled.lines ?? []);
    await play();
  }

  @protected
  void addLinesToQueue(List<Line> lines) {
    final list = <Line>[];
    lines.forEach((l) => list.add(l));

    queued.addAll(list);
  }

  // replay() async {
  //   await pause();
  //   _serializedChunks.forEach((chunk) {
  //     _loadChunkToQueue(chunk);
  //   });
  //   await play();
  // }

  play() {
    var playIdLocal = _playId = new Random().nextInt(100);

    Future.delayed(Duration(milliseconds: 50), () {
      _play(playIdLocal);
    });
  }

  _play(int playIdLocal) async {
    if (_playId != playIdLocal) return;

    if (queued.isEmpty == true) return;

    _skip = false;

    Future(() async {
      if (_playId != playIdLocal) return;
      while (queued.isNotEmpty == true) {
        var queuedLine = queued.first;

        var points =
            queuedLine.points.toList(); //.skip(queuedLine.processedPoints)
        // if (queuedLine.lineIndex == finalDraw.lines.length - 1) {
        // points = points.skip(finalDraw.lines.last.points.length).toList();
        // } else {
        finalDraw.lines?.add(queuedLine.copyWith(points: []));
        // }

        if (queuedLine.points.length == 0 && !_skip && queuedLine.duration > 0)
          await Future.delayed(
            Duration(
              milliseconds: queuedLine.duration,
            ),
          );
        else
          for (var point in points) {
            var duration = queuedLine.duration ~/ queuedLine.points.length;
            if (!_skip && queuedLine.duration > 0)
              await Future.delayed(
                Duration(
                  milliseconds: duration,
                ),
              );

            if (playIdLocal != _playId) return;

            finalDraw.lines?.last.points.add(point);
            // queuedLine.processedPoints = queuedLine.processedPoints + 1;
            if (!_skip) onChange(finalDraw.copyWith());
          }
        if (playIdLocal != _playId) return;
        queued.removeFirst();
      }

      _playId = null;
      if (_skip) onChange(finalDraw.copyWith());
      onComplete();
    });
  }

  Future pause() async {
    await _pause();
  }

  Future _pause() async {
    _playId = null;
  }

  close() {
    pause();
  }
}
