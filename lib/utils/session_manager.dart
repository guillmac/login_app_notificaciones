import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SessionManager {
  static const _userKey = 'user';
  static const _biometricKey = 'biometric';
  static const _userEmailKey = 'user_email';
  static const _userPasswordKey = 'user_password';
  static const _userDataKey = 'user_complete_data';

  // NUEVA CLAVE PARA VERIFICAR LOGIN INICIAL
  static const _initialLoginDoneKey = 'initial_login_done';

  // CLAVES PARA CONFIGURACIÓN
  static const _biometricEnabledKey = 'biometricEnabled';
  static const _notificationsEnabledKey = 'notificationsEnabled';
  static const _darkModeEnabledKey = 'darkModeEnabled';

  // Almacenamiento seguro para credenciales
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Sistema de logging mejorado
  static void _logInfo(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ SESSION: $message');
    }
  }

  static void _logError(String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ SESSION ERROR: $message - $error');
      } else {
        debugPrint('❌ SESSION ERROR: $message');
      }
    }
  }

  static void _logSuccess(String message) {
    if (kDebugMode) {
      debugPrint('✅ SESSION SUCCESS: $message');
    }
  }

  static void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 SESSION DEBUG: $message');
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user));

    // MARCAR QUE SE COMPLETÓ EL LOGIN INICIAL
    await prefs.setBool(_initialLoginDoneKey, true);

    if (user['email'] != null) {
      await prefs.setString(_userEmailKey, user['email']);
    }

    _logSuccess('Usuario guardado y login inicial marcado');
  }

  // NUEVO MÉTODO PARA VERIFICAR LOGIN INICIAL
  static Future<bool> isInitialLoginDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialLoginDoneKey) ?? false;
  }

  static Future<void> saveUserForBiometric({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Guardar email en SharedPreferences
    await prefs.setString(_userEmailKey, email);

    // Guardar contraseña de forma SEGURA en FlutterSecureStorage
    await _secureStorage.write(key: _userPasswordKey, value: password);

    await prefs.setString(_userDataKey, json.encode(userData));
    await prefs.setBool(_biometricKey, true);

    // Asegurar que el login inicial está marcado
    await prefs.setBool(_initialLoginDoneKey, true);

    _logSuccess('Usuario guardado para biométrico: $email');
  }

  // MODIFICAR ESTE MÉTODO PARA VERIFICAR LOGIN INICIAL Y DATOS SEGUROS
  static Future<bool> hasBiometricUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasEmail = prefs.containsKey(_userEmailKey);
    final hasData = prefs.containsKey(_userDataKey);
    final biometricEnabled = prefs.getBool(_biometricKey) ?? false;
    final initialLoginDone = await isInitialLoginDone();

    // Verificar si existe la contraseña en almacenamiento seguro
    final String? storedPassword = await _secureStorage.read(
      key: _userPasswordKey,
    );
    final hasSecurePassword =
        storedPassword != null && storedPassword.isNotEmpty;

    _logDebug(
      'Verificando usuario biométrico: '
      'email=$hasEmail, data=$hasData, '
      'biometric=$biometricEnabled, initialLoginDone=$initialLoginDone, '
      'hasSecurePassword=$hasSecurePassword',
    );

    return hasEmail &&
        hasData &&
        biometricEnabled &&
        initialLoginDone &&
        hasSecurePassword;
  }

  // NUEVO MÉTODO PARA VERIFICAR SI PUEDE USAR BIOMETRÍA
  static Future<bool> canUseBiometricLogin() async {
    final hasBiometricData = await hasBiometricUser();
    final initialLoginDone = await isInitialLoginDone();
    final biometricEnabled = await isBiometricEnabled();

    return hasBiometricData && initialLoginDone && biometricEnabled;
  }

  static Future<Map<String, dynamic>?> getBiometricUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);

    if (userDataString != null) {
      try {
        return json.decode(userDataString) as Map<String, dynamic>;
      } catch (e) {
        _logError('Error decoding biometric user data', e);
      }
    }
    return null;
  }

  static Future<String?> getBiometricEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getBiometricPassword() async {
    // Obtener contraseña de almacenamiento seguro
    return await _secureStorage.read(key: _userPasswordKey);
  }

  static Future<void> clearBiometricData() async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar contraseña del almacenamiento seguro
    await _secureStorage.delete(key: _userPasswordKey);

    await prefs.remove(_userDataKey);
    await prefs.setBool(_biometricKey, false);

    _logInfo('Datos biométricos eliminados');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar datos de SharedPreferences
    await prefs.remove(_userKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_biometricKey);

    // Eliminar contraseña del almacenamiento seguro
    await _secureStorage.delete(key: _userPasswordKey);

    // NO eliminar _initialLoginDoneKey para mantener el estado de login inicial
    // NO eliminar configuraciones (_biometricEnabledKey, etc.)

    _logInfo('Logout completo realizado');
  }

  static Future<void> completeLogout() async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar todos los datos
    await prefs.remove(_userKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_biometricKey);
    await prefs.remove(_initialLoginDoneKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_notificationsEnabledKey);
    await prefs.remove(_darkModeEnabledKey);

    // Eliminar contraseña del almacenamiento seguro
    await _secureStorage.delete(key: _userPasswordKey);

    _logInfo('Logout completo con eliminación de todos los datos');
  }

  // MÉTODOS PARA CONFIGURACIÓN BIOMÉTRICA
  static Future<void> updateBiometricSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);

    if (!enabled) {
      await clearBiometricData();
    }

    _logInfo(
      'Configuración biométrica ${enabled ? 'activada' : 'desactivada'}',
    );
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();

    if (settings.containsKey('biometricEnabled')) {
      await updateBiometricSetting(settings['biometricEnabled'] ?? false);
    }
    if (settings.containsKey('notificationsEnabled')) {
      await prefs.setBool(
        _notificationsEnabledKey,
        settings['notificationsEnabled'] ?? true,
      );
    }
    if (settings.containsKey('darkModeEnabled')) {
      await prefs.setBool(
        _darkModeEnabledKey,
        settings['darkModeEnabled'] ?? false,
      );
    }

    _logSuccess('Configuración guardada: $settings');
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'biometricEnabled': prefs.getBool(_biometricEnabledKey) ?? false,
      'notificationsEnabled': prefs.getBool(_notificationsEnabledKey) ?? true,
      'darkModeEnabled': prefs.getBool(_darkModeEnabledKey) ?? false,
    };
  }

  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Eliminar todos los datos de SharedPreferences
    await prefs.remove(_userKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_biometricKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_notificationsEnabledKey);
    await prefs.remove(_darkModeEnabledKey);
    await prefs.remove(_initialLoginDoneKey);

    // Eliminar todos los datos del almacenamiento seguro
    await _secureStorage.deleteAll();

    _logInfo(
      'Todos los datos limpiados (incluyendo configuraciones y datos seguros)',
    );
  }

  // MÉTODOS AUXILIARES PARA OBTENER INFORMACIÓN DEL USUARIO
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString != null) {
      try {
        return json.decode(userString) as Map<String, dynamic>;
      } catch (e) {
        _logError('Error decoding current user', e);
        // Intentar obtener datos del usuario biométrico como fallback
        return await getBiometricUser();
      }
    }
    return null;
  }

  static Future<String?> getCurrentUserEmail() async {
    final user = await getCurrentUser();
    if (user != null && user['email'] != null) {
      return user['email'];
    }
    return await getBiometricEmail();
  }

  static Future<String?> getCurrentUserName() async {
    final user = await getCurrentUser();
    if (user != null) {
      if (user['primer_nombre'] != null && user['primer_apellido'] != null) {
        return '${user['primer_nombre']} ${user['primer_apellido']}';
      } else if (user['primer_nombre'] != null) {
        return user['primer_nombre'];
      } else if (user['email'] != null) {
        return _getFirstNameFromEmail(user['email']);
      }
    }
    return null;
  }

  // MÉTODOS PARA VERIFICAR ESTADO DE LA SESIÓN
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUser = prefs.containsKey(_userKey);
    final initialLoginDone = await isInitialLoginDone();

    return hasUser && initialLoginDone;
  }

  static Future<Map<String, dynamic>> getSessionStatus() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'hasUser': prefs.containsKey(_userKey),
      'hasBiometricData': await hasBiometricUser(),
      'isBiometricEnabled': await isBiometricEnabled(),
      'isInitialLoginDone': await isInitialLoginDone(),
      'canUseBiometric': await canUseBiometricLogin(),
      'userEmail': await getCurrentUserEmail(),
      'hasSecurePassword':
          await _secureStorage.read(key: _userPasswordKey) != null,
    };
  }

  // Métodos auxiliares existentes
  static String _getFirstNameFromEmail(String email) {
    final namePart = email.split('@').first;
    final nameParts = namePart.split('.');
    if (nameParts.isNotEmpty) {
      return nameParts[0][0].toUpperCase() + nameParts[0].substring(1);
    }
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  // Métodos existentes por compatibilidad
  static Future<void> saveBiometric(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);

    if (!enabled) {
      await clearBiometricData();
    }
  }

  static Future<bool> getBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  // MÉTODO PARA DEBUG: Mostrar estado completo
  static Future<void> debugSessionStatus() async {
    if (!kDebugMode) return; // Solo en modo debug

    final status = await getSessionStatus();
    _logDebug('DEBUG Session Status:');
    status.forEach((key, value) {
      _logDebug('   $key: $value');
    });

    // Verificar almacenamiento seguro
    final secureKeys = await _secureStorage.readAll();
    _logDebug('   Secure Storage Keys: ${secureKeys.keys}');
  }

  // MÉTODO PARA VERIFICAR INTEGRIDAD DE DATOS
  static Future<Map<String, dynamic>> checkDataIntegrity() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();

    final integrityReport = {
      'sharedPreferencesKeys': allKeys.toList(),
      'hasUserData': prefs.containsKey(_userKey),
      'hasBiometricConfig': prefs.containsKey(_biometricKey),
      'hasInitialLoginFlag': prefs.containsKey(_initialLoginDoneKey),
      'hasEmail': prefs.containsKey(_userEmailKey),
      'hasUserCompleteData': prefs.containsKey(_userDataKey),
      'secureStoragePasswordExists':
          await _secureStorage.read(key: _userPasswordKey) != null,
    };

    if (kDebugMode) {
      _logDebug('Data Integrity Report: $integrityReport');
    }

    return integrityReport;
  }
}
