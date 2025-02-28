import 'dart:js_interop';
import 'package:web/web.dart' as web;

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

compFunc(Map props) {
  var s = useState(DateTime.now());
  useAnimationFrame((delta) => { s.set(DateTime.now()) });
  final now = s.value;
  final text = 'The time is soo0ooo ${now.hour}:${now.minute}:${now.second}';
  return div({}, text);
}

var comp = registerFunctionComponent(compFunc);

void main() {
  final element = web.document.querySelector('#output') as web.HTMLDivElement;
  react_dom.render(comp({}), element);
}
