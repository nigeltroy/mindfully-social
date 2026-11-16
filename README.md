# Mindfully Social

iOS app for mindful social browsing. Native SwiftUI shell with an in-app browser (WKWebView).

## Current slice

Dark home screen with the **Mindfully Social** name and a grid of site icons (Instagram, YouTube). Tapping an icon opens that site in an in-app WKWebView with back and close chrome.

## Develop / test (Mac mini Tart guest)

Host: Nigel’s Mac mini only. `TART_HOME=/Users/nigel/code/tart-home`, guest `mindfully-xcode`. Host launches Tart; build/test inside the guest on **iPhone 17**.

```bash
xcodebuild -project MindfullySocial.xcodeproj -scheme MindfullySocial \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ./DerivedData \
  test
```
