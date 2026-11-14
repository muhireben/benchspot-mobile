# benchspot-mobile

The Flutter app follows the web prototype's core flow: choose a Belgian city or
use device location, browse the OpenStreetMap map and library, add a bench at a
map pin or your current location, and add ratings, notes, photos, and reviews.
Bench data and resized photos are stored locally on the device. The five seeded
Louvain-la-Neuve entries are demo locations and should be verified before use.

## Design

The mobile app now uses the web prototype's cappuccino palette: cocoa
`#4B3832`, berry `#854442`, cream `#FFF4E6`, charcoal `#3C2F2F`, and latte
`#BE9B7B`. Its welcome screen uses the shared autumn bench artwork and outlined
city card. The same cocoa-backed bench mark is used for the app icon and web
branding. Tapping a map marker opens a compact name/rating card with buttons
for reviews, photos, directions, and writing a review.

## Run and test

From this directory:

```powershell
flutter pub get
flutter test
flutter run
```

The map uses OpenStreetMap tiles and attribution. Nearby place names are looked
up with OpenStreetMap's Nominatim service when adding a bench. Location is only
requested when you tap **Use my location**.

## Build an Android APK

With the Android SDK and Java 17+ installed, run:

```powershell
flutter pub get
flutter build apk --release
```

The APK is written to `build\app\outputs\flutter-apk\app-release.apk`. The
prototype release currently uses the local debug key for signing, so it is
suitable for testing but not for publishing. Copy it to the Samsung phone and
open it to install (allow installation from that file source if Android asks).
With USB debugging enabled, you can install it with:

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

For development with Flutter debugging enabled, use `flutter build apk --debug`.

## Build an iPhone IPA

The `Build unsigned iOS IPA` GitHub Actions workflow builds on a cloud macOS
runner with the current Xcode and Flutter 3.47.7. Push the source to GitHub,
then download the `benchspot-unsigned-ipa` artifact from the completed workflow
run. The IPA is intentionally unsigned so it can be signed for your device by
Sideloadly on Windows.

Sideloadly will need your Apple ID to sign the app for sideloading. The iOS
deployment target is 15.0, so the app is built for newer iOS releases including
iOS 26.6.1. The source and unsigned IPA do not contain your Apple credentials.

To start a build manually, open **Actions → Build unsigned iOS IPA → Run
workflow** in the GitHub repository. Builds also run automatically on pushes.

## Data and scope

This prototype stores its database and photos in the app's local documents
directory, so entries persist on that device but do not synchronize with the
web app's `benches.json` or between devices. The app needs an internet
connection for map tiles and nearby place-name suggestions.
