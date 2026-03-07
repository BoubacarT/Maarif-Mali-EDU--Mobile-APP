import 'package:flutter/material.dart';
import 'package:maarif_learn/CoursePage.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/auth_service.dart';
import 'package:maarif_learn/services/course_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;
  bool _userLoading = true;
  List<SubjectItem> _subjects = [];
  bool _subjectsLoading = true;
  String? _subjectsError;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSubjects();
  }

  Future<void> _loadUser() async {
    final user = await AuthStorage.getUser();
    if (mounted) setState(() { _user = user; _userLoading = false; });
  }

  Future<void> _loadSubjects() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _subjectsLoading = false; _subjectsError = 'Session expirée.'; });
      return;
    }
    try {
      final list = await CourseService.getSubjects(token);
      if (mounted) setState(() { _subjects = list; _subjectsLoading = false; _subjectsError = null; });
    } on CourseException catch (e) {
      if (mounted) setState(() { _subjectsLoading = false; _subjectsError = e.message; });
    } catch (e) {
      if (mounted) setState(() { _subjectsLoading = false; _subjectsError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      /// APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFF00ADBB),
        elevation: 0,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFFFfff3)),
                        color: Color(0xFFFfff3)
                        
                    ),
                    child: Icon(Icons.person,color: Colors.white,)
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userLoading ? "..." : (_user?['name'] ?? 'Élève'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _userLoading ? "" : ((_user?['level'] as Map?)?['name'] ?? ''),
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                )

              ],
            )

          ],
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Pagelogin()),
                (route) => false,
              );
            },
          ),
        ],

      ),

      /// BODY
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// CARTE BIENVENUE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bienvenue, ${_user?['name'] ?? 'Élève'} ! 👋",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text("Prêt(e) à apprendre aujourd'hui ?"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// TITRE MES MATIÈRES
            const Row(
              children: [
                Icon(Icons.menu_book, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  "Mes matières",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 15),

            /// Liste des matières
            if (_subjectsLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF00ADBB)),
              ))
            else if (_subjectsError != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.amber.shade800),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_subjectsError!)),
                    TextButton(
                      onPressed: _loadSubjects,
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              )
            else if (_subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucune matière disponible pour votre niveau.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._subjects.map((subject) => _buildSubjectCard(subject)),
          ],
        ),
      ),

      /// BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00ADBB),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Matières",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectItem subject) {
    Color color;
    try {
      color = Color(int.parse(subject.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      color = const Color(0xFF00ADBB);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Coursepage(subjectId: subject.id, subjectName: subject.name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.book, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${subject.coursesCount} cours disponible(s)",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
