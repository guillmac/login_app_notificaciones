import 'package:flutter/material.dart';

class ContactoPage extends StatelessWidget {
  const ContactoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacto')),
      body: const Center(
        child: Text(
          'Teléfonos, WhatsApp y ubicación',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
