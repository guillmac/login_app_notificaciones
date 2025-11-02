import 'package:flutter/material.dart';

class NoticiasPage extends StatelessWidget {
  const NoticiasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Noticias')),
      body: const Center(
        child: Text(
          'Últimas noticias del club',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
