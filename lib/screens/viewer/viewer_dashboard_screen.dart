import 'package:flutter/material.dart';

class ViewerDashboardScreen extends StatelessWidget {
  const ViewerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viewer Dashboard'),
      ),
      body: const Center(
        child: Text('Viewer Dashboard'),
      ),
    );
  }
}