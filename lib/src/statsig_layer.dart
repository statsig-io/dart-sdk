import 'evaluation_details.dart';

class Layer {
  /// The name of this Layer.
  final String name;

  /// Metadata about how this value was recieved.
  EvaluationDetails details;

  final Map<String, dynamic> _value;
  final Function(Layer, String) _onParamExposure;

  Layer(this.name, this.details,
      [this._value = const {}, this._onParamExposure = noop]);

  /// Gets a value from the Layer
  ///
  /// If a value for the given key is found, the value is returned and an exposure is logged.
  /// If no value for the given key is found, the defaultValue is returned and no exposure is logged.
  T? get<T>(String key, [T? defaultValue]) {
    var result = _value[key];

    if (result != null) {
      _onParamExposure(this, key);
    }
    return _value[key] ?? defaultValue;
  }

  static empty(String name, EvaluationDetails details) {
    return Layer(name, details);
  }
}

noop(a, b) {}
