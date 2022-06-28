import 'dart:convert';

abstract class TestData {
  static var initializeResponse = json.encode({
    "feature_gates": {
      "5v6IDYah7WmooSLkL7W3ak4pzBq5KXvJdac3tRmLnzE=" /* a_gate */ : {
        "name": "5v6IDYah7WmooSLkL7W3ak4pzBq5KXvJdac3tRmLnzE=",
        "value": true,
        "rule_id": "a_rule_id",
        "secondary_exposures": []
      }
    },
    "dynamic_configs": {
      "klGzwI7eIlw4LSeTwhb4C0NCIhHJrIf441Dni6g7DkE=": {
        "name": "klGzwI7eIlw4LSeTwhb4C0NCIhHJrIf441Dni6g7DkE=",
        "value": {
          "a_key": "a_value",
          "a_string_value": "foo",
          "a_bool_value": true,
          "a_number_value": 420
        },
        "rule_id": "a_rule_id",
        "group": "default",
        "is_device_based": false,
        "secondary_exposures": []
      }
    },
    "layer_configs": {},
    "sdkParams": {},
    "has_updates": true,
    "time": 1648749618359
  });
}
