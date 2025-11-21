import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_messaging_handler.dart';

// 백그라운드 메시지 핸들러 등록
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공고공구',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;
  bool isLoading = true;
  String? fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initializeFCM();
  }

  void _initializeWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterFCM',
        onMessageReceived: (JavaScriptMessage message) {
          // WebView에서 Flutter로 메시지 전달 (필요시 사용)
          debugPrint('WebView에서 메시지 수신: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            // 페이지 로드 완료 후 FCM 토큰 전달
            _sendFCMTokenToWebView();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('http://125.241.251.235:3000/'));
  }

  Future<void> _initializeFCM() async {
    // 알림 권한 요청 (iOS)
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('사용자가 알림 권한을 허용했습니다');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('사용자가 임시 알림 권한을 허용했습니다');
    } else {
      debugPrint('사용자가 알림 권한을 거부했습니다');
    }

    // FCM 토큰 가져오기
    FirebaseMessaging.instance.getToken().then((token) {
      setState(() {
        fcmToken = token;
      });
      debugPrint('FCM 토큰: $token');
      // WebView가 로드되면 토큰 전달
      _sendFCMTokenToWebView();
    });

    // 토큰 갱신 리스너
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      setState(() {
        fcmToken = newToken;
      });
      debugPrint('FCM 토큰 갱신: $newToken');
      _sendFCMTokenToWebView();
    });

    // 포그라운드 메시지 수신 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('포그라운드 메시지 수신: ${message.messageId}');
      debugPrint('제목: ${message.notification?.title}');
      debugPrint('내용: ${message.notification?.body}');
      debugPrint('데이터: ${message.data}');

      // WebView로 메시지 전달
      _sendMessageToWebView(message);
    });

    // 알림 클릭 시 앱이 열릴 때 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('알림 클릭으로 앱 열림: ${message.messageId}');
      _handleNotificationClick(message);
    });

    // 앱이 종료된 상태에서 알림 클릭으로 앱이 열린 경우 처리
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint('앱 종료 상태에서 알림 클릭으로 앱 열림: ${initialMessage.messageId}');
      _handleNotificationClick(initialMessage);
    }
  }

  void _sendFCMTokenToWebView() {
    if (fcmToken != null) {
      final script =
          '''
        if (typeof window.onFCMTokenReceived === 'function') {
          window.onFCMTokenReceived('$fcmToken');
        } else {
          console.log('FCM Token: $fcmToken');
        }
      ''';
      controller.runJavaScript(script);
    }
  }

  void _sendMessageToWebView(RemoteMessage message) {
    // 데이터를 JSON 문자열로 변환
    final dataMap = <String, dynamic>{
      'messageId': message.messageId ?? '',
      'title': message.notification?.title ?? '',
      'body': message.notification?.body ?? '',
      'data': message.data,
    };

    // 간단한 JSON 변환 (중첩 객체 처리)
    String convertToJsonString(dynamic value) {
      if (value is Map) {
        final entries = value.entries
            .map((e) => "'${e.key}': ${convertToJsonString(e.value)}")
            .join(', ');
        return '{$entries}';
      } else if (value is List) {
        final items = value.map((e) => convertToJsonString(e)).join(', ');
        return '[$items]';
      } else {
        return "'$value'";
      }
    }

    final jsonData = dataMap.entries
        .map((e) => "'${e.key}': ${convertToJsonString(e.value)}")
        .join(', ');

    final script =
        '''
      if (typeof window.onFCMMessageReceived === 'function') {
        window.onFCMMessageReceived({$jsonData});
      } else {
        console.log('FCM Message:', {$jsonData});
      }
    ''';

    controller.runJavaScript(script);
  }

  void _handleNotificationClick(RemoteMessage message) {
    // 알림 클릭 시 특정 URL로 이동하거나 데이터 전달
    if (message.data.containsKey('url')) {
      final url = message.data['url'];
      controller.loadRequest(Uri.parse(url));
    } else {
      // WebView로 알림 데이터 전달
      _sendMessageToWebView(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
