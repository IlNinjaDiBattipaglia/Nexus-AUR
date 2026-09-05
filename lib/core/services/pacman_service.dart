import 'dart:convert';
import 'dart:io';

class PackageModel {
  final String name;
  final String version;
  final String description;
  final bool isAur;
  
  PackageModel({
    required this.name,
    required this.version,
    required this.description,
    required this.isAur,
  });
}

class PacmanService {
  
  // Ricerca robusta: interroga pacman (ufficiali) e yay (AUR) separatamente e unisce i risultati
  static Future<List<PackageModel>> searchPackages(String query) async {
    if (query.trim().isEmpty) return [];

    List<PackageModel> packages = [];
    Set<String> addedNames = {};

    try {
      final pacmanResult = await Process.run('pacman', ['-Ss', query]);
      if (pacmanResult.exitCode == 0) {
        final officialPkgs = _parseSearchOutput(pacmanResult.stdout.toString(), isAur: false);
        for (var pkg in officialPkgs) {
          if (addedNames.add(pkg.name)) {
            packages.add(pkg);
          }
        }
      }

      final yayResult = await Process.run('yay', ['-Ss', '--aur', query]);
      if (yayResult.exitCode == 0) {
        final aurPkgs = _parseSearchOutput(yayResult.stdout.toString(), isAur: true);
        for (var pkg in aurPkgs) {
          if (addedNames.add(pkg.name)) {
            packages.add(pkg);
          }
        }
      }
    } catch (e) {
      // Gestione errori
    }

    return packages;
  }

  // Ottiene la lista di tutti i pacchetti installati (ufficiali + AUR)
  static Future<List<PackageModel>> getInstalledPackages() async {
    List<PackageModel> installed = [];
    try {
      // Identifica i pacchetti AUR (foreign packages)
      final foreignResult = await Process.run('yay', ['-Qm']);
      Set<String> aurPackages = {};
      if (foreignResult.exitCode == 0) {
        for (var line in foreignResult.stdout.toString().split('\n')) {
          if (line.trim().isEmpty) continue;
          var parts = line.split(RegExp(r'\s+'));
          if (parts.isNotEmpty) aurPackages.add(parts[0]);
        }
      }

      // Ottiene tutti i pacchetti installati nel sistema
      final result = await Process.run('pacman', ['-Q']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
        for (var line in output.split('\n')) {
          if (line.trim().isEmpty) continue;
          var parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            String name = parts[0];
            String version = parts[1];
            bool isAur = aurPackages.contains(name);
            installed.add(PackageModel(
              name: name,
              version: version,
              description: isAur ? 'Pacchetto AUR installato' : 'Pacchetto ufficiale installato',
              isAur: isAur,
            ));
          }
        }
      }
    } catch (e) {
      // Gestione errori
    }
    return installed;
  }

  // Ottiene la lista degli aggiornamenti
  static Future<List<PackageModel>> getUpdates() async {
    List<PackageModel> updates = [];
    try {
      final result = await Process.run('yay', ['-Qu']);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
        for (var line in output.split('\n')) {
          if (line.trim().isEmpty) continue;
          var parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            updates.add(PackageModel(
              name: parts[0],
              version: "${parts[1]} -> ${parts[3]}",
              description: "Aggiornamento disponibile",
              isAur: true,
            ));
          }
        }
      }
    } catch (e) {
      // Gestione errori
    }
    return updates;
  }

  static Future<bool> installPackage(String packageName, String sudoPassword, Function(String log) onLog) async {
    return _runWithSudo(['-S', '--noconfirm', '--needed', packageName], sudoPassword, onLog);
  }

  static Future<bool> upgradeSinglePackage(String packageName, String sudoPassword, Function(String log) onLog) async {
    return _runWithSudo(['-S', '--noconfirm', packageName], sudoPassword, onLog);
  }

  static Future<bool> upgradeSystem(String sudoPassword, Function(String log) onLog) async {
    return _runWithSudo(['-Syu', '--noconfirm'], sudoPassword, onLog);
  }

  static Future<bool> removePackage(String packageName, String sudoPassword, Function(String log) onLog) async {
    return _runWithSudo(['-Rns', '--noconfirm', packageName], sudoPassword, onLog);
  }

  static Future<bool> _runWithSudo(List<String> args, String sudoPassword, Function(String log) onLog) async {
    try {
      final sudoProcess = await Process.start('sudo', ['-S', 'true']);
      sudoProcess.stdin.writeln(sudoPassword);
      await sudoProcess.stdin.flush();
      await sudoProcess.stdin.close();

      final sudoExitCode = await sudoProcess.exitCode;
      if (sudoExitCode != 0) {
        onLog("Errore: Password di root errata o permessi negati.");
        return false;
      }

      final process = await Process.start('yay', args);

      process.stdout.transform(utf8.decoder).listen(onLog);
      process.stderr.transform(utf8.decoder).listen(onLog);

      final exitCode = await process.exitCode;
      return exitCode == 0;
    } catch (e) {
      onLog("Errore di esecuzione: $e");
      return false;
    }
  }

  static List<PackageModel> _parseSearchOutput(String rawOutput, {required bool isAur}) {
    final output = rawOutput.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
    List<PackageModel> list = [];
    final lines = output.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      if (!lines[i].startsWith('    ') && !lines[i].startsWith('\t') && line.contains(' ')) {
        String header = line;
        String desc = '';
        
        if (i + 1 < lines.length && (lines[i + 1].startsWith('    ') || lines[i + 1].startsWith('\t'))) {
          desc = lines[i + 1].trim();
          i++;
        }

        var parts = header.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          String fullName = parts[0];
          String name = fullName.contains('/') ? fullName.split('/')[1] : fullName;
          String version = parts.length > 1 ? parts[1] : '';

          if (name.isNotEmpty) {
            list.add(PackageModel(
              name: name,
              version: version,
              description: desc,
              isAur: isAur,
            ));
          }
        }
      }
    }
    
    return list;
  }
}