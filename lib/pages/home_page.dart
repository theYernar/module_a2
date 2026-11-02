import 'package:flutter/material.dart';
import '../utils/app_service.dart';
import 'game_page.dart';
import 'records_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppService _service = AppService.instance;

  Future<void> _openGame({required bool resume}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GamePage(resumeUnfinished: resume),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openRecords() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordsPage()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasUnfinished = _service.unfinishedGame != null;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/scenes/background.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/scenes/logo.png',
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 36),
                    if (hasUnfinished) ...[
                      _MenuButton(
                        label: 'Continue',
                        width: 280,
                        height: 54,
                        color: const Color(0xFFB35432),
                        fontSize: 20,
                        onTap: () => _openGame(resume: true),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _MenuButton(
                      label: 'Start Game',
                      onTap: () => _openGame(resume: false),
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      label: 'Records',
                      onTap: _openRecords,
                    ),
                    const SizedBox(height: 14),
                    _MenuButton(
                      label: 'Settings',
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;
  final Color color;
  final double fontSize;

  const _MenuButton({
    required this.label,
    required this.onTap,
    this.width = 230,
    this.height = 46,
    this.color = const Color(0xFFD68910),
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

