class LiveLocationSamplingPolicy {
  LiveLocationSamplingPolicy({
    this.currentWriteInterval = const Duration(seconds: 15),
    this.historyWriteInterval = const Duration(seconds: 60),
  });

  final Duration currentWriteInterval;
  final Duration historyWriteInterval;

  DateTime? _lastCurrentWriteAt;
  DateTime? _lastHistoryWriteAt;

  bool shouldWriteCurrent(DateTime now) {
    final lastWrite = _lastCurrentWriteAt;
    return lastWrite == null ||
        now.difference(lastWrite) >= currentWriteInterval;
  }

  bool shouldWriteHistory(DateTime now, {required bool movedEnough}) {
    final lastWrite = _lastHistoryWriteAt;
    return lastWrite == null ||
        (movedEnough && now.difference(lastWrite) >= historyWriteInterval);
  }

  void markCurrentWritten(DateTime now) {
    _lastCurrentWriteAt = now;
  }

  void markHistoryWritten(DateTime now) {
    _lastHistoryWriteAt = now;
  }

  void reset() {
    _lastCurrentWriteAt = null;
    _lastHistoryWriteAt = null;
  }
}
