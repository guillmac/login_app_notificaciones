import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/session_manager.dart';
import 'home_page.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingsPage({super.key, required this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  bool _loading = false;
  final LocalAuthentication _auth = LocalAuthentication();
  bool _biometricSupported = false;
  final int _selectedIndex = 2; // Settings seleccionado

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricSupport();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final settings = await SessionManager.getSettings();
    if (!mounted) return;

    setState(() {
      _biometricEnabled = settings['biometricEnabled'] ?? false;
      _notificationsEnabled = settings['notificationsEnabled'] ?? true;
      _loading = false;
    });
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();
      final bool canCheckBiometrics = availableBiometrics.isNotEmpty;

      if (!mounted) return;
      setState(() {
        _biometricSupported = isSupported && canCheckBiometrics;
      });
    } catch (e) {
      debugPrint("Error checking biometric support: $e");
      if (!mounted) return;
      setState(() => _biometricSupported = false);
    }
  }

  Future<void> _saveSettings() async {
    final settings = {
      'biometricEnabled': _biometricEnabled,
      'notificationsEnabled': _notificationsEnabled,
    };
    await SessionManager.saveSettings(settings);

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Configuración guardada correctamente"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _testBiometric() async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Autentícate para probar el login biométrico',
        // CORREGIDO: Solo biometricOnly está disponible en local_auth 3.0.0
        biometricOnly: false,
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      if (authenticated) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("✅ Autenticación biométrica exitosa"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("❌ Autenticación fallida"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToPage(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(user: widget.user)),
        (route) => false,
      );
    } else if (index == 1) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProfilePage(email: widget.user['email'] ?? ''),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Configuración",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: "Guardar configuración",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader("Seguridad"),
                _buildSettingSwitch(
                  "Login Biométrico",
                  "Usar huella digital o reconocimiento facial",
                  Icons.fingerprint,
                  _biometricEnabled,
                  _biometricSupported
                      ? (value) {
                          setState(() => _biometricEnabled = value);
                        }
                      : null,
                  enabled: _biometricSupported,
                ),
                if (!_biometricSupported)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Text(
                      "La biometría no está disponible en este dispositivo",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                if (_biometricSupported && _biometricEnabled)
                  _buildActionButton(
                    "Probar Biometría",
                    Icons.security,
                    _testBiometric,
                  ),

                const SizedBox(height: 24),
                _buildSectionHeader("Notificaciones"),
                _buildSettingSwitch(
                  "Notificaciones Push",
                  "Recibir notificaciones de eventos y actividades",
                  Icons.notifications,
                  _notificationsEnabled,
                  (value) => setState(() => _notificationsEnabled = value),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Información"),
                _buildInfoCard("Versión de la App", "1.0.0", Icons.info),

                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(25, 118, 210, 1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text(
                      "GUARDAR CONFIGURACIÓN",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFFF00).withValues(alpha: 0.7),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromRGBO(25, 118, 210, 1),
        unselectedItemColor: Colors.grey,
        onTap: _navigateToPage,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Config."),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color.fromRGBO(25, 118, 210, 1),
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool>? onChanged, {
    bool enabled = true,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color.fromRGBO(25, 118, 210, 1)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12),
        ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: const Color.fromRGBO(25, 118, 210, 1),
        ),
        enabled: enabled,
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    VoidCallback onPressed, {
    Color color = const Color.fromRGBO(25, 118, 210, 1),
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          text,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(value, style: const TextStyle(fontFamily: 'Montserrat')),
      ),
    );
  }
}