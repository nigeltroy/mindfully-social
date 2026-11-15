# Mindfully Social

iOS app for mindful social browsing. Native SwiftUI shell with an in-app browser (WKWebView).

## MVP

On launch the app searches Google for **cat**, then opens the first organic result (auto, or via **Open first result**).

## Develop / test (Tart guest)

```bash
xcodebuild -project MindfullySocial.xcodeproj -scheme MindfullySocial \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath ./DerivedData \
  test
```
