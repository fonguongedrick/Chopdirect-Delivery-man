const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Notify admins when a new delivery application is submitted
exports.onDeliveryApplication = functions.firestore
  .document('delivery_applications_chopdirect/{applicationId}')
  .onCreate(async (snap, context) => {
    try {
      const application = snap.data();

      if (!application || !application.userId) {
        console.warn('Incomplete application data.');
        return;
      }

      const adminsSnapshot = await admin.firestore()
        .collection('users_chopdirect')
        .where('isAdmin', '==', true)
        .get();

      const tokens = [];
      adminsSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: 'New Delivery Application',
            body: `New application from user ${application.userId}`,
          },
        };

        const options = {
          priority: 'high',
        };

        await admin.messaging().sendToDevice(tokens, payload, options);
        console.log('Notification sent to admins.');
      } else {
        console.log('No admin FCM tokens found.');
      }
    } catch (error) {
      console.error('Error in onDeliveryApplication:', error);
    }
  });

// Notify delivery person when assigned an order
exports.onOrderAssigned = functions.firestore
  .document('orders_chopdirect/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      // Only proceed if a deliveryId was just added
      if (!before.deliveryId && after.deliveryId) {
        const deliveryPersonRef = admin.firestore()
          .collection('users_chopdirect')
          .doc(after.deliveryId);

        const deliveryPersonSnap = await deliveryPersonRef.get();

        if (deliveryPersonSnap.exists) {
          const deliveryData = deliveryPersonSnap.data();

          if (deliveryData.fcmToken) {
            const payload = {
              notification: {
                title: 'New Delivery Assignment',
                body: `You have been assigned order ${context.params.orderId}`,
              },
              data: {
                orderId: context.params.orderId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
            };

            const options = {
              priority: 'high',
            };

            await admin.messaging().sendToDevice([deliveryData.fcmToken], payload, options);
            console.log('Notification sent to delivery person.');
          } else {
            console.log('Delivery person does not have an FCM token.');
          }
        } else {
          console.log('Delivery person not found.');
        }
      }
    } catch (error) {
      console.error('Error in onOrderAssigned:', error);
    }
  });

