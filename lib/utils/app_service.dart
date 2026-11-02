import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';

class AppService {
  AppService._();
  static final AppService instance = AppService._();

  static const int gridRows = 8;
  static const int gridCols = 12;

  late EasyConfig easyConfig;
  late List<List<MapCell>> grid;
  final Map<String, CityTradeConfig> cityTrades = {};

  SharedPreferences? _prefs;
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  double bgmVolume = 0.7;
  double sfxVolume = 0.8;
  bool onboardingDone = false;
  SavedGameState? unfinishedGame;
  List<GameRecord> records = [];

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _initAudioContext();
    await _loadJsonAssets();
    await _loadPersistentStorage();
    _initialized = true;
  }

  Future<void> _initAudioContext() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _loadJsonAssets() async {
    // 1. Load difficulties.json (Easy mode only)
    final diffStr = await rootBundle.loadString('assets/data/difficulties.json');
    final diffList = jsonDecode(diffStr) as List<dynamic>;
    final easyRaw = diffList.firstWhere(
      (e) => (e as Map)['difficulty'] == 'Easy',
      orElse: () => diffList.first,
    );
    easyConfig = EasyConfig.fromJson(Map<String, dynamic>.from(easyRaw as Map));

    // 2. Load map.json into 2D array grid[row][col]
    grid = List.generate(
      gridRows,
      (r) => List.generate(gridCols, (c) => MapCell(row: r, col: c)),
    );
    final mapStr = await rootBundle.loadString('assets/data/map.json');
    final mapList = jsonDecode(mapStr) as List<dynamic>;
    for (final item in mapList) {
      final map = Map<String, dynamic>.from(item as Map);
      final col = (map['positionX'] as num).toInt();
      final row = (map['positionY'] as num).toInt();
      if (row >= 0 && row < gridRows && col >= 0 && col < gridCols) {
        grid[row][col] = MapCell(
          row: row,
          col: col,
          type: map['type'] as String? ?? 'plain',
          name: map['name'] as String? ?? '',
        );
      }
    }

    // 3. Load trades.json
    cityTrades.clear();
    final tradeStr = await rootBundle.loadString('assets/data/trades.json');
    final tradeList = jsonDecode(tradeStr) as List<dynamic>;
    for (final item in tradeList) {
      final cfg =
          CityTradeConfig.fromJson(Map<String, dynamic>.from(item as Map));
      cityTrades[cfg.city] = cfg;
    }
  }

  Future<void> _loadPersistentStorage() async {
    _prefs = await SharedPreferences.getInstance();

    // Parse settings
    final settingsRaw = _prefs?.getString('settings');
    if (settingsRaw != null && settingsRaw.isNotEmpty) {
      try {
        final map = jsonDecode(settingsRaw) as Map<String, dynamic>;
        bgmVolume =
            ((map['bgmVolume'] as num?)?.toDouble() ?? 0.7).clamp(0.0, 1.0);
        sfxVolume =
            ((map['sfxVolume'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0);
      } catch (_) {}
    }

    // Parse onboarding flag
    onboardingDone = _prefs?.getBool('onboarding_done') ?? false;

    // Parse unfinished game
    final unfinishedRaw = _prefs?.getString('unfinished_game');
    if (unfinishedRaw != null && unfinishedRaw.isNotEmpty) {
      try {
        unfinishedGame = SavedGameState.fromJson(
          Map<String, dynamic>.from(jsonDecode(unfinishedRaw) as Map),
        );
      } catch (_) {
        unfinishedGame = null;
      }
    }

    // Parse records
    final recordsRaw = _prefs?.getString('records');
    if (recordsRaw != null && recordsRaw.isNotEmpty) {
      try {
        final list = jsonDecode(recordsRaw) as List<dynamic>;
        records = list
            .map((e) => GameRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        records = [];
      }
    }
  }

  Future<void> saveSettings({
    required double bgm,
    required double sfx,
  }) async {
    bgmVolume = bgm.clamp(0.0, 1.0);
    sfxVolume = sfx.clamp(0.0, 1.0);
    await _prefs?.setString(
      'settings',
      jsonEncode({
        'difficulty': 'Easy',
        'bgmVolume': bgmVolume,
        'sfxVolume': sfxVolume,
      }),
    );
  }

  Future<void> markOnboardingDone() async {
    onboardingDone = true;
    await _prefs?.setBool('onboarding_done', true);
  }

  Future<void> saveUnfinishedGame(SavedGameState? state) async {
    unfinishedGame = state;
    if (state == null) {
      await _prefs?.remove('unfinished_game');
    } else {
      await _prefs?.setString('unfinished_game', jsonEncode(state.toJson()));
    }
  }

  Future<void> addGameRecord(GameRecord record) async {
    records.insert(0, record);
    await _prefs?.setString(
      'records',
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  // Brick grid adjacency:
  // Even rows (row % 2 == 0) are base rows;
  // Odd rows (row % 2 == 1) are shifted right by half a cell width (width / 2).
  List<(int, int)> getAdjacentCoords(int row, int col) {
    final isOdd = row % 2 == 1;
    final offsets = isOdd
        ? const [
            (0, -1),
            (0, 1),
            (-1, 0),
            (-1, 1),
            (1, 0),
            (1, 1),
          ]
        : const [
            (0, -1),
            (0, 1),
            (-1, -1),
            (-1, 0),
            (1, -1),
            (1, 0),
          ];

    final result = <(int, int)>[];
    for (final (dr, dc) in offsets) {
      final nr = row + dr;
      final nc = col + dc;
      if (nr >= 0 && nr < gridRows && nc >= 0 && nc < gridCols) {
        result.add((nr, nc));
      }
    }
    return result;
  }

  bool isAdjacent(int r1, int c1, int r2, int c2) {
    return getAdjacentCoords(r1, c1).any((pos) => pos.$1 == r2 && pos.$2 == c2);
  }

  MapCell findCityCell(String cityName) {
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (grid[r][c].type == 'city' && grid[r][c].name == cityName) {
          return grid[r][c];
        }
      }
    }
    return grid[5][11]; // Fallback to Changan
  }

  // Audio helpers using audioplayers
  Future<void> startGameplayBgm() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmVolume);
      await _bgmPlayer.play(AssetSource('audios/background.mp3'));
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> setBgmVolumeRealtime(double volume) async {
    try {
      await _bgmPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> playSfx(
    String fileName, {
    bool loop = false,
    double? volume,
  }) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.stop,
      );
      await _sfxPlayer.setVolume((volume ?? sfxVolume).clamp(0.0, 1.0));
      await _sfxPlayer.play(AssetSource('audios/$fileName'));
    } catch (_) {}
  }

  Future<void> setSfxVolumeRealtime(double volume) async {
    try {
      await _sfxPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> stopSfx() async {
    try {
      await _sfxPlayer.stop();
    } catch (_) {}
  }

  static String formatGoodName(String name) {
    return name
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  static String goodIconPath(String name) => 'assets/images/goods/$name.png';

  static String cityIconPath(String name) => 'assets/images/cities/$name.png';

  static String formatCurrentTime() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }
}
