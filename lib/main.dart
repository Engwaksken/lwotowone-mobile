import 'package:flutter/material.dart';
import 'services/repository.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'theme.dart';

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
    theme: buildTheme(),
    home: AnimatedBuilder(
      animation: repo,
      builder: (context, _) =>
          repo.loggedIn ? Home(repo: repo) : Login(repo: repo),
    ),
  );
}
