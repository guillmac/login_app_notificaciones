import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/session_manager.dart';

class MisClasesPage extends StatefulWidget {
  const MisClasesPage({super.key});

  @override
  State<MisClasesPage> createState() => _MisClasesPageState();
}

class _MisClasesPageState extends State<MisClasesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _clasesRegulares = [];
  List<dynamic> _clasesMuestra = [];
  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMisClases();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMisClases() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final userData = await SessionManager.getCurrentUser();
      print('📱 User data: $userData');
      
      if (userData != null) {
        final numeroUsuario = userData['numero_usuario'] ?? '';
        print('🔢 Número de usuario: $numeroUsuario');
        
        if (numeroUsuario.isEmpty) {
          throw Exception('No se pudo obtener el número de usuario');
        }

        // Cargar clases regulares y muestras en paralelo
        await Future.wait([
          _loadClasesRegulares(numeroUsuario),
          _loadClasesMuestra(numeroUsuario)
        ]);
      } else {
        throw Exception('No se pudo obtener la información del usuario');
      }
    } catch (e) {
      print('❌ Error cargando mis clases: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadClasesRegulares(String numeroUsuario) async {
    try {
      print('🔄 Cargando clases regulares para: $numeroUsuario');
      
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_clases_regulares.php"),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Accept": "application/json",
        },
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      ).timeout(const Duration(seconds: 15));

      print('📡 Respuesta clases regulares - Status: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Datos clases regulares: $data');
        
        if (data['success'] == true) {
          // CORRECCIÓN: Acceder a los datos anidados
          final clasesRegularesData = data['data']?['clases_regulares'] ?? [];
          
          if (mounted) {
            setState(() {
              _clasesRegulares = clasesRegularesData;
            });
          }
          print('✅ Clases regulares cargadas: ${_clasesRegulares.length}');
        } else {
          throw Exception(data['message'] ?? 'Error al cargar clases regulares');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cargando clases regulares: $e');
      rethrow;
    }
  }

  Future<void> _loadClasesMuestra(String numeroUsuario) async {
    try {
      print('🔄 Cargando clases muestra para: $numeroUsuario');
      
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_clases_muestra.php"),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Accept": "application/json",
        },
        body: jsonEncode({"numero_usuario": numeroUsuario}),
      ).timeout(const Duration(seconds: 15));

      print('📡 Respuesta clases muestra - Status: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Datos clases muestra: $data');
        
        if (data['success'] == true) {
          // MODIFICACIÓN: Acceder directamente a 'clases_muestra' en lugar de 'data'
          final clasesMuestraData = data['clases_muestra'] ?? [];
          
          if (mounted) {
            setState(() {
              _clasesMuestra = clasesMuestraData;
            });
          }
          print('✅ Clases muestra cargadas: ${_clasesMuestra.length}');
          
          // Debug: Mostrar detalles de cada clase muestra
          for (var i = 0; i < _clasesMuestra.length; i++) {
            print('📋 Clase muestra $i: ${_clasesMuestra[i]}');
          }
        } else {
          throw Exception(data['message'] ?? 'Error al cargar clases muestra');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cargando clases muestra: $e');
      rethrow;
    }
  }

  Future<void> _cancelarClaseMuestra(Map<String, dynamic> clase) async {
    print('🔄 Iniciando cancelación de clase muestra');
    print('📋 Datos de la clase: $clase');
    
    final confirmarCancelacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar clase muestra'),
        content: Text(
          '¿Estás seguro de que deseas cancelar la clase muestra de "${clase['actividad_nombre']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmarCancelacion != true) {
      print('❌ Usuario canceló la acción');
      return;
    }

    try {
      final idReserva = clase['id']?.toString() ?? clase['id_reserva']?.toString();
      print('🗑️ ID Reserva a cancelar: $idReserva');
      
      if (idReserva == null) {
        _mostrarErrorSnackBar('No se pudo identificar la reserva para cancelar');
        return;
      }

      print('🌐 Enviando solicitud a: https://clubfrance.org.mx/api/cancelar_clase_muestra.php');
      print('📤 Datos enviados: {"id_reserva": "$idReserva"}');
      
      // HEADERS MODIFICADOS PARA EVITAR BLOQUEO DEL FIREWALL
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "ClubFrance-App/1.0.0",
        "X-Requested-With": "XMLHttpRequest",
        "Origin": "https://clubfrance.org.mx",
        "Referer": "https://clubfrance.org.mx/",
      };

      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/cancelar_clase_muestra.php"),
        headers: headers,
        body: jsonEncode({
          "id_reserva": idReserva,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 Respuesta recibida - Status: ${response.statusCode}');
      print('📦 Body completo: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📊 Datos parseados: $data');
        
        if (data['success'] == true) {
          _mostrarExitoSnackBar('Clase muestra cancelada exitosamente');
          // Recargar los datos
          _loadMisClases();
        } else {
          _mostrarErrorSnackBar(data['message'] ?? "Error al cancelar la clase muestra");
        }
      } else if (response.statusCode == 403) {
        _mostrarErrorSnackBar('Error de seguridad: Acceso denegado por el firewall. Contacta al administrador.');
      } else if (response.statusCode == 405) {
        _mostrarErrorSnackBar('Error: Método no permitido. Contacta al administrador.');
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        _mostrarErrorSnackBar('Error de conexión al servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error completo al cancelar: $e');
      print('📋 Stack trace: ${e.toString()}');
      
      if (e is http.ClientException) {
        _mostrarErrorSnackBar('Error de conexión: ${e.message}');
      } else if (e is FormatException) {
        _mostrarErrorSnackBar('Error en el formato de la respuesta del servidor');
      } else {
        _mostrarErrorSnackBar('Error al cancelar la clase muestra: $e');
      }
    }
  }

  void _mostrarErrorSnackBar(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _mostrarExitoSnackBar(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _refreshData() {
    _loadMisClases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Clases'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0D47A1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0D47A1),
          tabs: const [
            Tab(
              icon: Icon(Icons.school),
              text: 'CLASES REGULARES',
            ),
            Tab(
              icon: Icon(Icons.assignment),
              text: 'CLASES MUESTRA',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Actualizar",
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : _error
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            "Cargando mis clases...",
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              "Error al cargar las clases",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text("Reintentar"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    print('🎯 Build Content - Regulares: ${_clasesRegulares.length}, Muestra: ${_clasesMuestra.length}');
    return TabBarView(
      controller: _tabController,
      children: [
        _buildClasesRegulares(),
        _buildClasesMuestra(),
      ],
    );
  }

  Widget _buildClasesRegulares() {
    print('📚 Build Clases Regulares: ${_clasesRegulares.length}');
    if (_clasesRegulares.isEmpty) {
      return _buildEmptyState(
        "No tienes clases regulares programadas",
        Icons.school,
        "Las clases regulares aparecerán aquí después de realizar tu pago",
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadMisClases(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clasesRegulares.length,
        itemBuilder: (context, index) {
          return _buildTarjetaClaseRegular(_clasesRegulares[index]);
        },
      ),
    );
  }

  Widget _buildClasesMuestra() {
    print('🎨 Build Clases Muestra: ${_clasesMuestra.length}');
    
    // DEBUG: Verificar la estructura de los datos
    if (_clasesMuestra.isNotEmpty) {
      print('🔍 Estructura de la primera clase muestra:');
      _clasesMuestra.first.forEach((key, value) {
        print('   $key: $value (${value.runtimeType})');
      });
    }
    
    if (_clasesMuestra.isEmpty) {
      return _buildEmptyState(
        "No tienes clases muestra programadas",
        Icons.assignment,
        "Solicita clases muestra en la sección de actividades deportivas",
      );
    }

    // Filtrar clases por estado para mostrar en secciones
    final clasesAsignadas = _clasesMuestra.where((clase) => 
        (clase['estado']?.toString().toLowerCase() ?? 'asignada') == 'asignada').toList();
    
    final clasesTomadas = _clasesMuestra.where((clase) => 
        (clase['estado']?.toString().toLowerCase() ?? '') == 'tomada').toList();
    
    final clasesCanceladas = _clasesMuestra.where((clase) => 
        (clase['estado']?.toString().toLowerCase() ?? '') == 'cancelada').toList();

    print('📊 Resumen por estado:');
    print('   - Asignadas: ${clasesAsignadas.length}');
    print('   - Tomadas: ${clasesTomadas.length}');
    print('   - Canceladas: ${clasesCanceladas.length}');

    return RefreshIndicator(
      onRefresh: () async => _loadMisClases(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Clases Asignadas
          if (clasesAsignadas.isNotEmpty) ...[
            _buildSeccionEstado(
              'Clases Muestra Asignadas (${clasesAsignadas.length})',
              Icons.schedule,
              Colors.orange,
            ),
            ...clasesAsignadas.map((clase) => _buildTarjetaClaseMuestra(clase)),
            const SizedBox(height: 16),
          ],

          // Sección de Clases Tomadas
          if (clasesTomadas.isNotEmpty) ...[
            _buildSeccionEstado(
              'Clases Muestra Completadas (${clasesTomadas.length})',
              Icons.check_circle,
              Colors.green,
            ),
            ...clasesTomadas.map((clase) => _buildTarjetaClaseMuestra(clase)),
            const SizedBox(height: 16),
          ],

          // Sección de Clases Canceladas
          if (clasesCanceladas.isNotEmpty) ...[
            _buildSeccionEstado(
              'Clases Muestra Canceladas (${clasesCanceladas.length})',
              Icons.cancel,
              Colors.red,
            ),
            ...clasesCanceladas.map((clase) => _buildTarjetaClaseMuestra(clase)),
          ],
        ],
      ),
    );
  }

  Widget _buildSeccionEstado(String titulo, IconData icono, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaClaseRegular(Map<String, dynamic> clase) {
    final estado = clase['estado']?.toString().toLowerCase() ?? 'activa';
    final colorEstado = _getColorEstado(estado);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: colorEstado),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    clase['actividad_nombre'] ?? 'Clase Regular',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorEstado,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _buildInfoRow(Icons.person, 'Profesor:', clase['profesor'] ?? 'Por asignar'),
            _buildInfoRow(Icons.place, 'Ubicación:', clase['ubicacion'] ?? 'Por asignar'),
            
            if (clase['dia_clase'] != null && clase['horario_clase'] != null)
              _buildInfoRow(
                Icons.schedule,
                'Horario:',
                '${clase['dia_clase']} - ${clase['horario_clase']}',
              ),
            
            if (clase['fecha_inicio'] != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Inicia:',
                _formatearFecha(clase['fecha_inicio']),
              ),
            
            if (clase['fecha_fin'] != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Finaliza:',
                _formatearFecha(clase['fecha_fin']),
              ),
            
            if (clase['costo'] != null)
              _buildInfoRow(
                Icons.attach_money,
                'Costo:',
                '\$${double.parse(clase['costo'].toString()).toStringAsFixed(2)}',
              ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorEstado.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: colorEstado),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getMensajeEstado(estado),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorEstado,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaClaseMuestra(Map<String, dynamic> clase) {
    try {
      print('🎯 Iniciando construcción de tarjeta para: ${clase['actividad_nombre']}');
      
      // DEBUG: Verificar campos críticos
      final actividadNombre = clase['actividad_nombre']?.toString() ?? 'Clase Muestra';
      final profesor = clase['profesor']?.toString() ?? 'Por asignar';
      final ubicacion = clase['ubicacion']?.toString() ?? 'Por asignar';
      final diaSeleccionado = clase['dia_seleccionado']?.toString();
      final horarioSeleccionado = clase['horario_seleccionado']?.toString();
      final integrante = clase['numero_usuario_integrante']?.toString();
      final fechaRegistro = clase['fecha_registro']?.toString() ?? '';
      final estado = clase['estado']?.toString().toLowerCase() ?? 'asignada';
      final colorEstado = _getColorEstadoClaseMuestra(estado);

      print('🔍 Campos de la clase:');
      print('   - Actividad: $actividadNombre');
      print('   - Profesor: $profesor');
      print('   - Ubicación: $ubicacion');
      print('   - Día: $diaSeleccionado');
      print('   - Horario: $horarioSeleccionado');
      print('   - Integrante: $integrante');
      print('   - Estado: $estado');

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con icono y título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getIconoEstadoClaseMuestra(estado), color: colorEstado),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      actividadNombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTextoEstadoClaseMuestra(estado),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorEstado,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Información de la clase
              _buildInfoRow(Icons.person, 'Profesor:', profesor),
              _buildInfoRow(Icons.place, 'Ubicación:', ubicacion),
              
              if (diaSeleccionado != null && diaSeleccionado.isNotEmpty)
                _buildInfoRow(Icons.calendar_today, 'Día:', diaSeleccionado),
              
              if (horarioSeleccionado != null && horarioSeleccionado.isNotEmpty)
                _buildInfoRow(Icons.access_time, 'Horario:', horarioSeleccionado),
              
              if (integrante != null && integrante.isNotEmpty)
                _buildInfoRow(Icons.person_outline, 'Integrante:', integrante),
              
              if (fechaRegistro.isNotEmpty)
                _buildInfoRow(
                  Icons.date_range,
                  'Fecha registro:',
                  _formatearFechaHora(fechaRegistro),
                ),
              
              const SizedBox(height: 12),
              
              // Estado y acciones
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 16, color: colorEstado),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getMensajeEstadoClaseMuestra(estado),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorEstado,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Mostrar botón de cancelar solo para clases asignadas
                  if (estado == 'asignada') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _cancelarClaseMuestra(clase),
                      tooltip: "Cancelar clase muestra",
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ ERROR CRÍTICO construyendo tarjeta: $e');
      print('📋 Stack trace: $stackTrace');
      
      // Widget de fallback para debugging
      return Card(
        color: Colors.red[50],
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌ Error mostrando clase',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text('Error: $e'),
              const SizedBox(height: 8),
              Text('Datos: ${clase.toString()}'),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Funciones auxiliares para manejar estados de clases muestra
  Color _getColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return Colors.green;
      case 'completada':
        return Colors.blue;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getColorEstadoClaseMuestra(String estado) {
    switch (estado.toLowerCase()) {
      case 'asignada':
        return Colors.orange;
      case 'tomada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconoEstadoClaseMuestra(String estado) {
    switch (estado.toLowerCase()) {
      case 'asignada':
        return Icons.schedule;
      case 'tomada':
        return Icons.check_circle;
      case 'cancelada':
        return Icons.cancel;
      default:
        return Icons.assignment;
    }
  }

  String _getTextoEstadoClaseMuestra(String estado) {
    switch (estado.toLowerCase()) {
      case 'asignada':
        return 'ASIGNADA';
      case 'tomada':
        return 'COMPLETADA';
      case 'cancelada':
        return 'CANCELADA';
      default:
        return estado.toUpperCase();
    }
  }

  String _getMensajeEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return 'Clase regular activa';
      case 'completada':
        return 'Clase completada';
      case 'cancelada':
        return 'Clase cancelada';
      default:
        return 'Estado: $estado';
    }
  }

  String _getMensajeEstadoClaseMuestra(String estado) {
    switch (estado.toLowerCase()) {
      case 'asignada':
        return 'Clase muestra programada - Sin costo';
      case 'tomada':
        return 'Clase muestra completada - Ya has tomado esta clase';
      case 'cancelada':
        return 'Clase muestra cancelada';
      default:
        return 'Clase muestra - Sin costo';
    }
  }

  String _formatearFecha(String fecha) {
    try {
      final date = DateTime.parse(fecha);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return fecha;
    }
  }

  String _formatearFechaHora(String fechaHora) {
    try {
      final date = DateTime.parse(fechaHora);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fechaHora;
    }
  }
}