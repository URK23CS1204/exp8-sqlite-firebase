import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'firebase_options.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable SQLite for Flutter Web
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Database',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StudentPage(),
    );
  }
}

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController courseController = TextEditingController();

  final CollectionReference students = FirebaseFirestore.instance.collection(
    'students',
  );

  final DatabaseHelper databaseHelper = DatabaseHelper.instance;

  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    courseController.dispose();
    super.dispose();
  }

  // CREATE
  Future<void> addStudent() async {
    final name = nameController.text.trim();
    final course = courseController.text.trim();

    if (name.isEmpty || course.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Student Name and Course')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Add to Firebase first
      final firebaseDocument = await students.add({
        'name': name,
        'course': course,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add to SQLite with Firebase document ID
      await databaseHelper.insertStudent(
        name,
        course,
        firebaseId: firebaseDocument.id,
      );

      nameController.clear();
      courseController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added to SQLite and Firebase!'),
          ),
        );

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // UPDATE
  Future<void> updateStudent(
    int sqliteId,
    String? firebaseId,
    String name,
    String course,
  ) async {
    try {
      // Update SQLite
      await databaseHelper.updateStudent(sqliteId, name, course);

      // Update Firebase
      if (firebaseId != null && firebaseId.isNotEmpty) {
        await students.doc(firebaseId).update({'name': name, 'course': course});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student updated in SQLite and Firebase!'),
          ),
        );

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // DELETE
  Future<void> deleteStudent(int sqliteId, String? firebaseId) async {
    try {
      // Delete from SQLite
      await databaseHelper.deleteStudent(sqliteId);

      // Delete from Firebase
      if (firebaseId != null && firebaseId.isNotEmpty) {
        await students.doc(firebaseId).delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deleted from SQLite and Firebase!'),
          ),
        );

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // EDIT DIALOG
  void showEditDialog(Map<String, dynamic> student) {
    final TextEditingController editNameController = TextEditingController(
      text: student['name']?.toString() ?? '',
    );

    final TextEditingController editCourseController = TextEditingController(
      text: student['course']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Student'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: editCourseController,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = editNameController.text.trim();

                final course = editCourseController.text.trim();

                if (name.isEmpty || course.isEmpty) {
                  return;
                }

                await updateStudent(
                  student['id'] as int,
                  student['firebaseId']?.toString(),
                  name,
                  course,
                );

                editNameController.dispose();
                editCourseController.dispose();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // CONFIRM DELETE
  void confirmDelete(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Student'),
          content: Text('Delete ${student['name']}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await deleteStudent(
                  student['id'] as int,
                  student['firebaseId']?.toString(),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📚 Student Database',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // NAME
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),

                const SizedBox(height: 15),

                // COURSE
                TextField(
                  controller: courseController,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                ),

                const SizedBox(height: 15),

                // ADD BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : addStudent,
                    icon: const Icon(Icons.add),
                    label: Text(isLoading ? 'Adding...' : 'ADD STUDENT'),
                  ),
                ),

                const SizedBox(height: 25),

                const Divider(),

                const SizedBox(height: 10),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SQLite Student Records',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10),

                // READ FROM SQLITE
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: databaseHelper.getStudents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('SQLite Error: ${snapshot.error}'),
                        );
                      }

                      final studentList = snapshot.data ?? [];

                      if (studentList.isEmpty) {
                        return const Center(
                          child: Text(
                            'No students found',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: studentList.length,
                        itemBuilder: (context, index) {
                          final student = studentList[index];

                          final name = student['name']?.toString() ?? '';

                          final course = student['course']?.toString() ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(course),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // EDIT
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      showEditDialog(student);
                                    },
                                  ),

                                  // DELETE
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      confirmDelete(student);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
