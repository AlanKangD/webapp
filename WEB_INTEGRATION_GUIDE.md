# WebView FCM 통합 가이드

## 웹에서 FCM 토큰 및 메시지 수신하기

Flutter 앱에서 WebView로 FCM 토큰과 메시지를 전달합니다. 웹 페이지에서 다음 JavaScript 함수들을 구현하세요.

## 1. FCM 토큰 수신

앱이 시작되거나 토큰이 갱신될 때 자동으로 호출됩니다.

```javascript
// FCM 토큰을 받는 함수
window.onFCMTokenReceived = function(token) {
  console.log('FCM Token:', token);
  
  // 서버로 토큰 전송
  fetch('http://125.241.251.235:3000/api/fcm/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      token: token,
      platform: 'android' // 또는 'ios'
    })
  })
  .then(response => response.json())
  .then(data => {
    console.log('토큰 저장 완료:', data);
  })
  .catch(error => {
    console.error('토큰 저장 실패:', error);
  });
};
```

## 2. 포그라운드 메시지 수신

앱이 실행 중일 때 푸시 알림을 받으면 호출됩니다.

```javascript
// FCM 메시지를 받는 함수
window.onFCMMessageReceived = function(message) {
  console.log('FCM Message:', message);
  
  // 메시지 데이터 구조:
  // {
  //   messageId: '메시지 ID',
  //   title: '알림 제목',
  //   body: '알림 내용',
  //   data: { 커스텀 데이터 }
  // }
  
  // 예시: 알림 표시
  if (message.title && message.body) {
    alert(`${message.title}\n${message.body}`);
  }
  
  // 예시: 특정 페이지로 이동
  if (message.data && message.data.url) {
    window.location.href = message.data.url;
  }
};
```

## 3. Flutter로 메시지 전송 (선택사항)

웹에서 Flutter로 메시지를 보낼 수 있습니다.

```javascript
// FlutterFCM 채널을 통해 메시지 전송
// (현재 구현에서는 Flutter에서 웹으로만 통신하지만, 필요시 양방향 통신 가능)
```

## 4. 전체 예시 코드

```html
<!DOCTYPE html>
<html>
<head>
  <title>FCM WebView 통합</title>
</head>
<body>
  <h1>FCM WebView 통합 예시</h1>
  <div id="token-display"></div>
  <div id="message-display"></div>

  <script>
    // FCM 토큰 수신
    window.onFCMTokenReceived = function(token) {
      console.log('FCM Token:', token);
      document.getElementById('token-display').innerHTML = 
        '<p><strong>FCM Token:</strong> ' + token + '</p>';
      
      // 서버로 토큰 전송
      sendTokenToServer(token);
    };

    // FCM 메시지 수신
    window.onFCMMessageReceived = function(message) {
      console.log('FCM Message:', message);
      
      const messageDiv = document.getElementById('message-display');
      messageDiv.innerHTML = `
        <h3>새로운 메시지</h3>
        <p><strong>제목:</strong> ${message.title || 'N/A'}</p>
        <p><strong>내용:</strong> ${message.body || 'N/A'}</p>
        <p><strong>데이터:</strong> ${JSON.stringify(message.data || {})}</p>
      `;
      
      // 커스텀 데이터 처리
      if (message.data && message.data.url) {
        // 특정 URL로 이동
        window.location.href = message.data.url;
      }
    };

    // 서버로 토큰 전송
    function sendTokenToServer(token) {
      fetch('http://125.241.251.235:3000/api/fcm/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token: token,
          platform: 'android',
          timestamp: new Date().toISOString()
        })
      })
      .then(response => response.json())
      .then(data => {
        console.log('토큰 저장 완료:', data);
      })
      .catch(error => {
        console.error('토큰 저장 실패:', error);
      });
    }
  </script>
</body>
</html>
```

## 5. 서버에서 푸시 알림 전송 예시

서버에서 FCM Admin SDK를 사용하여 푸시 알림을 전송할 수 있습니다.

### Node.js 예시

```javascript
const admin = require('firebase-admin');

// Firebase Admin SDK 초기화
const serviceAccount = require('./path/to/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// 푸시 알림 전송
async function sendPushNotification(token, title, body, data = {}) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    token: token,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('성공적으로 전송됨:', response);
    return response;
  } catch (error) {
    console.error('전송 실패:', error);
    throw error;
  }
}

// 사용 예시
sendPushNotification(
  '사용자의_FCM_토큰',
  '알림 제목',
  '알림 내용',
  { url: 'https://example.com/page' }
);
```

## 주의사항

1. **함수 이름**: `onFCMTokenReceived`와 `onFCMMessageReceived` 함수는 반드시 전역 스코프(`window`)에 정의되어야 합니다.

2. **타이밍**: 페이지가 완전히 로드되기 전에 토큰이 전달될 수 있으므로, 스크립트는 페이지 상단에 배치하는 것을 권장합니다.

3. **에러 처리**: 함수가 정의되지 않은 경우를 대비해 Flutter 코드에서 콘솔 로그로도 출력하므로, 개발자 도구에서 확인할 수 있습니다.

