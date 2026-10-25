/// Saves a text file to the user's downloads folder (browser download on the
/// web). Not available in VM tests.
library;

export 'file_saver_stub.dart' if (dart.library.js_interop) 'file_saver_web.dart' show saveTextFile;
