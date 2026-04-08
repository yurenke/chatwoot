/* eslint-disable no-restricted-globals, no-console */
/* globals clients */
// self.addEventListener('push', event => {
//   let notification = event.data && event.data.json();

//   event.waitUntil(
//     self.registration.showNotification(notification.title, {
//       tag: notification.tag,
//       data: {
//         url: notification.url,
//       },
//     })
//   );
// });
self.addEventListener('push', event => {
  let notification;

  try {
    notification = event.data && event.data.json();
  } catch (e) {
    console.error('Push payload is not valid JSON:', e);

    notification = {
      title: '新通知',
      body: event.data ? event.data.text() : '',
    };
  }

  if (!notification) return;

  const importantTags = [
    'conversation_assignment',
    'assigned_conversation_new_message'
  ];

  const isImportant = importantTags.some(tag =>
    notification.tag?.includes(tag)
  );

  event.waitUntil(
    self.registration.showNotification(notification.title, {
      body: notification.body || '您有一則新訊息',
      tag: notification.tag,

      requireInteraction: isImportant,

      data: {
        url: notification.url,
      },
    })
  );
});

self.addEventListener('notificationclick', event => {
  let notification = event.notification;

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(windowClients => {
      let matchingWindowClients = windowClients.filter(
        client => client.url === notification.data.url
      );

      if (matchingWindowClients.length) {
        let firstWindow = matchingWindowClients[0];
        if (firstWindow && 'focus' in firstWindow) {
          firstWindow.focus();
          return;
        }
      }
      if (clients.openWindow) {
        clients.openWindow(notification.data.url);
      }
    })
  );
});
