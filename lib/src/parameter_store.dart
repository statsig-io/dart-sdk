import 'package:statsig/src/statsig_client.dart';

import 'evaluation_details.dart';

class ParameterStore {
  /// The name of this ParameterStore
  final String name;

  /// Metadata about how this value was recieved.
  EvaluationDetails details;

  Map<String, dynamic> value;

  StatsigClient? client;

  bool disableExposureLogging;

  ParameterStore(this.client, this.name, this.details, this.value,
      this.disableExposureLogging);

  static empty(String name, EvaluationDetails details) {
    return ParameterStore(null, name, details, {}, false);
  }

  T? get<T>(String key, [T? defaultValue]) {
    var data = cast<Map<String, dynamic>>(value[key]);
    if (data == null) {
      return defaultValue;
    }
    var paramType = cast<String>(data["param_type"]);
    if (paramType == null) {
      return defaultValue;
    }
    if (defaultValue != null) {
      switch (paramType) {
        case "boolean":
          if (defaultValue is! bool) {
            return defaultValue;
          }
        case "number":
          if (defaultValue is! num) {
            return defaultValue;
          }
        case "string":
          if (defaultValue is! String) {
            return defaultValue;
          }
        case "object":
          if (defaultValue is! Map) {
            return defaultValue;
          }
        case "array":
          if (defaultValue is! List) {
            return defaultValue;
          }
        default:
          return defaultValue;
      }
    }
    return _getValueFromRefType(data, defaultValue);
  }

  List<dynamic>? getArray(String key, [List<dynamic>? defaultValue]) {
    var data = cast<Map<String, dynamic>>(value[key]);
    if (data == null) {
      return defaultValue;
    }
    var paramType = cast<String>(data["param_type"]);
    if (paramType == null) {
      return defaultValue;
    }
    if (defaultValue != null) {
      if (paramType != "array") {
        return defaultValue;
      }
    }
    return _getValueFromRefType(data, defaultValue);
  }

  Map<String, dynamic>? getMap(String key,
      [Map<String, dynamic>? defaultValue]) {
    var data = cast<Map<String, dynamic>>(value[key]);
    if (data == null) {
      return defaultValue;
    }
    var paramType = cast<String>(data["param_type"]);
    if (paramType == null) {
      return defaultValue;
    }
    if (defaultValue != null) {
      if (paramType != "object") {
        return defaultValue;
      }
    }
    return _getValueFromRefType(data, defaultValue);
  }

  T? _getValueFromRefType<T>(Map<String, dynamic> data, [T? defaultValue]) {
    var refType = cast<String>(data["ref_type"]);
    switch (refType) {
      case "static":
        return _evalStatic(data["value"], defaultValue);
      case "gate":
        return _evalGate(data, defaultValue);
      case "experiment":
        return _evalExperiment(data, defaultValue);
      case "layer":
        return _evalLayer(data, defaultValue);
      case "dynamic_config":
        return _evalConfig(data, defaultValue);
      default:
        return defaultValue;
    }
  }

  T? _evalStatic<T>(dynamic value, [T? defaultValue]) {
    return value ?? defaultValue;
  }

  T? _evalGate<T>(Map<String, dynamic> param, [T? defaultValue]) {
    var gateName = cast<String>(param["gate_name"]);
    var passValue = cast<T>(param["pass_value"]);
    var failValue = cast<T>(param["fail_value"]);
    if (gateName == null || passValue == null || failValue == null) {
      return defaultValue;
    }
    if (client == null) {
      return defaultValue;
    }
    var res = client?.checkGate(
      gateName,
      cast<bool>(defaultValue) ?? false,
      disableExposureLogging,
    );
    if (res == null) {
      return defaultValue;
    }
    return res ? passValue : failValue;
  }

  T? _evalExperiment<T>(Map<String, dynamic> param, [T? defaultValue]) {
    var expName = cast<String>(param["experiment_name"]);
    var paramName = cast<String>(param["param_name"]);
    if (expName == null || paramName == null) {
      return defaultValue;
    }
    if (client == null) {
      return defaultValue;
    }
    var res = client?.getConfig(expName,
        disableExposureLogging: disableExposureLogging);
    if (res == null) {
      return defaultValue;
    }
    return res.get(paramName, defaultValue);
  }

  T? _evalConfig<T>(Map<String, dynamic> param, [T? defaultValue]) {
    var configName = cast<String>(param["config_name"]);
    var paramName = cast<String>(param["param_name"]);
    if (configName == null || paramName == null) {
      return defaultValue;
    }
    if (client == null) {
      return defaultValue;
    }
    var res = client?.getConfig(configName,
        disableExposureLogging: disableExposureLogging);
    if (res == null) {
      return defaultValue;
    }
    return res.get(paramName, defaultValue);
  }

  T? _evalLayer<T>(Map<String, dynamic> param, [T? defaultValue]) {
    var layerName = cast<String>(param["layer_name"]);
    var paramName = cast<String>(param["param_name"]);
    if (layerName == null || paramName == null) {
      return defaultValue;
    }
    if (client == null) {
      return defaultValue;
    }
    var res = client?.getLayer(layerName,
        disableExposureLogging: disableExposureLogging);
    if (res == null) {
      return defaultValue;
    }
    return res.get(paramName, defaultValue);
  }

  T? cast<T>(x) => x is T ? x : null;
}
