import 'package:firebase_messaging/firebase_messaging.dart';

/// 백그라운드 메시지 핸들러
/// 이 함수는 최상위 레벨에 있어야 합니다 (클래스 밖에)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화는 이미 완료되어 있어야 합니다
  // 백그라운드에서 메시지를 받았을 때 실행됩니다
  print('백그라운드 메시지 수신: ${message.messageId}');
  print('제목: ${message.notification?.title}');
  print('내용: ${message.notification?.body}');
  print('데이터: ${message.data}');
}

