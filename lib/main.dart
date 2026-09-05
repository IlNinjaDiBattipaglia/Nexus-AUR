import 'package:flutter/material.dart';
import 'core/services/system_service.dart';
import 'views/home_view.dart';
import 'views/setup_yay_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Controlla se yay è installato all'avvio
  bool yayExists = await SystemService.isYayInstalled();

  runApp(NexusAurApp(initialRoute: yayExists ? '/' : '/setup'));
}

class NexusAurApp extends StatelessWidget {
  final String initialRoute;
  
  const NexusAurApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus AUR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Tema scuro nativo molto apprezzato su Linux
        ),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => HomeView(),
        '/setup': (context) => const SetupYayView(),
      },
    );
  }
}
