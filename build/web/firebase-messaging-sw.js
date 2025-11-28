importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// هنا خاصك تجيب المعلومات من Firebase Console
// Project Settings > General > Your Apps (Web) > SDK Setup and Configuration
firebase.initializeApp({
  apiKey: "AIzaSyAwnX_OBLqMjyP4p6BsfLpb3fPWe7GwxgE",
  authDomain: "carida-c128a.firebaseapp.com",
  projectId: "carida-c128a",
  storageBucket: "carida-c128a.firebasestorage.app",
  messagingSenderId: "265928952104",
  appId: "1:265928952104:web:860a8e18068bf2f5f4a81d",
});

const messaging = firebase.messaging();

// هادي هي اللي كطلع الإشعار فالخلفية
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // الأيقونة اللي درنا فالمانيفيست
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});