import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class SetupYayView extends StatefulWidget {
  const SetupYayView({super.key});

  @override
  State<SetupYayView> createState() => _SetupYayViewState();
}

class _SetupYayViewState extends State<SetupYayView> {
  bool _isInstalling = false;
  String _statusMessage = 'Per utilizzare Nexus AUR è necessario installare "yay" (AUR helper).';
  List<String> _logs = [];

  Future<void> _startYayInstallation() async {
    setState(() {
      _isInstalling = true;
      _statusMessage = 'Preparazione dell\'ambiente...';
      _logs.clear();
    });

    try {
      final tempDir = Directory.systemTemp.createTempSync('nexus_yay_install_');
      
      _addLog('Clonazione di yay-bin in corso...');
      setState(() => _statusMessage = 'Clonazione del repository yay-bin...');

      final cloneResult = await Process.run('git', ['clone', 'https://aur.archlinux.org/yay-bin.git', tempDir.path]);
      
      if (cloneResult.exitCode != 0) {
        throw Exception('Errore durante il git clone: ${cloneResult.stderr}');
      }

      _addLog('Clonazione completata. Avvio della compilazione (makepkg)...');
      setState(() => _statusMessage = 'Compilazione e installazione del pacchetto...');

      final process = await Process.start(
        'makepkg',
        ['-si', '--noconfirm'],
        workingDirectory: tempDir.path,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        _addLog(data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _addLog(data);
      });

      final exitCode = await process.exitCode;

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}

      if (exitCode == 0) {
        setState(() {
          _statusMessage = 'Yay installato con successo! Riavvio dell\'app...';
        });
        await Future.delayed(const Duration(seconds: 2));
      } else {
        throw Exception('Processo di makepkg terminato con codice d\'errore: $exitCode');
      }

    } catch (e) {
      setState(() {
        _isInstalling = false;
        _statusMessage = 'Errore durante l\'installazione di yay.';
        _addLog('ERRORE: $e');
      });
    }
  }

  void _addLog(String log) {
    setState(() {
      _logs.add(log.trim());
      if (_logs.length > 50) _logs.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.rocket_launch_rounded, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Benvenuto in Nexus AUR',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isInstalling) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_isInstalling)
                FilledButton.icon(
                  onPressed: _startYayInstallation,
                  icon: const Icon(Icons.download_done_rounded),
                  label: const Text('Installa Yay Automaticamente'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
