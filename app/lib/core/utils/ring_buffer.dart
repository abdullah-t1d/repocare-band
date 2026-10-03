import 'dart:typed_data';

/// Fixed-size buffer of doubles that overwrites the oldest value when full.
///
/// Used for the live waveform: 100 values arrive every second and only the
/// last few seconds are drawn, so no allocation happens per sample.
class DoubleRingBuffer {
  DoubleRingBuffer(this.capacity)
      : assert(capacity > 0, 'capacity must be positive'),
        _data = Float64List(capacity);

  final int capacity;
  final Float64List _data;
  int _head = 0;
  int _length = 0;

  /// Number of values currently stored (at most [capacity]).
  int get length => _length;

  bool get isEmpty => _length == 0;

  void add(double value) {
    _data[_head] = value;
    _head = (_head + 1) % capacity;
    if (_length < capacity) _length++;
  }

  /// Value at [index], where 0 is the oldest stored value.
  double operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    final start = (_head - _length) % capacity;
    return _data[(start + index) % capacity];
  }

  void clear() {
    _head = 0;
    _length = 0;
  }

  /// Copy of the stored values, oldest first.
  List<double> toList() => [for (var i = 0; i < _length; i++) this[i]];
}
