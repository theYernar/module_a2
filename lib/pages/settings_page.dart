import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppService _service = AppService.instance;

  late double _bgmVolume;
  late double _sfxVolume;

  Timer? _bgmStopTimer;
  Timer? _sfxStopTimer;

  @override
  void initState() {
    super.initState();
    _bgmVolume = _service.bgmVolume;
    _sfxVolume = _service.sfxVolume;
  }

  @override
  void dispose() {
    _bgmStopTimer?.cancel();
    _sfxStopTimer?.cancel();
    _service.stopBgm();
    _service.stopSfx();
    super.dispose();
  }

  void _onBgmDragStart(double value) {
    _bgmStopTimer?.cancel();
    _sfxStopTimer?.cancel();
    _service.stopSfx();
    _service.startGameplayBgm();
    _service.setBgmVolumeRealtime(value);
  }

  void _onBgmChanged(double value) {
    setState(() => _bgmVolume = value);
    _service.setBgmVolumeRealtime(value);
    _service.saveSettings(bgm: _bgmVolume, sfx: _sfxVolume);
  }

  void _onBgmDragEnd(double value) {
    _bgmStopTimer?.cancel();
    _bgmStopTimer = Timer(const Duration(seconds: 1), () {
      _service.stopBgm();
    });
  }

  void _onSfxDragStart(double value) {
    _sfxStopTimer?.cancel();
    _bgmStopTimer?.cancel();
    _service.stopBgm();
    _service.playSfx('buy.mp3', loop: true, volume: value);
  }

  void _onSfxChanged(double value) {
    setState(() => _sfxVolume = value);
    _service.setSfxVolumeRealtime(value);
    _service.saveSettings(bgm: _bgmVolume, sfx: _sfxVolume);
  }

  void _onSfxDragEnd(double value) {
    _sfxStopTimer?.cancel();
    _sfxStopTimer = Timer(const Duration(seconds: 1), () {
      _service.stopSfx();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/scenes/background.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Bar with Back Button and Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Material(
                        color: const Color(0xFFD68910),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 38,
                            height: 38,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Settings Card
                Expanded(
                  child: Center(
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Game Difficulty (Easy mode only)
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/scenes/difficulty.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Game Difficulty',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.radio_button_checked,
                                color: Color(0xFFD68910),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Easy',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Background Music Volume Slider
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/scenes/background_music.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Background Music',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                              Text(
                                '${(_bgmVolume * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFD68910),
                              inactiveTrackColor: const Color(0xFFF5CBA7),
                              thumbColor: const Color(0xFFD68910),
                            ),
                            child: Slider(
                              value: _bgmVolume,
                              min: 0.0,
                              max: 1.0,
                              onChangeStart: _onBgmDragStart,
                              onChanged: _onBgmChanged,
                              onChangeEnd: _onBgmDragEnd,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Game Sound Effects Volume Slider
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/scenes/sound_effect.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Game Sound Effects',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              ),
                              Text(
                                '${(_sfxVolume * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFD68910),
                              inactiveTrackColor: const Color(0xFFF5CBA7),
                              thumbColor: const Color(0xFFD68910),
                            ),
                            child: Slider(
                              value: _sfxVolume,
                              min: 0.0,
                              max: 1.0,
                              onChangeStart: _onSfxDragStart,
                              onChanged: _onSfxChanged,
                              onChangeEnd: _onSfxDragEnd,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

