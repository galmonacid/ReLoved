class ChatOpenPerfProbe {
  ChatOpenPerfProbe._();

  static final Map<String, Object?> _values = <String, Object?>{};

  static void reset() {
    _values.clear();
  }

  static void record(Map<String, Object?> values) {
    _values.addAll(values);
  }

  static Map<String, Object?> snapshot() {
    return Map<String, Object?>.unmodifiable(_values);
  }
}
