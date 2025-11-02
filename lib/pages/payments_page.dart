import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/session_manager.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  Map<String, dynamic>? user;
  bool loading = true;
  List<Map<String, dynamic>> familiaUsuarios = [];
  final int _selectedIndex = 0;
  bool _usingMockData = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Método temporal para debug
  void _debugUserData() {
    debugPrint('=== DATOS DEL USUARIO ===');
    user?.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=========================');
  }

  Future<void> _loadUserData() async {
    setState(() => loading = true);
    _usingMockData = false;
    _debugInfo = 'Cargando datos...';
    
    try {
      final userData = await SessionManager.getCurrentUser();
      if (userData != null) {
        setState(() {
          user = userData;
        });
        _debugUserData(); // Debug temporal
        await _loadFamiliaInfo(userData['numero_usuario'] ?? '');
      } else {
        _setDefaultUserData();
      }
    } catch (e) {
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
        'primer_nombre': 'Usuario',
        'primer_apellido': 'Club France',
        'membresia': 'Individual',
        'estatus': 'Activo',
      };
      familiaUsuarios = [];
      _usingMockData = true;
      _debugInfo = 'Usando datos por defecto';
    });
  }

  Future<void> _loadFamiliaInfo(String numeroUsuarioBase) async {
    if (numeroUsuarioBase.isEmpty || numeroUsuarioBase == 'No disponible') {
      setState(() {
        familiaUsuarios = [];
        _debugInfo = 'Número de usuario no disponible';
      });
      return;
    }

    setState(() {
      _debugInfo = 'Buscando familia para: $numeroUsuarioBase';
    });

    try {
      debugPrint('🔍 Buscando información familiar para: $numeroUsuarioBase');
      
      // Usar GET que sabemos que funciona
      final url = "https://clubfrance.org.mx/api/get_usuarios_relacionados.php?numero_usuario_base=$numeroUsuarioBase";
      debugPrint('🔍 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📡 JSON decodificado: $data');
        
        if (data['success'] == true && data['usuarios_relacionados'] != null) {
          debugPrint('✅ ✅ ✅ DATOS REALES RECIBIDOS ✅ ✅ ✅');
          final usuariosProcesados = _procesarUsuariosFamilia(
            List<Map<String, dynamic>>.from(data['usuarios_relacionados'])
          );
          setState(() {
            familiaUsuarios = usuariosProcesados;
            _usingMockData = false;
            _debugInfo = 'Membresía cargada: ${usuariosProcesados.length} miembros';
          });
          return;
        } else {
          debugPrint('❌ API respondió: ${data['message']}');
          setState(() {
            _debugInfo = 'No se encontraron familiares: ${data['message']}';
          });
        }
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        setState(() {
          _debugInfo = 'Error del servidor: ${response.statusCode}';
        });
      }

      // Si no se encontraron datos reales, usar datos mock
      debugPrint('🎭 Usando datos de ejemplo');
      _useMockFamilyData(numeroUsuarioBase);
      
    } catch (e) {
      debugPrint('❌ Error: $e');
      _useMockFamilyData(numeroUsuarioBase);
    }
  }

  void _useMockFamilyData(String numeroUsuarioBase) {
    setState(() {
      familiaUsuarios = [
        {
          'numero_usuario': numeroUsuarioBase,
          'primer_nombre': user?['primer_nombre'] ?? 'Juan',
          'primer_apellido': user?['primer_apellido'] ?? 'Pérez',
          'rol': 'titular',
          'tipo_membresia': user?['tipo_membresia'] ?? 'Familiar',
          'estatus_membresia': user?['estatus_membresia'] ?? 'Activo',
          'es_mock': true,
        },
        {
          'numero_usuario': '${numeroUsuarioBase}A',
          'primer_nombre': 'María',
          'primer_apellido': user?['primer_apellido'] ?? 'García',
          'rol': 'conyuge',
          'tipo_membresia': user?['tipo_membresia'] ?? 'Familiar',
          'estatus_membresia': user?['estatus_membresia'] ?? 'Activo',
          'es_mock': true,
        },
        {
          'numero_usuario': '${numeroUsuarioBase}B',
          'primer_nombre': 'Carlos',
          'primer_apellido': user?['primer_apellido'] ?? 'Pérez',
          'rol': 'hijo',
          'tipo_membresia': user?['tipo_membresia'] ?? 'Familiar',
          'estatus_membresia': user?['estatus_membresia'] ?? 'Activo',
          'es_mock': true,
        },
      ];
      _usingMockData = true;
      _debugInfo = 'Datos de ejemplo (${familiaUsuarios.length} miembros)';
    });
  }

  List<Map<String, dynamic>> _procesarUsuariosFamilia(List<Map<String, dynamic>> usuarios) {
    final usuariosProcesados = usuarios.map((usuario) {
      return {
        'numero_usuario': usuario['numero_usuario'],
        'primer_nombre': usuario['primer_nombre'] ?? '',
        'segundo_nombre': usuario['segundo_nombre'] ?? '',
        'primer_apellido': usuario['primer_apellido'] ?? '',
        'segundo_apellido': usuario['segundo_apellido'] ?? '',
        'rol': _determinarRol(usuario['numero_usuario']),
        'tipo_membresia': usuario['tipo_membresia'],
        'estatus_membresia': usuario['estatus_membresia'],
        'es_mock': false,
      };
    }).toList();

    // Actualizar el usuario principal con datos de la membresía si están disponibles
    final titular = usuariosProcesados.firstWhere(
      (u) => u['rol'] == 'titular',
      orElse: () => usuariosProcesados.isNotEmpty ? usuariosProcesados[0] : {},
    );

    if (titular.isNotEmpty && user != null) {
      setState(() {
        user!['tipo_membresia'] = titular['tipo_membresia'] ?? user!['tipo_membresia'];
        user!['estatus_membresia'] = titular['estatus_membresia'] ?? user!['estatus_membresia'];
      });
    }

    return usuariosProcesados;
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

  String _getNombreCompleto(Map<String, dynamic> usuario) {
    final nombre = usuario['primer_nombre'] ?? '';
    final apellido = usuario['primer_apellido'] ?? '';
    
    if (nombre.isNotEmpty && apellido.isNotEmpty) {
      return '$nombre $apellido';
    } else if (nombre.isNotEmpty) {
      return nombre;
    } else {
      return 'Nombre no disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Cargando información de membresía...',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
              SizedBox(height: 10),
              Text(
                _debugInfo,
                style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de debug
            if (_debugInfo.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _usingMockData ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _usingMockData ? Colors.orange : Colors.green,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _usingMockData ? Icons.warning : Icons.check_circle,
                      color: _usingMockData ? Colors.orange : Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _debugInfo,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: _usingMockData ? Colors.orange[800] : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Información de la membresía principal
            _buildMembresiaCard(),
            
            const SizedBox(height: 24),
            
            // Grupo Familiar
            _buildFamiliaCard(),
            
            const SizedBox(height: 24),
            
            // Información de pagos
            _buildPagosCard(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMembresiaCard() {
    // Función helper para obtener valores seguros
    String getSafeValue(List<String> keys) {
      for (String key in keys) {
        if (user?[key] != null && user![key].toString().isNotEmpty) {
          return user![key].toString();
        }
      }
      return 'No disponible';
    }

    final numeroUsuario = getSafeValue(['numero_usuario', 'numero', 'id']);
    final tipoMembresia = getSafeValue(['tipo_membresia', 'membresia', 'tipo']);
    final estatusMembresia = getSafeValue(['estatus_membresia', 'estatus', 'status']);
    final fechaInicio = getSafeValue(['fecha_inicio_membresia', 'fecha_inicio', 'inicio_membresia']);
    final fechaFin = getSafeValue(['fecha_fin_membresia', 'fecha_fin', 'fin_membresia']);
    final saldoPendiente = getSafeValue(['saldo_pendiente', 'saldo', 'deuda']);

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
            _buildInfoRow("Número de Usuario", numeroUsuario),
            _buildInfoRow("Tipo de Membresía", tipoMembresia),
            _buildInfoRow("Estado de Membresía", estatusMembresia),
            if (fechaInicio != 'No disponible')
              _buildInfoRow("Fecha Inicio", fechaInicio),
            if (fechaFin != 'No disponible')
              _buildInfoRow("Fecha Fin", fechaFin),
            if (saldoPendiente != 'No disponible')
              _buildInfoRow("Saldo Pendiente", "\$$saldoPendiente"),
          ],
        ),
      ),
    );
  }

  Widget _buildFamiliaCard() {
    if (familiaUsuarios.isEmpty) {
      return const SizedBox.shrink();
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
                  "Membresía",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_usingMockData) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EJEMPLO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Miembros incluidos en tu membresía:",
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ...familiaUsuarios.map((usuario) => _buildMiembroFamiliaItem(usuario)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiembroFamiliaItem(Map<String, dynamic> usuario) {
    final numeroUsuario = usuario['numero_usuario'];
    final rol = usuario['rol'] ?? _determinarRol(numeroUsuario);
    final colorRol = _getColorRol(rol);
    final nombreCompleto = _getNombreCompleto(usuario);
    final esMock = usuario['es_mock'] == true;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colorRol.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esMock ? Colors.orange : colorRol.withAlpha(76)
        ),
      ),
      child: Row(
        children: [
          Icon(_getIconRol(rol), size: 20, color: colorRol),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombreCompleto,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          color: colorRol,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (esMock) ...[
                      SizedBox(width: 8),
                      Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    ],
                  ],
                ),
                Text(
                  numeroUsuario,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.black54,
                    fontSize: 12,
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
                  _showComingSoonSnackbar();
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

  void _showComingSoonSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidad en desarrollo'),
        duration: Duration(seconds: 2),
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
            color: const Color.fromRGBO(0, 0, 0, 13),
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
}