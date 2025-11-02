import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart';
import '../utils/session_manager.dart';
import 'welcome_page.dart';
import 'home_page.dart';
import 'settings_page.dart';

// Formateador para convertir texto a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ProfilePage extends StatefulWidget {
  final String email;
  const ProfilePage({super.key, required this.email});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;
  bool editing = false;
  File? _newImage;
  final int _selectedIndex = 1;

  // Animación
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Instancia de Logger
  final Logger _logger = Logger();

  // Listas de opciones para los dropdowns existentes
  final List<String> _generoOpciones = ['Masculino', 'Femenino', 'Otro'];
  final List<String> _tipoSangreOpciones = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];
  final List<String> _parentescoOpciones = [
    'Padre',
    'Madre',
    'Esposo(a)',
    'Hijo(a)',
    'Hermano(a)',
    'Abuelo(a)',
    'Tío(a)',
    'Primo(a)',
    'Amigo(a)',
    'Otro',
  ];

  // Listas para alergias y enfermedades crónicas
  final List<String> _alergiasOpciones = [
    'Ninguna',
    'Penicilina',
    'Amoxicilina',
    'Aspirina',
    'Ibuprofeno',
    'Sulfas',
    'Codeína',
    'Morfina',
    'Latex',
    'Yodo',
    'Anestésicos locales',
    'Polen',
    'Ácaros del polvo',
    'Hongos',
    'Caspa de animales',
    'Picaduras de insectos',
    'Mariscos',
    'Pescado',
    'Maní',
    'Nueces',
    'Almendras',
    'Huevo',
    'Leche',
    'Soya',
    'Trigo',
    'Gluten',
    'Fresas',
    'Chocolate',
    'Colorantes artificiales',
    'Conservadores',
    'Otro',
  ];

  final List<String> _enfermedadesCronicasOpciones = [
    'Ninguna',
    'Diabetes tipo 1',
    'Diabetes tipo 2',
    'Hipertensión arterial',
    'Artritis reumatoide',
    'Artrosis',
    'Osteoporosis',
    'Asma',
    'EPOC (Enfermedad Pulmonar Obstructiva Crónica)',
    'Enfisema pulmonar',
    'Enfermedad cardíaca coronaria',
    'Insuficiencia cardíaca',
    'Arritmia cardíaca',
    'Hipotiroidismo',
    'Hipertiroidismo',
    'Enfermedad de Crohn',
    'Colitis ulcerosa',
    'Síndrome de intestino irritable',
    'Enfermedad renal crónica',
    'Hepatitis B crónica',
    'Hepatitis C crónica',
    'Cirrosis hepática',
    'Migraña crónica',
    'Epilepsia',
    'Esclerosis múltiple',
    'Parkinson',
    'Alzheimer',
    'Depresión mayor',
    'Trastorno de ansiedad generalizada',
    'Fibromialgia',
    'Lupus eritematoso sistémico',
    'VIH/SIDA',
    'Cáncer',
    'Anemia crónica',
    'Otra',
  ];

  // Datos para colonias CDMX
  List<String> _alcaldiasOpciones = [];
  List<Map<String, dynamic>> _coloniasOpciones = [];
  bool _loadingAlcaldias = false;
  bool _loadingColonias = false;

  // NUEVAS PROPIEDADES PARA LAS TABLAS RELACIONADAS
  List<String> _nacionalidadesUsuario = [];
  List<String> _actividadesDeportivasUsuario = [];
  List<String> _actividadesOcioUsuario = [];
  List<String> _actividadesCulturalesUsuario = [];

  // Controladores para los nuevos campos directos
  final TextEditingController _profesionController = TextEditingController();
  final TextEditingController _empresaTrabajoController = TextEditingController();
  final TextEditingController _puestoTrabajoController = TextEditingController();
  final TextEditingController _rfcController = TextEditingController();
  final TextEditingController _curpController = TextEditingController();
  final TextEditingController _institucionEmergenciaController = TextEditingController();
  final TextEditingController _ocupacionController = TextEditingController();

  // Variables para checkboxes
  bool _avisoPrivacidad = false;
  bool _reglamentoAceptado = false;
  bool _terminosEmergencia = false;
  bool _vendeProductosServicios = false;

  // Listas de opciones para los nuevos dropdowns
  final List<String> _nacionalidadesOpciones = [
    'Mexicana', 'Española', 'Estadounidense', 'Francesa', 'Argentina', 
    'Colombiana', 'Peruana', 'Chilena', 'Brasileña', 'Italiana', 'Alemana',
    'Británica', 'Canadiense', 'Otra'
  ];

  final List<String> _actividadesDeportivasOpciones = [
    'Tenis', 'Natación', 'Golf', 'Fútbol', 'Básquetbol', 'Voleibol',
    'Pádel', 'Squash', 'Gimnasio', 'Yoga', 'Pilates', 'Spinning',
    'Artes Marciales', 'Box', 'CrossFit', 'Atletismo', 'Ciclismo', 'Otro'
  ];

  final List<String> _actividadesOcioOpciones = [
    'Billar', 'Bar', 'Restaurante', 'Terraza', 'Salón de Eventos',
    'Cine', 'Biblioteca', 'Jardines', 'Alberca', 'Área de Juegos',
    'Salón de Juegos', 'Sala de TV', 'Otro'
  ];

  final List<String> _actividadesCulturalesOpciones = [
    'Pintura', 'Música', 'Teatro', 'Danza', 'Escultura', 'Fotografía',
    'Literatura', 'Cine Club', 'Conferencias', 'Talleres', 'Exposiciones',
    'Conciertos', 'Presentaciones', 'Otro'
  ];

  final List<String> _ocupacionOpciones = [
    'Estudiante', 'Empleado', 'Empresario', 'Profesionista', 'Comerciante',
    'Servicios', 'Artesano', 'Jubilado', 'Ama de casa', 'Desempleado', 'Otro'
  ];

  // Controladores de texto existentes
  final TextEditingController _primerNombreController = TextEditingController();
  final TextEditingController _segundoNombreController = TextEditingController();
  final TextEditingController _primerApellidoController = TextEditingController();
  final TextEditingController _segundoApellidoController = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _calleController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _coloniaController = TextEditingController();
  final TextEditingController _alcaldiaController = TextEditingController();
  final TextEditingController _cpController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _emergenciaNombreController = TextEditingController();
  final TextEditingController _emergenciaTelefonoController = TextEditingController();
  final TextEditingController _emergenciaParentescoController = TextEditingController();
  final TextEditingController _tipoSangreController = TextEditingController();
  final TextEditingController _alergiasController = TextEditingController();
  final TextEditingController _enfermedadesCronicasController = TextEditingController();

  // Variables para manejar los valores seleccionados en dropdowns existentes
  String? _selectedGenero;
  String? _selectedTipoSangre;
  String? _selectedParentesco;
  String? _selectedAlergias;
  String? _selectedEnfermedadesCronicas;
  String? _selectedAlcaldia;
  Map<String, dynamic>? _selectedColonia;

  // Variables para nuevos dropdowns
  String? _selectedOcupacion;
  String? _selectedNacionalidadPrimera;
  String? _selectedNacionalidadSegunda;
  String? _selectedNacionalidadTercera;
  String? _selectedDeportivaPrincipal;
  String? _selectedDeportivaSecundaria;
  String? _selectedDeportivaTerciaria;
  String? _selectedOcioPrincipal;
  String? _selectedOcioSecundaria;
  String? _selectedOcioTerciaria;
  String? _selectedCulturalPrincipal;
  String? _selectedCulturalSecundaria;
  String? _selectedCulturalTerciaria;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchUser();
    _cargarAlcaldias();
    // Inicializar listas
    _nacionalidadesUsuario = [];
    _actividadesDeportivasUsuario = [];
    _actividadesOcioUsuario = [];
    _actividadesCulturalesUsuario = [];
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutBack,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Liberar todos los controladores para prevenir fugas de memoria
    _primerNombreController.dispose();
    _segundoNombreController.dispose();
    _primerApellidoController.dispose();
    _segundoApellidoController.dispose();
    _fechaNacimientoController.dispose();
    _generoController.dispose();
    _telefonoController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _coloniaController.dispose();
    _alcaldiaController.dispose();
    _cpController.dispose();
    _ciudadController.dispose();
    _emergenciaNombreController.dispose();
    _emergenciaTelefonoController.dispose();
    _emergenciaParentescoController.dispose();
    _tipoSangreController.dispose();
    _alergiasController.dispose();
    _enfermedadesCronicasController.dispose();
    
    // Nuevos disposers
    _profesionController.dispose();
    _empresaTrabajoController.dispose();
    _puestoTrabajoController.dispose();
    _rfcController.dispose();
    _curpController.dispose();
    _institucionEmergenciaController.dispose();
    _ocupacionController.dispose();
    
    super.dispose();
  }

  Future<void> _cargarAlcaldias() async {
    setState(() => _loadingAlcaldias = true);
    try {
      _logger.i('Cargando alcaldías...');
      final response = await http.get(
        Uri.parse(
          "https://clubfrance.org.mx/api/colonias_cdmx.php?action=alcaldias",
        ),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _logger.i(
          'Alcaldías cargadas exitosamente: ${data['alcaldias']?.length ?? 0} encontradas',
        );
        setState(() {
          _alcaldiasOpciones = List<String>.from(data['alcaldias']);
          _loadingAlcaldias = false;
        });
      } else {
        _logger.w('Error al cargar alcaldías: ${data['message']}');
        setState(() => _loadingAlcaldias = false);
      }
    } catch (e) {
      _logger.e('Error cargando alcaldías: $e');
      setState(() => _loadingAlcaldias = false);
    }
  }

  Future<void> _cargarColonias(String alcaldia) async {
    if (alcaldia.isEmpty) return;

    setState(() => _loadingColonias = true);
    try {
      _logger.i('Cargando colonias para alcaldía: $alcaldia');
      final response = await http.get(
        Uri.parse(
          "https://clubfrance.org.mx/api/colonias_cdmx.php?action=colonias&alcaldia=${Uri.encodeComponent(alcaldia)}",
        ),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _logger.i(
          'Colonias cargadas exitosamente: ${data['colonias']?.length ?? 0} encontradas',
        );
        setState(() {
          _coloniasOpciones = List<Map<String, dynamic>>.from(data['colonias']);
          _loadingColonias = false;

          // Si ya hay una colonia seleccionada, encontrar el objeto correspondiente
          if (_coloniaController.text.isNotEmpty) {
            _selectedColonia = _coloniasOpciones.firstWhere(
              (element) => element['colonia'] == _coloniaController.text,
              orElse: () => {},
            );
            if (_selectedColonia!.isEmpty) {
              _selectedColonia = null;
            }
          }
        });
      } else {
        _logger.w('Error al cargar colonias: ${data['message']}');
        setState(() => _loadingColonias = false);
      }
    } catch (e) {
      _logger.e('Error cargando colonias: $e');
      setState(() => _loadingColonias = false);
    }
  }

  void _onAlcaldiaChanged(String? newValue) {
    setState(() {
      _selectedAlcaldia = newValue;
      _alcaldiaController.text = newValue ?? '';
      _selectedColonia = null;
      _coloniaController.text = '';
      _cpController.text = '';
      _coloniasOpciones = [];
    });

    if (newValue != null && newValue.isNotEmpty) {
      _logger.d('Alcaldía cambiada a: $newValue');
      _cargarColonias(newValue);
    }
  }

  void _onColoniaChanged(Map<String, dynamic>? newValue) {
    if (newValue != null) {
      _logger.d(
        'Colonia seleccionada: ${newValue['colonia']}, CP: ${newValue['cp']}',
      );
      setState(() {
        _selectedColonia = newValue;
        _coloniaController.text = newValue['colonia'] ?? '';
        _cpController.text = newValue['cp'] ?? '';
      });
    }
  }

  Future<void> _fetchUser() async {
    setState(() => loading = true);
    try {
      _logger.i('Obteniendo datos del usuario: ${widget.email}');
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/get_user.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email.trim()}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);
      _logger.d('Datos recibidos del API para usuario: ${widget.email}');

      if (data['success'] == true) {
        _logger.i('Datos de usuario obtenidos exitosamente');
        setState(() {
          user = data['user'];
          loading = false;

          // Inicializar TODOS los controladores con valores limpios
          _primerNombreController.text = _getValorLimpio(
            user!['primer_nombre'],
          );
          _segundoNombreController.text = _getValorLimpio(
            user!['segundo_nombre'],
          );
          _primerApellidoController.text = _getValorLimpio(
            user!['primer_apellido'],
          );
          _segundoApellidoController.text = _getValorLimpio(
            user!['segundo_apellido'],
          );
          _fechaNacimientoController.text = _getValorLimpio(
            user!['fecha_nacimiento'],
          );

          final generoValue = _getValorLimpio(user!['genero']);
          _generoController.text = _getGeneroDisplay(generoValue);
          _selectedGenero = _generoController.text.isEmpty
              ? null
              : _generoController.text;

          _telefonoController.text = _getValorLimpio(user!['telefono']);
          _calleController.text = _getValorLimpio(user!['calle']);
          _numeroController.text = _getValorLimpio(user!['numero']);
          _coloniaController.text = _getValorLimpio(user!['colonia']);
          _alcaldiaController.text = _getValorLimpio(user!['alcaldia']);
          _selectedAlcaldia = _alcaldiaController.text.isEmpty
              ? null
              : _alcaldiaController.text;
          _cpController.text = _getValorLimpio(user!['cp']);
          _ciudadController.text = _getValorLimpio(user!['ciudad']);
          _emergenciaNombreController.text = _getValorLimpio(
            user!['emergencia_nombre'],
          );
          _emergenciaTelefonoController.text = _getValorLimpio(
            user!['emergencia_telefono'],
          );

          final parentescoValue = _getValorLimpio(
            user!['emergencia_parentesco'],
          );
          _emergenciaParentescoController.text = parentescoValue;
          _selectedParentesco = parentescoValue.isEmpty
              ? null
              : parentescoValue;

          final tipoSangreValue = _getValorLimpio(user!['tipo_sangre']);
          _tipoSangreController.text = tipoSangreValue;
          _selectedTipoSangre = tipoSangreValue.isEmpty
              ? null
              : tipoSangreValue;

          final alergiasValue = _getValorLimpio(user!['alergias']);
          _alergiasController.text = alergiasValue;
          _selectedAlergias = alergiasValue.isEmpty ? null : alergiasValue;

          final enfermedadesValue = _getValorLimpio(
            user!['enfermedades_cronicas'],
          );
          _enfermedadesCronicasController.text = enfermedadesValue;
          _selectedEnfermedadesCronicas = enfermedadesValue.isEmpty
              ? null
              : enfermedadesValue;

          // NUEVOS CONTROLADORES
          _profesionController.text = _getValorLimpio(user!['profesion']);
          _empresaTrabajoController.text = _getValorLimpio(user!['empresa_trabajo']);
          _puestoTrabajoController.text = _getValorLimpio(user!['puesto_trabajo']);
          _rfcController.text = _getValorLimpio(user!['rfc']);
          _curpController.text = _getValorLimpio(user!['curp']);
          _institucionEmergenciaController.text = _getValorLimpio(user!['institucion_emergencia']);
          _ocupacionController.text = _getValorLimpio(user!['ocupacion']);
          _selectedOcupacion = _ocupacionController.text.isEmpty ? null : _ocupacionController.text;

          // CHECKBOXES
          _avisoPrivacidad = user!['aviso_privacidad'] == 1 || user!['aviso_privacidad'] == true;
          _reglamentoAceptado = user!['reglamento_aceptado'] == 1 || user!['reglamento_aceptado'] == true;
          _terminosEmergencia = user!['terminos_emergencia'] == 1 || user!['terminos_emergencia'] == true;
          _vendeProductosServicios = user!['vende_productos_servicios'] == 1 || user!['vende_productos_servicios'] == true;

          // Cargar colonias si ya hay una alcaldía seleccionada
          if (_alcaldiaController.text.isNotEmpty) {
            _cargarColonias(_alcaldiaController.text);
          }
        });
      } else {
        _logger.w('Error al obtener usuario: ${data['message']}');
        setState(() => loading = false);
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Error al obtener usuario"),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error en _fetchUser: $e');
      if (!mounted) return;
      setState(() => loading = false);
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  String _getValorLimpio(dynamic valor) {
    if (valor == null) return "";
    final stringValor = valor.toString().trim();
    if (stringValor.isEmpty) return "";
    if (stringValor.toLowerCase() == 'null' ||
        stringValor == 'NULL' ||
        stringValor == 'Null' ||
        stringValor == 'n/a' ||
        stringValor == 'N/A' ||
        stringValor == 'no especificado') {
      return "";
    }
    return stringValor;
  }

  String _getGeneroDisplay(String genero) {
    if (genero.isEmpty) return "";
    switch (genero) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      case 'O':
        return 'Otro';
      default:
        return genero;
    }
  }

  String _getGeneroValue(String display) {
    switch (display) {
      case 'Masculino':
        return 'M';
      case 'Femenino':
        return 'F';
      case 'Otro':
        return 'O';
      default:
        return 'O';
    }
  }

  // Métodos para manejar selecciones múltiples
  void _agregarNacionalidad(String nacionalidad, String tipo) {
    setState(() {
      // Limpiar nacionalidad existente del mismo tipo
      _nacionalidadesUsuario.removeWhere((n) => n.startsWith('$tipo:'));
      // Agregar nueva nacionalidad
      if (nacionalidad.isNotEmpty) {
        _nacionalidadesUsuario.add('$tipo:$nacionalidad');
      }
    });
  }

  void _agregarActividadDeportiva(String actividad, String tipo) {
    setState(() {
      _actividadesDeportivasUsuario.removeWhere((a) => a.startsWith('$tipo:'));
      if (actividad.isNotEmpty) {
        _actividadesDeportivasUsuario.add('$tipo:$actividad');
      }
    });
  }

  void _agregarActividadOcio(String actividad, String tipo) {
    setState(() {
      _actividadesOcioUsuario.removeWhere((a) => a.startsWith('$tipo:'));
      if (actividad.isNotEmpty) {
        _actividadesOcioUsuario.add('$tipo:$actividad');
      }
    });
  }

  void _agregarActividadCultural(String actividad, String tipo) {
    setState(() {
      _actividadesCulturalesUsuario.removeWhere((a) => a.startsWith('$tipo:'));
      if (actividad.isNotEmpty) {
        _actividadesCulturalesUsuario.add('$tipo:$actividad');
      }
    });
  }

  Future<void> _guardarCambios() async {
    try {
      _logger.i('Iniciando guardado de cambios para usuario: ${widget.email}');
      String? fotoUrl = user!['foto'];

      if (_newImage != null) {
        _logger.d('Subiendo nueva imagen de perfil');
        File imagenCorregida = await _corregirOrientacionImagen(_newImage!);
        var request = http.MultipartRequest(
          "POST",
          Uri.parse("https://clubfrance.org.mx/api/upload_foto.php"),
        );
        request.fields['email'] = widget.email.trim();
        request.files.add(
          await http.MultipartFile.fromPath('foto', imagenCorregida.path),
        );
        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        if (!mounted) return;
        var json = jsonDecode(responseBody);
        if (json['success'] == true) {
          _logger.i('Imagen subida exitosamente: ${json['path']}');
          fotoUrl = json['path'];
        } else {
          _logger.w('Error al subir imagen: ${json['message']}');
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(json['message'] ?? "Error al subir la foto"),
            ),
          );
          return;
        }
      }

      final Map<String, dynamic> updateData = {
        "email": widget.email.trim(),
        "numero_usuario": user!['numero_usuario'],
        "primer_nombre": _primerNombreController.text.trim(),
        "segundo_nombre": _segundoNombreController.text.trim(),
        "primer_apellido": _primerApellidoController.text.trim(),
        "segundo_apellido": _segundoApellidoController.text.trim(),
        "fecha_nacimiento": _fechaNacimientoController.text.trim(),
        "genero": _getGeneroValue(_generoController.text),
        "telefono": _telefonoController.text.trim(),
        "calle": _calleController.text.trim(),
        "numero": _numeroController.text.trim(),
        "colonia": _coloniaController.text.trim(),
        "alcaldia": _alcaldiaController.text.trim(),
        "cp": _cpController.text.trim(),
        "ciudad": _ciudadController.text.trim(),
        "emergencia_nombre": _emergenciaNombreController.text.trim(),
        "emergencia_telefono": _emergenciaTelefonoController.text.trim(),
        "emergencia_parentesco": _emergenciaParentescoController.text.trim(),
        "tipo_sangre": _tipoSangreController.text.trim(),
        "alergias": _alergiasController.text.trim(),
        "enfermedades_cronicas": _enfermedadesCronicasController.text.trim(),
        "foto": fotoUrl,

        // NUEVOS CAMPOS DIRECTOS
        "profesion": _profesionController.text.trim(),
        "empresa_trabajo": _empresaTrabajoController.text.trim(),
        "puesto_trabajo": _puestoTrabajoController.text.trim(),
        "rfc": _rfcController.text.trim(),
        "curp": _curpController.text.trim(),
        "institucion_emergencia": _institucionEmergenciaController.text.trim(),
        "ocupacion": _ocupacionController.text.trim(),
        "aviso_privacidad": _avisoPrivacidad,
        "reglamento_aceptado": _reglamentoAceptado,
        "terminos_emergencia": _terminosEmergencia,
        "vende_productos_servicios": _vendeProductosServicios,

        // DATOS RELACIONADOS
        "nacionalidades": _nacionalidadesUsuario,
        "actividades_deportivas": _actividadesDeportivasUsuario,
        "actividades_ocio": _actividadesOcioUsuario,
        "actividades_culturales": _actividadesCulturalesUsuario,
      };

      _logger.d('Enviando datos actualizados al servidor');
      final response = await http.post(
        Uri.parse("https://clubfrance.org.mx/api/update_user.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updateData),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);
      final messenger = ScaffoldMessenger.of(context);
      if (data['success'] == true) {
        _logger.i('Datos actualizados exitosamente');
        setState(() {
          editing = false;
          _newImage = null;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text("Datos actualizados con éxito")),
        );
        _fetchUser();
      } else {
        _logger.w('Error al actualizar datos: ${data['message']}');
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Error al guardar cambios"),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error en _guardarCambios: $e');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showLogoutConfirmation() {
    _animationController.forward();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.logout,
                  size: 48,
                  color: Colors.red,
                ),
                SizedBox(height: 8),
                Text(
                  "Cerrar Sesión",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Text(
              "¿Estás seguro de que quieres cerrar sesión?",
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _animationController.reverse();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Cancelar",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _logout();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Cerrar Sesión",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _animationController.reverse();
    });
  }

  Future<void> _logout() async {
    try {
      _logger.i('Usuario cerrando sesión: ${widget.email}');
      
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          );
        },
      );

      await SessionManager.logout();
      
      if (!mounted) return;
      
      // Cerrar el diálogo de carga
      Navigator.of(context).pop();
      
      // Navegar a la página de bienvenida con animación
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const WelcomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (route) => false,
      );
    } catch (e) {
      _logger.e('Error durante el cierre de sesión: $e');
      if (!mounted) return;
      
      // Cerrar el diálogo de carga en caso de error
      Navigator.of(context).pop();
      
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Error al cerrar sesión",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
        ),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "No se pudo cargar el usuario",
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Perfil de ${user!['primer_nombre'] ?? ''}",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Usuario: ${user!['numero_usuario'] ?? ''}",
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (!editing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black87),
              onPressed: () => setState(() => editing = true),
            ),
          if (editing)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.black87),
              onPressed: _guardarCambios,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _showLogoutConfirmation,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Foto de perfil
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: ClipOval(child: _buildProfileImage()),
                ),
                if (editing)
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Información principal
            Text(
              "${_primerNombreController.text} ${_primerApellidoController.text}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: "Montserrat",
              ),
            ),
            Text(
              user!['email'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: "Montserrat",
              ),
            ),

            // Información de membresía
            _buildInfoCard("Membresía", Icons.card_membership, [
              _buildInfoItem(
                "Número de Usuario",
                user!['numero_usuario']?.toString() ?? '',
              ),
              _buildInfoItem(
                "Tipo de Membresía",
                user!['tipo_membresia'] ?? "Individual",
              ),
              _buildInfoItem("Estado", user!['estatus_membresia'] ?? "Activo"),
              if (user!['fecha_inicio_membresia'] != null)
                _buildInfoItem(
                  "Fecha Inicio",
                  user!['fecha_inicio_membresia'] ?? "",
                ),
              if (user!['fecha_fin_membresia'] != null)
                _buildInfoItem("Fecha Fin", user!['fecha_fin_membresia'] ?? ""),
              if (user!['saldo_pendiente'] != null &&
                  user!['saldo_pendiente'] != "0.00")
                _buildInfoItem(
                  "Saldo Pendiente",
                  "\$${user!['saldo_pendiente']}",
                ),
            ]),

            const SizedBox(height: 24),

            // SECCIÓN: INFORMACIÓN PERSONAL
            _buildSectionHeader("Información Personal"),
            if (editing)
              _buildField(
                "Primer Nombre",
                _primerNombreController,
                editing,
                Icons.person,
              ),
            if (editing)
              _buildField(
                "Segundo Nombre",
                _segundoNombreController,
                editing,
                Icons.person_outline,
              ),
            if (editing)
              _buildField(
                "Primer Apellido",
                _primerApellidoController,
                editing,
                Icons.person,
              ),
            if (editing)
              _buildField(
                "Segundo Apellido",
                _segundoApellidoController,
                editing,
                Icons.person_outline,
              ),

            _buildField(
              "Fecha de Nacimiento",
              _fechaNacimientoController,
              editing,
              Icons.cake,
            ),
            if (!editing && _fechaNacimientoController.text.isNotEmpty)
              _buildStaticInfo(
                "Edad",
                _calcularEdad() ?? "No especificada",
                Icons.emoji_people,
              ),

            // GÉNERO CON DROPDOWN
            if (editing)
              _buildDropdownField(
                "Género",
                _selectedGenero,
                _generoOpciones,
                Icons.person_outline,
                (newValue) {
                  setState(() {
                    _selectedGenero = newValue;
                    _generoController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _generoController.text.isNotEmpty)
              _buildStaticInfo(
                "Género",
                _generoController.text,
                Icons.person_outline,
              ),

            _buildField(
              "Celular",
              _telefonoController,
              editing,
              Icons.phone_android,
            ),

            const SizedBox(height: 24),

            // SECCIÓN: DIRECCIÓN
            _buildSectionHeader("Dirección"),
            if (editing) ...[
              _buildField("Calle", _calleController, editing, Icons.signpost),
              _buildField("Número", _numeroController, editing, Icons.numbers),

              // ALACALDÍA CON DROPDOWN
              _buildAlcaldiaDropdown(),

              // COLONIA CON DROPDOWN (dependiente de alcaldía)
              _buildColoniaDropdown(),

              // CÓDIGO POSTAL (se llena automáticamente)
              _buildField(
                "Código Postal",
                _cpController,
                false,
                Icons.markunread_mailbox,
              ),
            ] else
              _buildStaticInfo(
                "Calle y Número",
                _getDireccionCompleta(),
                Icons.location_on,
              ),

            if (!editing) ...[
              if (_coloniaController.text.isNotEmpty)
                _buildStaticInfo(
                  "Colonia",
                  _coloniaController.text,
                  Icons.home,
                ),
              if (_alcaldiaController.text.isNotEmpty)
                _buildStaticInfo(
                  "Alcaldía/Municipio",
                  _alcaldiaController.text,
                  Icons.account_balance,
                ),
              if (_cpController.text.isNotEmpty)
                _buildStaticInfo(
                  "Código Postal",
                  _cpController.text,
                  Icons.markunread_mailbox,
                ),
            ],

            _buildField(
              "Ciudad",
              _ciudadController,
              editing,
              Icons.location_city,
            ),

            const SizedBox(height: 24),

            // SECCIÓN: CONTACTO DE EMERGENCIA
            _buildSectionHeader("Contacto de Emergencia"),
            _buildField(
              "Nombre Completo",
              _emergenciaNombreController,
              editing,
              Icons.emergency,
            ),
            _buildField(
              "Celular",
              _emergenciaTelefonoController,
              editing,
              Icons.phone_android,
            ),

            // PARENTESCO CON DROPDOWN
            if (editing)
              _buildDropdownField(
                "Parentesco",
                _selectedParentesco,
                _parentescoOpciones,
                Icons.family_restroom,
                (newValue) {
                  setState(() {
                    _selectedParentesco = newValue;
                    _emergenciaParentescoController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _emergenciaParentescoController.text.isNotEmpty)
              _buildStaticInfo(
                "Parentesco",
                _emergenciaParentescoController.text,
                Icons.family_restroom,
              ),

            const SizedBox(height: 24),

            // SECCIÓN: INFORMACIÓN MÉDICA
            _buildSectionHeader("Información Médica"),

            // TIPO DE SANGRE CON DROPDOWN (simplificado)
            if (editing)
              _buildDropdownField(
                "Tipo de Sangre",
                _selectedTipoSangre,
                _tipoSangreOpciones,
                Icons.bloodtype,
                (newValue) {
                  setState(() {
                    _selectedTipoSangre = newValue;
                    _tipoSangreController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _tipoSangreController.text.isNotEmpty)
              _buildStaticInfo(
                "Tipo de Sangre",
                _tipoSangreController.text,
                Icons.bloodtype,
              ),

            // ALERGIAS CON DROPDOWN
            if (editing)
              _buildDropdownField(
                "Alergias",
                _selectedAlergias,
                _alergiasOpciones,
                Icons.health_and_safety,
                (newValue) {
                  setState(() {
                    _selectedAlergias = newValue;
                    _alergiasController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _alergiasController.text.isNotEmpty)
              _buildStaticInfo(
                "Alergias",
                _alergiasController.text,
                Icons.health_and_safety,
              ),

            // ENFERMEDADES CRÓNICAS CON DROPDOWN
            if (editing)
              _buildDropdownField(
                "Enfermedades Crónicas",
                _selectedEnfermedadesCronicas,
                _enfermedadesCronicasOpciones,
                Icons.medical_services,
                (newValue) {
                  setState(() {
                    _selectedEnfermedadesCronicas = newValue;
                    _enfermedadesCronicasController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _enfermedadesCronicasController.text.isNotEmpty)
              _buildStaticInfo(
                "Enfermedades Crónicas",
                _enfermedadesCronicasController.text,
                Icons.medical_services,
              ),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: INFORMACIÓN LABORAL Y PROFESIONAL
            _buildSectionHeader("Información Laboral y Profesional"),
            _buildField(
              "Profesión",
              _profesionController,
              editing,
              Icons.work,
            ),
            _buildField(
              "Empresa donde trabaja",
              _empresaTrabajoController,
              editing,
              Icons.business,
            ),
            _buildField(
              "Puesto que desempeña",
              _puestoTrabajoController,
              editing,
              Icons.badge,
            ),

            // DROPDOWN PARA OCUPACIÓN
            if (editing)
              _buildDropdownField(
                "Ocupación",
                _selectedOcupacion,
                _ocupacionOpciones,
                Icons.work_outline,
                (newValue) {
                  setState(() {
                    _selectedOcupacion = newValue;
                    _ocupacionController.text = newValue ?? '';
                  });
                },
              ),
            if (!editing && _ocupacionController.text.isNotEmpty)
              _buildStaticInfo(
                "Ocupación",
                _ocupacionController.text,
                Icons.work_outline,
              ),

            // CAMPO RFC EN MAYÚSCULAS
            _buildUppercaseField(
              "RFC",
              _rfcController,
              editing,
              Icons.assignment,
            ),

            // CAMPO CURP EN MAYÚSCULAS
            _buildUppercaseField(
              "CURP",
              _curpController,
              editing,
              Icons.assignment_ind,
            ),

            // CHECKBOX PARA VENTA DE PRODUCTOS/SERVICIOS
            if (editing)
              _buildCheckboxField(
                "¿Vendes algún producto o servicio?",
                _vendeProductosServicios,
                Icons.shopping_cart,
                (newValue) {
                  setState(() {
                    _vendeProductosServicios = newValue ?? false;
                  });
                },
              ),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: NACIONALIDADES
            _buildSectionHeader("Nacionalidades"),
            if (editing) ...[
              _buildMultiSelectDropdown(
                "1ra Nacionalidad",
                _selectedNacionalidadPrimera,
                _nacionalidadesOpciones,
                Icons.flag,
                (newValue) {
                  setState(() {
                    _selectedNacionalidadPrimera = newValue;
                    _agregarNacionalidad(newValue ?? '', 'Primera');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "2da Nacionalidad", 
                _selectedNacionalidadSegunda,
                _nacionalidadesOpciones,
                Icons.flag_outlined,
                (newValue) {
                  setState(() {
                    _selectedNacionalidadSegunda = newValue;
                    _agregarNacionalidad(newValue ?? '', 'Segunda');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "3ra Nacionalidad",
                _selectedNacionalidadTercera,
                _nacionalidadesOpciones,
                Icons.flag_outlined,
                (newValue) {
                  setState(() {
                    _selectedNacionalidadTercera = newValue;
                    _agregarNacionalidad(newValue ?? '', 'Tercera');
                  });
                },
              ),
            ] else
              _buildStaticListInfo("Nacionalidades", _nacionalidadesUsuario, Icons.flag),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: ACTIVIDADES DEPORTIVAS
            _buildSectionHeader("Actividades Deportivas"),
            if (editing) ...[
              _buildMultiSelectDropdown(
                "Deportiva Principal",
                _selectedDeportivaPrincipal,
                _actividadesDeportivasOpciones,
                Icons.sports_soccer,
                (newValue) {
                  setState(() {
                    _selectedDeportivaPrincipal = newValue;
                    _agregarActividadDeportiva(newValue ?? '', 'Principal');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Deportiva Secundaria",
                _selectedDeportivaSecundaria,
                _actividadesDeportivasOpciones,
                Icons.sports_baseball,
                (newValue) {
                  setState(() {
                    _selectedDeportivaSecundaria = newValue;
                    _agregarActividadDeportiva(newValue ?? '', 'Secundaria');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Deportiva Terciaria",
                _selectedDeportivaTerciaria,
                _actividadesDeportivasOpciones,
                Icons.sports_tennis,
                (newValue) {
                  setState(() {
                    _selectedDeportivaTerciaria = newValue;
                    _agregarActividadDeportiva(newValue ?? '', 'Terciaria');
                  });
                },
              ),
            ] else
              _buildStaticListInfo("Actividades Deportivas", _actividadesDeportivasUsuario, Icons.sports),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: ACTIVIDADES DE OCIO
            _buildSectionHeader("Actividades de Ocio"),
            if (editing) ...[
              _buildMultiSelectDropdown(
                "Ocio Principal",
                _selectedOcioPrincipal,
                _actividadesOcioOpciones,
                Icons.local_bar,
                (newValue) {
                  setState(() {
                    _selectedOcioPrincipal = newValue;
                    _agregarActividadOcio(newValue ?? '', 'Principal');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Ocio Secundaria",
                _selectedOcioSecundaria,
                _actividadesOcioOpciones,
                Icons.restaurant,
                (newValue) {
                  setState(() {
                    _selectedOcioSecundaria = newValue;
                    _agregarActividadOcio(newValue ?? '', 'Secundaria');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Ocio Terciaria",
                _selectedOcioTerciaria,
                _actividadesOcioOpciones,
                Icons.games,
                (newValue) {
                  setState(() {
                    _selectedOcioTerciaria = newValue;
                    _agregarActividadOcio(newValue ?? '', 'Terciaria');
                  });
                },
              ),
            ] else
              _buildStaticListInfo("Actividades de Ocio", _actividadesOcioUsuario, Icons.local_bar),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: ACTIVIDADES CULTURALES
            _buildSectionHeader("Actividades Culturales"),
            if (editing) ...[
              _buildMultiSelectDropdown(
                "Cultural Principal",
                _selectedCulturalPrincipal,
                _actividadesCulturalesOpciones,
                Icons.palette,
                (newValue) {
                  setState(() {
                    _selectedCulturalPrincipal = newValue;
                    _agregarActividadCultural(newValue ?? '', 'Principal');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Cultural Secundaria",
                _selectedCulturalSecundaria,
                _actividadesCulturalesOpciones,
                Icons.music_note,
                (newValue) {
                  setState(() {
                    _selectedCulturalSecundaria = newValue;
                    _agregarActividadCultural(newValue ?? '', 'Secundaria');
                  });
                },
              ),
              _buildMultiSelectDropdown(
                "Cultural Terciaria",
                _selectedCulturalTerciaria,
                _actividadesCulturalesOpciones,
                Icons.theater_comedy,
                (newValue) {
                  setState(() {
                    _selectedCulturalTerciaria = newValue;
                    _agregarActividadCultural(newValue ?? '', 'Terciaria');
                  });
                },
              ),
            ] else
              _buildStaticListInfo("Actividades Culturales", _actividadesCulturalesUsuario, Icons.palette),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: INSTITUCIÓN DE EMERGENCIA
            _buildSectionHeader("Institución de Emergencia"),
            _buildField(
              "En caso de emergencia urgente a qué institución se canaliza",
              _institucionEmergenciaController,
              editing,
              Icons.local_hospital,
            ),

            const SizedBox(height: 24),

            // NUEVA SECCIÓN: TÉRMINOS Y CONDICIONES
            _buildSectionHeader("Términos y Condiciones"),
            if (editing) ...[
              _buildCheckboxField(
                "Aviso de Privacidad",
                _avisoPrivacidad,
                Icons.privacy_tip,
                (newValue) {
                  setState(() {
                    _avisoPrivacidad = newValue ?? false;
                  });
                },
              ),
              _buildCheckboxField(
                "Reglamento del Club",
                _reglamentoAceptado,
                Icons.gavel,
                (newValue) {
                  setState(() {
                    _reglamentoAceptado = newValue ?? false;
                  });
                },
              ),
              _buildCheckboxField(
                "Términos de Emergencia",
                _terminosEmergencia,
                Icons.medical_services,
                (newValue) {
                  setState(() {
                    _terminosEmergencia = newValue ?? false;
                  });
                },
              ),
            ] else ...[
              if (_avisoPrivacidad) _buildStaticInfo("Aviso de Privacidad", "Aceptado", Icons.privacy_tip),
              if (_reglamentoAceptado) _buildStaticInfo("Reglamento del Club", "Aceptado", Icons.gavel),
              if (_terminosEmergencia) _buildStaticInfo("Términos de Emergencia", "Aceptado", Icons.medical_services),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // NUEVO MÉTODO PARA CAMPOS EN MAYÚSCULAS
  Widget _buildUppercaseField(
    String label,
    TextEditingController controller,
    bool editable,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: editable
          ? TextFormField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                UpperCaseTextFormatter(),
              ],
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(fontSize: 16),
              ),
            )
          : _buildStaticInfo(
              label,
              controller.text.isNotEmpty ? controller.text : "No especificado",
              icon,
            ),
    );
  }

  Widget _buildAlcaldiaDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _selectedAlcaldia,
        decoration: InputDecoration(
          labelText: "Alcaldía/Municipio",
          prefixIcon: const Icon(Icons.account_balance),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _loadingAlcaldias
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 28),
        iconSize: 28,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        items: _alcaldiasOpciones.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                value,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
        onChanged: _onAlcaldiaChanged,
      ),
    );
  }

  Widget _buildColoniaDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        isExpanded: true,
        initialValue: _selectedColonia,
        decoration: InputDecoration(
          labelText: "Colonia",
          prefixIcon: const Icon(Icons.home),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _loadingColonias
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 28),
        iconSize: 28,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        items: _coloniasOpciones.map((Map<String, dynamic> colonia) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: colonia,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    colonia['colonia'] ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    "CP: ${colonia['cp'] ?? ''}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: _onColoniaChanged,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? selectedValue,
    List<String> options,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selectedValue,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 28),
        iconSize: 28,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                value,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMultiSelectDropdown(
    String label,
    String? selectedValue,
    List<String> options,
    IconData icon,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selectedValue?.isEmpty ?? true ? null : selectedValue,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          labelStyle: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 28),
        iconSize: 28,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Seleccionar',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          })
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckboxField(
    String label,
    bool value,
    IconData icon,
    ValueChanged<bool?> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16),
        ),
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1976D2)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                fontSize: 14,
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
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticInfo(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D47A1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: "Montserrat",
                    color: Color(0xFF0D47A1),
                    fontSize: 14,
                  ),
                ),
                Text(
                  value.isNotEmpty ? value : "No especificado",
                  style: const TextStyle(fontFamily: "Montserrat", fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticListInfo(String label, List<String> items, IconData icon) {
    final displayItems = items.map((item) {
      final parts = item.split(':');
      return parts.length > 1 ? '${parts[0]}: ${parts[1]}' : item;
    }).toList();

    return _buildStaticInfo(
      label,
      displayItems.isNotEmpty ? displayItems.join('\n') : 'No especificado',
      icon,
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    bool editable,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: editable
          ? TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(fontSize: 16),
              ),
              style: const TextStyle(fontSize: 16),
            )
          : _buildStaticInfo(
              label,
              controller.text.isNotEmpty ? controller.text : "No especificado",
              icon,
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
            color: const Color(0x0D000000),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1976D2),
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

  String? _calcularEdad() {
    final fechaNacimiento = _fechaNacimientoController.text;
    if (fechaNacimiento.isEmpty) return null;
    try {
      final nacimiento = DateTime.parse(fechaNacimiento);
      final ahora = DateTime.now();
      final edad = ahora.year - nacimiento.year;
      final mesCumple =
          ahora.month > nacimiento.month ||
          (ahora.month == nacimiento.month && ahora.day >= nacimiento.day);
      return mesCumple ? edad.toString() : (edad - 1).toString();
    } catch (e) {
      _logger.e('Error calculando edad: $e');
      return null;
    }
  }

  String _getDireccionCompleta() {
    final calle = _calleController.text;
    final numero = _numeroController.text;
    if (calle.isEmpty && numero.isEmpty) return "No especificada";
    if (calle.isEmpty) return numero;
    if (numero.isEmpty) return calle;
    return "$calle $numero";
  }

  void _navigateToPage(int index) {
    if (index == _selectedIndex) return;
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(user: user!)),
        (route) => false,
      );
    } else if (index == 2) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SettingsPage(user: user!)),
        (route) => false,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      _logger.d('Iniciando selección de imagen');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        _logger.i('Imagen seleccionada: ${pickedFile.path}');
        setState(() => _newImage = File(pickedFile.path));
      }
    } catch (e) {
      _logger.e('Error al seleccionar imagen: $e');
    }
  }

  Widget _buildProfileImage() {
    if (_newImage != null) {
      return Image.file(_newImage!, fit: BoxFit.cover, width: 120, height: 120);
    } else if (user!['foto'] != null && user!['foto']!.isNotEmpty) {
      return Image.network(
        user!['foto']!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 60, color: Colors.grey);
        },
      );
    } else {
      return const Icon(Icons.person, size: 60, color: Colors.grey);
    }
  }

  Future<File> _corregirOrientacionImagen(File imageFile) async {
    return imageFile;
  }
}