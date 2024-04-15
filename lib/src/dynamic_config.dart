class DynamicConfig {
  /// The name of this DynamicConfig
  final String name;

  /// The loaded values of this DynamicConfig for the current user.
  Map<String, dynamic> value;

  DynamicConfig(this.name, [this.value = const {}]);

  /// Gets a value from the DynamicConfig
  ///
  /// Uses the given key to fetch a value from the DynamicConfig if it exists.
  /// If no value for the given key is found, the defaultValue is returned.
  T? get<T>(String key, [T? defaultValue]) {
    return value[key] ?? defaultValue;
  }

  static empty(String name) {
    return DynamicConfig(name);
  }
}
