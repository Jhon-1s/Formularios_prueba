import 'package:flutter/material.dart';

class FormulariosScreen extends StatelessWidget {
  const FormulariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Próximamente...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            'Lista de formularios disponibles',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}