# Mindfully Social

iOS app for mindful social browsing. Native SwiftUI shell with an in-app browser (WKWebView).

## MVP

On launch the app searches Google for **cat**, then opens the first organic result (auto, or via **Open first result**).

## Develop / test (Mac mini Tart guest)

Host: Nigel’s Mac mini only. `TART_HOME=/Users/nigel/code/tart-home`, guest `mindfully-xcode`. Host launches Tart; build/test inside the guest on **iPhone 17**.

```bash
xcodebuild -project MindfullySocial.xcodeproj -scheme MindfullySocial \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ./DerivedData \
  test
```
