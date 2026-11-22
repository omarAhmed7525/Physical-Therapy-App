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
  await initializeDateFormatting('ar');
  await ReminderService().initialize();
  runApp(const PhysioApp());
}