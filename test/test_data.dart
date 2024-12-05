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

  static var paramStoreResponse = json.encode({
    "feature_gates": {},
    "dynamic_configs": {
      "3112790908": {
        "name": "3112790908",
        "value": {"my_test_param": "test value"},
        "rule_id": "default",
        "group": "default",
        "is_device_based": false,
        "passed": false,
        "id_type": "userID",
        "secondary_exposures": []
      },
      "2902556896": {
        "name": "2902556896",
        "value": {
          "a_key": "a_value",
          "a_string_value": "foo",
          "a_bool_value": true,
          "a_number_value": 420,
          "a_array_value": ['123', '124', '125', '126', '127'],
        },
        "rule_id": "a_rule_id",
        "group": "default",
        "is_device_based": false,
        "secondary_exposures": []
      }
    },
    "layer_configs": {},
    "param_stores": {
      "3178975413": {
        "my_test_param": {
          "name": "my_test_param",
          "ref_type": "dynamic_config",
          "param_type": "string",
          "config_name": "3112790908",
          "param_name": "my_test_param"
        }
      },
      "3018051459": {
        "enabled_values": {
          "ref_type": "static",
          "value": ['123', '124', '125', '126', '127'],
          "param_type": "array"
        },
        "enabled_values_v4": {
          "ref_type": "static",
          "value": [1, 4, 6],
          "param_type": "array"
        },
        "enabled_values_v2": {
          "ref_type": "static",
          "value": {
            "key": "value",
            "key2": {"value": 2},
          },
          "param_type": "object"
        },
        "enabled_values_v3": {
          "ref_type": "static",
          "value": {
            "key": "value",
            "key2": "value2",
          },
          "param_type": "object"
        }
      }
    },
    "sdkParams": {},
    "has_updates": true,
    "time": 1648749618359,
    "hash_used": "djb2",
  });
}
