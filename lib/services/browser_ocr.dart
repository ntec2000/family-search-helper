import 'dart:js_interop';

@JS('jokboRecognize')
external JSPromise<JSString> _recognize(JSString path, JSBoolean singleColumn);

Future<String> recognizeInBrowser(String path, {bool singleColumn = false}) async =>
    (await _recognize(path.toJS, singleColumn.toJS).toDart).toDart;


@JS('jokboRecognizeGlyph')
external JSPromise<JSString> _recognizeGlyph(JSString path);

Future<String> recognizeGlyphInBrowser(String path) async =>
    (await _recognizeGlyph(path.toJS).toDart).toDart;
