import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart'; // ✅ مهمة جداً لـ OAuth
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ مكتبة Env

// ---------------------- إعدادات DATABASE ----------------------
const String SUBJECTS_COLLECTION = "subjects";
const String THEMES_COLLECTION = "themes";
const String CARDS_COLLECTION = "cards";
const String TOKENS_COLLECTION = "tokens";

// ---------------------- إعدادات FIREBASE ----------------------
const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyAwnX_OBLqMjyP4p6BsfLpb3fPWe7GwxgE",
  authDomain: "carida-c128a.firebaseapp.com",
  projectId: "carida-c128a",
  storageBucket: "carida-c128a.firebasestorage.app",
  messagingSenderId: "265928952104",
  appId: "1:265928952104:web:860a8e18068bf2f5f4a81d",
);

// ---------------------- COLORS & THEME ----------------------
const Color kBgColor = Color(0xFF0F172A);
const Color kCardColor = Color(0xFF1E293B);
const Color kPrimaryColor = Color(0xFF38BDF8);
const Color kAccentColor = Color(0xFFF472B6);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ تحميل ملف .env
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBgColor,
        primaryColor: kPrimaryColor,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          secondary: kAccentColor,
          surface: kCardColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------------- AUTH GATE ----------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final Client client = Client();
  late Account account;
  bool isLoading = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    // ✅ القراءة من Env
    client
        .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);
    account = Account(client);
    _checkSession();
  }

  void _checkSession() async {
    try {
      await account.get();
      setState(() { isLoggedIn = true; isLoading = false; });
    } catch (e) {
      setState(() { isLoggedIn = false; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    return isLoggedIn ? const DashboardScreen() : const AuthScreen();
  }
}

// ---------------------- AUTH SCREEN ----------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final Client client = Client();
  late Account account;
  
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // ✅ القراءة من Env
    client
        .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);
    account = Account(client);
  }

  void _authenticate() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await account.createEmailPasswordSession(email: _emailController.text, password: _passwordController.text);
      } else {
        await account.create(userId: ID.unique(), email: _emailController.text, password: _passwordController.text, name: _nameController.text);
        await account.createEmailPasswordSession(email: _emailController.text, password: _passwordController.text);
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _loginWithGoogle() {
      try {
        account.createOAuth2Session(
          provider: OAuthProvider.google,
          success: 'https://cardia-two.vercel.app', 
          failure: 'https://cardia-two.vercel.app',
        );
      } catch (e) {
        print("Login Error: $e");
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF334155)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Cardia 🧠", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(isLogin ? "Welcome Back" : "Start Learning", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 32),
                      
                      if (!isLogin)
                        _buildTextField(_nameController, "Full Name", Icons.person),
                      if (!isLogin) const SizedBox(height: 16),
                      
                      _buildTextField(_emailController, "Email", Icons.email),
                      const SizedBox(height: 16),
                      _buildTextField(_passwordController, "Password", Icons.lock, isPassword: true),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : Text(isLogin ? "Login" : "Sign Up", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _loginWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
                          label: const Text("Continue with Google", style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => setState(() => isLogin = !isLogin),
                        child: Text(isLogin ? "Create Account" : "I have an account", style: const TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kPrimaryColor.withOpacity(0.7)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

// ---------------------- DASHBOARD ----------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Client client = Client();
  late Databases databases;
  late Account account;
  String? userId;
  bool notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    // ✅ القراءة من Env
    client
        .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);
    databases = Databases(client);
    account = Account(client);
    _getUser();
  }

  void _getUser() async {
    var user = await account.get();
    setState(() => userId = user.$id);
    _checkPermissionStatus();
  }

  String _getEmojiForSubject(String name) {
    name = name.toLowerCase();
    if (name.contains('math') || name.contains('calc') || name.contains('ryadiyat')) return '📐';
    if (name.contains('hist') || name.contains('tarikh')) return '📜';
    if (name.contains('geo') || name.contains('ard')) return '🌍';
    if (name.contains('phys') || name.contains('fisi')) return '⚛️';
    if (name.contains('chem') || name.contains('kim')) return '🧪';
    if (name.contains('bio') || name.contains('hayat')) return '🧬';
    if (name.contains('eng') || name.contains('ing')) return '🇬🇧';
    if (name.contains('arab')) return '🕌';
    if (name.contains('fran')) return '🇫🇷';
    if (name.contains('code') || name.contains('prog') || name.contains('info')) return '💻';
    if (name.contains('law') || name.contains('droit') || name.contains('kanoun')) return '⚖️';
    return '📚';
  }

  void _addSubject() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => _buildGlassDialog(
        title: "New Subject",
        controller: controller,
        hint: "Ex: Mathematics",
        onConfirm: () async {
          if (controller.text.isNotEmpty && userId != null) {
            String emoji = _getEmojiForSubject(controller.text);
            await databases.createDocument(
              databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
              collectionId: SUBJECTS_COLLECTION,
              documentId: ID.unique(),
              data: {
                'name': controller.text,
                'emoji': emoji,
                'userId': userId,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              }
            );
            setState(() {});
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _logout(BuildContext context) async {
    await account.deleteSession(sessionId: 'current');
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  void _checkPermissionStatus() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      setState(() => notificationsEnabled = true);
      _getToken();
    }
  }
  void _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      setState(() => notificationsEnabled = true);
      _getToken();
    }
  }
  void _getToken() async {
    // ✅ القراءة من Env
    String? token = await FirebaseMessaging.instance.getToken(vapidKey: dotenv.env['VAPID_KEY']);
    if (token != null && userId != null) {
       try {
        var result = await databases.listDocuments(databaseId: dotenv.env['DATABASE_ID']!, collectionId: TOKENS_COLLECTION, queries: [Query.equal('userId', userId!)]);
        if (result.total == 0) {
          await databases.createDocument(databaseId: dotenv.env['DATABASE_ID']!, collectionId: TOKENS_COLLECTION, documentId: ID.unique(), data: {'userId': userId, 'fcmToken': token});
        }
       } catch(e) { print(e); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Subjects"),
        actions: [
          if (!notificationsEnabled)
            IconButton(onPressed: _requestPermission, icon: const Icon(Icons.notifications_active, color: Colors.orangeAccent)),
          IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubject,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: userId == null 
        ? const Center(child: CircularProgressIndicator()) 
        : FutureBuilder(
            future: databases.listDocuments(
              databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
              collectionId: SUBJECTS_COLLECTION,
              queries: [Query.equal('userId', userId!)],
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.documents.isEmpty) {
                return const Center(child: Text("No subjects yet. Tap + to start 🚀", style: TextStyle(color: Colors.white54)));
              }
              final subjects = snapshot.data!.documents;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final sub = subjects[index];
                  return _buildGlassCard(
                    title: sub.data['name'],
                    subtitle: sub.data['emoji'],
                    isBigEmoji: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThemesScreen(subjectId: sub.$id, subjectName: sub.data['name']))),
                  );
                },
              );
            },
          ),
    );
  }
}

// ---------------------- THEMES SCREEN ----------------------
class ThemesScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  const ThemesScreen({super.key, required this.subjectId, required this.subjectName});
  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  final Client client = Client();
  late Databases databases;
  late Account account;
  String? userId;

  @override
  void initState() {
    super.initState();
    // ✅ القراءة من Env
    client
        .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);
    databases = Databases(client);
    account = Account(client);
    _getUser();
  }
   void _getUser() async {
    var user = await account.get();
    setState(() => userId = user.$id);
  }

  void _addTheme() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => _buildGlassDialog(
        title: "New Theme",
        controller: controller,
        hint: "Ex: Chapter 1 - Introduction",
        onConfirm: () async {
          if (controller.text.isNotEmpty && userId != null) {
            await databases.createDocument(
              databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
              collectionId: THEMES_COLLECTION,
              documentId: ID.unique(),
              data: {
                'name': controller.text,
                'subjectId': widget.subjectId,
                'userId': userId,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
              }
            );
            setState(() {});
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTheme,
        backgroundColor: kAccentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: userId == null ? const Center(child: CircularProgressIndicator()) : FutureBuilder(
        future: databases.listDocuments(
          databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
          collectionId: THEMES_COLLECTION,
          queries: [Query.equal('subjectId', widget.subjectId)],
        ),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           if (!snapshot.hasData || snapshot.data!.documents.isEmpty) {
                return const Center(child: Text("No themes yet. Add one!", style: TextStyle(color: Colors.white54)));
           }
           final themes = snapshot.data!.documents;
           return ListView.builder(
             padding: const EdgeInsets.all(16),
             itemCount: themes.length,
             itemBuilder: (context, index) {
               final theme = themes[index];
               return Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: _buildGlassCard(
                   title: theme.data['name'],
                   subtitle: "Tap to view cards 🃏",
                   isBigEmoji: false,
                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardsScreen(themeId: theme.$id, themeName: theme.data['name']))),
                 ),
               );
             },
           );
        },
      ),
    );
  }
}

// ---------------------- CARDS SCREEN ----------------------
class CardsScreen extends StatefulWidget {
  final String themeId;
  final String themeName;
  const CardsScreen({super.key, required this.themeId, required this.themeName});
  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final Client client = Client();
  late Databases databases;
  late Account account;
  String? userId;
  bool isUploading = false;
  List<Map<String, dynamic>> myCards = [];

  @override
  void initState() {
    super.initState();
    // ✅ القراءة من Env
    client
        .setEndpoint(dotenv.env['APPWRITE_ENDPOINT']!)
        .setProject(dotenv.env['APPWRITE_PROJECT_ID']!)
        .setSelfSigned(status: true);
    databases = Databases(client);
    account = Account(client);
    _getUser();
  }
  
  void _getUser() async {
    var user = await account.get();
    setState(() => userId = user.$id);
    _fetchCards();
  }

  Future<void> _uploadCSV() async {
    if (userId == null) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);

    if (result != null) {
      setState(() => isUploading = true);
      try {
        final bytes = result.files.first.bytes;
        final csvString = utf8.decode(bytes!);
        List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
        String batchId = DateTime.now().millisecondsSinceEpoch.toString();
        
        for (var row in rows) {
          if (row.length >= 2) {
            await databases.createDocument(
              databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
              collectionId: CARDS_COLLECTION,
              documentId: ID.unique(),
              data: {
                'front': row[0].toString(), 'back': row[1].toString(),
                'userId': userId,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'batchId': batchId,
                'themeId': widget.themeId,
              },
            );
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cards Imported!')));
        _fetchCards();
      } catch (e) { print(e); } finally { setState(() => isUploading = false); }
    }
  }

  void _fetchCards() async {
    if (userId == null) return;
    try {
      var result = await databases.listDocuments(
        databaseId: dotenv.env['DATABASE_ID']!, // ✅ Env
        collectionId: CARDS_COLLECTION,
        queries: [Query.equal('themeId', widget.themeId), Query.orderDesc('createdAt')],
      );
      setState(() { myCards = result.documents.map((doc) => doc.data).toList(); });
    } catch (e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.themeName), actions: [
        IconButton(
          onPressed: isUploading ? null : _uploadCSV,
          icon: isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file),
        )
      ]),
      body: myCards.isEmpty 
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text("No cards yet.", style: TextStyle(color: Colors.white54)),
              TextButton(onPressed: _uploadCSV, child: const Text("Import CSV", style: TextStyle(color: kPrimaryColor)))
            ],
          ))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: myCards.length,
            itemBuilder: (context, index) {
              final card = myCards[index];
              return FlipCard(
                direction: FlipDirection.HORIZONTAL,
                front: _buildFlipSide(card['front'], kCardColor),
                back: _buildFlipSide(card['back'], kPrimaryColor.withOpacity(0.2)),
              );
            },
          ),
    );
  }

  Widget _buildFlipSide(String text, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------- COMMON WIDGETS ----------------------
Widget _buildGlassCard({required String title, required String subtitle, required bool isBigEmoji, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: isBigEmoji ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              if (isBigEmoji) Text(subtitle, style: const TextStyle(fontSize: 48)),
              if (isBigEmoji) const SizedBox(height: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (!isBigEmoji) Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildGlassDialog({required String title, required TextEditingController controller, required String hint, required VoidCallback onConfirm}) {
  return AlertDialog(
    backgroundColor: const Color(0xFF1E293B),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    ),
    actions: [
      TextButton(onPressed: onConfirm, child: const Text("Create", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
    ],
  );
}