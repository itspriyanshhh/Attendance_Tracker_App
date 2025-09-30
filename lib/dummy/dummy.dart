// import 'dart:async';

// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:table_calendar/table_calendar.dart';

// // add near the top of the file (next to your imports)
// final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
// // allows picking dates up to N years in the future
// DateTime _maxPickableDate({int years = 5}) =>
//     DateTime.now().add(Duration(days: 365 * years));

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp();
//   }
//   await NotificationService.instance.init();
//   AttendanceMonitor.instance.start();
//   runApp(const MyApp());
// }

// class NotificationService {
//   NotificationService._();
//   static final NotificationService instance = NotificationService._();

//   final FlutterLocalNotificationsPlugin _fln =
//       FlutterLocalNotificationsPlugin();

//   Future<void> init() async {
//     const AndroidInitializationSettings androidInit =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
//     const InitializationSettings initSettings = InitializationSettings(
//       android: androidInit,
//       iOS: iosInit,
//     );
//     await _fln.initialize(initSettings);

//     // Request FCM / platform permissions for iOS
//     await FirebaseMessaging.instance.requestPermission();
//   }

//   Future<void> show({
//     required String title,
//     required String body,
//     int id = 0,
//   }) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//           'attendance_channel',
//           'Attendance Alerts',
//           channelDescription: 'Alerts when attendance is below threshold',
//           importance: Importance.high,
//           priority: Priority.high,
//         );
//     const NotificationDetails platformDetails = NotificationDetails(
//       android: androidDetails,
//     );
//     await _fln.show(id, title, body, platformDetails);
//   }
// }

// class AttendanceMonitor {
//   AttendanceMonitor._();
//   static final AttendanceMonitor instance = AttendanceMonitor._();

//   // Threshold (75%)
//   static const double threshold = 75.0;

//   // check every X minutes while app is running (adjust as desired)
//   static const Duration _pollInterval = Duration(minutes: 60);

//   Timer? _timer;
//   final Set<String> _notifiedSubjects =
//       {}; // subjectId or 'TOTAL' to avoid duplicate notifications

//   Future<void> start() async {
//     // ensure notification service ready
//     await NotificationService.instance.init();

//     // initial run
//     await checkAll();

//     // periodic checks
//     _timer?.cancel();
//     _timer = Timer.periodic(_pollInterval, (_) => checkAll());
//   }

//   Future<void> stop() async {
//     _timer?.cancel();
//     _timer = null;
//   }

//   /// checks per-subject and total attendance, triggers notifications for drops below threshold
//   Future<void> checkAll() async {
//     try {
//       // load subjects & records (assumes FirestoreService exists)
//       final records = await FirestoreService.instance.getAllRecords();

//       // compute total held/attended globally
//       int globalHeld = 0;
//       int globalAttended = 0;
//       for (var r in records) {
//         globalHeld += r.held;
//         globalAttended += r.attended;
//       }

//       final totalPerc = globalHeld > 0
//           ? (globalAttended / globalHeld) * 100.0
//           : 100.0;

//       if (totalPerc < threshold) {
//         // only notify once until recovery; use 'TOTAL' key in notified set
//         if (!_notifiedSubjects.contains('TOTAL')) {
//           await NotificationService.instance.show(
//             id: 'TOTAL'.hashCode,
//             title: 'Low total attendance',
//             body:
//                 '${totalPerc.toStringAsFixed(1)}% (below ${threshold.toStringAsFixed(0)}%)',
//           );
//           _notifiedSubjects.add('TOTAL');
//         }
//       } else {
//         // recovered -> allow future notifications again
//         _notifiedSubjects.remove('TOTAL');
//       }
//     } catch (e) {
//       print('AttendanceMonitor.checkAll error: $e');
//     }
//   }

//   /// optional: call this after a specific subject changed so we check immediately for that subject
//   Future<void> checkSubject(String subjectId) async {
//     // small optimization: just call checkAll for simplicity
//     await checkAll();
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     // light theme: (keep your existing theme code here — I've mirrored it)
//     final ThemeData lightTheme = ThemeData(
//       primarySwatch: Colors.indigo,
//       colorScheme: ColorScheme.fromSwatch(
//         primarySwatch: Colors.indigo,
//         accentColor: Colors.pinkAccent,
//         backgroundColor: Colors.white,

//         // surface: const Color(0xFF1E1E1E),
//       ),
//       fontFamily: GoogleFonts.poppins().fontFamily,
//       scaffoldBackgroundColor: const Color(0xFFF5F5F5),
//       cardTheme: CardThemeData(
//         elevation: 4,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         color: Colors.white,
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         ),
//       ),
//       appBarTheme: const AppBarTheme(
//         backgroundColor: Color(0xFFF5F5F5),
//         elevation: 0,
//         // iconTheme: IconThemeData(color: Colors.white),
//       ),
//       textTheme: TextTheme(
//         headlineLarge: GoogleFonts.poppins(
//           fontSize: 32,
//           fontWeight: FontWeight.bold,
//           color: Colors.indigo[900],
//         ),
//         headlineMedium: GoogleFonts.poppins(
//           fontSize: 24,
//           fontWeight: FontWeight.w600,
//           color: Colors.indigo[800],
//         ),
//         bodySmall: GoogleFonts.poppins(fontSize: 12, color: Colors.black),
//         bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
//         bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
//       ),
//     );

//     // dark theme: dark background (#121212) and adjusted colors for text/icons
//     final ThemeData darkTheme = ThemeData.dark().copyWith(
//       scaffoldBackgroundColor: const Color(0xFF121212),
//       primaryColor: Colors.indigo[200],
//       colorScheme: ColorScheme.dark(
//         primary: Colors.indigo[200]!,
//         background: const Color(0xFF121212),
//         surface: const Color(0xFF1E1E1E),
//         onPrimary: Colors.black,
//         onSurface: Colors.white,
//       ),

//       appBarTheme: const AppBarTheme(
//         backgroundColor: Color(0xFF121212),
//         elevation: 0,
//         iconTheme: IconThemeData(color: Colors.white),
//       ),
//       cardTheme: CardThemeData(
//         color: const Color.fromARGB(255, 62, 62, 62),
//         elevation: 4,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           foregroundColor: Colors.white,
//           backgroundColor: Colors.indigoAccent,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         ),
//       ),
//       textTheme: TextTheme(
//         headlineLarge: GoogleFonts.poppins(
//           fontSize: 32,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//         headlineMedium: GoogleFonts.poppins(
//           fontSize: 24,
//           fontWeight: FontWeight.w600,
//           color: Colors.white,
//         ),
//         bodySmall: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
//         bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
//         bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
//       ),
//       iconTheme: const IconThemeData(color: Colors.white),
//     );

//     return ValueListenableBuilder<bool>(
//       valueListenable: isDarkMode,
//       builder: (context, dark, _) {
//         return MaterialApp(
//           title: 'Your New App Name',
//           debugShowCheckedModeBanner: false,
//           theme: lightTheme,
//           darkTheme: darkTheme,
//           themeMode: dark ? ThemeMode.dark : ThemeMode.light,
//           home: const SplashScreen(),
//         );
//       },
//     );
//   }
// }

// class Subject {
//   String? id;
//   String name;
//   bool isLab;
//   String color; // hex like "#3B82F6"

//   Subject({
//     this.id,
//     required this.name,
//     this.isLab = false,
//     this.color = '#FFFFFF', // default dark gray
//   });

//   Map<String, dynamic> toMap() {
//     return {'name': name, 'isLab': isLab ? 1 : 0, 'color': color};
//   }

//   factory Subject.fromMap(Map<String, dynamic> map) {
//     return Subject(
//       id: map['id'],
//       name: map['name'] ?? '',
//       isLab: (map['isLab'] == 1 || map['isLab'] == true),
//       color: (map['color'] as String?) ?? '#3B82F6',
//     );
//   }
// }

// class AttendanceRecord {
//   String? id;
//   String subjectId;
//   String date;
//   int held;
//   int attended;

//   AttendanceRecord({
//     this.id,
//     required this.subjectId,
//     required this.date,
//     this.held = 0,
//     this.attended = 0,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'subjectId': subjectId,
//       'date': date,
//       'held': held,
//       'attended': attended,
//     };
//   }

//   factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
//     return AttendanceRecord(
//       id: map['id'],
//       subjectId: map['subjectId'],
//       date: map['date'],
//       held: map['held'],
//       attended: map['attended'],
//     );
//   }
// }

// class FirestoreService {
//   static FirestoreService? _instance;
//   static FirestoreService get instance => _instance ??= FirestoreService._();
//   FirestoreService._();

//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   CollectionReference _subjectsCollection() {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     if (userId == null) throw Exception('User not authenticated');
//     return _firestore.collection('users').doc(userId).collection('subjects');
//   }

//   /// Delete all attendance records for a given date (yyyy-MM-dd)
//   Future<void> deleteRecordsForDate(String date) async {
//     final snapshot = await _recordsCollection()
//         .where('date', isEqualTo: date)
//         .get();
//     for (final doc in snapshot.docs) {
//       await doc.reference.delete();
//     }
//   }

//   CollectionReference _recordsCollection() {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     if (userId == null) throw Exception('User not authenticated');
//     return _firestore
//         .collection('users')
//         .doc(userId)
//         .collection('attendance_records');
//   }

//   Future<List<Subject>> getAllSubjects() async {
//     QuerySnapshot snapshot = await _subjectsCollection().get();
//     return snapshot.docs
//         .map(
//           (doc) => Subject.fromMap(
//             doc.data() as Map<String, dynamic>..['id'] = doc.id,
//           ),
//         )
//         .toList();
//   }

//   Future<void> insertSubject(Subject subject) async {
//     await _subjectsCollection().add(subject.toMap());
//   }

//   Future<void> deleteSubject(String id) async {
//     await _recordsCollection().where('subjectId', isEqualTo: id).get().then((
//       snapshot,
//     ) {
//       for (var doc in snapshot.docs) {
//         doc.reference.delete();
//       }
//     });
//     await _subjectsCollection().doc(id).delete();
//   }

//   Future<List<AttendanceRecord>> getAllRecords() async {
//     QuerySnapshot snapshot = await _recordsCollection().get();
//     return snapshot.docs
//         .map(
//           (doc) => AttendanceRecord.fromMap(
//             doc.data() as Map<String, dynamic>..['id'] = doc.id,
//           ),
//         )
//         .toList();
//   }

//   Future<List<String>> getUniqueDates() async {
//     QuerySnapshot snapshot = await _recordsCollection().get();
//     Set<String> dates = snapshot.docs
//         .map((doc) => doc['date'] as String)
//         .toSet();
//     return dates.toList()
//       ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
//   }

//   Future<List<AttendanceRecord>> getRecordsForDate(String date) async {
//     QuerySnapshot snapshot = await _recordsCollection()
//         .where('date', isEqualTo: date)
//         .get();
//     return snapshot.docs
//         .map(
//           (doc) => AttendanceRecord.fromMap(
//             doc.data() as Map<String, dynamic>..['id'] = doc.id,
//           ),
//         )
//         .toList();
//   }

//   Future<AttendanceRecord?> getRecordForSubjectAndDate(
//     String subjectId,
//     String date,
//   ) async {
//     QuerySnapshot snapshot = await _recordsCollection()
//         .where('subjectId', isEqualTo: subjectId)
//         .where('date', isEqualTo: date)
//         .limit(1)
//         .get();
//     if (snapshot.docs.isEmpty) return null;
//     return AttendanceRecord.fromMap(
//       snapshot.docs.first.data() as Map<String, dynamic>
//         ..['id'] = snapshot.docs.first.id,
//     );
//   }

//   Future<void> insertRecord(AttendanceRecord record) async {
//     await _recordsCollection().add(record.toMap());
//   }

//   Future<void> updateRecord(AttendanceRecord record) async {
//     await _recordsCollection().doc(record.id).update(record.toMap());
//   }

//   Future<void> deleteRecord(String id) async {
//     await _recordsCollection().doc(id).delete();
//   }
// }

// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   Future<void> _signInWithGoogle(BuildContext context) async {
//     try {
//       final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
//       final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
//       if (googleUser == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Sign-in canceled by user')),
//         );
//         return;
//       }

//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;
//       if (googleAuth.accessToken == null || googleAuth.idToken == null) {
//         throw Exception(
//           'Google Sign-In failed: Missing accessToken or idToken',
//         );
//       }

//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       await FirebaseAuth.instance.signInWithCredential(credential);
//     } catch (e) {
//       String errorMessage = 'Sign-in failed: $e';
//       if (e is FirebaseAuthException) {
//         errorMessage = 'Firebase Auth Error: ${e.code} - ${e.message}';
//       } else if (e is PlatformException) {
//         errorMessage = 'Platform Error: ${e.code} - ${e.message}';
//       }
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(errorMessage)));
//       print('Sign-in error: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasData) {
//           return const MainNav(); // <--- new app shell with bottom navigation
//         }

//         return Scaffold(
//           body: Center(
//             child: ElevatedButton.icon(
//               icon: const Icon(Icons.g_mobiledata, size: 32),
//               label: const Text(
//                 'Sign in with Google',
//                 style: TextStyle(fontSize: 18),
//               ),
//               style: ElevatedButton.styleFrom(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 24,
//                   vertical: 12,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 backgroundColor: Colors.white,
//                 foregroundColor: Colors.black87,
//                 elevation: 4,
//               ),
//               onPressed: () => _signInWithGoogle(context),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   _SplashScreenState createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     // Initialize animation controller for 1-second fade-in
//     _controller = AnimationController(
//       duration: const Duration(seconds: 1),
//       vsync: this,
//     );
//     _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
//     _controller.forward(); // Start the fade-in animation

//     // Navigate to LoginScreen after 3 seconds
//     Future.delayed(const Duration(seconds: 5), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: FadeTransition(
//           opacity: _animation,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(20),
//                 child: Image.asset(
//                   'assets/icon/icon.png',
//                   width: 150,
//                   height: 150,
//                   fit: BoxFit.contain,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 'By Priyansh Garg',
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   color: Colors.black87,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class AttendanceHome extends StatefulWidget {
//   const AttendanceHome({super.key});

//   @override
//   State<AttendanceHome> createState() => _AttendanceHomeState();
// }

// class _AttendanceHomeState extends State<AttendanceHome> {
//   List<Subject> _subjects = [];
//   List<AttendanceRecord> _records = [];
//   double _totalAttendance = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   // ---------- state fields ----------
//   Map<String, bool> _batchSelections = {}; // subjectId -> selected
//   DateTime _batchSelectedDate = DateTime.now();

//   // ---------- open dialog ----------
//   Future<void> _openBatchMarkDialog() async {
//     // initialize selection map
//     _batchSelections = {for (var s in _subjects) s.id!: false};
//     _batchSelectedDate = DateTime.now();

//     await showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         // use StatefulBuilder inside sheet to update UI
//         return StatefulBuilder(
//           builder: (context, dialogSetState) {
//             // local helpers inside dialog
//             String _searchQuery = '';
//             List<Subject> filteredSubjects() {
//               final q = _searchQuery.trim().toLowerCase();
//               if (q.isEmpty) return _subjects;
//               return _subjects
//                   .where((s) => s.name.toLowerCase().contains(q))
//                   .toList();
//             }

//             int selectedCount() =>
//                 _batchSelections.values.where((v) => v).length;

//             // sheet UI
//             return SafeArea(
//               bottom: true,
//               child: DraggableScrollableSheet(
//                 initialChildSize: 0.8,
//                 minChildSize: 0.5,
//                 maxChildSize: 0.95,
//                 builder: (_, controller) => Container(
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).dialogBackgroundColor,
//                     borderRadius: const BorderRadius.vertical(
//                       top: Radius.circular(20),
//                     ),
//                   ),
//                   padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       // top handle
//                       Center(
//                         child: Container(
//                           width: 48,
//                           height: 4,
//                           decoration: BoxDecoration(
//                             color: Colors.grey.shade400,
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),

//                       // Header: date + select count
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               'Batch Mark — ${DateFormat('MMMM d, yyyy').format(_batchSelectedDate)}',
//                               style: Theme.of(context).textTheme.titleMedium
//                                   ?.copyWith(fontWeight: FontWeight.w600),
//                             ),
//                           ),
//                           // small date picker icon
//                           IconButton(
//                             tooltip: 'Pick date',
//                             icon: const Icon(Icons.calendar_today_outlined),
//                             onPressed: () async {
//                               final picked = await showDatePicker(
//                                 context: context,
//                                 initialDate: _batchSelectedDate,
//                                 firstDate: DateTime(2000),
//                                 lastDate: _maxPickableDate(),
//                               );
//                               if (picked != null) {
//                                 dialogSetState(
//                                   () => _batchSelectedDate = picked,
//                                 );
//                               }
//                             },
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 8),

//                       // Compact inline calendar (small height)
//                       SizedBox(
//                         // height: 280,
//                         child: TableCalendar(
//                           firstDay: DateTime(2000),
//                           lastDay: _maxPickableDate(),
//                           focusedDay: _batchSelectedDate,
//                           selectedDayPredicate: (d) =>
//                               DateFormat('yyyy-MM-dd').format(d) ==
//                               DateFormat(
//                                 'yyyy-MM-dd',
//                               ).format(_batchSelectedDate),
//                           onDaySelected: (selectedDay, focusedDay) {
//                             dialogSetState(
//                               () => _batchSelectedDate = selectedDay,
//                             );
//                           },
//                           headerVisible: false,
//                           calendarStyle: CalendarStyle(
//                             todayDecoration: BoxDecoration(
//                               color: Theme.of(
//                                 context,
//                               ).colorScheme.primary.withOpacity(0.9),
//                               shape: BoxShape.circle,
//                             ),
//                             selectedDecoration: BoxDecoration(
//                               color: Theme.of(context).colorScheme.primary,
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 12),

//                       // list header (selected count)
//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 4,
//                           horizontal: 4,
//                         ),
//                         child: Row(
//                           children: [
//                             Text(
//                               '${selectedCount()} selected',
//                               style: Theme.of(context).textTheme.bodySmall,
//                             ),
//                             const Spacer(),
//                             Text(
//                               'Tap to select',
//                               style: Theme.of(context).textTheme.bodySmall
//                                   ?.copyWith(color: Colors.grey),
//                             ),
//                           ],
//                         ),
//                       ),

//                       const SizedBox(height: 4),

//                       // Subjects list - scrollable
//                       Expanded(
//                         child: Scrollbar(
//                           thumbVisibility: true,
//                           child: ListView.separated(
//                             controller: controller,
//                             itemCount: filteredSubjects().length,
//                             separatorBuilder: (_, __) =>
//                                 const Divider(height: 1),
//                             itemBuilder: (context, idx) {
//                               final s = filteredSubjects()[idx];
//                               final sid = s.id!;
//                               final checked = _batchSelections[sid] ?? false;
//                               final bg = checked
//                                   ? Theme.of(
//                                       context,
//                                     ).colorScheme.primary.withOpacity(0.12)
//                                   : Colors.transparent;
//                               return InkWell(
//                                 onTap: () => dialogSetState(
//                                   () => _batchSelections[sid] =
//                                       !_batchSelections[sid]!,
//                                 ),
//                                 child: Container(
//                                   color: bg,
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 8,
//                                     horizontal: 6,
//                                   ),
//                                   child: Row(
//                                     children: [
//                                       Checkbox(
//                                         value: checked,
//                                         onChanged: (val) => dialogSetState(
//                                           () => _batchSelections[sid] =
//                                               val ?? false,
//                                         ),
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                               s.name,
//                                               style: Theme.of(context)
//                                                   .textTheme
//                                                   .bodyLarge
//                                                   ?.copyWith(
//                                                     fontWeight: FontWeight.w600,
//                                                   ),
//                                             ),
//                                             const SizedBox(height: 4),
//                                             Row(
//                                               children: [
//                                                 Container(
//                                                   padding:
//                                                       const EdgeInsets.symmetric(
//                                                         horizontal: 8,
//                                                         vertical: 4,
//                                                       ),
//                                                   decoration: BoxDecoration(
//                                                     color: s.isLab
//                                                         ? Colors.orange
//                                                               .withOpacity(0.15)
//                                                         : Colors.blue
//                                                               .withOpacity(
//                                                                 0.12,
//                                                               ),
//                                                     borderRadius:
//                                                         BorderRadius.circular(
//                                                           12,
//                                                         ),
//                                                   ),
//                                                   child: Text(
//                                                     s.isLab
//                                                         ? 'Lab (2 pts)'
//                                                         : 'Lecture (1 pt)',
//                                                     style: Theme.of(
//                                                       context,
//                                                     ).textTheme.bodySmall,
//                                                   ),
//                                                 ),
//                                                 const SizedBox(width: 8),
//                                                 // quick stats (optional): sessions / percent
//                                                 Text(
//                                                   '${_getSubjectAttendedSessions(s)} / ${_getSubjectTotalSessions(s)}',
//                                                   style: Theme.of(context)
//                                                       .textTheme
//                                                       .bodySmall
//                                                       ?.copyWith(
//                                                         color: Colors.grey,
//                                                       ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       // right chevron
//                                       Icon(
//                                         Icons.chevron_right,
//                                         color: Theme.of(
//                                           context,
//                                         ).iconTheme.color?.withOpacity(0.4),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 12),

//                       // Footer actions: Cancel + Mark buttons
//                       Row(
//                         children: [
//                           Expanded(
//                             child: OutlinedButton(
//                               onPressed: () => Navigator.pop(context),
//                               child: const Padding(
//                                 padding: EdgeInsets.symmetric(vertical: 12),
//                                 child: Text('Cancel'),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: selectedCount() > 0
//                                   ? () {
//                                       Navigator.pop(context);
//                                       _confirmBatchMark(
//                                         _batchSelectedDate,
//                                         Map<String, bool>.from(
//                                           _batchSelections,
//                                         ),
//                                         true,
//                                       );
//                                     }
//                                   : null,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 12,
//                                 ),
//                                 backgroundColor: Colors.green,
//                               ),
//                               child: Text(
//                                 'Attended (${selectedCount()})',
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: selectedCount() > 0
//                                   ? () {
//                                       Navigator.pop(context);
//                                       _confirmBatchMark(
//                                         _batchSelectedDate,
//                                         Map<String, bool>.from(
//                                           _batchSelections,
//                                         ),
//                                         false,
//                                       );
//                                     }
//                                   : null,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 12,
//                                 ),
//                                 backgroundColor: Colors.red,
//                               ),
//                               child: Text(
//                                 'Missed (${selectedCount()})',
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // ---------- perform batch mark + show Undo ----------
//   Future<void> _confirmBatchMark(
//     DateTime day,
//     Map<String, bool> selections,
//     bool markAsAttended,
//   ) async {
//     final selectedIds = selections.entries
//         .where((e) => e.value)
//         .map((e) => e.key)
//         .toList();
//     if (selectedIds.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No subjects selected')));
//       return;
//     }

//     final iso = DateFormat('yyyy-MM-dd').format(day);

//     // Keep snapshots for undo:
//     final List<Map<String, dynamic>> snapshots = [];

//     for (final sid in selectedIds) {
//       try {
//         // fetch existing record (if any)
//         final existing = await FirestoreService.instance
//             .getRecordForSubjectAndDate(sid, iso);
//         if (existing != null) {
//           // save previous snapshot
//           snapshots.add({
//             'subjectId': sid,
//             'previous': AttendanceRecord.fromMap({
//               'id': existing.id,
//               'subjectId': existing.subjectId,
//               'date': existing.date,
//               'held': existing.held,
//               'attended': existing.attended,
//             }),
//           });

//           // update
//           existing.held += 1;
//           if (markAsAttended) existing.attended += 1;
//           await FirestoreService.instance.updateRecord(existing);
//           // store the resulting id if needed for undo
//           snapshots.last['resultId'] = existing.id;
//         } else {
//           // no existing — create new. Save previous null.
//           snapshots.add({'subjectId': sid, 'previous': null, 'resultId': null});
//           final newRec = AttendanceRecord(
//             subjectId: sid,
//             date: iso,
//             held: 1,
//             attended: markAsAttended ? 1 : 0,
//           );
//           await FirestoreService.instance.insertRecord(newRec);
//           AttendanceMonitor.instance.checkSubject(newRec.subjectId);

//           // retrieve the created record to get its id (some implementations return id; if not, fetch it)
//           final created = await FirestoreService.instance
//               .getRecordForSubjectAndDate(sid, iso);
//           if (created != null) snapshots.last['resultId'] = created.id;
//         }
//       } catch (e) {
//         // Skip failing subjects but collect nothing for undo for them (you may want to surface errors)
//         print('Batch mark failed for $sid: $e');
//       }
//     }

//     // Refresh UI
//     await _loadData();

//     // Show snackbar with Undo
//     final snack = SnackBar(
//       content: Text(
//         '${selectedIds.length} subjects marked for ${DateFormat('MMMM d, yyyy').format(day)}',
//       ),
//       action: SnackBarAction(
//         label: 'Undo',
//         onPressed: () async {
//           await _revertBatch(snapshots);
//         },
//       ),
//       duration: const Duration(seconds: 6),
//     );
//     ScaffoldMessenger.of(context).showSnackBar(snack);
//   }

//   // ---------- revert changes ----------
//   Future<void> _revertBatch(List<Map<String, dynamic>> snapshots) async {
//     for (final snap in snapshots) {
//       final String sid = snap['subjectId'];
//       final AttendanceRecord? prev = snap['previous'] as AttendanceRecord?;
//       final String? resultId = snap['resultId'] as String?;

//       try {
//         if (prev == null) {
//           // record was newly created — delete it (by resultId if available, else lookup)
//           String? idToDelete = resultId;
//           if (idToDelete == null) {
//             final found = await FirestoreService.instance
//                 .getRecordForSubjectAndDate(
//                   sid,
//                   prev == null
//                       ? DateTime.now().toIso8601String().split('T')[0]
//                       : prev.date,
//                 );
//             idToDelete = found?.id;
//           }
//           if (idToDelete != null) {
//             await FirestoreService.instance.deleteRecord(idToDelete);
//           }
//         } else {
//           // record existed — restore previous values
//           // ensure we use the correct id: if prev.id is null, try resultId
//           final restoreId = prev.id ?? resultId;
//           if (restoreId != null) {
//             // create a record object with id and previous values and update
//             final restore = AttendanceRecord(
//               id: restoreId,
//               subjectId: prev.subjectId,
//               date: prev.date,
//               held: prev.held,
//               attended: prev.attended,
//             );
//             await FirestoreService.instance.updateRecord(restore);
//           } else {
//             // fallback: try fetch by subject+date and update
//             final fetched = await FirestoreService.instance
//                 .getRecordForSubjectAndDate(prev.subjectId, prev.date);
//             if (fetched != null) {
//               fetched.held = prev.held;
//               fetched.attended = prev.attended;
//               await FirestoreService.instance.updateRecord(fetched);
//             }
//           }
//         }
//       } catch (e) {
//         print('Undo failed for $sid: $e');
//       }
//     }

//     // Refresh UI
//     await _loadData();

//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Changes undone')));
//   }

//   Future<void> _loadData() async {
//     List<Subject> subjects = await FirestoreService.instance.getAllSubjects();
//     List<AttendanceRecord> records = await FirestoreService.instance
//         .getAllRecords();
//     setState(() {
//       _subjects = subjects;
//       _records = records;
//       _calculateTotalAttendance();
//     });
//   }

//   void _calculateTotalAttendance() {
//     int totalPoints = 0;
//     int attendedPoints = 0;

//     for (var record in _records) {
//       Subject? subject = _subjects.firstWhere(
//         (s) => s.id == record.subjectId,
//         orElse: () => Subject(name: ''),
//       );
//       if (subject.id == null) continue;
//       int pointsPerSession = subject.isLab ? 2 : 1;
//       totalPoints += record.held * pointsPerSession;
//       attendedPoints += record.attended * pointsPerSession;
//     }

//     _totalAttendance = totalPoints > 0
//         ? (attendedPoints / totalPoints) * 100
//         : 0.0;
//   }

//   Future<void> _addSubject(BuildContext context) async {
//     final _formKey = GlobalKey<FormState>();
//     String name = '';
//     bool isLab = false;

//     await showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) => StatefulBuilder(
//         builder: (BuildContext context, StateSetter dialogSetState) => AlertDialog(
//           title: const Text('Add Subject'),
//           content: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 TextFormField(
//                   decoration: const InputDecoration(labelText: 'Subject Name'),
//                   validator: (v) => (v == null || v.trim().isEmpty)
//                       ? 'Please enter a subject name'
//                       : null,
//                   onSaved: (v) => name = v!.trim(),
//                 ),
//                 const SizedBox(height: 12),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Is Lab?'),
//                     Switch(
//                       value: isLab,
//                       onChanged: (value) => dialogSetState(() => isLab = value),
//                       activeColor: Colors.indigo, // when ON
//                       inactiveThumbColor: Colors.grey, // thumb when OFF
//                       inactiveTrackColor:
//                           Colors.grey.shade300, // track when OFF
//                       materialTapTargetSize: MaterialTapTargetSize
//                           .shrinkWrap, // optional: smaller tap target inside dialogs
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(dialogContext),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 if (_formKey.currentState!.validate()) {
//                   _formKey.currentState!.save();
//                   final newSubject = Subject(
//                     name: name,
//                     isLab: isLab,
//                     color: '#FFFFFF',
//                   );
//                   try {
//                     await FirestoreService.instance.insertSubject(newSubject);
//                     await _loadData();
//                     Navigator.pop(dialogContext);
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(content: Text('Failed to add subject: $e')),
//                     );
//                   }
//                 }
//               },
//               child: const Text('Add'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _markSession(Subject subject, bool attend) async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: _maxPickableDate(),
//     );
//     if (picked == null) return;
//     await _confirmBatchMark(picked, {subject.id!: true}, attend);
//     await AttendanceMonitor.instance.checkAll();
//   }

//   Future<void> _deleteSubject(Subject subject) async {
//     bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: const Text('Delete Subject'),
//         content: Text(
//           'Are you sure you want to delete "${subject.name}"? This will also delete all attendance records for this subject.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       try {
//         await FirestoreService.instance.deleteSubject(subject.id!);
//         _loadData();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('${subject.name} deleted successfully')),
//         );
//       } catch (e) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to delete subject: $e')));
//       }
//     }
//   }

//   String _getSubjectType(Subject subject) {
//     return subject.isLab ? 'Lab (2 pts)' : 'Lecture (1 pt)';
//   }

//   int _getSubjectTotalSessions(Subject subject) {
//     return _records
//         .where((r) => r.subjectId == subject.id)
//         .fold(0, (sum, r) => sum + r.held);
//   }

//   int _getSubjectAttendedSessions(Subject subject) {
//     return _records
//         .where((r) => r.subjectId == subject.id)
//         .fold(0, (sum, r) => sum + r.attended);
//   }

//   double _getSubjectPercentage(Subject subject) {
//     int total = _getSubjectTotalSessions(subject);
//     int attended = _getSubjectAttendedSessions(subject);
//     return total > 0 ? (attended / total) * 100 : 0.0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cardTextColor = Theme.of(context).textTheme.bodyLarge!.color;
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Attendify',
//           style: Theme.of(context).textTheme.headlineMedium!,
//         ),
//         actions: [
//           ValueListenableBuilder<bool>(
//             valueListenable: isDarkMode,
//             builder: (context, dark, _) => IconButton(
//               tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
//               icon: Icon(dark ? Icons.dark_mode : Icons.light_mode),
//               onPressed: () => isDarkMode.value = !dark,
//             ),
//           ),
//           IconButton(
//             tooltip: 'Batch mark attendance',
//             icon: const Icon(Icons.calendar_today_outlined),
//             onPressed: _openBatchMarkDialog,
//           ),

//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: () => _addSubject(context),
//           ),
//           IconButton(
//             icon: const Icon(Icons.history),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const HistoryScreen()),
//               ).then((_) => _loadData());
//             },
//           ),
//         ],
//       ),
//       body: SafeArea(
//         bottom: true,
//         child: Column(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Colors.indigo, Colors.indigo[700]!],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: const BorderRadius.vertical(
//                   bottom: Radius.circular(24),
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   const Text(
//                     'Total Attendance',
//                     style: TextStyle(color: Colors.white, fontSize: 18),
//                   ),
//                   Text(
//                     '${_totalAttendance.toStringAsFixed(2)}%',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 48,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: _subjects.isEmpty
//                   ? const Center(child: Text('No subjects added yet.'))
//                   : ListView.builder(
//                       padding: const EdgeInsets.all(16),
//                       itemCount: _subjects.length,
//                       itemBuilder: (context, index) {
//                         Subject subject = _subjects[index];

//                         return Card(
//                           margin: const EdgeInsets.only(bottom: 16),
//                           child: Padding(
//                             padding: const EdgeInsets.all(16),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       subject.name,
//                                       style: Theme.of(context)
//                                           .textTheme
//                                           .headlineMedium!
//                                           .copyWith(color: cardTextColor),
//                                     ),
//                                     IconButton(
//                                       icon: const Icon(
//                                         Icons.delete,
//                                         color: Colors.red,
//                                       ),
//                                       onPressed: () => _deleteSubject(subject),
//                                     ),
//                                   ],
//                                 ),
//                                 Text(
//                                   _getSubjectType(subject),
//                                   style: Theme.of(context).textTheme.bodySmall,
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   'Sessions: ${_getSubjectAttendedSessions(subject)} / ${_getSubjectTotalSessions(subject)}',
//                                   style: Theme.of(context).textTheme.bodyMedium!
//                                       .copyWith(color: cardTextColor),
//                                 ),
//                                 Text(
//                                   'Percentage: ${_getSubjectPercentage(subject).toStringAsFixed(2)}%',
//                                   style: Theme.of(context).textTheme.bodyLarge!
//                                       .copyWith(color: cardTextColor),
//                                 ),
//                                 const SizedBox(height: 16),
//                                 Row(
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceEvenly,
//                                   children: [
//                                     ElevatedButton.icon(
//                                       icon: const Icon(
//                                         Icons.check,
//                                         color: Colors.white,
//                                       ),
//                                       label: const Text(
//                                         'Attended',
//                                         style: TextStyle(color: Colors.white),
//                                       ),
//                                       onPressed: () async {
//                                         _markSession(subject, true);
//                                         await AttendanceMonitor.instance
//                                             .checkAll();
//                                       },
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.green,
//                                       ),
//                                     ),
//                                     ElevatedButton.icon(
//                                       icon: const Icon(
//                                         Icons.close,
//                                         color: Colors.white,
//                                       ),
//                                       label: const Text(
//                                         'Missed',
//                                         style: TextStyle(color: Colors.white),
//                                       ),
//                                       onPressed: () async {
//                                         _markSession(subject, false);
//                                         await AttendanceMonitor.instance
//                                             .checkAll();
//                                       },
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: Colors.red,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Main app shell that holds bottom navigation and pages
// class MainNav extends StatefulWidget {
//   const MainNav({super.key});

//   @override
//   State<MainNav> createState() => _MainNavState();
// }

// class _MainNavState extends State<MainNav> {
//   int _currentIndex = 0;
//   // Add this near the top of _MainNavState
//   final GlobalKey<_AttendanceHomeState> _attendanceHomeKey =
//       GlobalKey<_AttendanceHomeState>();

//   // Pages for each nav item
//   late final List<Widget> _pages;

//   @override
//   void initState() {
//     super.initState();
//     _pages = [
//       AttendanceHome(key: _attendanceHomeKey), // Home
//       const BatchMarkScreen(), // Mark
//       const HistoryScreen(), // History
//       const SettingsScreen(), // Settings
//     ];
//   }

//   void _onTap(int index) {
//     setState(() => _currentIndex = index);
//   }

//   @override
//   Widget build(BuildContext context) {
//     // set system navigation bar color to match the nav container
//     final Color navBarColor = Theme.of(context).scaffoldBackgroundColor;
//     final Brightness navIconBrightness =
//         Theme.of(context).brightness == Brightness.dark
//         ? Brightness.light
//         : Brightness.dark;
//     SystemChrome.setSystemUIOverlayStyle(
//       SystemUiOverlayStyle(
//         systemNavigationBarColor: navBarColor,
//         systemNavigationBarIconBrightness: navIconBrightness,
//         systemNavigationBarDividerColor: navBarColor,
//       ),
//     );

//     // Modern elevated rounded container for nav
//     return Scaffold(
//       // show selected page
//       body: SafeArea(child: _pages[_currentIndex]),

//       // Bottom navigation with modern styling
//       bottomNavigationBar: SafeArea(
//         top: false,
//         bottom: true,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
//           child: PhysicalShape(
//             elevation: 0,
//             color: Theme.of(context).scaffoldBackgroundColor,

//             clipper: ShapeBorderClipper(
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(0),
//               ),
//             ),
//             child: Container(
//               height: 75,
//               decoration: BoxDecoration(
//                 color: Theme.of(context).scaffoldBackgroundColor,
//                 borderRadius: BorderRadius.circular(0),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _NavItem(
//                     index: 0,
//                     currentIndex: _currentIndex,
//                     icon: Icons.home_rounded,
//                     label: 'Home',
//                     onTap: _onTap,
//                   ),
//                   _NavItem(
//                     index: 1,
//                     currentIndex: _currentIndex,
//                     icon: Icons.add_box_rounded,
//                     label: 'Mark',
//                     onTap: _onTap,
//                   ),
//                   _NavItem(
//                     index: 2,
//                     currentIndex: _currentIndex,
//                     icon: Icons.history_rounded,
//                     label: 'History',
//                     onTap: _onTap,
//                   ),
//                   _NavItem(
//                     index: 3,
//                     currentIndex: _currentIndex,
//                     icon: Icons.settings_rounded,
//                     label: 'Settings',
//                     onTap: _onTap,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Small nav item widget for consistent modern look
// class _NavItem extends StatelessWidget {
//   final int index;
//   final int currentIndex;
//   final IconData icon;
//   final String label;
//   final void Function(int) onTap;

//   const _NavItem({
//     required this.index,
//     required this.currentIndex,
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final bool selected = index == currentIndex;
//     final Color primary = Theme.of(context).colorScheme.primary;
//     final Color iconColor = selected
//         ? primary
//         : Theme.of(context).iconTheme.color!.withOpacity(0.7);
//     final TextStyle labelStyle = selected
//         ? Theme.of(context).textTheme.bodySmall!.copyWith(
//             color: primary,
//             fontWeight: FontWeight.w600,
//           )
//         : Theme.of(context).textTheme.bodySmall!.copyWith(
//             color: Theme.of(
//               context,
//             ).textTheme.bodySmall!.color!.withOpacity(0.7),
//           );

//     return Expanded(
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () => onTap(index),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 decoration: selected
//                     ? BoxDecoration(
//                         color: primary.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(10),
//                       )
//                     : null,
//                 padding: const EdgeInsets.all(6),
//                 child: Icon(icon, size: 22, color: iconColor),
//               ),
//               const SizedBox(height: 6),
//               Text(label, style: labelStyle),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Mark screen: dedicated page to launch batch marking or quick single marks
// class BatchMarkScreen extends StatefulWidget {
//   const BatchMarkScreen({super.key});

//   @override
//   State<BatchMarkScreen> createState() => _BatchMarkScreenState();
// }

// class _BatchMarkScreenState extends State<BatchMarkScreen> {
//   List<Subject> _subjects = [];
//   Map<String, bool> _sel = {};
//   DateTime _selectedDate = DateTime.now();
//   String _search = '';
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final subs = await FirestoreService.instance.getAllSubjects();
//       final map = {for (var s in subs) s.id!: false};
//       setState(() {
//         _subjects = subs;
//         _sel = map;
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to load subjects: $e')));
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   List<Subject> get _filteredSubjects {
//     final q = _search.trim().toLowerCase();
//     if (q.isEmpty) return _subjects;
//     return _subjects.where((s) => s.name.toLowerCase().contains(q)).toList();
//   }

//   int get selectedCount => _sel.values.where((v) => v).length;


//   Future<void> _confirmBatchMark(bool markAttended) async {
//     final selectedIds = _sel.entries
//         .where((e) => e.value)
//         .map((e) => e.key)
//         .toList();
//     if (selectedIds.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No subjects selected')));
//       return;
//     }
//     final iso = DateFormat('yyyy-MM-dd').format(_selectedDate);

//     final List<Map<String, dynamic>> snapshots = [];

//     for (final sid in selectedIds) {
//       try {
//         final existing = await FirestoreService.instance
//             .getRecordForSubjectAndDate(sid, iso);
//         if (existing != null) {
//           snapshots.add({
//             'subjectId': sid,
//             'previous': AttendanceRecord.fromMap({
//               'id': existing.id,
//               'subjectId': existing.subjectId,
//               'date': existing.date,
//               'held': existing.held,
//               'attended': existing.attended,
//             }),
//             'resultId': existing.id,
//           });

//           existing.held += 1;
//           if (markAttended) existing.attended += 1;
//           await FirestoreService.instance.updateRecord(existing);
//         } else {
//           snapshots.add({'subjectId': sid, 'previous': null, 'resultId': null});
//           final created = AttendanceRecord(
//             subjectId: sid,
//             date: iso,
//             held: 1,
//             attended: markAttended ? 1 : 0,
//           );
//           await FirestoreService.instance.insertRecord(created);
//           final found = await FirestoreService.instance
//               .getRecordForSubjectAndDate(sid, iso);
//           if (found != null) snapshots.last['resultId'] = found.id;
//         }
//       } catch (e) {
//         // continue with others; optionally collect errors
//         print('Batch mark failed for $sid: $e');
//       }
//     }

//     // After operations, show snackbar with Undo
//     await _refreshAndShowUndo(snapshots, iso, selectedIds.length);
//   }

//   Future<void> _refreshAndShowUndo(
//     List<Map<String, dynamic>> snapshots,
//     String iso,
//     int count,
//   ) async {
//     // refresh UI (if needed)
//     await _load();

//     final snack = SnackBar(
//       content: Text(
//         '$count subjects marked for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
//       ),
//       action: SnackBarAction(
//         label: 'Undo',
//         onPressed: () async {
//           await _revertBatch(snapshots);
//         },
//       ),
//       duration: const Duration(seconds: 6),
//     );

//     if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
//   }

//   Future<void> _revertBatch(List<Map<String, dynamic>> snapshots) async {
//     for (final snap in snapshots) {
//       final String sid = snap['subjectId'];
//       final AttendanceRecord? prev = snap['previous'] as AttendanceRecord?;
//       final String? resultId = snap['resultId'] as String?;

//       try {
//         if (prev == null) {
//           // newly created record — delete by id if we have it, otherwise attempt lookup and delete
//           String? idToDelete = resultId;
//           if (idToDelete == null) {
//             final found = await FirestoreService.instance
//                 .getRecordForSubjectAndDate(
//                   sid,
//                   DateFormat('yyyy-MM-dd').format(_selectedDate),
//                 );
//             idToDelete = found?.id;
//           }
//           if (idToDelete != null)
//             await FirestoreService.instance.deleteRecord(idToDelete);
//         } else {
//           // existed before — restore previous values
//           final restoreId = prev.id ?? resultId;
//           if (restoreId != null) {
//             final restore = AttendanceRecord(
//               id: restoreId,
//               subjectId: prev.subjectId,
//               date: prev.date,
//               held: prev.held,
//               attended: prev.attended,
//             );
//             await FirestoreService.instance.updateRecord(restore);
//           } else {
//             final fetched = await FirestoreService.instance
//                 .getRecordForSubjectAndDate(prev.subjectId, prev.date);
//             if (fetched != null) {
//               fetched.held = prev.held;
//               fetched.attended = prev.attended;
//               await FirestoreService.instance.updateRecord(fetched);
//             }
//           }
//         }
//       } catch (e) {
//         print('Undo failed for $sid: $e');
//       }
//     }
//     await _load();
//     if (mounted)
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Changes undone')));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Batch Mark Attendance')),
//       body: SafeArea(
//         child: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : Column(
//                 children: [
//                   // calendar header
//                   Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             DateFormat('MMMM d, yyyy').format(_selectedDate),
//                             style: Theme.of(context).textTheme.titleMedium
//                                 ?.copyWith(fontWeight: FontWeight.w600),
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.calendar_today_outlined),
//                           onPressed: () async {
//                             final picked = await showDatePicker(
//                               context: context,
//                               initialDate: _selectedDate,
//                               firstDate: DateTime(2000),
//                               lastDate: _maxPickableDate(),
//                             );
//                             if (picked != null)
//                               setState(() => _selectedDate = picked);
//                           },
//                         ),
//                       ],
//                     ),
//                   ),

//                   SizedBox(
//                     // height: 175,
//                     child: TableCalendar(
//                       firstDay: DateTime(2000),
//                       lastDay: _maxPickableDate(),
//                       focusedDay: _selectedDate,
//                       selectedDayPredicate: (d) =>
//                           DateFormat('yyyy-MM-dd').format(d) ==
//                           DateFormat('yyyy-MM-dd').format(_selectedDate),
//                       onDaySelected: (d, _) =>
//                           setState(() => _selectedDate = d),
//                       headerVisible: false,
//                       calendarStyle: CalendarStyle(
//                         todayDecoration: BoxDecoration(
//                           color: Theme.of(
//                             context,
//                           ).colorScheme.primary.withOpacity(0.9),
//                           shape: BoxShape.circle,
//                         ),
//                         selectedDecoration: BoxDecoration(
//                           color: Theme.of(context).colorScheme.primary,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                     ),
//                   ),

//                   Expanded(
//                     child: ListView.separated(
//                       padding: const EdgeInsets.symmetric(horizontal: 8),
//                       itemCount: _filteredSubjects.length,
//                       separatorBuilder: (_, __) => const Divider(height: 1),
//                       itemBuilder: (context, i) {
//                         final s = _filteredSubjects[i];
//                         final sid = s.id!;
//                         final checked = _sel[sid] ?? false;
//                         return CheckboxListTile(
//                           value: checked,
//                           title: Text(s.name),
//                           subtitle: Text(
//                             s.isLab ? 'Lab (2 pts)' : 'Lecture (1 pt)',
//                           ),
//                           onChanged: (v) =>
//                               setState(() => _sel[sid] = v ?? false),
//                         );
//                       },
//                     ),
//                   ),

//                   Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: () => Navigator.pop(context),
//                             child: const Text('Cancel'),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: selectedCount > 0
//                                 ? () => _confirmBatchMark(true)
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.green,
//                             ),
//                             child: Text('Mark Attended ($selectedCount)'),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: selectedCount > 0
//                                 ? () => _confirmBatchMark(false)
//                                 : null,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red,
//                             ),
//                             child: Text('Mark Missed ($selectedCount)'),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }
// }

// /// Settings screen placeholder — add your settings here (dark mode toggle, notifications, etc.)
// class SettingsScreen extends StatelessWidget {
//   const SettingsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Settings'),
//         automaticallyImplyLeading: false,
//       ),
//       body: SafeArea(
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             SwitchListTile(
//               title: const Text('Dark mode'),
//               subtitle: const Text('Toggle app dark mode'),
//               value: isDarkMode.value,
//               onChanged: (v) => isDarkMode.value = v,
//             ),
//             const SizedBox(height: 8),
//             ListTile(
//               leading: const Icon(Icons.notifications),
//               title: const Text('Low attendance notifications'),
//               subtitle: const Text('Enable or disable attendance reminders'),
//               trailing: const Icon(Icons.chevron_right),
//               onTap: () {
//                 // open settings details or toggle a preference
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Open notification settings')),
//                 );
//               },
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'App version: 1.0.0',
//               style: Theme.of(context).textTheme.bodySmall,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class HistoryScreen extends StatefulWidget {
//   const HistoryScreen({super.key});

//   @override
//   State<HistoryScreen> createState() => _HistoryScreenState();
// }

// class _HistoryScreenState extends State<HistoryScreen> {
//   List<String> _dates = [];
//   List<String> _filteredDates = [];
//   Map<String, List<AttendanceRecord>> _recordsByDate = {};
//   List<Subject> _subjects = [];

//   // Filters / UI state
//   String _searchQuery = '';
//   String? _selectedSubjectId; // null == all subjects
//   String? _selectedMonthLabel; // e.g. "September 2025"
//   List<String> _monthLabels = [];
//   bool _showCalendar = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadDates();
//   }

//   Future<void> _deleteDate(String date) async {
//     final readable = _formatDate(date);
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Delete all attendance'),
//         content: Text(
//           'Are you sure you want to delete all attendance records for $readable? This cannot be undone.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (confirm != true) return;

//     try {
//       await FirestoreService.instance.deleteRecordsForDate(date);
//       // refresh UI
//       await _loadDates();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Deleted all attendance for $readable')),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Failed to delete records: $e')));
//     }
//   }

//   Future<void> _loadDates() async {
//     // Load dates and records (and subjects) from repository (works offline via Repository)
//     final dates = await FirestoreService.instance.getUniqueDates();
//     final allRecords = await FirestoreService.instance.getAllRecords();
//     final allSubjects = await FirestoreService.instance.getAllSubjects();

//     // Build recordsByDate map
//     final Map<String, List<AttendanceRecord>> map = {};
//     for (var r in allRecords) {
//       map.putIfAbsent(r.date, () => []).add(r);
//     }

//     // Build month labels (unique month-year labels from dates)
//     final monthSet = <String>{};
//     for (var d in dates) {
//       final dt = DateTime.parse(d);
//       monthSet.add(DateFormat('MMMM yyyy').format(dt));
//     }
//     final months = monthSet.toList()
//       ..sort((a, b) {
//         // sort by date descending using parsed month-year - convert back to DateTime for sorting
//         DateTime pa = DateFormat('MMMM yyyy').parse(a);
//         DateTime pb = DateFormat('MMMM yyyy').parse(b);
//         return pb.compareTo(pa);
//       });

//     setState(() {
//       _dates = dates;
//       _recordsByDate = map;
//       _subjects = allSubjects;
//       _monthLabels = months;
//     });

//     _applyFilters();
//   }

//   void _applyFilters() {
//     List<String> result = _dates.where((dateStr) {
//       // 1) search filter: check date formatted string or ISO date contains search text
//       final formatted = DateFormat(
//         'MMMM d, yyyy',
//       ).format(DateTime.parse(dateStr));
//       final searchLower = _searchQuery.trim().toLowerCase();
//       if (searchLower.isNotEmpty) {
//         if (!(formatted.toLowerCase().contains(searchLower) ||
//             dateStr.toLowerCase().contains(searchLower))) {
//           return false;
//         }
//       }

//       // 2) month filter
//       if (_selectedMonthLabel != null) {
//         final monthLabel = DateFormat(
//           'MMMM yyyy',
//         ).format(DateTime.parse(dateStr));
//         if (monthLabel != _selectedMonthLabel) return false;
//       }

//       // 3) subject filter: if selected, only include dates that have at least one record for that subject
//       if (_selectedSubjectId != null) {
//         final records = _recordsByDate[dateStr] ?? [];
//         final has = records.any((r) => r.subjectId == _selectedSubjectId);
//         if (!has) return false;
//       }

//       return true;
//     }).toList();

//     // Keep descending date order (same as your existing approach)
//     result.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));

//     setState(() {
//       _filteredDates = result;
//     });
//   }

//   Future<void> _onSearchChanged(String q) async {
//     setState(() => _searchQuery = q);
//     _applyFilters();
//   }

//   Future<void> _onSelectedSubjectChanged(String? subjectId) async {
//     setState(() => _selectedSubjectId = subjectId);
//     _applyFilters();
//   }

//   Future<void> _onMonthChanged(String? monthLabel) async {
//     setState(() => _selectedMonthLabel = monthLabel);
//     _applyFilters();
//   }

//   // Helper: build dropdown items for subjects (include "All subjects")
//   List<DropdownMenuItem<String?>> _subjectDropdownItems() {
//     final items = <DropdownMenuItem<String?>>[];
//     items.add(
//       const DropdownMenuItem<String?>(value: null, child: Text('All subjects')),
//     );
//     for (var s in _subjects) {
//       items.add(DropdownMenuItem<String?>(value: s.id, child: Text(s.name)));
//     }
//     return items;
//   }

//   List<DropdownMenuItem<String?>> _monthDropdownItems() {
//     final items = <DropdownMenuItem<String?>>[];
//     items.add(
//       const DropdownMenuItem<String?>(value: null, child: Text('All months')),
//     );
//     for (var m in _monthLabels) {
//       items.add(DropdownMenuItem<String?>(value: m, child: Text(m)));
//     }
//     return items;
//   }

//   // Calendar event loader for TableCalendar: convert DateTime->List of records for that date
//   List<AttendanceRecord> _eventsForDay(DateTime day) {
//     final key = DateFormat('yyyy-MM-dd').format(day);
//     return _recordsByDate[key] ?? [];
//   }

//   // When selecting a day on the calendar, navigate if there are records or allow navigation anyway
//   void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
//     final iso = DateFormat('yyyy-MM-dd').format(selectedDay);
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => EditDayScreen(date: iso)),
//     ).then((_) => _loadDates());
//   }

//   // Format date for list display
//   String _formatDate(String date) {
//     return DateFormat('MMMM d, yyyy').format(DateTime.parse(date));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Attendance History')),
//       body: SafeArea(
//         bottom: true,
//         child: Column(
//           children: [
//             // Search bar + calendar toggle
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       decoration: const InputDecoration(
//                         prefixIcon: Icon(Icons.search),
//                         hintText:
//                             'Search by date (e.g. September 3, 2025) or ISO (yyyy-mm-dd)',
//                         border: OutlineInputBorder(),
//                         isDense: true,
//                       ),
//                       onChanged: _onSearchChanged,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   IconButton(
//                     tooltip: 'Toggle calendar view',
//                     icon: Icon(
//                       _showCalendar ? Icons.view_list : Icons.calendar_today,
//                     ),
//                     onPressed: () =>
//                         setState(() => _showCalendar = !_showCalendar),
//                   ),
//                 ],
//               ),
//             ),

//             // Filters row: subject + month
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: DropdownButtonFormField<String?>(
//                       isExpanded: true,
//                       value: _selectedSubjectId,
//                       decoration: const InputDecoration(
//                         labelText: 'Filter by subject',
//                         isDense: true,
//                         border: OutlineInputBorder(),
//                       ),
//                       items: _subjectDropdownItems(),
//                       onChanged: _onSelectedSubjectChanged,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   SizedBox(
//                     width: 200,
//                     child: DropdownButtonFormField<String?>(
//                       isExpanded: true,
//                       value: _selectedMonthLabel,
//                       decoration: const InputDecoration(
//                         labelText: 'Filter by month',
//                         isDense: true,
//                         border: OutlineInputBorder(),
//                       ),
//                       items: _monthDropdownItems(),
//                       onChanged: _onMonthChanged,
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Calendar view or list view
//             Expanded(
//               child: _showCalendar
//                   ? Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       child: TableCalendar<AttendanceRecord>(
//                         firstDay: DateTime(2000),
//                         lastDay: DateTime.now(),
//                         focusedDay: DateTime.now(),
//                         availableCalendarFormats: const {
//                           CalendarFormat.month: 'Month',
//                         },
//                         calendarBuilders: CalendarBuilders(
//                           markerBuilder: (context, date, events) {
//                             final evs = _eventsForDay(date);
//                             if (evs.isEmpty) return const SizedBox.shrink();
//                             // small dot with count
//                             return Align(
//                               alignment: Alignment.bottomCenter,
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                   vertical: 2,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   borderRadius: BorderRadius.circular(12),
//                                   color: Colors.indigo[700],
//                                 ),
//                                 child: Text(
//                                   '${evs.length}',
//                                   style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                         eventLoader: (date) => _eventsForDay(date),
//                         onDaySelected: _onDaySelected,
//                       ),
//                     )
//                   : _filteredDates.isEmpty
//                   ? const Center(
//                       child: Text('No attendance records match the filter.'),
//                     )
//                   : ListView.builder(
//                       padding: const EdgeInsets.all(16),
//                       itemCount: _filteredDates.length,
//                       itemBuilder: (context, index) {
//                         final date = _filteredDates[index];
//                         final records = _recordsByDate[date] ?? [];
//                         // Build a subtitle listing subjects present that day (nice quick summary)
//                         final subjectNames = records
//                             .map(
//                               (r) => _subjects
//                                   .firstWhere(
//                                     (s) => s.id == r.subjectId,
//                                     orElse: () => Subject(name: 'Unknown'),
//                                   )
//                                   .name,
//                             )
//                             .toSet()
//                             .join(', ');

//                         return Card(
//                           margin: const EdgeInsets.only(bottom: 12),
//                           child: ListTile(
//                             title: Text(_formatDate(date)),
//                             subtitle: subjectNames.isNotEmpty
//                                 ? Text(subjectNames)
//                                 : null,
//                             trailing: Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 IconButton(
//                                   icon: const Icon(Icons.edit),
//                                   tooltip: 'Edit',
//                                   onPressed: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                         builder: (context) =>
//                                             EditDayScreen(date: date),
//                                       ),
//                                     ).then((_) => _loadDates());
//                                   },
//                                 ),
//                                 IconButton(
//                                   icon: const Icon(
//                                     Icons.delete,
//                                     color: Colors.red,
//                                   ),
//                                   tooltip: 'Delete all records for this date',
//                                   onPressed: () => _deleteDate(date),
//                                 ),
//                               ],
//                             ),

//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                   builder: (context) =>
//                                       EditDayScreen(date: date),
//                                 ),
//                               ).then((_) => _loadDates());
//                             },
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           DateTime? picked = await showDatePicker(
//             context: context,
//             initialDate: DateTime.now(),
//             firstDate: DateTime(2000),
//             lastDate: _maxPickableDate(), // allows adding future day entries
//           );

//           if (picked != null) {
//             String newDate = DateFormat('yyyy-MM-dd').format(picked);
//             Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => EditDayScreen(date: newDate),
//               ),
//             ).then((_) => _loadDates());
//           }
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

// class EditDayScreen extends StatefulWidget {
//   final String date;

//   const EditDayScreen({super.key, required this.date});

//   @override
//   State<EditDayScreen> createState() => _EditDayScreenState();
// }

// class _EditDayScreenState extends State<EditDayScreen> {
//   List<Subject> _subjects = [];
//   List<AttendanceRecord> _dayRecords = [];
//   Map<String, TextEditingController> _heldControllers = {};
//   Map<String, TextEditingController> _attendedControllers = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   Future<void> _loadData() async {
//     List<Subject> subjects = await FirestoreService.instance.getAllSubjects();
//     List<AttendanceRecord> records = await FirestoreService.instance
//         .getRecordsForDate(widget.date);
//     setState(() {
//       _subjects = subjects;
//       _dayRecords = records;
//       _heldControllers.clear();
//       _attendedControllers.clear();
//       for (var record in _dayRecords) {
//         _heldControllers[record.id!] = TextEditingController(
//           text: record.held.toString(),
//         );
//         _attendedControllers[record.id!] = TextEditingController(
//           text: record.attended.toString(),
//         );
//       }
//     });
//   }

//   Future<void> _saveChanges() async {
//     bool valid = true;
//     for (var record in _dayRecords) {
//       int? newHeld = int.tryParse(_heldControllers[record.id!]!.text);
//       int? newAttended = int.tryParse(_attendedControllers[record.id!]!.text);
//       if (newHeld == null ||
//           newAttended == null ||
//           newAttended > newHeld ||
//           newHeld < 0 ||
//           newAttended < 0) {
//         valid = false;
//         break;
//       }
//       record.held = newHeld;
//       record.attended = newAttended;
//       await FirestoreService.instance.updateRecord(record);
//     }
//     if (!valid) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Invalid input: attended <= held, non-negative'),
//         ),
//       );
//     } else {
//       Navigator.pop(context);
//     }
//   }

//   Future<void> _addNewRecord() async {
//     List<Subject> availableSubjects = _subjects
//         .where((s) => !_dayRecords.any((r) => r.subjectId == s.id))
//         .toList();
//     if (availableSubjects.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No more subjects to add')));
//       return;
//     }

//     Subject? selectedSubject = availableSubjects.first;
//     String heldText = '1';
//     String attendedText = '0';

//     await showDialog(
//       context: context,
//       builder: (BuildContext dialogContext) => StatefulBuilder(
//         builder: (BuildContext context, StateSetter dialogSetState) =>
//             AlertDialog(
//               title: const Text('Add Record'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   DropdownButton<Subject>(
//                     value: selectedSubject,
//                     onChanged: (Subject? newValue) {
//                       dialogSetState(() => selectedSubject = newValue);
//                     },
//                     items: availableSubjects.map((Subject subject) {
//                       return DropdownMenuItem<Subject>(
//                         value: subject,
//                         child: Text(subject.name),
//                       );
//                     }).toList(),
//                   ),
//                   TextField(
//                     decoration: const InputDecoration(
//                       labelText: 'Sessions Held',
//                     ),
//                     keyboardType: TextInputType.number,
//                     onChanged: (value) => heldText = value,
//                   ),
//                   TextField(
//                     decoration: const InputDecoration(
//                       labelText: 'Sessions Attended',
//                     ),
//                     keyboardType: TextInputType.number,
//                     onChanged: (value) => attendedText = value,
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () => Navigator.pop(dialogContext),
//                   child: const Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () async {
//                     int? held = int.tryParse(heldText);
//                     int? attended = int.tryParse(attendedText);
//                     if (held != null &&
//                         attended != null &&
//                         attended <= held &&
//                         held >= 0 &&
//                         attended >= 0) {
//                       AttendanceRecord newRecord = AttendanceRecord(
//                         subjectId: selectedSubject!.id!,
//                         date: widget.date,
//                         held: held,
//                         attended: attended,
//                       );
//                       await FirestoreService.instance.insertRecord(newRecord);
//                       AttendanceMonitor.instance.checkSubject(
//                         newRecord.subjectId,
//                       );

//                       _loadData();
//                       Navigator.pop(dialogContext);
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Invalid input')),
//                       );
//                     }
//                   },
//                   child: const Text('Add'),
//                 ),
//               ],
//             ),
//       ),
//     );
//   }

//   Future<void> _deleteRecord(AttendanceRecord record) async {
//     Subject? subject = _subjects.firstWhere(
//       (s) => s.id == record.subjectId,
//       orElse: () => Subject(name: 'Unknown'),
//     );

//     bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) => AlertDialog(
//         title: const Text('Delete Record'),
//         content: Text(
//           'Are you sure you want to delete the attendance record for ${subject.name} on ${_formatDate(record.date)}?',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       try {
//         await FirestoreService.instance.deleteRecord(record.id!);
//         _loadData();
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Record deleted successfully')));
//       } catch (e) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to delete record: $e')));
//       }
//     }
//   }

//   String _formatDate(String date) {
//     return DateFormat('MMMM d, yyyy').format(DateTime.parse(date));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Edit ${_formatDate(widget.date)}'),
//         actions: [
//           IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
//         ],
//       ),
//       body: SafeArea(
//         bottom: true,
//         child: _dayRecords.isEmpty
//             ? const Center(child: Text('No records for this day.'))
//             : ListView.builder(
//                 padding: const EdgeInsets.all(16),
//                 itemCount: _dayRecords.length,
//                 itemBuilder: (context, index) {
//                   AttendanceRecord record = _dayRecords[index];
//                   Subject? subject = _subjects.firstWhere(
//                     (s) => s.id == record.subjectId,
//                     orElse: () => Subject(name: 'Unknown'),
//                   );
//                   return Card(
//                     margin: const EdgeInsets.only(bottom: 16),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 subject.name,
//                                 style: Theme.of(
//                                   context,
//                                 ).textTheme.headlineMedium,
//                               ),
//                               IconButton(
//                                 icon: const Icon(
//                                   Icons.delete,
//                                   color: Colors.red,
//                                 ),
//                                 onPressed: () => _deleteRecord(record),
//                               ),
//                             ],
//                           ),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: TextField(
//                                   controller: _heldControllers[record.id],
//                                   decoration: const InputDecoration(
//                                     labelText: 'Held',
//                                   ),
//                                   keyboardType: TextInputType.number,
//                                 ),
//                               ),
//                               const SizedBox(width: 16),
//                               Expanded(
//                                 child: TextField(
//                                   controller: _attendedControllers[record.id],
//                                   decoration: const InputDecoration(
//                                     labelText: 'Attended',
//                                   ),
//                                   keyboardType: TextInputType.number,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _addNewRecord,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
