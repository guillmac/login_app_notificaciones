import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ IMPORT NUEVO
import 'package:url_launcher/url_launcher.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Map<String, dynamic>> eventos = [];
  bool loading = true;
  bool error = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting(); // ✅ INICIALIZAR FECHAS PRIMERO
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('es_ES', null).then((_) {
      _loadEventos(); // ✅ CARGAR EVENTOS DESPUÉS DE INICIALIZAR FECHAS
    });
  }

  Future<void> _loadEventos() async {
    setState(() {
      loading = true;
      error = false;
    });

    try {
      final url = "https://clubfrance.org.mx/api/get_eventos.php";
      debugPrint('🔍 Cargando eventos desde: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📡 JSON decodificado: $data');
        
        if (data['success'] == true && data['eventos'] != null) {
          debugPrint('✅ Eventos cargados exitosamente');
          final eventosProcesados = _procesarEventos(
            List<Map<String, dynamic>>.from(data['eventos'])
          );
          setState(() {
            eventos = eventosProcesados;
            error = false;
          });
        } else {
          debugPrint('❌ API respondió: ${data['message']}');
          _useMockEventos();
        }
      } else {
        debugPrint('❌ Error HTTP: ${response.statusCode}');
        _useMockEventos();
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      _useMockEventos();
    } finally {
      setState(() => loading = false);
    }
  }

  void _useMockEventos() {
    setState(() {
      eventos = [
        {
          'id': 1,
          'evento': 'Torneo de Tenis Interclubes',
          'nombre': 'Campeonato Anual',
          'organizador': 'Club France',
          'fecha': '2025-11-16',
          'lugar': 'Canchas de Tenis',
          'horario': '09:00 - 18:00',
          'celular': '+525551234567',
          'avisos': 'Traer raqueta y ropa deportiva. Inscripción previa requerida.',
          'es_mock': true,
        },
        {
          'id': 2,
          'evento': 'Noche de Gala Navideña',
          'nombre': 'Cena de Fin de Año',
          'organizador': 'Comité Social',
          'fecha': '2024-12-20',
          'lugar': 'Salón Principal',
          'horario': '20:00 - 02:00',
          'celular': '+525559876543',
          'avisos': 'Vestimenta formal. Confirmar asistencia antes del 10/12.',
          'es_mock': true,
        },
        {
          'id': 3,
          'evento': 'Clase de Yoga al Aire Libre',
          'nombre': 'Yoga Matutino',
          'organizador': 'Departamento de Wellness',
          'fecha': '2024-12-08',
          'lugar': 'Jardín Principal',
          'horario': '07:00 - 08:30',
          'celular': '+525554567890',
          'avisos': 'Traer tapete propio. Clase gratuita para miembros.',
          'es_mock': true,
        },
      ];
      error = true;
      errorMessage = 'Usando datos de ejemplo';
    });
  }

  List<Map<String, dynamic>> _procesarEventos(List<Map<String, dynamic>> eventosRaw) {
    return eventosRaw.map((evento) {
      return {
        'id': evento['id'],
        'evento': evento['evento'] ?? 'Evento sin nombre',
        'nombre': evento['nombre'] ?? '',
        'organizador': evento['organizador'] ?? 'Club France',
        'fecha': evento['fecha'] ?? '',
        'lugar': evento['lugar'] ?? 'Por confirmar',
        'horario': evento['horario'] ?? 'Por confirmar',
        'celular': evento['celular'] ?? '',
        'avisos': evento['avisos'] ?? '',
        'es_mock': false,
      };
    }).toList();
  }

  // Función mejorada para parsear fechas
  DateTime? _parsearFecha(String fecha) {
    try {
      if (fecha.isEmpty) return null;
      
      // Primero intentar parseo directo (para formato ISO)
      DateTime? parsedDate = DateTime.tryParse(fecha);
      if (parsedDate != null) return parsedDate;
      
      // Lista de formatos posibles
      final formats = [
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('yyyy/MM/dd'),
        DateFormat('dd-MM-yyyy'),
        DateFormat('MM-dd-yyyy'),
      ];
      
      // Intentar cada formato
      for (var format in formats) {
        try {
          return format.parse(fecha);
        } catch (e) {
          continue;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error parseando fecha $fecha: $e');
      return null;
    }
  }

  String _formatearFecha(String fecha) {
    try {
      final parsedDate = _parsearFecha(fecha);
      
      if (parsedDate != null) {
        // Formato: "Lunes, 6 de Octubre del 2025"
        final dayName = DateFormat('EEEE', 'es_ES').format(parsedDate);
        final day = parsedDate.day;
        final monthName = DateFormat('MMMM', 'es_ES').format(parsedDate);
        final year = parsedDate.year;
        
        // Capitalizar primera letra del día y mes
        final capitalizedDayName = '${dayName[0].toUpperCase()}${dayName.substring(1)}';
        final capitalizedMonthName = '${monthName[0].toUpperCase()}${monthName.substring(1)}';
        
        return '$capitalizedDayName, $day de $capitalizedMonthName del $year';
      }
      
      return fecha.isNotEmpty ? fecha : 'Fecha por confirmar';
    } catch (e) {
      debugPrint('❌ Error formateando fecha $fecha: $e');
      return fecha.isNotEmpty ? fecha : 'Fecha por confirmar';
    }
  }

  String _obtenerDiaNumero(String fecha) {
    try {
      final parsedDate = _parsearFecha(fecha);
      return parsedDate?.day.toString() ?? '--';
    } catch (e) {
      debugPrint('❌ Error obteniendo día número $fecha: $e');
      return '--';
    }
  }

  // Función para obtener el día de la semana abreviado
  String _obtenerDiaSemanaAbreviado(String fecha) {
    try {
      final parsedDate = _parsearFecha(fecha);
      if (parsedDate != null) {
        final dayName = DateFormat('EEE', 'es_ES').format(parsedDate);
        return dayName.toUpperCase();
      }
      
      return '--';
    } catch (e) {
      debugPrint('❌ Error obteniendo día semana $fecha: $e');
      return '--';
    }
  }

  // Función para abrir WhatsApp
  Future<void> _abrirWhatsApp(String telefono) async {
    final numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'https://wa.me/$numeroLimpio';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _mostrarMensajeError('No se pudo abrir WhatsApp');
      }
    } catch (e) {
      _mostrarMensajeError('Error al abrir WhatsApp: $e');
    }
  }

  Color _getColorEvento(int index) {
    final colors = [
      const Color.fromRGBO(25, 118, 210, 1),
      Colors.purple,
      Colors.green,
      Colors.orange,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  Widget _buildEventoCard(Map<String, dynamic> evento, int index) {
    final color = _getColorEvento(index);
    final esMock = evento['es_mock'] == true;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: esMock ? Colors.orange : color.withAlpha(100),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con título y badge de mock
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha en círculo - CON DÍA DE LA SEMANA DEBAJO
                  Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _obtenerDiaNumero(evento['fecha']),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _obtenerDiaSemanaAbreviado(evento['fecha']),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                evento['evento'],
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (esMock) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
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
                        if (evento['nombre'].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            evento['nombre'],
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Información del evento - FECHA CON LETRA
              _buildInfoItem(Icons.calendar_today, _formatearFecha(evento['fecha'])),
              _buildInfoItem(Icons.schedule, evento['horario']),
              _buildInfoItem(Icons.location_on, evento['lugar']),
              _buildInfoItem(Icons.person, 'Organiza: ${evento['organizador']}'),
              
              if (evento['celular'].isNotEmpty) ...[
                _buildInfoItemWithWhatsApp(evento['celular']),
              ],
              
              if (evento['avisos'].isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Avisos Importantes:',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evento['avisos'],
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Botón único de REGISTRO
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _mostrarRegistroEvento(evento);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(25, 118, 210, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.app_registration, size: 20),
                  label: const Text(
                    'REGISTRARME EN EL EVENTO',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItemWithWhatsApp(String telefono) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.chat, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirWhatsApp(telefono),
              child: Row(
                children: [
                  Text(
                    telefono,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new, size: 12, color: Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarRegistroEvento(Map<String, dynamic> evento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Registro en Evento',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Deseas registrarte en el evento?',
              style: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${evento['evento']}"',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(25, 118, 210, 1),
              ),
            ),
            const SizedBox(height: 16),
            if (evento['celular'].isNotEmpty) ...[
              const Text(
                'También puedes contactarnos por WhatsApp:',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _abrirWhatsApp(evento['celular']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.chat, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        evento['celular'],
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, size: 14, color: Colors.green),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarMensajeExito('Registro exitoso para ${evento['evento']}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(25, 118, 210, 1),
            ),
            child: const Text(
              'REGISTRARME',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMensajeExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Eventos y Actividades",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEventos,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: loading
          ? _buildLoadingState()
          : error
              ? _buildErrorState()
              : eventos.isEmpty
                  ? _buildEmptyState()
                  : _buildEventosList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Cargando eventos...',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        Text(
          errorMessage,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Mostrando eventos de ejemplo',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            color: Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loadEventos,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(25, 118, 210, 1),
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'REINTENTAR',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay eventos programados',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vuelve pronto para ver nuevas actividades',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventosList() {
    return Column(
      children: [
        if (error)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.event, color: Color.fromRGBO(25, 118, 210, 1)),
              const SizedBox(width: 8),
              Text(
                '${eventos.length} evento${eventos.length != 1 ? 's' : ''} encontrado${eventos.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              return _buildEventoCard(eventos[index], index);
            },
          ),
        ),
      ],
    );
  }
}