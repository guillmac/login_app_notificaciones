import 'package:flutter/material.dart';

class EntrenadoresPage extends StatelessWidget {
  const EntrenadoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenadores')),
      body: const Center(
        child: Text(
          'Directorio de entrenadores con especialidad y horarios',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
