// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // ✅ AGREGAR esta importación
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  // Instancia de Firebase Messaging para manejar notificaciones push
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // Plugin para mostrar notificaciones locales
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Stream para comunicar notificaciones a toda la app
  static final StreamController<Map<String, dynamic>> _notificationStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getter público para que otras partes de la app escuchen notificaciones
  static Stream<Map<String, dynamic>> get notificationStream => 
      _notificationStreamController.stream;

  // ✅ AGREGAR: GlobalKey para navegación global
  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  // Método principal de inicialización
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔄 Iniciando configuración de FCM...');
      }

      // 1. Configurar notificaciones locales
      await _setupLocalNotifications();
      
      // 2. Configurar Firebase Cloud Messaging
      await _setupFCM();
      
      if (kDebugMode) {
        print('✅ Servicio de notificaciones inicializado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error inicializando servicio de notificaciones: $e');
      }
    }
  }

  // Configurar notificaciones locales (para cuando la app está en primer plano)
  static Future<void> _setupLocalNotifications() async {
    // Configuración para Android
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );
    
    // Inicializar el plugin de notificaciones locales
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (kDebugMode) {
          print('📱 Notificación tocada: ${details.payload}');
        }
        // Cuando el usuario toca la notificación, procesar el payload
        if (details.payload != null) {
          _handleNotificationTap(Uri.splitQueryString(details.payload!));
        } else {
          // ✅ SI no hay payload, igual navegar a notificaciones
          _navigateToNotificationsPage();
        }
      },
    );
  }

  // Configurar Firebase Cloud Messaging
  static Future<void> _setupFCM() async {
    try {
      // 1. Solicitar permisos al usuario
      await _requestNotificationPermissions();

      // 2. Configurar manejadores de notificaciones
      _setupNotificationHandlers();

      // 3. Configurar y obtener el token FCM
      await _setupFCMToken();

      if (kDebugMode) {
        print('✅ FCM configurado correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error configurando FCM: $e');
      }
    }
  }

  // Solicitar permisos para notificaciones
  static Future<void> _requestNotificationPermissions() async {
    // Para Android
    if (await Permission.notification.request().isGranted) {
      if (kDebugMode) {
        print('✅ Permiso de notificaciones concedido en Android');
      }
    } else {
      if (kDebugMode) {
        print('❌ Permiso de notificaciones denegado en Android');
      }
    }

    // Para iOS - Firebase maneja los permisos de manera diferente
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,    // Permitir alertas
      badge: true,    // Permitir badges
      sound: true,    // Permitir sonidos
    );

    if (kDebugMode) {
      print('🔔 Estado de permisos: ${settings.authorizationStatus}');
    }
  }

  // Configurar los manejadores de diferentes tipos de notificaciones
  static void _setupNotificationHandlers() {
    // 1. Notificaciones recibidas con la APP EN PRIMER PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📱 Notificación en primer plano: ${message.notification?.title}');
      }
      _showNotification(message);
    });

    // 2. Notificación abierta con la APP EN SEGUNDO PLANO
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('🚀 App abierta desde notificación: ${message.notification?.title}');
      }
      
      // ✅ PRIMERO: Guardar la notificación
      await _saveNotificationFromMessage(message);
      
      // ✅ LUEGO: Navegar a la página de notificaciones
      _navigateToNotificationsPage();
      
      // También enviar datos al stream por si acaso
      _handleNotificationTap(message.data);
    });

    // 3. Notificación abierta con la APP TERMINADA
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) async {
      if (message != null) {
        if (kDebugMode) {
          print('📱 Notificación abierta desde estado terminado: ${message.data}');
        }
        
        // ✅ PRIMERO: Guardar la notificación
        await _saveNotificationFromMessage(message);
        
        // ✅ LUEGO: Navegar a la página de notificaciones
        _navigateToNotificationsPage();
        
        // También enviar datos al stream por si acaso
        _handleNotificationTap(message.data);
      }
    });
  }

  // Configurar el token FCM (identificador único del dispositivo)
  static Future<void> _setupFCMToken() async {
    try {
      // Obtener token actual del dispositivo
      String? token = await _firebaseMessaging.getToken();
      
      if (kDebugMode) {
        print('✅ ======= TOKEN FCM OBTENIDO =======');
        print('✅ $token');
        print('✅ =================================');
      }
    
      // Escuchar cambios en el token (puede cambiar con el tiempo)
      _firebaseMessaging.onTokenRefresh.listen((String newToken) {
        if (kDebugMode) {
          print('🔄 Token FCM actualizado: $newToken');
        }
        // Actualizar el token en tu backend cuando cambie
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo token FCM: $e');
      }
    }
  }

  // Mostrar notificación local cuando la app está en primer plano
  static Future<void> _showNotification(RemoteMessage message) async {
    try {
      RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        // Configuración específica para Android
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'high_importance_channel',    // ID del canal
          'Notificaciones Club France', // Nombre del canal
          channelDescription: 'Canal para notificaciones importantes del Club France',
          importance: Importance.max,   // Máxima importancia
          priority: Priority.high,      // Alta prioridad
          showWhen: true,               // Mostrar hora
        );
        
        // Configuración específica para iOS
        const DarwinNotificationDetails iosPlatformChannelSpecifics =
            DarwinNotificationDetails(
          presentAlert: true,   // Mostrar alerta
          presentBadge: true,   // Actualizar badge
          presentSound: true,   // Reproducir sonido
        );
        
        const NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iosPlatformChannelSpecifics,
        );

        // Preparar datos adicionales para navegación
        String payload = Uri(queryParameters: message.data).query;

        // Mostrar la notificación
        await _flutterLocalNotificationsPlugin.show(
          notification.hashCode, // ID único para la notificación
          notification.title ?? 'Club France', // Título por defecto
          notification.body ?? 'Nueva notificación', // Cuerpo por defecto
          platformChannelSpecifics,
          payload: payload.isNotEmpty ? payload : null, // Datos adicionales
        );
        
        // ✅ GUARDAR NOTIFICACIÓN EN ALMACENAMIENTO LOCAL
        await _saveNotificationToStorage(
          title: notification.title ?? 'Club France',
          body: notification.body ?? 'Nueva notificación',
          data: message.data,
        );
        
        if (kDebugMode) {
          print('📲 Notificación mostrada y guardada: ${notification.title}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error mostrando notificación: $e');
      }
    }
  }

  // ✅ NUEVO MÉTODO: Guardar notificación desde mensaje
  static Future<void> _saveNotificationFromMessage(RemoteMessage message) async {
    try {
      final RemoteNotification? notification = message.notification;
      
      if (notification != null) {
        await _saveNotificationToStorage(
          title: notification.title ?? 'Club France',
          body: notification.body ?? 'Nueva notificación',
          data: message.data,
        );
        
        if (kDebugMode) {
          print('💾 Notificación guardada desde tap: ${notification.title}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error guardando notificación desde tap: $e');
      }
    }
  }

  // Guardar notificación en almacenamiento local
  static Future<void> _saveNotificationToStorage({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('app_notifications') ?? [];
      
      final newNotification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'data': data,
      };
      
      // Agregar nueva notificación al inicio
      notificationsJson.insert(0, jsonEncode(newNotification));
      
      // Limitar a 100 notificaciones máximo
      if (notificationsJson.length > 100) {
        notificationsJson.removeLast();
      }
      
      await prefs.setStringList('app_notifications', notificationsJson);
      
      if (kDebugMode) {
        print('💾 Notificación guardada en almacenamiento local: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error guardando notificación en almacenamiento: $e');
      }
    }
  }

  // ✅ MODIFICADO: Manejar cuando el usuario toca una notificación
  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('👆 Notificación tocada con datos: $data');
    }
    
    // ✅ Navegar a la página de notificaciones
    _navigateToNotificationsPage();
    
    // También enviar los datos al stream para que los listeners (como HomePage) puedan reaccionar
    _notificationStreamController.add(data);
  }

  // ✅ NUEVO MÉTODO: Navegar a la página de notificaciones
  static void _navigateToNotificationsPage() {
    if (_navigatorKey.currentState != null) {
      // Usar pushNamed para navegar a la ruta de notificaciones
      _navigatorKey.currentState!.pushNamed('/notifications');
      
      if (kDebugMode) {
        print('🚀 Navegando a página de notificaciones desde notificación push');
      }
    } else {
      if (kDebugMode) {
        print('❌ Navigator key no está disponible - verifica la configuración en main.dart');
      }
    }
  }

  // ========== MÉTODOS PÚBLICOS ==========
  // Estos métodos pueden ser usados desde cualquier parte de tu app

  // Obtener el token FCM actual
  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }
  
  // Suscribirse a un topic (ej: 'noticias', 'promociones')
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('✅ Suscrito al topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error suscribiendo al topic $topic: $e');
      }
    }
  }
  
  // Desuscribirse de un topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('✅ Desuscrito del topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error desuscribiendo del topic $topic: $e');
      }
    }
  }

  // Enviar el token FCM a tu backend (cuando implementes tu API)
  static Future<void> sendTokenToBackend(String token, String userId) async {
    try {
      if (kDebugMode) {
        print('📤 Token listo para enviar al backend:');
        print('👤 Usuario: $userId');
        print('🔑 Token: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando token al backend: $e');
      }
    }
  }

  // ========== MÉTODOS PARA ALMACENAMIENTO LOCAL DE NOTIFICACIONES ==========

  // Obtener todas las notificaciones almacenadas
  static Future<List<Map<String, dynamic>>> getStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('app_notifications') ?? [];
      
      final notifications = notificationsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      // Ordenar por fecha (más reciente primero)
      notifications.sort((a, b) {
        final dateA = DateTime.parse(a['timestamp']);
        final dateB = DateTime.parse(b['timestamp']);
        return dateB.compareTo(dateA);
      });
      
      return notifications;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo notificaciones: $e');
      }
      return [];
    }
  }

  // Marcar una notificación como leída
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('app_notifications') ?? [];
      
      final updatedNotifications = notificationsJson.map((json) {
        final notification = jsonDecode(json) as Map<String, dynamic>;
        if (notification['id'] == notificationId) {
          notification['isRead'] = true;
        }
        return jsonEncode(notification);
      }).toList();
      
      await prefs.setStringList('app_notifications', updatedNotifications);
      
      if (kDebugMode) {
        print('✅ Notificación marcada como leída: $notificationId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marcando notificación como leída: $e');
      }
    }
  }

  // Marcar todas las notificaciones como leídas
  static Future<void> markAllNotificationsAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('app_notifications') ?? [];
      
      final updatedNotifications = notificationsJson.map((json) {
        final notification = jsonDecode(json) as Map<String, dynamic>;
        notification['isRead'] = true;
        return jsonEncode(notification);
      }).toList();
      
      await prefs.setStringList('app_notifications', updatedNotifications);
      
      if (kDebugMode) {
        print('✅ Todas las notificaciones marcadas como leídas');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marcando todas como leídas: $e');
      }
    }
  }

  // Eliminar todas las notificaciones
  static Future<void> clearAllStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_notifications');
      
      if (kDebugMode) {
        print('✅ Todas las notificaciones eliminadas');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error eliminando notificaciones: $e');
      }
    }
  }

  // Obtener contador de notificaciones no leídas
  static Future<int> getUnreadNotificationsCount() async {
    try {
      final notifications = await getStoredNotifications();
      return notifications.where((notification) => !(notification['isRead'] ?? false)).length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo contador de no leídas: $e');
      }
      return 0;
    }
  }

  // Limpiar recursos cuando ya no se necesiten
  static void dispose() {
    _notificationStreamController.close();
    if (kDebugMode) {
      print('🧹 Servicio de notificaciones limpiado');
    }
  }
}