import 'dart:async';
import 'package:app/features/scorm_view.dart';
import 'package:app/features/scorm_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    // Wrap the app with ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (context) => ScormViewModel(),  // Provide ScormViewModel
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crash Logger',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorKey: navigatorKey, // Set the navigator key here
      home: ScormView(),
    );
  }
}
