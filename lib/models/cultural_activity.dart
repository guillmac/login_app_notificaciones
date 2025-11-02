class CulturalActivity {
  final int id;
  final String nombreActividad;
  final String lugar;
  final String profesor;
  final String celular;
  final String horario;
  final String avisos;
  final String facebook;
  final String categoria;
  final String status;
  final List<String> grupos;
  final List<String> horarios;
  final List<String> diasSemana;

  CulturalActivity({
    required this.id,
    required this.nombreActividad,
    required this.lugar,
    required this.profesor,
    required this.celular,
    required this.horario,
    required this.avisos,
    required this.facebook,
    required this.categoria,
    required this.status,
    required this.grupos,
    required this.horarios,
    required this.diasSemana,
  });

  factory CulturalActivity.fromJson(Map<String, dynamic> json) {
    // Recoger todos los grupos no vacíos (grupo1 a grupo6)
    final grupos = <String>[];
    for (int i = 1; i <= 6; i++) {
      final grupo = json['grupo$i']?.toString();
      if (grupo != null && 
          grupo.isNotEmpty && 
          grupo != 'null' && 
          grupo.toLowerCase() != 'n/a') {
        grupos.add(grupo);
      }
    }

    // Recoger todos los horarios no vacíos (horario_grupo1 a horario_grupo28)
    final horarios = <String>[];
    for (int i = 1; i <= 28; i++) {
      final horario = json['horario_grupo$i']?.toString();
      if (horario != null && 
          horario.isNotEmpty && 
          horario != 'null' && 
          horario.toLowerCase() != 'n/a') {
        horarios.add(horario);
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

    return CulturalActivity(
      id: parseId(json['id']),
      nombreActividad: json['nombre_actividad']?.toString() ?? '',
      lugar: json['lugar']?.toString() ?? '',
      profesor: json['profesor']?.toString() ?? '',
      celular: json['celular']?.toString() ?? '',
      horario: json['horario']?.toString() ?? '',
      avisos: json['avisos']?.toString() ?? '',
      facebook: json['facebook']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      grupos: grupos,
      horarios: horarios,
      diasSemana: diasSemana,
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
    if (horarios.isNotEmpty) {
      return horarios.join('\n');
    }
    
    // Si no hay horarios específicos, usar el horario general
    if (horario.isNotEmpty && horario.toLowerCase() != 'n/a') {
      return horario;
    }
    
    return 'Por confirmar';
  }

  // Verificar si tiene información de días
  bool get tieneDias => diasSemana.isNotEmpty;

  // Verificar si tiene información de horarios
  bool get tieneHorarios => horarios.isNotEmpty || 
                          (horario.isNotEmpty && horario.toLowerCase() != 'n/a');

  bool get isInfantil => categoria.toLowerCase().contains('infantil');
  bool get isAdulto => categoria.toLowerCase().contains('adulto');

  String get tipo {
    if (isInfantil) return 'infantil';
    if (isAdulto) return 'adulto';
    return 'general';
  }
}