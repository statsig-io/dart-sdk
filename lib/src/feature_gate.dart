import 'evaluation_details.dart';

class FeatureGate {
  /// The name of this FeatureGate
  final String name;

  /// The value of this FeatureGate for the current user.
  final bool value;

  final String ruleID;

  final List<dynamic> secondaryExposures;

  final String idType;

  /// Metadata about how this value was recieved.
  EvaluationDetails details;

  FeatureGate(this.name, this.details,
      [this.value = false,
      this.ruleID = "default",
      this.secondaryExposures = const [],
      this.idType = ""]);

  static empty(String name, EvaluationDetails details) {
    return FeatureGate(name, details);
  }
}
