import 'evaluation_details.dart';

class FeatureGate {
  /// The name of this FeatureGate
  final String name;

  /// The value of this FeatureGate for the current user.
  final bool value;

  /// Metadata about how this value was recieved.
  EvaluationDetails details;

  FeatureGate(this.name, this.details, [this.value = false]);

  static empty(String name, EvaluationDetails details) {
    return FeatureGate(name, details);
  }
}
