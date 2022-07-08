class DynamicConfig {
  String name;
  Map value;
  DynamicConfig(this.name, [this.value = const {}]);

  T? get<T>(String key, [T? defaultValue]) {
    return value[key] ?? defaultValue;
  }

  static empty(String name) {
    return DynamicConfig(name);
  }
}
