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
