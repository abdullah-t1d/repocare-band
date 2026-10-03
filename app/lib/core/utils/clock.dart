/// Source of the current time, injected so time-based logic can be tested.
typedef Now = DateTime Function();

DateTime systemNow() => DateTime.now();
