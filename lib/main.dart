import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flip_card/flip_card.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------- THEME ----------------------
const Color kBgColor = Color(0xFF0F172A);
const Color kCardColor = Color(0xFF1E293B);
const Color kPrimaryColor = Color(0xFF38BDF8);
const Color kAccentColor = Color(0xFFF472B6);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. إعداد Firebase بالقيم المباشرة (Hardcoded)
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAwnX_OBLqMjyP4p6BsfLpb3fPWe7GwxgE',
      authDomain: 'carida-c128a.firebaseapp.com',
      projectId: 'carida-c128a',
      storageBucket: 'carida-c128a.firebasestorage.app',
      messagingSenderId: '265928952104',
      appId: '1:265928952104:web:860a8e18068bf2f5f4a81d',
    ),
  );
  
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
      home: const DashboardScreen(),
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
  late Client client;
  late Databases databases;
  late Account account;
  
  String? userId;
  bool notificationsEnabled = false;
  bool isLoading = true;

  // 2. المتغيرات مباشرة (Hardcoded) من ملف env ديالك
  final String dbId = '692a1676000ec2efe6b7';
  final String colSubjects = 'subjects';
  final String colTokens = 'tokens';
  
  // VAPID KEY للإشعارات
  final String vapidKey = 'BJuMHF6db0WaWrrR_Cd3cwJHfEgdTLjX1oQHdN6fgG_Nn-vQ-VbZonixH2lmm8Q9n8OiFsobzNIv2u0ioRc70bQ';

  @override
  void initState() {
    super.initState();
    _initAppwrite();
  }

  void _initAppwrite() async {
    // إعداد Appwrite بالقيم المباشرة
    client = Client()
        .setEndpoint('https://fra.cloud.appwrite.io/v1') // انتبه: الرابط ديالك فيه fra (Frankfurt)
        .setProject('692a1631002d05865c41')
        .setSelfSigned(status: true);
        
    databases = Databases(client);
    account = Account(client);

    try {
      var user = await account.get();
      if (mounted) setState(() => userId = user.$id);
    } catch (e) {
      try {
        var user = await account.createAnonymousSession();
        if (mounted) setState(() => userId = user.userId);
      } catch (e) {
        print("Auth Error: $e");
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
      _checkPermissionStatus();
    }
  }

  String _getEmojiForSubject(String name) {
    name = name.toLowerCase();
    if (name.contains('math') || name.contains('calc')) return '📐';
    if (name.contains('hist') || name.contains('tarikh')) return '📜';
    if (name.contains('geo') || name.contains('ard')) return '🌍';
    if (name.contains('phys') || name.contains('fisi')) return '⚛️';
    if (name.contains('chem') || name.contains('kim')) return '🧪';
    if (name.contains('bio') || name.contains('hayat')) return '🧬';
    if (name.contains('eng') || name.contains('ing')) return '🇬🇧';
    if (name.contains('arab')) return '🕌';
    if (name.contains('fran')) return '🇫🇷';
    if (name.contains('code') || name.contains('prog') || name.contains('info')) return '💻';
    if (name.contains('law') || name.contains('droit')) return '⚖️';
    return '📚';
  }

  void _addSubject() {
    final controller = TextEditingController();
    showDialog(context: context, builder: (context) => _buildGlassDialog(
      title: "New Subject", 
      controller: controller, 
      hint: "Ex: Mathematics", 
      onConfirm: () async {
        if (controller.text.isNotEmpty && userId != null) {
          String emoji = _getEmojiForSubject(controller.text);
          await databases.createDocument(
            databaseId: dbId,
            collectionId: colSubjects,
            documentId: ID.unique(),
            data: {
              'name': controller.text,
              'emoji': emoji,
              'userId': userId,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            }
          );
          if(mounted) { setState(() {}); Navigator.pop(context); }
        }
      }
    ));
  }

  void _checkPermissionStatus() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if(mounted) setState(() => notificationsEnabled = true);
      _getToken();
    }
  }

  void _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if(mounted) setState(() => notificationsEnabled = true);
      _getToken();
    }
  }

  void _getToken() async {
    // استعمال VAPID KEY المباشر
    String? token = await FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
    
    if (token != null && userId != null) {
       try {
        var result = await databases.listDocuments(
            databaseId: dbId, 
            collectionId: colTokens, 
            queries: [Query.equal('userId', userId!)]
        );
        
        if (result.total == 0) {
          await databases.createDocument(
              databaseId: dbId, 
              collectionId: colTokens, 
              documentId: ID.unique(), 
              data: {'userId': userId, 'fcmToken': token}
          );
        } else {
            // تحديث التوكن إذا كان موجوداً ولكن مختلفاً (احتياط)
            if (result.documents.first.data['fcmToken'] != token) {
                await databases.updateDocument(
                    databaseId: dbId,
                    collectionId: colTokens,
                    documentId: result.documents.first.$id,
                    data: {'fcmToken': token}
                );
            }
        }
       } catch(e) { print(e); }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));

    return Scaffold(
      appBar: AppBar(title: const Text("My Subjects"), actions: [
        if (!notificationsEnabled) IconButton(onPressed: _requestPermission, icon: const Icon(Icons.notifications_active, color: Colors.orangeAccent)),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addSubject, backgroundColor: kPrimaryColor, child: const Icon(Icons.add, color: Colors.white)),
      body: userId == null ? const Center(child: Text("Error: No User")) : FutureBuilder(
        future: databases.listDocuments(databaseId: dbId, collectionId: colSubjects, queries: [Query.equal('userId', userId!)]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.documents.isEmpty) return const Center(child: Text("No subjects yet. Tap + to start 🚀", style: TextStyle(color: Colors.white54)));
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThemesScreen(subjectId: sub.$id, subjectName: sub.data['name'])))
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
  
  // قيم Hardcoded
  final String dbId = '692a1676000ec2efe6b7';
  final String colThemes = 'themes';

  @override
  void initState() {
    super.initState();
    client.setEndpoint('https://fra.cloud.appwrite.io/v1').setProject('692a1631002d05865c41').setSelfSigned(status: true);
    databases = Databases(client);
    account = Account(client);
    _getUser();
  }

  void _getUser() async {
    var user = await account.get();
    if (mounted) setState(() => userId = user.$id);
  }

  void _addTheme() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => _buildGlassDialog(
        title: "New Theme",
        controller: controller,
        hint: "Ex: Chapter 1",
        onConfirm: () async {
          if (controller.text.isNotEmpty && userId != null) {
            await databases.createDocument(
              databaseId: dbId,
              collectionId: colThemes,
              documentId: ID.unique(),
              data: {
                'name': controller.text,
                'subjectId': widget.subjectId,
                'userId': userId,
                'createdAt': DateTime.now().toUtc().toIso8601String()
              },
            );
            if (mounted) {
              setState(() {});
              Navigator.pop(context);
            }
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
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: databases.listDocuments(
                databaseId: dbId,
                collectionId: colThemes,
                queries: [Query.equal('subjectId', widget.subjectId)],
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.documents.isEmpty) return const Center(child: Text("No themes yet. Add one!", style: TextStyle(color: Colors.white54)));
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
  
  // قيم Hardcoded
  final String dbId = '692a1676000ec2efe6b7';
  final String colCards = 'cards';
  final String colTokens = 'tokens';
  // هذا هو ID ديال notifications_queue اللي أكدتي عليه في الصورة
  final String colQueue = 'notifications_queue'; 

  @override
  void initState() {
    super.initState();
    client.setEndpoint('https://fra.cloud.appwrite.io/v1').setProject('692a1631002d05865c41').setSelfSigned(status: true);
    databases = Databases(client);
    account = Account(client);
    _getUser();
  }

  void _getUser() async {
    var user = await account.get();
    if (mounted) {
      setState(() => userId = user.$id);
      _fetchCards();
    }
  }

  // ============== دالة جدولة الإشعارات (Queue System) ==============
  Future<void> _scheduleNotifications(String userId) async {
    String? fcmToken;
    try {
      // 1. جلب التوكن (باستعمال المتغير المباشر)
      final tokenDocs = await databases.listDocuments(
        databaseId: dbId,
        collectionId: colTokens,
        queries: [Query.equal('userId', userId)],
      );

      if (tokenDocs.documents.isNotEmpty) {
        fcmToken = tokenDocs.documents.first.data['fcmToken'];
        // تنبيه صغير للتأكد أن التوكن كايني
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ User Token Found - Scheduling...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
        ));
      } else {
        // تنبيه إذا لم يتم العثور على التوكن
        print("❌ Warning: No FCM token found for user $userId");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Notification Token Missing! Tap the bell icon.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
        ));
        return;
      }
    } catch (e) {
      print("Error fetching token: $e");
      return;
    }

    // 2. الفترات الزمنية الكاملة
    final now = DateTime.now().toUtc();
    final intervals = [
      {'label': '1 ساعة', 'duration': const Duration(hours: 1)},
      {'label': '3 ساعات', 'duration': const Duration(hours: 3)},
      {'label': 'يوم واحد', 'duration': const Duration(days: 1)},
      {'label': '3 أيام', 'duration': const Duration(days: 3)},
      {'label': 'أسبوع', 'duration': const Duration(days: 7)},
      {'label': '15 يوم', 'duration': const Duration(days: 15)},
      {'label': '30 يوم', 'duration': const Duration(days: 30)},
    ];

    // 3. إنشاء المهام في الطابور
    int successCount = 0;
    for (var interval in intervals) {
      final scheduledTime = now.add(interval['duration'] as Duration);
      try {
        await databases.createDocument(
          databaseId: dbId,
          collectionId: colQueue, // notifications_queue
          documentId: ID.unique(),
          data: {
            'userId': userId,
            'fcmToken': fcmToken,
            'title': 'Cardia Reminder 🧠',
            'body': 'حان وقت مراجعة البطاقات (${interval['label']})!',
            'scheduledAt': scheduledTime.toIso8601String(),
          }
        );
        successCount++;
      } catch (e) {
        print("Error scheduling ${interval['label']}: $e");
      }
    }
    
    if (successCount > 0) {
        print("✅ تم جدولة $successCount إشعارات بنجاح في الطابور.");
    }
  }
  // ==============================================================

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
        
        bool hasImported = false;
        
        for (var row in rows) {
          if (row.length >= 2) {
            await databases.createDocument(
              databaseId: dbId,
              collectionId: colCards,
              documentId: ID.unique(),
              data: {
                'front': row[0].toString(),
                'back': row[1].toString(),
                'userId': userId,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'batchId': batchId,
                'themeId': widget.themeId
              },
            );
            hasImported = true;
          }
        }
        
        if (mounted && hasImported) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Cards Imported!')));
          
          // تشغيل دالة الجدولة فوراً بعد الرفع
          _scheduleNotifications(userId!);
          
          _fetchCards();
        }
      } catch (e) {
        print(e);
      } finally {
        if (mounted) setState(() => isUploading = false);
      }
    }
  }

  void _fetchCards() async {
    if (userId == null) return;
    try {
      var result = await databases.listDocuments(
        databaseId: dbId,
        collectionId: colCards,
        queries: [Query.equal('themeId', widget.themeId), Query.orderDesc('createdAt')],
      );
      if (mounted) setState(() { myCards = result.documents.map((doc) => doc.data).toList(); });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.themeName),
        actions: [
          IconButton(
            onPressed: isUploading ? null : _uploadCSV,
            icon: isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
          )
        ],
      ),
      body: myCards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.style, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text("No cards yet.", style: TextStyle(color: Colors.white54)),
                  TextButton(onPressed: _uploadCSV, child: const Text("Import CSV", style: TextStyle(color: kPrimaryColor)))
                ],
              ),
            )
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
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
              if (!isBigEmoji) Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12))
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
      TextButton(onPressed: onConfirm, child: const Text("Create", style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16)))
    ],
  );
}