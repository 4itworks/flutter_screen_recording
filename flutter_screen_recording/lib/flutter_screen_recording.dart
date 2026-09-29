//import 'file:D:/Workspace/flutter_screen_recording/flutter_screen_recording_platform_interface/lib/flutter_screen_recording_platform_interface.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_screen_recording_platform_interface/flutter_screen_recording_platform_interface.dart';

class FlutterScreenRecording {
  static Future<bool> startRecordScreen(String name, {String? titleNotification, String? messageNotification}) async {
    try {
      if (titleNotification == null) {
        titleNotification = "";
      }
      if (messageNotification == null) {
        messageNotification = "";
      }

      if (!kIsWeb) {
        _maybeStartFGS(titleNotification, messageNotification);
      }
      final bool start = await FlutterScreenRecordingPlatform.instance.startRecordScreen(
        name,
        notificationTitle: titleNotification,
        notificationMessage: messageNotification,
      );

      return start;
    } catch (err) {
      print("startRecordScreen err");
      print(err);
    }

    return false;
  }

  static Future<bool> startRecordScreenAndAudio(String name, {String? titleNotification, String? messageNotification}) async {
    try {
      if (titleNotification == null) {
        titleNotification = "";
      }
      if (messageNotification == null) {
        messageNotification = "";
      }
      if (!kIsWeb) {
        _maybeStartFGS(titleNotification, messageNotification);
      }
      final bool start = await FlutterScreenRecordingPlatform.instance.startRecordScreenAndAudio(
        name,
        notificationTitle: titleNotification,
        notificationMessage: messageNotification,
      );
      return start;
    } catch (err) {
      print("startRecordScreenAndAudio err");
      print(err);
    }
    return false;
  }

  /// Stops native recording, preserving failures when termination is unconfirmed.
  /// An empty path means recording stopped without a usable video. Requires the
  /// matching native plugin; web and older native builds throw instead.
  static Future<String> get stopRecordScreenConfirmed async {
    final path = await const MethodChannel('flutter_screen_recording').invokeMethod<String>('stopRecordScreenConfirmed');
    if (path == null) {
      throw PlatformException(code: 'INVALID_STOP_RESULT', message: 'Recording stop was not confirmed.');
    }
    return path;
  }

  static Future<String> get stopRecordScreen async {
    try {
      final String path = await FlutterScreenRecordingPlatform.instance.stopRecordScreen;
      if (!kIsWeb && Platform.isAndroid) {
        FlutterForegroundTask.stopService();
      }
      return path;
    } catch (err) {
      print("stopRecordScreen err");
      print(err);
    }
    return "";
  }

  static _maybeStartFGS(String titleNotification, String messageNotification) {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'notification_channel_id',
            channelName: titleNotification,
            channelDescription: messageNotification,
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
            // iconData: const NotificationIconData(
            //   resType: ResourceType.mipmap,
            //   resPrefix: ResourcePrefix.ic,
            //   name: 'launcher',
            // ),
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: true,
            playSound: false,
          ),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(5000),
            autoRunOnBoot: true,
            autoRunOnMyPackageReplaced: true,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );
      }
    } catch (err) {
      print("_maybeStartFGS err");
      print(err);
    }
  }
}
