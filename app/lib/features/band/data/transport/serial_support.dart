/// Web Serial on the web, a stub everywhere else (so the rest of the app and
/// the unit tests compile on the Dart VM).
library;

export 'serial_support_stub.dart'
    if (dart.library.js_interop) 'web_serial_transport.dart'
    show createUsbSerialTransport, isWebSerialSupported;
