import 'package:flutter/material.dart';
import '../core/services/pacman_service.dart';
import 'package_detail_view.dart';

class HomeView extends StatefulWidget {
  HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<PackageModel> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<PackageModel> _updates = [];
  bool _isLoadingUpdates = false;
  final Map<String, String> _packageErrors = {};

  List<PackageModel> _installedPackages = [];
  bool _isLoadingInstalled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadUpdates(),
      _loadInstalledPackages(),
    ]);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await PacmanService.searchPackages(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _loadUpdates() async {
    setState(() => _isLoadingUpdates = true);
    final updates = await PacmanService.getUpdates();
    setState(() {
      _updates = updates;
      _isLoadingUpdates = false;
    });
  }

  Future<void> _loadInstalledPackages() async {
    setState(() => _isLoadingInstalled = true);
    final installed = await PacmanService.getInstalledPackages();
    setState(() {
      _installedPackages = installed;
      _isLoadingInstalled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexus AUR'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.search), text: 'Cerca'),
            Tab(
              icon: Badge(
                isLabelVisible: _updates.isNotEmpty,
                label: Text('${_updates.length}'),
                child: const Icon(Icons.system_update),
              ), 
              text: 'Aggiornamenti',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _installedPackages.isNotEmpty,
                label: Text('${_installedPackages.length}'),
                child: const Icon(Icons.inventory_2_outlined),
              ),
              text: 'Installati',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: RICERCA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cerca tra pacman (ufficiali) e AUR...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onSubmitted: _performSearch,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? const Center(child: Text('Nessun pacchetto trovato o ricerca vuota'))
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final pkg = _searchResults[index];
                                final isInstalled = _installedPackages.any((p) => p.name == pkg.name);

                                return Card(
                                  elevation: 0,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(pkg.isAur ? 'AUR' : 'Ufficiale'),
                                          backgroundColor: pkg.isAur ? Colors.orange.shade100 : Colors.blue.shade100,
                                          labelStyle: TextStyle(fontSize: 10, color: pkg.isAur ? Colors.orange.shade900 : Colors.blue.shade900),
                                          padding: EdgeInsets.zero,
                                        ),
                                        if (isInstalled) ...[
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: const Text('Installato'),
                                            backgroundColor: Colors.green.shade100,
                                            labelStyle: TextStyle(fontSize: 10, color: Colors.green.shade900),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text('${pkg.version}\n${pkg.description}'),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PackageDetailView(
                                            packageName: pkg.name,
                                            isInstalled: isInstalled,
                                          ),
                                        ),
                                      );
                                      _loadAllData();
                                    },
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // TAB 2: AGGIORNAMENTI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Disponibili: ${_updates.length}', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoadingUpdates ? null : _loadAllData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Verifica'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _updates.isEmpty ? null : () {
                            _promptPasswordAndExecuteForBatch(
                              title: 'Report Aggiornamento di Sistema',
                            );
                          },
                          icon: const Icon(Icons.update),
                          label: const Text('Aggiorna Tutto'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingUpdates
                      ? const Center(child: CircularProgressIndicator())
                      : _updates.isEmpty
                          ? const Center(child: Text('Il sistema è perfettamente aggiornato!'))
                          : ListView.builder(
                              itemCount: _updates.length,
                              itemBuilder: (context, index) {
                                final update = _updates[index];
                                final hasError = _packageErrors.containsKey(update.name);
                                
                                return ListTile(
                                  title: Text(update.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(update.version),
                                      if (hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            'Errore: ${_packageErrors[update.name]}',
                                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                    ],
                                  ),
                                  isThreeLine: hasError,
                                  trailing: OutlinedButton(
                                    onPressed: () {
                                      _promptPasswordAndExecute(
                                        title: 'Aggiornamento di ${update.name}',
                                        singleAction: (password, onLog) {
                                          setState(() => _packageErrors.remove(update.name));
                                          return PacmanService.upgradeSinglePackage(update.name, password, onLog);
                                        },
                                      );
                                    },
                                    child: const Text('Aggiorna'),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // TAB 3: INSTALLATI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Installati nel sistema: ${_installedPackages.length}', style: Theme.of(context).textTheme.titleMedium),
                    OutlinedButton.icon(
                      onPressed: _isLoadingInstalled ? null : _loadAllData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Aggiorna Lista'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingInstalled
                      ? const Center(child: CircularProgressIndicator())
                      : _installedPackages.isEmpty
                          ? const Center(child: Text('Nessun pacchetto trovato'))
                          : ListView.builder(
                              itemCount: _installedPackages.length,
                              itemBuilder: (context, index) {
                                final pkg = _installedPackages[index];
                                return Card(
                                  elevation: 0,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(pkg.isAur ? 'AUR' : 'Ufficiale'),
                                          backgroundColor: pkg.isAur ? Colors.orange.shade100 : Colors.blue.shade100,
                                          labelStyle: TextStyle(fontSize: 10, color: pkg.isAur ? Colors.orange.shade900 : Colors.blue.shade900),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    subtitle: Text('Versione: ${pkg.version}'),
                                    trailing: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PackageDetailView(
                                              packageName: pkg.name,
                                              isInstalled: true,
                                            ),
                                          ),
                                        ).then((_) => _loadAllData());
                                      },
                                      icon: const Icon(Icons.info_outline, size: 16),
                                      label: const Text('Dettagli'),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _promptPasswordAndExecute({
    required String title,
    required Future<bool> Function(String password, Function(String log) onLog) singleAction,
  }) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autenticazione richiesta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inserisci la password di root (sudo) per: "$title".'),
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
                _showActionDialog(title: title, password: value, singleAction: singleAction);
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
              _showActionDialog(title: title, password: passwordController.text, singleAction: singleAction);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _promptPasswordAndExecuteForBatch({required String title}) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autenticazione richiesta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inserisci la password di root per eseguire l\'aggiornamento di tutti i pacchetti.'),
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
                _showBatchReportDialog(title: title, password: value);
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
              _showBatchReportDialog(title: title, password: passwordController.text);
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showActionDialog({
    required String title,
    required String password,
    required Future<bool> Function(String password, Function(String log) onLog) singleAction,
  }) {
    List<String> logs = [];
    final ScrollController scrollController = ScrollController();

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
            singleAction(password, (log) {
              setDialogState(() {
                logs.add(log.trim());
                if (logs.length > 100) logs.removeAt(0);
              });
              Future.delayed(const Duration(milliseconds: 50), scrollToBottom);
            }).then((success) {
              _loadAllData();
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
                onPressed: () {
                  Navigator.pop(context);
                  _loadAllData();
                },
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBatchReportDialog({required String title, required String password}) {
    bool isProcessing = true;
    final Map<String, String> packageStatuses = {};
    final Map<String, String> packageErrorMessages = {};
    
    for (var pkg in _updates) {
      packageStatuses[pkg.name] = 'pending';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isProcessing && packageStatuses.values.every((status) => status == 'pending' || packageStatuses.values.any((s) => s == 'in_progress'))) {
            Future.microtask(() async {
              final listToUpdate = List<PackageModel>.from(_updates);

              for (var pkg in listToUpdate) {
                setDialogState(() {
                  packageStatuses[pkg.name] = 'in_progress';
                });

                String currentError = "";

                bool success = await PacmanService.upgradeSinglePackage(
                  pkg.name, 
                  password, 
                  (logLine) {
                    if (logLine.toLowerCase().contains('errore') || logLine.toLowerCase().contains('error')) {
                      currentError = logLine.trim();
                    }
                  },
                );

                setDialogState(() {
                  if (success) {
                    packageStatuses[pkg.name] = 'success';
                    _packageErrors.remove(pkg.name);
                  } else {
                    packageStatuses[pkg.name] = 'failed';
                    if (currentError.isEmpty) currentError = "Errore durante la compilazione o l'installazione";
                    packageErrorMessages[pkg.name] = currentError;
                    _packageErrors[pkg.name] = currentError;
                  }
                });
              }

              setDialogState(() {
                isProcessing = false;
              });
              
              _loadAllData();
            });
          }

          int successCount = packageStatuses.values.where((s) => s == 'success').length;
          int failCount = packageStatuses.values.where((s) => s == 'failed').length;
          int totalCount = _updates.length;
          int completedCount = successCount + failCount;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isProcessing ? Icons.sync : Icons.assignment_turned_in_rounded,
                  color: isProcessing ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 12),
                Text(title),
              ],
            ),
            content: SizedBox(
              width: 550,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProcessing) ...[
                    LinearProgressIndicator(value: totalCount > 0 ? completedCount / totalCount : null),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Completati: $completedCount / $totalCount'),
                      Row(
                        children: [
                          if (successCount > 0)
                            Chip(
                              avatar: const Icon(Icons.check, size: 14, color: Colors.green),
                              label: Text('$successCount Riusciti'),
                              backgroundColor: Colors.green.shade50,
                              labelStyle: const TextStyle(color: Colors.green, fontSize: 11),
                            ),
                          const SizedBox(width: 8),
                          if (failCount > 0)
                            Chip(
                              avatar: const Icon(Icons.close, size: 14, color: Colors.red),
                              label: Text('$failCount Falliti'),
                              backgroundColor: Colors.red.shade50,
                              labelStyle: const TextStyle(color: Colors.red, fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final pkg = _updates[index];
                        final status = packageStatuses[pkg.name] ?? 'pending';
                        
                        Widget statusIcon;

                        if (status == 'pending') {
                          statusIcon = const Icon(Icons.hourglass_empty, color: Colors.grey, size: 20);
                        } else if (status == 'in_progress') {
                          statusIcon = const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        } else if (status == 'success') {
                          statusIcon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
                        } else {
                          statusIcon = const Icon(Icons.error, color: Colors.red, size: 20);
                        }

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: statusIcon,
                            title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: status == 'failed' 
                                ? Text(
                                    packageErrorMessages[pkg.name] ?? 'Errore sconosciuto',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                  )
                                : Text(pkg.version, style: const TextStyle(fontSize: 11)),
                            trailing: Text(
                              status == 'pending' ? 'In attesa' :
                              status == 'in_progress' ? 'Aggiornamento...' :
                              status == 'success' ? 'Completato' : 'Fallito',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status == 'success' ? Colors.green :
                                       status == 'failed' ? Colors.red : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: isProcessing ? null : () {
                  Navigator.pop(context);
                  _loadAllData();
                },
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }
}