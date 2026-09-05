import 'package:flutter/material.dart';
import 'dart:io';
import '../core/services/pacman_service.dart';

class PackageDetailView extends StatefulWidget {
  final String packageName;
  final bool isInstalled;

  const PackageDetailView({
    super.key, 
    required this.packageName, 
    required this.isInstalled,
  });

  @override
  State<PackageDetailView> createState() => _PackageDetailViewState();
}

class _PackageDetailViewState extends State<PackageDetailView> {
  bool _isLoading = true;
  Map<String, String> _packageInfo = {};

  @override
  void initState() {
    super.initState();
    _fetchPackageDetails();
  }

  Future<void> _fetchPackageDetails() async {
    try {
      final result = await Process.run('env', ['LC_ALL=C', 'yay', '-Si', widget.packageName]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        Map<String, String> info = {};
        String currentKey = '';

        for (var line in lines) {
          if ((line.startsWith('    ') || line.startsWith('\t')) && currentKey.isNotEmpty) {
            info[currentKey] = "${info[currentKey]} ${line.trim()}";
          } else if (line.contains(':')) {
            final parts = line.split(':');
            currentKey = parts[0].trim().toLowerCase();
            info[currentKey] = parts.sublist(1).join(':').trim();
          }
        }

        setState(() {
          _packageInfo = info;
          _isLoading = false;
        });
      } else {
        setState(() {
          _packageInfo = {'version': 'Installato'};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openUrl(String urlString) async {
    if (urlString.isEmpty || urlString == 'N/D') return;
    try {
      await Process.run('xdg-open', [urlString]);
    } catch (e) {
      // Ignora errori
    }
  }

  @override
  Widget build(BuildContext context) {
    String getVal(List<String> keys) {
      for (var k in keys) {
        if (_packageInfo.containsKey(k.toLowerCase())) {
          return _packageInfo[k.toLowerCase()]!;
        }
      }
      return 'N/D';
    }

    final version = getVal(['version']);
    final description = getVal(['description']);
    final url = getVal(['url']);
    final licenses = getVal(['licenses']);
    final depends = getVal(['depends on']);
    final makeDepends = getVal(['makedepends']);
    final votes = getVal(['votes']);
    final popularity = getVal(['popularity']);
    final maintainer = getVal(['maintainer']);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.packageName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Informazioni Pacchetto', style: Theme.of(context).textTheme.titleLarge),
                                    if (widget.isInstalled)
                                      Chip(
                                        avatar: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        label: const Text('Già Installato'),
                                        backgroundColor: Colors.green.shade50,
                                        labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                                const Divider(),
                                _buildInfoRow('Nome', widget.packageName),
                                _buildInfoRow('Versione', version),
                                _buildInfoRow('Descrizione', description),
                                _buildUrlRow('URL', url),
                                _buildInfoRow('Licenza', licenses),
                                _buildInfoRow('Dipendenze', depends),
                                if (makeDepends != 'N/D') _buildInfoRow('Dip. Compilazione', makeDepends),
                                _buildInfoRow('Voti AUR', votes),
                                _buildInfoRow('Popolarità', popularity),
                                _buildInfoRow('Maintainer', maintainer.isEmpty ? 'Orfano / Ufficiale' : maintainer),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  widget.isInstalled
                      ? FilledButton.icon(
                          onPressed: () => _promptPasswordAndAction(context, isRemoval: true),
                          icon: const Icon(Icons.delete_outline),
                          label: Text('Disinstalla ${widget.packageName}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: () => _promptPasswordAndAction(context, isRemoval: false),
                          icon: const Icon(Icons.download_rounded),
                          label: Text('Installa ${widget.packageName}'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildUrlRow(String label, String value) {
    bool isLink = value.startsWith('http://') || value.startsWith('https://');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(
            child: InkWell(
              onTap: isLink ? () => _openUrl(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  color: isLink ? Colors.blue : Colors.black,
                  decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _promptPasswordAndAction(BuildContext context, {required bool isRemoval}) {
    final TextEditingController passwordController = TextEditingController();
    final actionName = isRemoval ? 'disinstallare' : 'installare';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autenticazione richiesta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inserisci la password di root per $actionName "${widget.packageName}".'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (value) {
                Navigator.pop(context);
                _showActionDialog(context, value, isRemoval: isRemoval);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showActionDialog(context, passwordController.text, isRemoval: isRemoval);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showActionDialog(BuildContext context, String password, {required bool isRemoval}) {
    List<String> logs = [];
    final ScrollController scrollController = ScrollController();
    String title = isRemoval ? 'Disinstallazione di ${widget.packageName}' : 'Installazione di ${widget.packageName}';

    void scrollToBottom() {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (logs.isEmpty) {
            Future<bool> actionFuture = isRemoval 
                ? PacmanService.removePackage(widget.packageName, password, (log) {
                    setDialogState(() {
                      logs.add(log.trim());
                      if (logs.length > 100) logs.removeAt(0);
                    });
                    Future.delayed(const Duration(milliseconds: 50), scrollToBottom);
                  })
                : PacmanService.installPackage(widget.packageName, password, (log) {
                    setDialogState(() {
                      logs.add(log.trim());
                      if (logs.length > 100) logs.removeAt(0);
                    });
                    Future.delayed(const Duration(milliseconds: 50), scrollToBottom);
                  });

            actionFuture.then((success) {
              if (success) {
                setDialogState(() {
                  logs.add(isRemoval ? "==> Disinstallazione completata con successo!" : "==> Installazione completata con successo!");
                });
              }
            });
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 500,
              height: 250,
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) => Text(
                          logs[index],
                          style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }
}