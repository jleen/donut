import 'dart:js_interop';
import 'dart:math';
import 'package:web/web.dart' as web;
import 'package:collection/collection.dart';

import 'package:react/hooks.dart';
import 'package:react/react.dart';
import 'package:react/react_dom.dart' as react_dom;

useAnimationFrame(callback) {
  final requestRef = useRefInit(0);
  final previousTimeRef = useRefInit<num>(0);

  animate(num time) {
    if (previousTimeRef.current != 0) {
      final deltaTime = time - previousTimeRef.current;
      callback(deltaTime);
    }
    previousTimeRef.current = time;
    requestRef.current = web.window.requestAnimationFrame(animate.toJS);
  }

  useEffect(() {
    requestRef.current = web.window.requestAnimationFrame(animate.toJS);
    return () => web.window.cancelAnimationFrame(requestRef.current);
  }, []);
}

var app = registerFunctionComponent((Map props) {
  var st = useStateLazy(init);
  useAnimationFrame((delta) => st.setWithUpdater((s) => update(s, delta)));
  return view(st.value);
});

void main() {
  final element = web.document.querySelector('#output') as web.HTMLDivElement;
  react_dom.render(app({}), element);
}


//// CONFIG

const umImg = 'um.png';
const slowness = 2500;
const horizTimeslice = 0.2;


//// MODEL

typedef State = ({List<PipeRow> pipes, num frameNum, Um um});
typedef Pipe = ({bool n, bool e, bool s, bool w});
typedef PipeRow = ({num y, List<Pipe> pipes});
typedef Um = ({int from, int to, num endFrameNum, bool spin});

State init() => (frameNum: 0, pipes: [], um: (from: 2, to: 2, endFrameNum: 0, spin: false));



//// EVOLUTION

State update(State model, num delta) {
  final frameNum = model.frameNum + delta / slowness;
  final pipes = updatePipes(frameNum, model.pipes);
  final um = updateUm(frameNum, pipes, model.um);
  return (frameNum: frameNum, pipes: pipes, um: um);
}

// Pipe grid

List<PipeRow> updatePipes(num frameNum, List<PipeRow> pipes) {
  final visPipes = pipes.where((p) => boxY(p.y, frameNum) > -2).toList();
  if (visPipes.isEmpty) {
    return visPipes + [generatePipes(frameNum.floor(), null)];
  } else {
    final lastPipe = visPipes[visPipes.length - 1];
    if (boxY(lastPipe.y, frameNum) > 6) {
      return visPipes;
    } else {
      return visPipes + [generatePipes(lastPipe.y + 1, lastPipe)];
    }
  }
}

bool toss() {
  return Random().nextBool();
}

Pipe newPipe() {
  return (n: toss(), s: toss(), e: toss(), w: toss());
}

PipeRow generatePipes(num y, PipeRow? prevRow) {
  var newRow = (
    y: y,
    pipes: [ newPipe(), newPipe(), newPipe(), newPipe(), newPipe() ]);
  newRow = reconcileV(newRow, prevRow);
  newRow = reconcileH(newRow);
  return newRow;
}

PipeRow reconcileV(PipeRow newRow, PipeRow? prevRow) {
  if (prevRow == null) {
    return newRow;
  } else {
    return (y: newRow.y,
            pipes: newRow.pipes.mapIndexed((i, p) =>
                       (n: prevRow.pipes[i].s, s: p.s, e: p.e, w: p.w)).toList());
  }
}

PipeRow reconcileH(PipeRow newRow) {
  return (y: newRow.y, pipes: newRow.pipes.mapIndexed((i, p) =>
      (e: i < 4 ? newRow.pipes[i+1].w : p.e, w: p.w, n: p.n, s: p.s)).toList());
}

boxY(num y, num frame) {
  return y - frame;
}

// Mon

Um updateUm(num frame, List<PipeRow> pipes, Um um) {
  if (frame <= um.endFrameNum) {
    return um;
  } else {
    final target = Random().nextInt(60);
    final (dest, spin) = selectGoal(pipes, um.to, target);
    final newUm = (from: um.to, to: dest, endFrameNum: frame.ceil(), spin: spin);
    return newUm;
  }
}

(int, bool) selectGoal(List<PipeRow> rows, int currentCol, int target) {
  if (rows.length < 3) {
    return (currentCol, true);
  } else {
    final row = rows[2];
    final connected = findConnected(currentCol, row.pipes);
    if (connected.isEmpty) {
      // Tumble in the void.
      return (currentCol, true);
    } else {
      // Can we get anywhere that lets us proceed?
      final unblocked = connected.where((i) => row.pipes[i].s).toList();
      final (candidates, spin) = unblocked.isEmpty ? (connected, true) : (unblocked, false);
      return (candidates[target % candidates.length], spin);
    }
  }
}

List<int> findConnected(int start, List<Pipe> pipes) {
  return [0,1,2,3,4].where((i) => connected(pipes, start, i)).toList();
}

connected(List<Pipe> pipes, int start, int end) {
  if (start == end) {
    // Wherever you go, there you are.
    return true;
  } else if (start < end) {
    return pipes.sublist(start, end).every((p) => p.e);
  } else {
    return pipes.sublist(end+1, start+1).every((p) => p.w);
  }
}


//// VIEW

view(State model) {
  return div({}, svg({'viewbox': '0 0 480 400', 'width': '480', 'height': '400'},
                     [pipeGrid(model.frameNum, model.pipes), umView(model.frameNum, model.um)]));
}

pipeGrid(num frameNum, List<PipeRow> rows) {
  return svg({'x': '0', 'y': '0', 'width': '480', 'height': '400', 'viewBox': '0 0 6 3'},
             rows.map((row) => row.pipes.mapIndexed((i, pipe) =>
                 pipeCell(i + 0.5, boxY(row.y, frameNum), pipe))));
}

const ne = "M 6 0 L 6 3 A 1 1 0 0 0 7 4 L 10 4";
const es = "M 6 10 L 6 7 A 1 1 0 0 1 7 6 L 10 6";
const sw = "M 0 6 L 3 6 A 1 1 0 0 1 4 7 L 4 10";
const wn = "M 0 4 L 3 4 A 1 1 0 0 0 4 3 L 4 0";
const ns = "M 6 0 L 6 10";
const sn = "M 4 0 L 4 10";
const we = "M 0 4 L 10 4";
const ew = "M 0 6 L 10 6";
const neo = "M 4 0 L 4 5 A 1 1 0 0 0 5 6 L 10 6";
const eso = "M 4 10 L 4 5 A 1 1 0 0 1 5 4 L 10 4";
const swo = "M 0 4 L 5 4 A 1 1 0 0 1 6 5 L 6 10";
const wno = "M 0 6 L 5 6 A 1 1 0 0 0 6 5 L 6 0";
const nx = "M 4 0 L 4 3 L 6 3 L 6 0";
const ex = "M 10 4 L 7 4 L 7 6 L 10 6";
const sx = "M 6 10 L 6 7 L 4 7 L 4 10";
const wx = "M 0 6 L 3 6 L 3 4 L 0 4";

pipeCell(num x, num y, Pipe p) {
  final (:n, :s, :e, :w) = p;
  return svg({'x': x, 'y': y, 'width': 1, 'height': 1, 'viewBox': '0 0 10 10 ', 'key': '${x}_$y'}, [
      pathIf(ne, n && e),
      pathIf(es, e && s),
      pathIf(sw, s && w),
      pathIf(wn, w && n),
      pathIf(ns, n && s && !e),
      pathIf(sn, s && n && !w),
      pathIf(we, w && e && !n),
      pathIf(ew, e && w && !s),
      pathIf(neo, n && e && !s && !w),
      pathIf(eso, e && s && !w && !n),
      pathIf(swo, s && w && !n && !e),
      pathIf(wno, w && n && !e && !s),
      pathIf(nx, n && !e && !s && !w),
      pathIf(ex, e && !s && !w && !n),
      pathIf(sx, s && !w && !n && !e),
      pathIf(wx, w && !n && !e && !s)
  ]);
}

pathIf(String p, bool cond) {
  if (cond) {
    return path({'d': p, 'stroke': 'blue', 'fill': 'none', 'strokeWidth': '0.2'});
  } else {
    return null;
  }
}

// Mon

umView(num frame, Um um) {
  final x = 40 + 80 * xUm(frame, um);
  final y = 70 + 80 * yUm(frame, um);
  final r = um.spin ? 360 * max(0, (((1 + horizTimeslice) * umParam(frame, um)) - horizTimeslice)) : 0;
  return foreignObject({'x': x, 'y': y, 'width': '100', 'height': '100', 'transform': rotation(r, x)},
            [img({'src': umImg, 'width': '80', 'height': '80'})]);
}

num xUm(num frame, Um um) {
  return interp(um.from, um.to, umParam(frame, um), horizTimeslice);
}

num yUm(num frame, Um um) {
  final t = umParam(frame, um);
  if (t < horizTimeslice) {
    return 1-t;
  } else {
    return (1 - 2 * horizTimeslice + horizTimeslice * t) / (1 - horizTimeslice);
  }
}

num umParam(num frame, Um um) {
  return 1 + frame - um.endFrameNum;
}

num interp(num a, num b, num t, num s) {
  final tt = min(1, t/s);
  return b * tt + a * (1-tt);
}

String rotation(num rot, num pos) {
  final x = pos + 45;
  final y = 175;
  return 'rotate($rot, $x, $y)';
}
