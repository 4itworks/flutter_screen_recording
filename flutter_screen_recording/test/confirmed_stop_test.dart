import 'package:flutter/services.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_screen_recording');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final path in ['', '/recording.mp4']) {
    test('confirmed stop accepts terminal output "$path"', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'stopRecordScreenConfirmed');
        return path;
      });
      expect(await FlutterScreenRecording.stopRecordScreenConfirmed, path);
    });
  }

  test('confirmed stop preserves native failure', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'STOP_ERROR'));
    await expectLater(
      FlutterScreenRecording.stopRecordScreenConfirmed,
      throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'STOP_ERROR')),
    );
  });

  test('older native binaries cannot falsely confirm stop', () async {
    await expectLater(FlutterScreenRecording.stopRecordScreenConfirmed, throwsA(isA<MissingPluginException>()));
  });

  test('null output cannot falsely confirm stop', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      FlutterScreenRecording.stopRecordScreenConfirmed,
      throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'INVALID_STOP_RESULT')),
    );
  });

  test('legacy stop still converts native failure into empty output', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'stopRecordScreen');
      throw PlatformException(code: 'STOP_ERROR');
    });
    expect(await FlutterScreenRecording.stopRecordScreen, '');
  });
}
