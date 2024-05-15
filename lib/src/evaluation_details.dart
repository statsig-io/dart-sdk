import 'internal_store.dart';

class EvaluationDetails {
  /// This is a string containing the source as well as whether or not the specific config was found.
  String reason;

  /// Last Config Update Time - This is the unix timestamp for when any configuration in your project changed.
  int lcut = 0;

  /// This is the unix timestamp of when the SDK received these values. This can be useful in knowing how old your cache is.
  int receivedAt = 0;

  EvaluationDetails(this.reason, this.lcut, this.receivedAt);

  static uninitialized() {
    return EvaluationDetails(EvalReason.Uninitialized.name, 0, 0);
  }
}
