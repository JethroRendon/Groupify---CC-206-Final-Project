class DataCacheEntry<T> {
  final T value;
  final DateTime expiry;
  DataCacheEntry(this.value, this.expiry);
  bool get isValid => DateTime.now().isBefore(expiry);
}

class DataCache {
  static final DataCache _instance = DataCache._internal();
  factory DataCache() => _instance;
  DataCache._internal();

  final Map<String, DataCacheEntry<dynamic>> _store = {};

  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (!entry.isValid) { _store.remove(key); return null; }
    return entry.value as T;
  }

  void set<T>(String key, T value, {Duration ttl = const Duration(seconds: 30)}) {
    _store[key] = DataCacheEntry<T>(value, DateTime.now().add(ttl));
  }

  void invalidate(String key) => _store.remove(key);
  void clear() => _store.clear();
}
