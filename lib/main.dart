import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:physical_therapy/app/app.dart';
import 'package:physical_therapy/core/services/reminder_service.dart';
import 'package:physical_therapy/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final initialUser = FirebaseAuth.instance.currentUser;
  debugPrint(
    '[AUTHDIAG] main() post-init: currentUser=${initialUser?.uid ?? "null"}, isNull=${initialUser == null}',
  );
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint(
      '[AUTHDIAG] authStateChanges (${DateTime.now().toIso8601String()}): uid=${user?.uid ?? "null"}',
    );
  });
  FirebaseAuth.instance.idTokenChanges().listen((user) {
    debugPrint(
      '[AUTHDIAG] idTokenChanges (${DateTime.now().toIso8601String()}): uid=${user?.uid ?? "null"}',
    );
  });
  await initializeDateFormatting('ar');
  await ReminderService().initialize();
  runApp(const PhysioApp());
}