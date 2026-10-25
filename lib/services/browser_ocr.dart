import 'dart:js_interop';

@JS('jokboRecognize')
external JSPromise<JSString> _recognize(JSString path, JSBoolean singleColumn);

Future<String> recognizeInBrowser(String path, {bool singleColumn = false}) async =>
    (await _recognize(path.toJS, singleColumn.toJS).toDart).toDart;
