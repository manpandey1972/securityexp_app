// Import Firebase scripts - Updated to latest stable version
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in Service Worker
firebase.initializeApp({
  apiKey: 'AIzaSyBNcNVnt6Td9FJ_0aOLcLSU-t4DLdYFlHk',
  authDomain: 'securityexp-app.firebaseapp.com',
  projectId: 'securityexp-app',
  storageBucket: 'securityexp-app.firebasestorage.app',
  messagingSenderId: '1015827376061',
  appId: '1:1015827376061:web:03f59d7cd8330245ca54d4'
});

// Handle background messages
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'Firebase Message';
  const notificationOptions = {
    body: payload.notification?.body || 'You have received a message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    // Pass custom data for navigation on click
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  // Get notification data for navigation
  const notificationData = event.notification.data || {};
  const notificationType = notificationData.type;
  
  // Build URL based on notification type
  let targetUrl = '/';
  if (notificationType === 'new_message' && notificationData.conversationId) {
    targetUrl = `/chat?conversationId=${notificationData.conversationId}`;
  } else if (notificationType === 'incoming_call' && notificationData.channelName) {
    targetUrl = `/call?channelName=${notificationData.channelName}`;
  }
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Try to focus an existing window
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if ('focus' in client) {
          // Navigate existing window to the target URL
          client.postMessage({
            type: 'notification_click',
            data: notificationData
          });
          return client.focus();
        }
      }
      // Open new window if no existing window found
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
