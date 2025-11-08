import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:task_manager_app/login_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/storage_service.dart';

// Importăm paginile noi și widget-urile separate
import 'package:task_manager_app/create_task_page.dart';
import 'package:task_manager_app/task_details_page.dart';
import 'package:task_manager_app/group_details_page.dart';
// import 'package:task_manager_app/widgets/delegation_chain_widget.dart';

//############################################################################
// PASUL 1: DEFINIM TOATE WIDGET-URILE "ECRAN"
//############################################################################

// --- ECRANUL 1: ACASĂ (SARCINI) ---
// --- ECRANUL 1: ACASĂ (SARCINI) ---
class _TasksScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String currentUsername; // Necesar pentru DelegationChainWidget

  const _TasksScreen({
    super.key,
    required this.apiClient,
    required this.currentUsername,
  });

  @override
  State<_TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<_TasksScreen> {
  late Future<List<dynamic>> _tasksFuture;
  String _selectedFilter = 'all';

  // O listă pentru a ține evidența sarcinilor care se încarcă
  final Set<String> _loadingTaskIds = {};

  @override
  void initState() {
    super.initState();
    _tasksFuture = _fetchTasks();
  }

  Future<List<dynamic>> _fetchTasks() async {
    try {
      final response = await widget.apiClient.get(
        '/tasks?filter=$_selectedFilter',
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Eroare la încărcarea sarcinilor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Eroare la încărcarea sarcinilor: $e');
    }
  }

  // Funcție publică pentru reîmprospătare, apelată de HomePage
  void refreshTasks() {
    setState(() {
      _tasksFuture = _fetchTasks();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter.toLowerCase();
      _tasksFuture = _fetchTasks();
    });
  }

  // Funcția pentru a finaliza/reactiva o sarcină din listă
  Future<void> _handleQuickToggle(String taskId, String currentStatus) async {
    setState(() {
      _loadingTaskIds.add(taskId);
    });

    final newStatus = (currentStatus == 'DONE') ? 'IN_PROGRESS' : 'DONE';

    try {
      final response = await widget.apiClient.patch('/tasks/$taskId/status', {
        'status': newStatus,
      });

      if (response.statusCode == 200) {
        refreshTasks(); // Reîmprospătăm
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare rețea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTaskIds.remove(taskId);
        });
      }
    }
  }

  // În clasa _TasksScreenState

  @override
  Widget build(BuildContext context) {
    // NOU: Am mutat definiția filtrelor AICI, în afara listei 'children'
    final Map<String, String> filters = {
      'Toate': 'all',
      'Azi': 'today',
      'Săptămână': 'week',
      'Delegat': 'delegated',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sarcinile Mele',
            style: GoogleFonts.robotoSlab(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),

            // AICI ESTE BLOCUL CORECTAT
            children: filters.entries.map((entry) {
              final label = entry.key; // ex: "Toate"
              final value = entry.value; // ex: "all"

              final isSelected = _selectedFilter == value; // Comparație corectă

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  // NOU: Trimitem valoarea corectă la API (ex: "all")
                  onSelected: (bool selected) => _onFilterChanged(value),
                  backgroundColor: Colors.grey[900],
                  selectedColor: Colors.red,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.red,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              );
            }).toList(), // Transformăm map-ul înapoi într-o listă de widget-uri
          ),
        ),
        const SizedBox(height: 16.0),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _tasksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Eroare: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Nicio sarcină găsită.',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              final tasks = snapshot.data!;
              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  // Trimitem doar task-ul
                  return _buildTaskCard(context, task);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Cardul pentru o sarcină
  Widget _buildTaskCard(
    BuildContext context,
    Map<String, dynamic> task,
    // ** AM ȘTERS 'chain' DE AICI **
  ) {
    final title = task['title'] ?? 'Sarcină fără titlu';
    final taskId = task['id'] as String;
    final status = task['status'] as String;
    final dueDate = task['dueDate'] != null
        ? 'Termen: ${task['dueDate'].substring(0, 10)}'
        : 'Fără termen';
    final isDone = status == 'DONE';

    final isLoading = _loadingTaskIds.contains(taskId);

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsPage(
                taskId: task['id'],
                currentUsername: widget.currentUsername,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ** AICI A FOST ȘTERS WIDGET-UL DelegationChain ȘI DIVIDER-UL **
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 40.0,
                      height: 40.0,
                      child: isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.red,
                                  strokeWidth: 2.0,
                                ),
                              ),
                            )
                          : Checkbox(
                              value: isDone,
                              onChanged: (bool? value) {
                                _handleQuickToggle(taskId, status);
                              },
                              activeColor: Colors.red,
                              checkColor: Colors.white,
                              side: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          dueDate,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                  const Center(
                    heightFactor: 2.0,
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ECRANUL 2: GRUPURI ---
class _GroupsScreen extends StatefulWidget {
  // ... (ACEASTĂ CLASĂ RĂMÂNE NESCHIMBATĂ) ...
  final ApiClient apiClient;
  final String currentUsername;

  const _GroupsScreen({required this.apiClient, required this.currentUsername});

  @override
  State<_GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<_GroupsScreen> {
  // ... (TOT CONȚINUTUL ACESTEI CLASE RĂMÂNE NESCHIMBAT) ...
  late Future<List<dynamic>> _groupsFuture;
  final _newGroupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _groupsFuture = _fetchGroups();
  }

  @override
  void dispose() {
    _newGroupNameController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchGroups() async {
    try {
      final response = await widget.apiClient.get('/workspaces');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Eroare la încărcarea grupurilor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Eroare la încărcarea grupurilor: $e');
    }
  }

  void _showAddGroupDialog() {
    _newGroupNameController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Grup Nou',
            style: GoogleFonts.robotoSlab(color: Colors.red),
          ),
          content: TextField(
            controller: _newGroupNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Numele grupului',
              labelStyle: const TextStyle(color: Colors.redAccent),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Anulează',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Salvează',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => _handleCreateGroup(dialogContext),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCreateGroup(BuildContext dialogContext) async {
    final groupName = _newGroupNameController.text;
    if (groupName.isEmpty) return;

    Navigator.of(dialogContext).pop(); // Închide dialogul

    try {
      final response = await widget.apiClient.post('/workspaces', {
        'name': groupName,
      });

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grup creat cu succes!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _groupsFuture = _fetchGroups(); // Reîmprospătează lista
        });
      } else {
        final error = jsonDecode(response.body)['error']['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare de rețea: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<dynamic>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Eroare: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nu ești în niciun grup.',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            );
          }

          final groups = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final role = group['role'] ?? 'MEMBER';
              final roleText = 'Tu ești: $role';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: const Icon(
                    Icons.group_work,
                    color: Colors.red,
                    size: 40,
                  ),
                  title: Text(
                    group['name'] ?? 'Grup fără nume',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    roleText,
                    style: TextStyle(
                      color: role == 'OWNER' || role == 'LEADER'
                          ? Colors.redAccent
                          : Colors.grey,
                      fontWeight: role == 'OWNER' || role == 'LEADER'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.red,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailsPage(
                          workspaceId: group['id'],
                          currentUsername: widget.currentUsername,
                          userRole: role,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGroupDialog,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- ECRANUL 3: VIZUALIZĂRI ---
// NOU: L-am transformat în StatefulWidget pentru a încărca date reale
class _VisualizationsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const _VisualizationsScreen({required this.apiClient});

  @override
  State<_VisualizationsScreen> createState() => _VisualizationsScreenState();
}

class _VisualizationsScreenState extends State<_VisualizationsScreen> {
  // NOU: Un singur future pentru a încărca toate sarcinile o dată
  late Future<List<dynamic>> _allTasksFuture;

  @override
  void initState() {
    super.initState();
    _allTasksFuture = _fetchAllTasks();
  }

  Future<List<dynamic>> _fetchAllTasks() async {
    try {
      final response = await widget.apiClient.get('/tasks?filter=all');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Eroare la încărcarea sarcinilor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Eroare la încărcarea sarcinilor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: Colors.red,
            labelStyle: GoogleFonts.robotoSlab(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.robotoSlab(),
            labelColor: Colors.red,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Listă'),
              Tab(text: 'Calendar'),
              Tab(text: 'Flux (Kanban)'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // TODO: Tab-ul 1 (Listă)
                const Center(
                  child: Text(
                    'Listă (de implementat)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                // TODO: Tab-ul 2 (Calendar)
                const Center(
                  child: Text(
                    'Calendar (de implementat)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                // NOU: Tab-ul 3 (Kanban) cu date reale
                FutureBuilder<List<dynamic>>(
                  future: _allTasksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Eroare: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nicio sarcină de afișat.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    // Filtrăm sarcinile în coloane
                    final allTasks = snapshot.data!;
                    final todoTasks = allTasks
                        .where((t) => t['status'] == 'TODO')
                        .toList();
                    final inProgressTasks = allTasks
                        .where((t) => t['status'] == 'IN_PROGRESS')
                        .toList();
                    final doneTasks = allTasks
                        .where((t) => t['status'] == 'DONE')
                        .toList();

                    return _buildKanbanView(
                      todoTasks,
                      inProgressTasks,
                      doneTasks,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOU: Am redenumit funcția (din _buildKanbanDemo)
  Widget _buildKanbanView(
    List<dynamic> todo,
    List<dynamic> inProgress,
    List<dynamic> done,
  ) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloanele acum primesc carduri reale
            _buildKanbanColumn(
              'De Făcut',
              todo
                  .map(
                    (task) => _buildKanbanCard(task['title'] ?? 'Fără titlu'),
                  )
                  .toList(),
            ),
            _buildKanbanColumn(
              'În Progres',
              inProgress
                  .map(
                    (task) => _buildKanbanCard(task['title'] ?? 'Fără titlu'),
                  )
                  .toList(),
            ),
            _buildKanbanColumn(
              'Finalizat',
              done
                  .map(
                    (task) => _buildKanbanCard(task['title'] ?? 'Fără titlu'),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ECRANUL 4: PROFIL ---
class _ProfileScreen extends StatefulWidget {
  // ... (ACEASTĂ CLASĂ RĂMÂNE NESCHIMBATĂ) ...
  final ApiClient apiClient;
  const _ProfileScreen({required this.apiClient});

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  // ... (TOT CONȚINUTUL ACESTEI CLASE RĂMÂNE NESCHIMBAT) ...
  late Future<List<dynamic>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _fetchLogs();
  }

  Future<List<dynamic>> _fetchLogs() async {
    try {
      final response = await widget.apiClient.get('/logs');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Eroare la încărcarea log-urilor: ${response.body}');
      }
    } catch (e) {
      throw Exception('Eroare la încărcarea log-urilor: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Setări și Securitate',
            style: GoogleFonts.robotoSlab(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildProfileOption(Icons.key, 'Schimbă Parola'),
          _buildProfileOption(Icons.notifications, 'Setări Notificări'),
          const Divider(color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'Log-uri de Activitate',
            style: GoogleFonts.robotoSlab(color: Colors.red, fontSize: 18),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<dynamic>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Eroare: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Niciun log găsit.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final logs = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final time = log['timestamp']?.substring(11, 16) ?? '??:??';
                  return _buildLogEntry(
                    time,
                    log['action'] ?? 'Acțiune necunoscută',
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

//############################################################################
// PASUL 2: FUNCȚIILE HELPER (Globale în acest fișier)
//############################################################################

// --- Pentru Ecranul PROFIL ---
Widget _buildProfileOption(IconData icon, String title) {
  return ListTile(
    leading: Icon(icon, color: Colors.red),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
    onTap: () {},
  );
}

Widget _buildLogEntry(String time, String action) {
  return Card(
    color: Colors.grey[900],
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: ListTile(
      leading: const Icon(Icons.info_outline, color: Colors.grey),
      title: Text(action, style: const TextStyle(color: Colors.white)),
      subtitle: Text(time, style: const TextStyle(color: Colors.grey)),
    ),
  );
}

// --- Pentru Ecranul VIZUALIZĂRI ---
Widget _buildKanbanColumn(String title, List<Widget> cards) {
  return Container(
    width: 200,
    margin: const EdgeInsets.symmetric(horizontal: 8.0),
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      color: Colors.grey[900],
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.robotoSlab(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Divider(color: Colors.red),
        // NOU: Facem coloana scroll-abilă intern dacă sunt prea multe carduri
        Column(
          children: cards.isNotEmpty
              ? cards
              : [
                  const Text(
                    "Niciun task",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
        ),
      ],
    ),
  );
}

Widget _buildKanbanCard(String title) {
  return Card(
    color: Colors.grey[800],
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(title, style: const TextStyle(color: Colors.white)),
    ),
  );
}

//############################################################################
// PASUL 3: PAGINA PRINCIPALĂ (Clasa "Container")
//############################################################################

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  // O cheie globală pentru a accesa starea _TasksScreen
  final GlobalKey<_TasksScreenState> _tasksScreenKey =
      GlobalKey<_TasksScreenState>();

  late final List<Widget> _pages;
  late final String _currentUsername; // Stocăm username-ul aici

  // În clasa _HomePageState

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.username; // Salvăm username-ul la inițializare

    // NOU: Lista de pagini CORECTATĂ (doar 3 elemente)
    _pages = <Widget>[
      _TasksScreen(
        key: _tasksScreenKey, // Legăm cheia de widget
        apiClient: _apiClient,
        currentUsername: _currentUsername,
      ),
      _GroupsScreen(apiClient: _apiClient, currentUsername: _currentUsername),
      // Am șters _VisualizationsScreen de aici
      _ProfileScreen(apiClient: _apiClient), // Acum este la indexul 2
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Funcția de Logout
  Future<void> _handleLogout() async {
    try {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post('/auth/logout', {'refreshToken': refreshToken});
      }
    } catch (e) {
      print('Eroare la logout pe server (ignorăm): $e');
    } finally {
      await _storageService.clearAuthData();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildDemoAppBar(context, widget.username, _handleLogout),
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Acasă',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_work),
            label: 'Grupuri',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.bar_chart),
          //   label: 'Vizualizări',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      floatingActionButton:
          _selectedIndex ==
              0 // Doar pe tab-ul Acasă
          ? FloatingActionButton(
              onPressed: () async {
                // Facem funcția async
                // Aici are loc navigarea la Creare Sarcină
                final result = await Navigator.push(
                  // Așteptăm un rezultat
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateTaskPage(),
                  ),
                );

                // Dacă ne întoarcem cu succes (din CreateTaskPage)
                if (result == true && mounted) {
                  // Apelăm funcția de refresh din _TasksScreen
                  _tasksScreenKey.currentState?.refreshTasks();
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_task),
            )
          : null,
    );
  }

  AppBar _buildDemoAppBar(
    BuildContext context,
    String username,
    VoidCallback onLogout,
  ) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      title: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Column(
          children: [
            Text(
              'ADMINISTRATOR DOSARE',
              style: GoogleFonts.robotoSlab(
                color: const Color.fromARGB(255, 255, 0, 0),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 14,
              ),
            ),
            Text(
              'STRICT SECRET',
              style: GoogleFonts.robotoSlab(
                color: const Color.fromARGB(255, 255, 0, 0),
                fontWeight: FontWeight.normal,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Center(
            child: Text(
              username,
              style: const TextStyle(
                color: Color.fromARGB(255, 48, 207, 0),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          onPressed: onLogout,
        ),
      ],
    );
  }
}
