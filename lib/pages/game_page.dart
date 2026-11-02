import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../utils/app_service.dart';

class GamePage extends StatefulWidget {
  final bool resumeUnfinished;

  const GamePage({super.key, required this.resumeUnfinished});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final AppService _service = AppService.instance;

  late int _playerRow;
  late int _playerCol;
  late int _coins;
  late int _remainingDays;
  late Map<String, int> _currentGoods;
  late Map<String, int> _targetGoods;
  late List<CityTransaction> _transactions;
  late List<MoveSnapshot> _history;
  bool _hasActiveCitySession = false;

  String? _activeTradingCity;
  bool _isGameEnded = false;
  int? _onboardingStep; // 1, 2, 3 or null

  @override
  void initState() {
    super.initState();
    _initGame();
    _service.startGameplayBgm();
  }

  @override
  void dispose() {
    _service.stopBgm();
    super.dispose();
  }

  void _initGame({bool forceNew = false}) {
    final saved = !forceNew && widget.resumeUnfinished
        ? _service.unfinishedGame
        : null;

    if (saved != null) {
      _playerRow = saved.row;
      _playerCol = saved.col;
      _coins = saved.coins;
      _remainingDays = saved.remainingDays;
      _currentGoods = Map<String, int>.from(saved.currentGoods);
      _targetGoods = Map<String, int>.from(saved.targetGoods);
      _transactions = saved.transactions.map((t) => t.copy()).toList();
      _history = List<MoveSnapshot>.from(saved.history);
      _hasActiveCitySession = saved.hasActiveCitySession;
    } else {
      final cfg = _service.easyConfig;
      final startCell = _service.findCityCell(cfg.from);
      _playerRow = startCell.row;
      _playerCol = startCell.col;
      _coins = cfg.coins;
      _remainingDays = cfg.days;
      _currentGoods = {};
      _targetGoods = Map<String, int>.from(cfg.targets);
      _transactions = [];
      _history = [];
      _hasActiveCitySession = false;
      _persistUnfinishedState();
    }

    _activeTradingCity = null;
    _isGameEnded = false;
    _onboardingStep = _service.onboardingDone ? null : 1;
  }

  void _persistUnfinishedState() {
    if (_isGameEnded) return;
    _service.saveUnfinishedGame(
      SavedGameState(
        row: _playerRow,
        col: _playerCol,
        coins: _coins,
        remainingDays: _remainingDays,
        currentGoods: _currentGoods,
        targetGoods: _targetGoods,
        transactions: _transactions,
        history: _history,
        hasActiveCitySession: _hasActiveCitySession,
      ),
    );
  }

  bool _meetsTargetGoods() {
    for (final entry in _targetGoods.entries) {
      if ((_currentGoods[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  void _onCellTapped(int row, int col) {
    if (_isGameEnded || _onboardingStep != null) return;

    // Reopen trading panel if tapping the current city node before moving away
    if (row == _playerRow && col == _playerCol) {
      final currentCell = _service.grid[row][col];
      if (currentCell.type == 'city') {
        setState(() {
          _activeTradingCity = currentCell.name;
        });
      }
      return;
    }

    if (_remainingDays <= 0) return;
    if (!_service.isAdjacent(_playerRow, _playerCol, row, col)) return;

    // Save snapshot before moving for Undo support
    final snapshot = MoveSnapshot(
      row: _playerRow,
      col: _playerCol,
      coins: _coins,
      remainingDays: _remainingDays,
      currentGoods: _currentGoods,
      transactions: _transactions,
      hasActiveCitySession: _hasActiveCitySession,
    );

    final targetCell = _service.grid[row][col];

    setState(() {
      _history.add(snapshot);
      _playerRow = row;
      _playerCol = col;
      _remainingDays -= 1;
      _hasActiveCitySession = false;
      _activeTradingCity = null;
    });

    _service.playSfx('move.mp3');

    // Check Victory / Defeat conditions
    final destCity = _service.easyConfig.to; // "Roma"
    if (targetCell.type == 'city' && targetCell.name == destCity) {
      if (_meetsTargetGoods()) {
        _finishGame(succeeded: true);
      } else {
        _finishGame(succeeded: false);
      }
      return;
    }

    if (_remainingDays <= 0) {
      _finishGame(succeeded: false);
      return;
    }

    // Pop up trading panel if arriving at a city
    if (targetCell.type == 'city') {
      setState(() {
        _activeTradingCity = targetCell.name;
      });
    }

    _persistUnfinishedState();
  }

  void _onUndo() {
    if (_isGameEnded || _onboardingStep != null || _history.isEmpty) return;

    final last = _history.removeLast();
    setState(() {
      _playerRow = last.row;
      _playerCol = last.col;
      _coins = last.coins;
      _remainingDays = last.remainingDays;
      _currentGoods = Map<String, int>.from(last.currentGoods);
      _transactions = last.transactions.map((t) => t.copy()).toList();
      _hasActiveCitySession = last.hasActiveCitySession;
      _activeTradingCity = null;
    });

    _persistUnfinishedState();
  }

  CityTransaction _ensureCurrentCityTransaction(String city) {
    if (!_hasActiveCitySession ||
        _transactions.isEmpty ||
        _transactions.last.city != city) {
      final tx = CityTransaction(city: city);
      _transactions.add(tx);
      _hasActiveCitySession = true;
    }
    return _transactions.last;
  }

  void _buyGood( String city, TradeOffer offer) {
    if (_isGameEnded || _coins < offer.price) return;
    setState(() {
      _coins -= offer.price;
      _currentGoods[offer.name] = (_currentGoods[offer.name] ?? 0) + 1;
      final tx = _ensureCurrentCityTransaction(city);
      tx.purchased[offer.name] = (tx.purchased[offer.name] ?? 0) + 1;
    });
    _service.playSfx('buy.mp3');
    _persistUnfinishedState();
  }

  void _sellGood(String city, TradeOffer offer) {
    final held = _currentGoods[offer.name] ?? 0;
    if (_isGameEnded || held < 1) return;
    setState(() {
      _coins += offer.price;
      if (held == 1) {
        _currentGoods.remove(offer.name);
      } else {
        _currentGoods[offer.name] = held - 1;
      }
      final tx = _ensureCurrentCityTransaction(city);
      tx.sold[offer.name] = (tx.sold[offer.name] ?? 0) + 1;
    });
    _service.playSfx('sell.mp3');
    _persistUnfinishedState();
  }

  Future<void> _finishGame({required bool succeeded}) async {
    setState(() {
      _isGameEnded = true;
      _activeTradingCity = null;
    });

    await _service.saveUnfinishedGame(null);

    final usedDays = _service.easyConfig.days - _remainingDays;
    final cleanFinalGoods = <String, int>{};
    _currentGoods.forEach((k, v) {
      if (v > 0) cleanFinalGoods[k] = v;
    });

    final record = GameRecord(
      difficulty: 'Easy',
      succeeded: succeeded,
      endTime: AppService.formatCurrentTime(),
      usedDays: usedDays,
      coins: _coins,
      transactions: _transactions
          .where((t) => t.purchased.isNotEmpty || t.sold.isNotEmpty)
          .map((t) => t.copy())
          .toList(),
      finalGoods: cleanFinalGoods,
    );
    await _service.addGameRecord(record);

    if (!mounted) return;
    _showResultDialog(succeeded: succeeded);
  }

  void _showResultDialog({required bool succeeded}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBF0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              succeeded ? Icons.emoji_events : Icons.error_outline,
              color: succeeded ? const Color(0xFFD68910) : Colors.redAccent,
              size: 30,
            ),
            const SizedBox(width: 10),
            Text(
              succeeded ? 'Victory' : 'Defeat',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          succeeded
              ? 'You have completed the mission!'
              : 'You failed to finish the mission...',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (!succeeded)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD68910),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _initGame(forceNew: true);
                });
              },
              child: const Text('Retry'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB35432),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Return to Main Menu'),
          ),
        ],
      ),
    );
  }

  void _showHintsDialog() {
    if (_onboardingStep != null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFBF0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 540),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Color(0xFFD68910), size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Optimal Global Trading Solution (Easy)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHintSectionTitle(
                          'Strategy A: Maximum Coins Route (Final: 325 Coins, 25/26 Days)',
                        ),
                        const SizedBox(height: 8),
                        _buildHintStep(
                          step: '1',
                          city: 'Changan → Dunhuang (2 days)',
                          action: 'Buy: Tea ×3 (Cost: 150 coins, Remaining: 30 coins)',
                        ),
                        _buildHintStep(
                          step: '2',
                          city: 'Dunhuang → Samarkand (3 days)',
                          action: 'Sell: Tea ×3 (+195 coins, Balance: 225 coins)',
                        ),
                        _buildHintStep(
                          step: '3',
                          city: 'Samarkand → Dunhuang (3 days)',
                          action: 'Buy: Tea ×4 (Cost: 200 coins, Remaining: 25 coins)',
                        ),
                        _buildHintStep(
                          step: '4',
                          city: 'Dunhuang → Samarkand (3 days)',
                          action: 'Sell: Tea ×4 (+260 coins, Balance: 285 coins)',
                        ),
                        _buildHintStep(
                          step: '5',
                          city: 'Samarkand → Dunhuang (3 days)',
                          action:
                              'Buy: Silk ×1 (60) + Tea ×4 (200) (Cost: 260 coins, Remaining: 25 coins)',
                        ),
                        _buildHintStep(
                          step: '6',
                          city: 'Dunhuang → Constantinople (8 days)',
                          action:
                              'Sell: Tea ×3 (+300 coins, Balance: 325 coins; Keep Silk ×1, Tea ×1)',
                        ),
                        _buildHintStep(
                          step: '7',
                          city: 'Constantinople → Roma (3 days)',
                          action:
                              'Arrive at Roma with Silk ×1, Tea ×1 and 325 coins (1 day left).',
                        ),
                        const SizedBox(height: 16),
                        _buildHintSectionTitle(
                          'Strategy B: Direct Westbound Route (Final: 120 Coins, 13/26 Days)',
                        ),
                        const SizedBox(height: 8),
                        _buildHintStep(
                          step: '1',
                          city: 'Changan → Dunhuang (2 days)',
                          action:
                              'Buy: Silk ×1 (60) + Tea ×2 (100) (Cost: 160 coins, Remaining: 20 coins)',
                        ),
                        _buildHintStep(
                          step: '2',
                          city: 'Dunhuang → Samarkand → Baghdad → Constantinople (8 days)',
                          action:
                              'Sell in Constantinople: Tea ×1 (+100 coins, Balance: 120 coins)',
                        ),
                        _buildHintStep(
                          step: '3',
                          city: 'Constantinople → Roma (3 days)',
                          action:
                              'Arrive at Roma with Target Goods (Silk ×1, Tea ×1) and 120 coins.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEBD0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF873600),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHintStep({
    required String step,
    required String city,
    required String action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFD68910),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _nextOnboardingStep() {
    if (_onboardingStep == 1) {
      setState(() => _onboardingStep = 2);
    } else if (_onboardingStep == 2) {
      setState(() {
        _onboardingStep = 3;
        _activeTradingCity = 'Dunhuang';
      });
    } else if (_onboardingStep == 3) {
      _service.markOnboardingDone();
      setState(() {
        _onboardingStep = null;
        _activeTradingCity = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adjacentCoords = (_remainingDays > 0 && !_isGameEnded)
        ? _service.getAdjacentCoords(_playerRow, _playerCol).toSet()
        : <(int, int)>{};

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0CA),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Game Layout
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Logo, Current Goods, Target Goods
                  SizedBox(
                    width: 215,
                    child: _buildLeftColumn(),
                  ),
                  const SizedBox(width: 16),
                  // Right Area: Top Bar + Brick Grid Map
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildBrickGridMap(adjacentCoords),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Trading Panel Overlay (normal gameplay)
            if (_activeTradingCity != null && _onboardingStep == null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTradingCity = null),
                  child: Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {},
                      child: _buildTradingPanel(_activeTradingCity!),
                    ),
                  ),
                ),
              ),

            // First-time Onboarding Overlay (Steps 1, 2, 3)
            if (_onboardingStep != null)
              _buildOnboardingOverlay(adjacentCoords),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Row(
            children: [
              const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF873600)),
              const SizedBox(width: 4),
              Expanded(
                child: Image.asset(
                  'assets/images/scenes/logo.png',
                  height: 68,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildGoodsListsColumn(),
        ),
      ],
    );
  }

  Widget _buildGoodsListsColumn({bool highlighted = false}) {
    final heldEntries = _currentGoods.entries.where((e) => e.value > 0).toList();
    final targetEntries = _targetGoods.entries.toList();

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB300), width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 12),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _GoodsCard(
              iconPath: 'assets/images/scenes/bag.png',
              title: 'Current Goods',
              entries: heldEntries,
              emptyText: 'No goods yet',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: _GoodsCard(
              iconPath: 'assets/images/scenes/target.png',
              title: 'Target Goods',
              entries: targetEntries,
              emptyText: 'None',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final canUndo = _history.isNotEmpty && !_isGameEnded;

    return Row(
      children: [
        _ActionIconButton(
          icon: Icons.undo_rounded,
          tooltip: 'Undo',
          enabled: canUndo,
          onTap: _onUndo,
        ),
        const SizedBox(width: 10),
        _ActionIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: 'Hints',
          enabled: true,
          onTap: _showHintsDialog,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/scenes/difficulty.png', width: 22, height: 22),
              const SizedBox(width: 6),
              const Text(
                'Easy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 20),
              Image.asset('assets/images/scenes/gold.png', width: 22, height: 22),
              const SizedBox(width: 6),
              Text(
                '$_coins',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 20),
              Image.asset('assets/images/scenes/remaining.png', width: 22, height: 22),
              const SizedBox(width: 6),
              Text(
                '$_remainingDays',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrickGridMap(
    Set<(int, int)> adjacentCoords, {
    bool onlyRenderStepTwoHighlights = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        // 12 columns + 0.5 column shift for odd rows = 12.5 cell widths
        // 8 rows = 8.0 cell heights
        final cellW = maxW / (AppService.gridCols + 0.5);
        final cellH = maxH / AppService.gridRows;
        final cellSize = (cellW < cellH ? cellW : cellH).clamp(24.0, 120.0);

        final totalGridW = cellSize * (AppService.gridCols + 0.5);
        final totalGridH = cellSize * AppService.gridRows;
        final offsetX = (maxW - totalGridW) / 2;
        final offsetY = (maxH - totalGridH) / 2;

        double cellLeft(int row, int col) =>
            offsetX + col * cellSize + (row % 2 == 1 ? cellSize / 2 : 0);
        double cellTop(int row) => offsetY + row * cellSize;

        final children = <Widget>[];

        for (int r = 0; r < AppService.gridRows; r++) {
          for (int c = 0; c < AppService.gridCols; c++) {
            final isPlayerCell = (r == _playerRow && c == _playerCol);
            final isAdjacent = adjacentCoords.contains((r, c));

            if (onlyRenderStepTwoHighlights && !isPlayerCell && !isAdjacent) {
              continue;
            }

            final cell = _service.grid[r][c];
            children.add(
              Positioned(
                left: cellLeft(r, c),
                top: cellTop(r),
                width: cellSize,
                height: cellSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onCellTapped(r, c),
                  child: _buildBrickCellWidget(
                    cell: cell,
                    cellSize: cellSize,
                    isAdjacent: isAdjacent,
                    isPlayerCell: isPlayerCell,
                  ),
                ),
              ),
            );
          }
        }

        // Animated camel token for player position
        children.add(
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            left: cellLeft(_playerRow, _playerCol),
            top: cellTop(_playerRow),
            width: cellSize,
            height: cellSize,
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(cellSize * 0.08),
                child: Image.asset(
                  'assets/images/scenes/camel.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: children,
        );
      },
    );
  }

  Widget _buildBrickCellWidget({
    required MapCell cell,
    required double cellSize,
    required bool isAdjacent,
    required bool isPlayerCell,
  }) {
    final isSea = cell.type == 'sea';
    final bgColor = isSea
        ? const Color(0xFF38BFFA)
        : (isAdjacent ? const Color(0xFFFFEE88) : const Color(0xFFFDD848));

    final borderColor = isAdjacent
        ? const Color(0xFFE65100)
        : (isPlayerCell ? const Color(0xFF2E7D32) : const Color(0xFFE5B822));

    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: (isAdjacent || isPlayerCell) ? 2.5 : 1.0,
        ),
        boxShadow: isAdjacent
            ? const [
                BoxShadow(
                  color: Color(0x66E65100),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (cell.type == 'mountain')
            Padding(
              padding: EdgeInsets.all(cellSize * 0.06),
              child: Image.asset(
                'assets/images/scenes/hexagonal_mountain.png',
                fit: BoxFit.contain,
              ),
            ),
          if (cell.type == 'city') ...[
            Padding(
              padding: EdgeInsets.only(
                top: cellSize * 0.16,
                left: cellSize * 0.06,
                right: cellSize * 0.06,
                bottom: cellSize * 0.04,
              ),
              child: Image.asset(
                AppService.cityIconPath(cell.name),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFD68910), width: 0.8),
                ),
                child: Text(
                  cell.name,
                  style: TextStyle(
                    fontSize: (cellSize * 0.14).clamp(7.5, 11.0),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF873600),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradingPanel(String cityName, {bool isOnboardingPreview = false}) {
    final tradeConfig = _service.cityTrades[cityName];
    final buyingList = tradeConfig?.buyingList ?? const <TradeOffer>[];
    final sellingList = tradeConfig?.sellingList ?? const <TradeOffer>[];

    return Container(
      width: 580,
      constraints: const BoxConstraints(maxHeight: 440),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnboardingPreview
              ? const Color(0xFFFFB300)
              : const Color(0xFFD68910),
          width: isOnboardingPreview ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset(
                AppService.cityIconPath(cityName),
                width: 36,
                height: 36,
                errorBuilder: (_, _, _) => const Icon(Icons.location_city),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$cityName Trading Post',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/scenes/gold.png', width: 20, height: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$_coins',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Close',
                onPressed: isOnboardingPreview
                    ? null
                    : () => setState(() => _activeTradingCity = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buying Price List ("Buy" button)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buying Price List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF873600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: buyingList.isEmpty
                            ? const Center(
                                child: Text(
                                  'No goods available to buy',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : ListView.separated(
                                itemCount: buyingList.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, idx) {
                                  final offer = buyingList[idx];
                                  final canBuy = !isOnboardingPreview &&
                                      _coins >= offer.price;
                                  return _buildTradeItemRow(
                                    offer: offer,
                                    actionLabel: 'Buy',
                                    enabled: canBuy,
                                    onPressed: () => _buyGood(cityName, offer),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 24),
                // Selling Price List ("Sell" button)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selling Price List',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF873600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: sellingList.isEmpty
                            ? const Center(
                                child: Text(
                                  'No goods accepted for sale',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            : ListView.separated(
                                itemCount: sellingList.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, idx) {
                                  final offer = sellingList[idx];
                                  final heldQty =
                                      _currentGoods[offer.name] ?? 0;
                                  final canSell =
                                      !isOnboardingPreview && heldQty >= 1;
                                  return _buildTradeItemRow(
                                    offer: offer,
                                    actionLabel: 'Sell',
                                    enabled: canSell,
                                    onPressed: () => _sellGood(cityName, offer),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeItemRow({
    required TradeOffer offer,
    required String actionLabel,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5D5B5)),
      ),
      child: Row(
        children: [
          Image.asset(
            AppService.goodIconPath(offer.name),
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppService.formatGoodName(offer.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Row(
                  children: [
                    Image.asset('assets/images/scenes/gold.png',
                        width: 14, height: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${offer.price}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD68910),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: enabled ? onPressed : null,
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingOverlay(Set<(int, int)> adjacentCoords) {
    final step = _onboardingStep!;
    final stepTitle = switch (step) {
      1 => 'Step one',
      2 => 'Step two',
      _ => 'Step three',
    };
    final stepDesc = switch (step) {
      1 =>
        'Check your Current Goods and the Target Goods required to win at Roma.',
      2 =>
        'Tap any highlighted adjacent grid cell around your camel to move along the Silk Road.',
      _ =>
        'When entering a city, use the Trading Panel to buy and sell goods for profit.',
    };

    return Positioned.fill(
      child: Stack(
        children: [
          // Semi-transparent black overlay covering non-highlighted areas
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

          // Step 1 Highlight: Current Goods List & Target Goods List
          if (step == 1)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 215,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 80),
                          Expanded(
                            child: _buildGoodsListsColumn(highlighted: true),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

          // Step 2 Highlight: Player's current position and adjacent cells
          if (step == 2)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: 231),
                    Expanded(
                      child: Column(
                        children: [
                          const SizedBox(height: 52),
                          Expanded(
                            child: _buildBrickGridMap(
                              adjacentCoords,
                              onlyRenderStepTwoHighlights: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Step 3 Highlight: Pop up Trading Panel and highlight it
          if (step == 3)
            Center(
              child: _buildTradingPanel(
                _activeTradingCity ?? 'Dunhuang',
                isOnboardingPreview: true,
              ),
            ),

          // Onboarding Step Card with Step Number and Next Button
          Positioned(
            bottom: 24,
            right: 24,
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD68910), width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 12),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stepTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD68910),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stepDesc,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD68910),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _nextOnboardingStep,
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoodsCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final List<MapEntry<String, int>> entries;
  final String emptyText;

  const _GoodsCard({
    required this.iconPath,
    required this.title,
    required this.entries,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(iconPath, width: 20, height: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: entries
                          .map(
                            (e) => _GoodBadgeItem(
                              name: e.key,
                              quantity: e.value,
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GoodBadgeItem extends StatelessWidget {
  final String name;
  final int quantity;

  const _GoodBadgeItem({required this.name, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF0CA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  AppService.goodIconPath(name),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0392B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            AppService.formatGoodName(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: const Color(0xFFD68910),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

