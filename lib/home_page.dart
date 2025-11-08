import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:task_manager_app/login_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:task_manager_app/api_client.dart'; // NOU: Clientul API
import 'package:task_manager_app/storage_service.dart'; // NOU: Serviciul de stocare

//############################################################################
// PAGINA PRINCIPALĂ (CONȚINĂTORUL)
//############################################################################

class HomePage extends StatefulWidget {
  final String username;
  // Fără token în constructor, e gestionat automat!

  const HomePage({super.key, required this.username});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final ApiClient _apiClient = ApiClient(); // NOU: Instanță a clientului API
  final StorageService _storageService =
      StorageService(); // NOU: Instanță stocare

  // NOU: O listă de pagini (widget-uri)
  // Am pus widget-urile de body direct aici
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      _TasksScreen(apiClient: _apiClient), // Tab-ul Acasă (Sarcini)
      _GroupsScreen(apiClient: _apiClient), // Tab-ul Grupuri
      _VisualizationsScreen(apiClient: _apiClient), // Tab-ul Vizualizări
      _ProfileScreen(apiClient: _apiClient), // Tab-ul Profil
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // NOU: Funcția de Logout
  Future<void> _handleLogout() async {
    try {
      // Notificăm serverul
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post('/auth/logout', {'refreshToken': refreshToken});
      }
    } catch (e) {
      // Prindem erori de rețea, dar continuăm
      print('Eroare la logout pe server (ignorăm): $e');
    } finally {
      // Ștergem token-urile local
      await _storageService.clearTokens();
      // Navigăm la Login
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
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Vizualizări',
          ),
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
              onPressed: () {
                // TODO: Implementează ecranul de creare sarcină (POST /tasks)
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
                // Font actualizat
                color: const Color.fromARGB(255, 255, 0, 0),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 14,
              ),
            ),
            Text(
              'STRICT SECRET',
              style: GoogleFonts.robotoSlab(
                // Font actualizat
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
          onPressed: onLogout, // NOU: Butonul de Logout
        ),
      ],
    );
  }
}

//############################################################################
// ECRANUL 1: ACASĂ (SARCINI) - DATE REALE
//############################################################################
class _TasksScreen extends StatefulWidget {
  final ApiClient apiClient;
  const _TasksScreen({required this.apiClient});

  @override
  State<_TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<_TasksScreen> {
  late Future<List<dynamic>> _tasksFuture;
  String _selectedFilter = 'all'; // NOU: Filtru real

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

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter.toLowerCase();
      // Recarcm sarcinile cu noul filtru
      _tasksFuture = _fetchTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titlul și Filtrele Rapide... (UI-ul rămâne)
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
            children: ['All', 'Today', 'Week', 'Delegated'].map((filter) {
              final isSelected = _selectedFilter == filter.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (bool selected) => _onFilterChanged(filter),
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
            }).toList(),
          ),
        ),
        const SizedBox(height: 16.0),

        // NOU: FutureBuilder pentru a afișa datele reale
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
                  // Extragem lanțul de delegare (hidratat)
                  final chain = (task['delegationChain'] as List)
                      .map((user) => user['name'] as String)
                      .toList();
                  return _buildTaskCard(context, task, chain);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Cardul de sarcină - acum primește date reale
  Widget _buildTaskCard(
    BuildContext context,
    Map<String, dynamic> task,
    List<String> chain,
  ) {
    final title = task['title'] ?? 'Sarcină fără titlu';
    final dueDate = task['dueDate'] != null
        ? 'Termen: ${task['dueDate'].substring(0, 10)}' // Simplificat
        : 'Fără termen';
    final isDone = task['status'] == 'DONE';

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          // TODO: Navighează la ecranul de detalii (GET /tasks/:id)
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DelegationChainWidget(chain: chain, isSmall: true),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Checkbox(
                      value: isDone,
                      onChanged: (bool? value) {
                        // TODO: Implementează PATCH /tasks/:id/status
                      },
                      activeColor: Colors.red,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.red, width: 2),
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

//############################################################################
// ECRANUL 2: GRUPURI - DATE REALE
//############################################################################
class _GroupsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const _GroupsScreen({required this.apiClient});

  @override
  State<_GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<_GroupsScreen> {
  late Future<List<dynamic>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _fetchGroups();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
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
                  // TODO: Navighează la ecranul de detalii (GET /workspaces/:id)
                },
              ),
            );
          },
        );
      },
    );
  }
}

//############################################################################
// ECRANUL 3: VIZUALIZĂRI (Placeholder)
//############################################################################
class _VisualizationsScreen extends StatelessWidget {
  final ApiClient apiClient;
  const _VisualizationsScreen({required this.apiClient});

  @override
  Widget build(BuildContext context) {
    // Păstrăm demo-ul Kanban deocamdată, deoarece e independent de API
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
                const Center(
                  child: Text(
                    'Listă (de implementat)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const Center(
                  child: Text(
                    'Calendar (de implementat)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                _buildKanbanDemo(), // Păstrăm demo-ul vizual
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanDemo() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKanbanColumn('De Făcut', [
              _buildKanbanCard('Design UI Ecrane'),
              _buildKanbanCard('Implementare Login'),
            ]),
            _buildKanbanColumn('În Progres', [
              _buildKanbanCard('Conectare API'),
            ]),
            _buildKanbanColumn('Finalizat', [
              _buildKanbanCard('Setup Proiect'),
              _buildKanbanCard('Definire Schema DB'),
              _buildKanbanCard('Autentificare'),
            ]),
          ],
        ),
      ),
    );
  }

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
          ...cards, // Adaugă cardurile
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
}

//############################################################################
// ECRANUL 4: PROFIL (LOG-URI REALE)
//############################################################################
class _ProfileScreen extends StatefulWidget {
  final ApiClient apiClient;
  const _ProfileScreen({required this.apiClient});

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
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
            'Jurnal de Activitate (SQLite)',
            style: GoogleFonts.robotoSlab(color: Colors.red, fontSize: 18),
          ),
          const SizedBox(height: 8),

          // NOU: FutureBuilder pentru log-urile reale
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
                shrinkWrap: true, // Important într-un SingleChildScrollView
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

  // Funcțiile helper rămân (le-am scos din clasa demo)
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
}

//############################################################################
// WIDGET-URI HELPER (din demo-ul anterior)
// Acestea pot fi mutate într-un fișier separat
//############################################################################

// Widget pentru afișarea lanțului de delegare
class _DelegationChainWidget extends StatelessWidget {
  final List<String> chain;
  final bool isSmall;

  const _DelegationChainWidget({required this.chain, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0,
      runSpacing: 4.0,
      children: List.generate(chain.length * 2 - 1, (index) {
        if (index.isEven) {
          final itemIndex = index ~/ 2;
          final isYou =
              chain[itemIndex] == 'Tu'; // TODO: Logica asta trebuie actualizată
          return Chip(
            padding: isSmall
                ? const EdgeInsets.all(2.0)
                : const EdgeInsets.all(8.0),
            backgroundColor: isYou ? Colors.red[800] : Colors.grey[800],
            label: Text(
              chain[itemIndex],
              style: TextStyle(
                color: Colors.white,
                fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
                fontSize: isSmall ? 10 : 14,
              ),
            ),
            avatar: Icon(
              isYou ? Icons.account_circle : Icons.person_pin_circle,
              color: Colors.white,
              size: isSmall ? 14 : 18,
            ),
          );
        } else {
          return Icon(
            Icons.arrow_right_alt,
            color: Colors.red,
            size: isSmall ? 16 : 24,
          );
        }
      }),
    );
  }
}

Widget _buildKanbanDemo() {
  return Container(
    color: Colors.black,
    padding: const EdgeInsets.all(8.0),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKanbanColumn('De Făcut', [
            _buildKanbanCard('Design UI Ecrane'),
            _buildKanbanCard('Implementare Login'),
          ]),
          _buildKanbanColumn('În Progres', [_buildKanbanCard('Conectare API')]),
          _buildKanbanColumn('Finalizat', [
            _buildKanbanCard('Setup Proiect'),
            _buildKanbanCard('Definire Schema DB'),
            _buildKanbanCard('Autentificare'),
          ]),
        ],
      ),
    ),
  );
}

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
        ...cards, // Adaugă cardurile
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
