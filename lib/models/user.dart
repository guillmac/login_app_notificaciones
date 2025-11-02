class User {
  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final String fechaNacimiento;
  final int edad;
  final String direccion;

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.fechaNacimiento,
    required this.edad,
    required this.direccion,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'apellido': apellido,
    'email': email,
    'fechaNacimiento': fechaNacimiento,
    'edad': edad,
    'direccion': direccion,
  };

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'],
    nombre: map['nombre'],
    apellido: map['apellido'],
    email: map['email'],
    fechaNacimiento: map['fechaNacimiento'],
    edad: map['edad'],
    direccion: map['direccion'],
  );
}
