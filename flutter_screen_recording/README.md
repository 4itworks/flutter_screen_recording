# flutter_screen_recording

Flutter plugin to record the screen on Android, iOS, and web.

Current platform support in this repository:

- Android: `minSdkVersion 23`
- iOS: `iOS 11.0+`
- Web: supported through the federated web implementation

## Getting Started

Import the package:

```dart
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
```

Start screen recording:

```dart
final bool started = await FlutterScreenRecording.startRecordScreen(
  'my_recording',
  titleNotification: 'Screen recording',
  messageNotification: 'Recording in progress',
);
```

Start screen recording with microphone audio:

```dart
final bool started = await FlutterScreenRecording.startRecordScreenAndAudio(
  'my_recording',
  titleNotification: 'Screen recording',
  messageNotification: 'Recording in progress',
);
```

Stop recording and get the output path or file name:

```dart
final String path = await FlutterScreenRecording.stopRecordScreen;
```

### Confirmed native stop

For privacy-sensitive Android/iOS callers, await `FlutterScreenRecording.stopRecordScreenConfirmed` after awaiting start. Its completion confirms capture termination; the returned path may be empty when no usable video was produced. Native failures and missing implementations throw, so keep protected content hidden and allow a retry. The legacy `stopRecordScreen` getter still converts errors to an empty string and cannot establish recorder state.

This API requires a full native build with the matching plugin. Older native binaries and web do not implement the confirmed-stop method. Service cleanup and attachment finalization are separate from capture termination.

Run `flutter test test/confirmed_stop_test.dart` in this package for the Dart contract. Real-device checks still need to verify normal stop, immediate stop/no frames, OS-stopped capture, interrupted service cleanup, retry after native failure, and a subsequent recording on Android and iOS. These scenarios require physical-device validation.

## Android

The Android implementation uses `MediaProjection`, `MediaRecorder`, and a foreground service.

- The plugin currently builds with `compileSdkVersion 35`
- The plugin manifest already includes its service declaration and required foreground-service permissions
- If you record audio, request microphone permission at runtime in your app
- On modern Android versions, you may also need notification permission for the foreground service notification

The example app requests permissions with `permission_handler` before starting recording.

## iOS

The iOS implementation uses `ReplayKit` and requires `iOS 11.0+`.

Add the usage description for microphone access if you record audio:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Save audio in video</string>
```

The plugin returns the local output file path. If your app later saves the file to the Photos library, also add the appropriate Photos usage description to your app.

## Web

The web implementation uses `getDisplayMedia` and `MediaRecorder`.

- Best experience is on modern desktop browsers
- Browser support depends on screen-capture and codec support
- The web implementation downloads the recorded file in the browser when recording stops

## Notes

- This package exposes asynchronous APIs; use `await` when starting and stopping recordings
- Notification title and message parameters are used by the Android implementation
- Returned output differs by platform: native platforms return a local path, while web triggers a browser download
