import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 알림 카테고리 및 액션 설정
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      // 완료 액션 정의
      let completeAction = UNNotificationAction(
        identifier: "complete",
        title: "완료",
        options: []
      )

      // 스누즈 액션 정의
      let snoozeAction = UNNotificationAction(
        identifier: "snooze",
        title: "10분 후 다시",
        options: []
      )

      // 알람 카테고리 정의
      let alarmCategory = UNNotificationCategory(
        identifier: "alarmCategory",
        actions: [completeAction, snoozeAction],
        intentIdentifiers: [],
        options: .customDismissAction
      )

      // 카테고리 등록
      UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 알림 액션 처리 (앱이 백그라운드에 있을 때)
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Flutter 플러그인으로 전달
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // 앱이 포그라운드에 있을 때 알림 표시
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
