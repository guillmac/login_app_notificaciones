class SportActivity {
  final int id;
  final String nombreActividad;
  final String lugar;
  final String edad;
  final String nombreProfesor;
  final String categoria;
  final String status;
  final String avisos;
  final List<String> grupos;
  final List<String> horarios;
  final List<String> costosMensuales;
  final List<String> diasSemana; // Solo dia1 a dia7
  final String? celular;
  final String? costoClase;

  SportActivity({
    required this.id,
    required this.nombreActividad,
    required this.lugar,
    required this.edad,
    required this.nombreProfesor,
    required this.categoria,
    required this.status,
    required this.avisos,
    required this.grupos,
    required this.horarios,
    required this.costosMensuales,
    required this.diasSemana,
    this.celular,
    this.costoClase,
  });

  factory SportActivity.fromJson(Map<String, dynamic> json) {
    // Recoger todos los grupos no vacíos (grupo1 a grupo6)
    final grupos = <String>[];
    for (int i = 1; i <= 6; i++) {
      final grupo = json['grupo$i']?.toString();
      if (grupo != null && grupo.isNotEmpty && grupo != 'null' && grupo.toLowerCase() != 'n/a') {
        grupos.add(grupo);
      }
    }

    // Recoger todos los horarios no vacíos (horario_grupo1 a horario_grupo28)
    final horarios = <String>[];
    for (int i = 1; i <= 28; i++) {
      final horario = json['horario_grupo$i']?.toString();
      if (horario != null && horario.isNotEmpty && horario != 'null' && horario.toLowerCase() != 'n/a') {
        horarios.add(horario);
      }
    }

    // Recoger todos los costos mensuales no vacíos
    final costosMensuales = <String>[];
    for (int i = 1; i <= 9; i++) {
      final costo = json['costo_mensual_paquete$i']?.toString();
      if (costo != null && costo.isNotEmpty && costo != 'null' && costo.toLowerCase() != 'n/a') {
        costosMensuales.add(costo);
      }
    }

    // Recoger todos los días de la semana no vacíos (dia1 a dia7) - IGNORANDO "n/a"
    final diasSemana = <String>[];
    for (int i = 1; i <= 7; i++) {
      final dia = json['dia$i']?.toString();
      if (dia != null && 
          dia.isNotEmpty && 
          dia != 'null' && 
          dia.toLowerCase() != 'n/a' &&
          dia.toLowerCase() != 'na' &&
          dia.trim().isNotEmpty) {
        diasSemana.add(dia);
      }
    }

    // Convertir el ID a int, manejando el caso donde viene como String
    int parseId(dynamic idValue) {
      if (idValue == null) return 0;
      if (idValue is int) return idValue;
      if (idValue is String) {
        return int.tryParse(idValue) ?? 0;
      }
      return 0;
    }

    return SportActivity(
      id: parseId(json['id']),
      nombreActividad: json['nombre_actividad']?.toString() ?? '',
      lugar: json['lugar']?.toString() ?? '',
      edad: json['edad']?.toString() ?? '',
      nombreProfesor: json['nombre_profesor']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      avisos: json['avisos']?.toString() ?? '',
      grupos: grupos,
      horarios: horarios,
      costosMensuales: costosMensuales,
      diasSemana: diasSemana,
      celular: json['celular']?.toString(),
      costoClase: json['costo_clase']?.toString(),
    );
  }

  // Método para obtener los días formateados - SOLO usa diasSemana (dia1-dia7)
  String get diasFormateados {
    if (diasSemana.isNotEmpty) {
      return diasSemana.join(', ');
    }
    return 'Por confirmar';
  }

  // Método para obtener horarios formateados
  String get horariosFormateados {
    if (horarios.isEmpty) return 'Por confirmar';
    
    // Si hay grupos específicos con horarios, mostrarlos
    if (grupos.isNotEmpty && grupos.length == horarios.length) {
      final horariosConGrupos = <String>[];
      for (int i = 0; i < grupos.length; i++) {
        if (i < horarios.length) {
          horariosConGrupos.add('${grupos[i]}: ${horarios[i]}');
        }
      }
      return horariosConGrupos.join('\n');
    }
    
    // Si no, mostrar todos los horarios
    return horarios.join('\n');
  }

  // Verificar si tiene información de días
  bool get tieneDias => diasSemana.isNotEmpty;

  bool get isInfantil => categoria.toLowerCase().contains('infantil');
  bool get isAdulto => categoria.toLowerCase().contains('adulto');

  String get tipo {
    if (isInfantil) return 'infantil';
    if (isAdulto) return 'adulto';
    return 'general';
  }
}