import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flip_card/flip_card.dart';

// ---------------------- إعدادات APPWRITE ----------------------
const String APPWRITE_PROJECT_ID = "692a1631002d05865c41";
const String APPWRITE_ENDPOINT = "https://fra.cloud.appwrite.io/v1";
const String DATABASE_ID = "692a1676000ec2efe6b7";
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

// ---------------------- المتغير الناقص ----------------------
// سير لـ Firebase Console > Project Settings > Cloud Messaging > Web configuration
// وانسخ الـ "Key pair" وحطو هنا
const String VAPID_KEY = "BJuMHF6db0WaWrrR_Cd3cwJHfEgdTLjX1oQHdN6fgG_Nn-vQ-VbZonixH2lmm8Q9n8OiFsobzNIv2u0ioRc70bQ"; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
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
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        primaryColor: Colors.blueAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), elevation: 0),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Appwrite SDK
  final Client client = Client();
  late Databases databases;
  late Account account;

  String? userId;
  bool isUploading = false;
  List<Map<String, dynamic>> myCards = [];

  @override
  void initState() {
    super.initState();
    _initAppwrite();
    _setupNotifications();
  }

  // 1. الاتصال بـ Appwrite وتسجيل الدخول
  void _initAppwrite() async {
    client
        .setEndpoint(APPWRITE_ENDPOINT)
        .setProject(APPWRITE_PROJECT_ID)
        .setSelfSigned(status: true);

    databases = Databases(client);
    account = Account(client);

    try {
      // التحقق من الجلسة الحالية
      var user = await account.get();
      setState(() => userId = user.$id);
    } catch (e) {
      // إنشاء جلسة مجهولة إذا لم توجد
      try {
        var user = await account.createAnonymousSession();
        setState(() => userId = user.userId);
      } catch (e) {
        print("Error creating session: $e");
      }
    }

    if (userId != null) {
      _fetchCards(); // جلب البطاقات عند الدخول
    }
  }

  // 2. إعداد الإشعارات (Firebase Messaging)
  void _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب الإذن
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // جلب الـ Token (خاصك تكون حطيتي VAPID_KEY الفوق)
      try {
        String? token = await messaging.getToken(vapidKey: VAPID_KEY);
        if (token != null) {
          print("FCM Token Found: $token");
          _saveTokenToDb(token);
        }
      } catch (e) {
        print("Error getting token: $e. Make sure VAPID Key is correct.");
      }
    }
  }

  // 3. تخزين التوكن في Appwrite
  void _saveTokenToDb(String token) async {
    if (userId == null) return;

    try {
      var result = await databases.listDocuments(
        databaseId: DATABASE_ID,
        collectionId: TOKENS_COLLECTION,
        queries: [Query.equal('userId', userId!)],
      );

      if (result.total == 0) {
        await databases.createDocument(
          databaseId: DATABASE_ID,
          collectionId: TOKENS_COLLECTION,
          documentId: ID.unique(),
          data: {
            'userId': userId,
            'fcmToken': token,
          },
        );
        print("✅ Token saved to Appwrite");
      }
    } catch (e) {
      print("❌ Error saving token: $e");
    }
  }

  // 4. رفع ملف CSV
  Future<void> _uploadCSV() async {
    if (userId == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // مهم للويب
    );

    if (result != null) {
      setState(() => isUploading = true);
      
      try {
        // قراءة الملف
        final bytes = result.files.first.bytes;
        final csvString = utf8.decode(bytes!);
        List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

        String batchId = DateTime.now().millisecondsSinceEpoch.toString();

        // حلقة لإضافة البطاقات
        for (var row in rows) {
          if (row.length >= 2) { // تأكد أن السطر فيه Front و Back
            await databases.createDocument(
              databaseId: DATABASE_ID,
              collectionId: CARDS_COLLECTION,
              documentId: ID.unique(),
              data: {
                'front': row[0].toString(),
                'back': row[1].toString(),
                'userId': userId,
                'createdAt': DateTime.now().toIso8601String(),
                'batchId': batchId,
              },
            );
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم رفع البطاقات بنجاح!')),
        );
        _fetchCards(); // تحديث الواجهة

      } catch (e) {
        print("Error uploading CSV: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الرفع: $e')),
        );
      } finally {
        setState(() => isUploading = false);
      }
    }
  }

  // 5. جلب البطاقات من Appwrite
  void _fetchCards() async {
    if (userId == null) return;
    
    try {
      var result = await databases.listDocuments(
        databaseId: DATABASE_ID,
        collectionId: CARDS_COLLECTION,
        queries: [
          Query.equal('userId', userId!),
          Query.orderDesc('createdAt'), // الأحدث أولاً
        ],
      );
      
      setState(() {
        myCards = result.documents.map((doc) => doc.data).toList();
      });
    } catch (e) {
      print("Error fetching cards: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cardia 🧠"),
        actions: [
          if (userId != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: Text("User: ${userId!.substring(0, 5)}...")),
            )
        ],
      ),
      body: userId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // زر الرفع
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isUploading ? null : _uploadCSV,
                      icon: isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(isUploading ? "جاري الرفع..." : "Import CSV Cards"),
                    ),
                  ),
                ),
                
                // قائمة البطاقات
                Expanded(
                  child: myCards.isEmpty
                      ? const Center(child: Text("لا توجد بطاقات، قم برفع ملف CSV"))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // عدد الأعمدة
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: myCards.length,
                          itemBuilder: (context, index) {
                            final card = myCards[index];
                            return FlipCard(
                              direction: FlipDirection.HORIZONTAL,
                              front: _buildCardFace(card['front'], Colors.blueAccent),
                              back: _buildCardFace(card['back'], Colors.teal),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCardFace(String text, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(2, 2))
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
}