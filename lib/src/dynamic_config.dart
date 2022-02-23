class DynamicConfig {
  String name;
  Map? value;
  DynamicConfig(this.name, this.value);

  T? get<T>(String key, [T? defaultValue]) {
    return value?[key] ?? defaultValue;
  }
}
