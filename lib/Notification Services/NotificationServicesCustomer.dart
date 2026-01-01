import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:project_sem7/booking/booked_slot.dart';
import 'package:project_sem7/uiscreen/liked_shops.dart';

class Notificationservicescustomer {

   FirebaseMessaging messaging = FirebaseMessaging.instance;
   String? _currentToken;
   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

   //Request for the Notification Permission
   Future<void> requestNotificaationPerission() async{
      NotificationSettings settings = await messaging.requestPermission(
         alert: true,
         announcement: true,
         sound: true,
         carPlay: true,
         badge: true,
         criticalAlert: true
      );
      if(settings.authorizationStatus == AuthorizationStatus.authorized){
         print("Access has been granted");
      }else{
         print("Access has been benied");
      }
   }

   Future<void> firebaseInit(BuildContext context) async {
      FirebaseMessaging.onMessage.listen((message){
         print(message.notification!.title.toString());
         print(message.notification!.body.toString());
         if(Platform.isAndroid){
            initLocalNotification(context, message);
            showNotification(message);
         }else {
            showNotification(message);
         }
      });
   }

   void initLocalNotification(BuildContext context, RemoteMessage message)async{
      var androidInitializationSettings = AndroidInitializationSettings('@mipmap/logo');

      var initializationSettings = InitializationSettings(
         android: androidInitializationSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (payload){
             handleMessage(context, message);
          }
      );
   }

   void handleMessage(BuildContext context,RemoteMessage message){
      if(message.data['type'] == 'message') {
         Navigator.push(
             context, MaterialPageRoute(builder: (context) => LikedShops()));
      }
   }

   Future<void> showNotification(RemoteMessage message) async{

      final title = message.notification?.title ?? 'New Booking';
      final body  = message.notification?.body ?? 'You have a new update';

      AndroidNotificationChannel channel = AndroidNotificationChannel(
          Random.secure().nextInt(10000).toString(),
          'High importance Notification',
          playSound: true,
          importance: Importance.max);

      AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
          channel.id.toString(),
          channel.name.toString(),
          channelDescription: 'your channel description',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          icon: '@mipmap/logo'
      );

      NotificationDetails notificationDetails = NotificationDetails(
          android: androidNotificationDetails
      );

      Future.delayed(Duration.zero,(){
         _flutterLocalNotificationsPlugin.show(
             DateTime.now().millisecondsSinceEpoch ~/ 1000,
             title,
             body,
             notificationDetails);
      });
   }

   Future<void> setupInteractMessage(BuildContext context) async{
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

      if(initialMessage != null){
         handleMessage(context, initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp.listen((event){
         handleMessage(context, event);
      });
   }


   //Getting Device Token
   Future<void> getDeviceToken() async{
      messaging.onTokenRefresh.listen((newToken) async {
         _currentToken = newToken;
         await _saveTokenToFirestore(newToken);
      });

      // 🔑 Get initial token
      final token = await messaging.getToken();
      if (token != null) {
         _currentToken = token;
         await _saveTokenToFirestore(token);
      }
   }

   /// 3️⃣ Save token to Firestore
   Future<void> _saveTokenToFirestore(String token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('CustomerSignupDetails')
          .doc(user.uid)
          .set({
         'deviceToken': token,
         'platform': Platform.isAndroid ? 'android' : 'ios',
         'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
   }

   /// 4️⃣ Remove token on logout
   Future<void> removeTokenOnLogout() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('CustomerSignupDetails')
          .doc(user.uid)
          .update({
         'deviceToken': FieldValue.delete(),
      });

      _currentToken = null;
   }
}

