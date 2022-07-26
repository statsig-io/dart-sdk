## Initialization

```jsx
import 'package:statsig/statsig.dart';

await Statsig.initialize('client-sdk-key', StatsigUser(userId: "a-user-id"));
```

## Feature Gates

```jsx
if (Statsig.checkGate("new_homepage_design")) {
  // Gate is on, show new home page
} else {
  // Gate is off, show old home page
}
```

## Dynamic Configs

```jsx
var config = Statsig.getConfig("awesome_product_details");

// The 2nd parameter is the default value to be used in case the given parameter name does not exist on
// the Dynamic Config object. This can happen when there is a typo, or when the user is offline and the
// value has not been cached on the client.
var itemName = config.get("product_name", "Awesome Product v1");
var price = config.get("price", 10.0);
var shouldDiscount = config.get("discount", false);
```

## Experiments

```jsx
var expConfig = Statsig.getExperiment("new_user_promo");

var promoTitle = expConfig.get(
  "title",
  "Welcome to Statsig! Use discount code WELCOME10OFF for 10% off your first purchase!"
);
var discount = expConfig.get("discount", 0.1);
```

## Layers

```jsx
var layer = Statsig.getLayer("button_themes");

var primaryButtonColor = layer.get("primary_button_color", "#194b7d");
```

## Logging Events

```jsx
// Provide a doubleValue argument for number values
Statsig.logEvent("purchase", doubleValue: 2.99, metadata: {"item_name": "remove_ads"});

// or provide a stringValue arugment for string values
Statsig.logEvent("login", stringValue: "a.user@mail.com");
```
