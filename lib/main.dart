import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/home_page.dart';
import 'utils/app_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  await AppService.instance.init();
  runApp(const SilkRoadApp());
}

class SilkRoadApp extends StatelessWidget {
  const SilkRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silk Road Journey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD68910),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
