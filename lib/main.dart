import 'package:flutter/material.dart';
import 'services/repository.dart';
import 'screens/login.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = Repository();
  await repo.init();
  runApp(LwotowoneApp(repo: repo));
}

class LwotowoneApp extends StatelessWidget {
  final Repository repo;
  const LwotowoneApp({super.key, required this.repo});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Lwotowone',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff175742)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff6f8f3),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: AnimatedBuilder(
      animation: repo,
      builder: (context, _) =>
          repo.loggedIn ? Home(repo: repo) : Login(repo: repo),
    ),
  );
}
