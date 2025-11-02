import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/session_manager.dart';
// Agrega las importaciones de las páginas que necesitas
import 'home_page.dart'; // Asegúrate de que esta ruta sea correcta
import 'profile_page.dart'; // Asegúrate de que esta ruta sea correcta
import 'settings_page.dart'; // Asegúrate de que esta ruta sea correcta

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  Map<String, dynamic>? user;
  bool loading = true;
  List<String> familiaUsuarios = [];
  final int _selectedIndex = 0; // Home seleccionado

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => loading = true);
    
    try {
      // CORREGIDO: Usar getCurrentUser() en lugar de getUser()
      final userData = await SessionManager.getCurrentUser();
      if (userData != null) {
        setState(() {
          user = userData;
        });
        
        // Cargar información de la familia
        await _loadFamiliaInfo(userData['numero_usuario'] ?? '');
      } else {
        // Si no hay datos del usuario, usar datos por defecto
        _setDefaultUserData();
      }
    } catch (e) {
      // Manejar error
      _setDefaultUserData();
    } finally {
      setState(() => loading = false);
    }
  }

  void _setDefaultUserData() {
    setState(() {
      user = {
        'numero_usuario': 'No disponible',
        'tipo_membresia': 'Individual',
        'estatus_membresia': 'Activo',
        'email': 'No disponible',
      };
      familiaUsuarios = [user!['numero_usuario']];
    });
  }

  Future<void> _loadFamiliaInfo(String numeroUsuarioBase) async {
    if (numeroUsuarioBase.isEmpty || numeroUsuarioBase == 'No disponible') {
      setState(() {
        familiaUsuarios = [numeroUsuarioBase];
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_usuarios_relacionados.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"numero_usuario_base": numeroUsuarioBase}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            familiaUsuarios = List<String>.from(data['usuarios_relacionados']);
          });
        } else {
          // Si la API no tiene éxito, mostrar solo el usuario actual
          setState(() {
            familiaUsuarios = [numeroUsuarioBase];
          });
        }
      } else {
        // En caso de error HTTP, mostrar solo el usuario actual
        setState(() {
          familiaUsuarios = [numeroUsuarioBase];
        });
      }
    } catch (e) {
      // En caso de error, mostrar solo el usuario actual
      setState(() {
        familiaUsuarios = [numeroUsuarioBase];
      });
    }
  }

  void _navigateToPage(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        if (user != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomePage(user: user!)),
            (route) => false,
          );
        }
        break;
      case 1:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ProfilePage(email: user?['email'] ?? ''),
          ),
          (route) => false,
        );
        break;
      case 2:
        if (user != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => SettingsPage(user: user!)),
            (route) => false,
          );
        }
        break;
    }
  }

  String _determinarRol(String numeroUsuario) {
    if (!numeroUsuario.contains(RegExp(r'[A-Z]$'))) return 'titular';
    
    final sufijo = numeroUsuario.substring(numeroUsuario.length - 1);
    switch (sufijo) {
      case 'A': return 'conyuge';
      case 'B': return 'hijo';
      case 'C': return 'hijo';
      case 'D': return 'hijo';
      case 'E': return 'hijo';
      default: return 'hijo';
    }
  }

  String _getRolDisplay(String rol) {
    switch (rol) {
      case 'titular': return 'Titular';
      case 'conyuge': return 'Cónyuge';
      case 'hijo': return 'Hijo/a';
      default: return 'Miembro';
    }
  }

  Color _getColorRol(String rol) {
    switch (rol) {
      case 'titular': return const Color.fromRGBO(25, 118, 210, 1);
      case 'conyuge': return Colors.purple;
      case 'hijo': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getIconRol(String rol) {
    switch (rol) {
      case 'titular': return Icons.person;
      case 'conyuge': return Icons.favorite;
      case 'hijo': return Icons.child_care;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Mi Membresía",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la membresía principal
            _buildMembresiaCard(),
            
            const SizedBox(height: 24),
            
            // Grupo Familiar
            _buildFamiliaCard(),
            
            const SizedBox(height: 24),
            
            // Información de pagos (mantener funcionalidad existente)
            _buildPagosCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMembresiaCard() {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership, color: Color.fromRGBO(25, 118, 210, 1)),
                const SizedBox(width: 8),
                const Text(
                  "Información de Membresía",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Número de Usuario", user?['numero_usuario'] ?? ''),
            _buildInfoRow("Tipo de Membresía", user?['tipo_membresia'] ?? "Individual"),
            _buildInfoRow("Estado", user?['estatus_membresia'] ?? "Activo"),
            if (user?['fecha_inicio_membresia'] != null)
              _buildInfoRow("Fecha Inicio", user!['fecha_inicio_membresia']),
            if (user?['fecha_fin_membresia'] != null)
              _buildInfoRow("Fecha Fin", user!['fecha_fin_membresia']),
            if (user?['saldo_pendiente'] != null && user!['saldo_pendiente'] != "0.00")
              _buildInfoRow("Saldo Pendiente", "\$${user!['saldo_pendiente']}"),
          ],
        ),
      ),
    );
  }

  Widget _buildFamiliaCard() {
    if (familiaUsuarios.length <= 1) {
      return const SizedBox.shrink(); // No mostrar si no hay familia
    }

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: Color.fromRGBO(25, 118, 210, 1)),
                const SizedBox(width: 8),
                const Text(
                  "Grupo Familiar",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Miembros incluidos en tu membresía familiar:",
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ...familiaUsuarios.map((numeroUsuario) => 
              _buildMiembroFamiliaItem(numeroUsuario)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiembroFamiliaItem(String numeroUsuario) {
    final rol = _determinarRol(numeroUsuario);
    final colorRol = _getColorRol(rol);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colorRol.withAlpha(25), // Reemplazado withOpacity(0.1)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorRol.withAlpha(76)), // Reemplazado withOpacity(0.3)
      ),
      child: Row(
        children: [
          Icon(_getIconRol(rol), size: 20, color: colorRol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numeroUsuario,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    color: colorRol,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getRolDisplay(rol),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colorRol,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getRolDisplay(rol).toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagosCard() {
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Color.fromRGBO(25, 118, 210, 1)),
                const SizedBox(width: 8),
                const Text(
                  "Información de Pagos",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Próximo Pago", "15 de cada mes"),
            _buildInfoRow("Método de Pago", "Tarjeta de Crédito"),
            _buildInfoRow("Estado del Pago", "Al corriente"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navegar a pantalla de pagos detallada
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(25, 118, 210, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "VER DETALLES DE PAGOS",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : "No especificado",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
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
            color: const Color.fromRGBO(0, 0, 0, 13), // Reemplazado con valores RGBO
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
}