import 'dart:js_interop';

@JS('__triggerMeritPwaInstall')
external JSPromise<JSString>? _jsTriggerMeritPwaInstall(JSString platformHint);

@JS('__triggerSwarmRebuild')
external void _jsTriggerSwarmRebuild();

Future<String> triggerMeritPwaInstall(String platformHint) async {
  try {
    final promise = _jsTriggerMeritPwaInstall(platformHint.toJS);
    if (promise == null) return 'unavailable';
    final result = await promise.toDart;
    return result.toDart;
  } catch (_) {
    return 'error';
  }
}

void triggerSwarmRebuild() {
  try {
    _jsTriggerSwarmRebuild();
  } catch (_) {}
}
