import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../../core/constants/band_constants.dart';
import '../../domain/enums.dart';
import '../protocol/line_assembler.dart';
import 'band_transport.dart';

/// The browser offers the Web Serial API (Chrome or Edge on a computer).
bool isWebSerialSupported() => web.window.navigator.has('serial');

BandTransport createUsbSerialTransport() => WebSerialTransport();

/// USB link through the Web Serial API (`navigator.serial`) at 115200 baud.
///
/// * The port picker needs a user gesture, so [connect] must be called from a
///   click handler. Reconnecting after a lost connection opens the picker
///   again.
/// * An unplugged cable or a board reset (for example after an upload) ends
///   the read loop and is reported as [TransportFailureCode.connectionLost].
/// * A port that is already open elsewhere (Arduino Serial Monitor, another
///   tab) is reported as [TransportFailureCode.portBusy].
class WebSerialTransport extends BandTransportBase {
  /// Read errors after which the browser offers a new readable stream.
  static const Set<String> _recoverableReadErrors = {
    'BufferOverrunError',
    'BreakError',
    'FramingError',
    'ParityError',
  };

  _Serial? _serial;
  _SerialPort? _port;
  _Reader? _reader;
  Future<void>? _readLoopDone;
  JSFunction? _unplugListener;
  bool _closing = false;
  final LineAssembler _assembler = LineAssembler();
  ByteConversionSink? _decoder;

  @override
  TransportKind get kind => TransportKind.usbSerial;

  @override
  Future<void> connect() async {
    if (state != BandConnectionState.disconnected || isDisposed) return;
    final serial = _serialApi();
    if (serial == null) throw const TransportFailure(TransportFailureCode.unsupportedBrowser);

    setState(BandConnectionState.connecting);
    final _SerialPort port;
    try {
      port = await serial.requestPort().toDart;
    } on Object catch (e) {
      setState(BandConnectionState.disconnected);
      throw TransportFailure(
        _errorName(e) == 'NotFoundError'
            ? TransportFailureCode.noPortSelected
            : TransportFailureCode.openFailed,
        '$e',
      );
    }

    try {
      await port.open(_SerialOptions(baudRate: BandConstants.baudRate)).toDart;
    } on Object catch (e) {
      setState(BandConnectionState.disconnected);
      // Chrome reports a port that another program holds as
      // "NetworkError: Failed to open serial port."
      final busy = const {'NetworkError', 'InvalidStateError'}.contains(_errorName(e));
      throw TransportFailure(
        busy ? TransportFailureCode.portBusy : TransportFailureCode.openFailed,
        '$e',
      );
    }

    _serial = serial;
    _port = port;
    _closing = false;
    _assembler.clear();
    _decoder = const Utf8Decoder(allowMalformed: true)
        .startChunkedConversion(_TextSink(_onText));
    _listenForUnplug(serial, port);
    setState(BandConnectionState.connected);
    _readLoopDone = _readLoop(port);
  }

  @override
  Future<void> disconnect() async {
    final port = _port;
    if (port == null) {
      setState(BandConnectionState.disconnected);
      return;
    }
    _closing = true;
    await _cancelReader();
    try {
      await _readLoopDone;
    } on Object {
      // The loop handles its own errors; nothing left to do.
    }
    await _closePort(port);
    setState(BandConnectionState.disconnected);
  }

  @override
  Future<void> send(String command) async {
    final writable = _port?.writable;
    if (writable == null || state != BandConnectionState.connected) return;
    final writer = writable.getWriter();
    try {
      await writer.write(utf8.encode(command).toJS).toDart;
    } on Object {
      // A failed write means the link is gone; the read loop reports it.
    } finally {
      writer.releaseLock();
    }
  }

  Future<void> _readLoop(_SerialPort port) async {
    var lost = false;
    while (!_closing && !lost) {
      final readable = port.readable;
      if (readable == null) {
        lost = true;
        break;
      }
      final reader = readable.getReader();
      _reader = reader;
      try {
        while (true) {
          final result = await reader.read().toDart;
          if (result.done) {
            lost = !_closing;
            break;
          }
          final chunk = result.value;
          if (chunk != null) _decoder?.add(chunk.toDart);
        }
      } on Object catch (e) {
        if (!_closing && !_recoverableReadErrors.contains(_errorName(e))) lost = true;
      } finally {
        _reader = null;
        try {
          reader.releaseLock();
        } on Object {
          // Already released by the browser after a fatal error.
        }
      }
    }
    if (lost && !_closing) await _handleLost(port);
  }

  Future<void> _handleLost(_SerialPort port) async {
    if (_closing) return;
    _closing = true;
    await _cancelReader();
    await _closePort(port);
    setState(BandConnectionState.disconnected);
    reportFailure(const TransportFailure(TransportFailureCode.connectionLost));
  }

  Future<void> _cancelReader() async {
    try {
      await _reader?.cancel().toDart;
    } on Object {
      // The device may already be gone.
    }
  }

  Future<void> _closePort(_SerialPort port) async {
    try {
      await port.close().toDart;
    } on Object {
      // Closing an unplugged port fails; the browser frees it anyway.
    }
    final listener = _unplugListener;
    if (listener != null) _serial?.removeEventListener('disconnect', listener);
    _unplugListener = null;
    _port = null;
    _decoder = null;
    _assembler.clear();
  }

  void _listenForUnplug(_Serial serial, _SerialPort port) {
    void onDisconnect(web.Event event) {
      if (event.target.strictEquals(port).toDart) unawaited(_handleLost(port));
    }

    final listener = onDisconnect.toJS;
    serial.addEventListener('disconnect', listener);
    _unplugListener = listener;
  }

  void _onText(String text) => _assembler.add(text).forEach(emitLine);

  static _Serial? _serialApi() {
    final navigator = web.window.navigator;
    if (!navigator.has('serial')) return null;
    return navigator.getProperty<_Serial>('serial'.toJS);
  }

  /// Name of a browser error (`NotFoundError`, `NetworkError`, ...).
  ///
  /// A DOMException converts to text as `"<Name>: <message>"`.
  static String? _errorName(Object error) {
    for (final match in RegExp(r'\b([A-Z][A-Za-z]*Error)\b').allMatches('$error')) {
      final name = match.group(1);
      if (name != 'Error') return name;
    }
    return null;
  }
}

/// Receives decoded text from the UTF-8 decoder.
class _TextSink implements Sink<String> {
  const _TextSink(this._onText);

  final void Function(String) _onText;

  @override
  void add(String data) => _onText(data);

  @override
  void close() {}
}

// Minimal bindings for the Web Serial API, which package:web does not cover.
// https://wicg.github.io/serial/

extension type _Serial._(JSObject _) implements web.EventTarget {
  external JSPromise<_SerialPort> requestPort();
}

extension type _SerialPort._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(_SerialOptions options);
  external JSPromise<JSAny?> close();
  external _ReadableStream? get readable;
  external _WritableStream? get writable;
}

extension type _SerialOptions._(JSObject _) implements JSObject {
  external factory _SerialOptions({required int baudRate});
}

extension type _ReadableStream._(JSObject _) implements JSObject {
  external _Reader getReader();
}

extension type _Reader._(JSObject _) implements JSObject {
  external JSPromise<_ReadResult> read();
  external JSPromise<JSAny?> cancel();
  external void releaseLock();
}

extension type _ReadResult._(JSObject _) implements JSObject {
  external bool get done;
  external JSUint8Array? get value;
}

extension type _WritableStream._(JSObject _) implements JSObject {
  external _Writer getWriter();
}

extension type _Writer._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array chunk);
  external void releaseLock();
}
