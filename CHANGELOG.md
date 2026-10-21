## 1.3.0

### New Features
- Added lifecycle diagnostics for SDK initialization and `updateUser()` operations, including cache, network, and response-processing phases.
- Added `forceDiagnosticsSampling` to `StatsigOptions` for deterministic diagnostics capture in development and test environments.

### Improvements
- Improved diagnostics metadata with evaluation source, timing information, HTTP status when available, region, and typed failure details.
- Added bounded marker collection and omission of unavailable diagnostic fields for more consistent telemetry.

### Fixes
- Fixed lifecycle diagnostics for timeouts, malformed responses, rejected SDK keys, retries, and superseded `updateUser()` calls so reported outcomes reflect the completed operation.
- Prevented late responses from timed-out or superseded requests from being recorded as part of a later initialization or user update.

## 1.2.9

### Fixes
- `updateUser()` now always triggers a fresh network fetch, even when called with the same user. Previously it was a no-op, which could leave the SDK serving stale values indefinitely.
- Evaluations after a failed or timed-out `initialize()` now return reason `NoValues` instead of `Uninitialized`.

## 1.2.8

### Improvements
- Improved package metadata for pub.dev.
### Fixes
- Removed an invalid public export for `StatsigEnvironment`
- Cleaned up analyzer warnings while preserving Dart 3.0 compatibility

For older releases, visit https://github.com/statsig-io/dart-sdk/releases.
