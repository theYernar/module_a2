class MapCell {
  final int row;
  final int col;
  final String type; // 'plain', 'sea', 'mountain', 'city'
  final String name;

  const MapCell({
    required this.row,
    required this.col,
    this.type = 'plain',
    this.name = '',
  });
}

class TradeOffer {
  final String name;
  final int price;

  const TradeOffer({required this.name, required this.price});

  factory TradeOffer.fromJson(Map<String, dynamic> json) => TradeOffer(
        name: json['name'] as String,
        price: (json['price'] as num).toInt(),
      );
}

class CityTradeConfig {
  final String city;
  // In trades.json:
  // "city_selling" = goods the city sells -> player's Buying Price List ("Buy" button)
  // "city_buying"  = goods the city buys  -> player's Selling Price List ("Sell" button)
  final List<TradeOffer> buyingList;
  final List<TradeOffer> sellingList;

  const CityTradeConfig({
    required this.city,
    required this.buyingList,
    required this.sellingList,
  });

  factory CityTradeConfig.fromJson(Map<String, dynamic> json) {
    final sellingRaw = (json['city_selling'] as List<dynamic>? ?? []);
    final buyingRaw = (json['city_buying'] as List<dynamic>? ?? []);
    return CityTradeConfig(
      city: json['city'] as String,
      buyingList: sellingRaw
          .map((e) => TradeOffer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      sellingList: buyingRaw
          .map((e) => TradeOffer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class EasyConfig {
  final String difficulty;
  final String from;
  final String to;
  final int coins;
  final int days;
  final Map<String, int> targets;

  const EasyConfig({
    required this.difficulty,
    required this.from,
    required this.to,
    required this.coins,
    required this.days,
    required this.targets,
  });

  factory EasyConfig.fromJson(Map<String, dynamic> json) {
    final targetsMap = <String, int>{};
    for (final item in (json['targets'] as List<dynamic>? ?? [])) {
      final map = Map<String, dynamic>.from(item as Map);
      targetsMap[map['name'] as String] = (map['quantity'] as num).toInt();
    }
    return EasyConfig(
      difficulty: json['difficulty'] as String? ?? 'Easy',
      from: json['from'] as String? ?? 'Changan',
      to: json['to'] as String? ?? 'Roma',
      coins: (json['coins'] as num?)?.toInt() ?? 180,
      days: (json['days'] as num?)?.toInt() ?? 26,
      targets: targetsMap,
    );
  }
}

class CityTransaction {
  final String city;
  final Map<String, int> sold;
  final Map<String, int> purchased;

  CityTransaction({
    required this.city,
    Map<String, int>? sold,
    Map<String, int>? purchased,
  })  : sold = Map<String, int>.from(sold ?? {}),
        purchased = Map<String, int>.from(purchased ?? {});

  CityTransaction copy() => CityTransaction(
        city: city,
        sold: Map<String, int>.from(sold),
        purchased: Map<String, int>.from(purchased),
      );

  Map<String, dynamic> toJson() => {
        'city': city,
        'sold': sold,
        'purchased': purchased,
      };

  factory CityTransaction.fromJson(Map<String, dynamic> json) => CityTransaction(
        city: json['city'] as String? ?? '',
        sold: (json['sold'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        purchased: (json['purchased'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
}

class MoveSnapshot {
  final int row;
  final int col;
  final int coins;
  final int remainingDays;
  final Map<String, int> currentGoods;
  final List<CityTransaction> transactions;
  final bool hasActiveCitySession;

  MoveSnapshot({
    required this.row,
    required this.col,
    required this.coins,
    required this.remainingDays,
    required Map<String, int> currentGoods,
    required List<CityTransaction> transactions,
    required this.hasActiveCitySession,
  })  : currentGoods = Map<String, int>.from(currentGoods),
        transactions = transactions.map((t) => t.copy()).toList();

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'coins': coins,
        'remainingDays': remainingDays,
        'currentGoods': currentGoods,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'hasActiveCitySession': hasActiveCitySession,
      };

  factory MoveSnapshot.fromJson(Map<String, dynamic> json) => MoveSnapshot(
        row: (json['row'] as num).toInt(),
        col: (json['col'] as num).toInt(),
        coins: (json['coins'] as num).toInt(),
        remainingDays: (json['remainingDays'] as num).toInt(),
        currentGoods: (json['currentGoods'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((e) => CityTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasActiveCitySession: json['hasActiveCitySession'] as bool? ?? false,
      );
}

class SavedGameState {
  final int row;
  final int col;
  final int coins;
  final int remainingDays;
  final Map<String, int> currentGoods;
  final Map<String, int> targetGoods;
  final List<CityTransaction> transactions;
  final List<MoveSnapshot> history;
  final bool hasActiveCitySession;

  SavedGameState({
    required this.row,
    required this.col,
    required this.coins,
    required this.remainingDays,
    required this.currentGoods,
    required this.targetGoods,
    required this.transactions,
    required this.history,
    required this.hasActiveCitySession,
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'coins': coins,
        'remainingDays': remainingDays,
        'currentGoods': currentGoods,
        'targetGoods': targetGoods,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'hasActiveCitySession': hasActiveCitySession,
      };

  factory SavedGameState.fromJson(Map<String, dynamic> json) => SavedGameState(
        row: (json['row'] as num).toInt(),
        col: (json['col'] as num).toInt(),
        coins: (json['coins'] as num).toInt(),
        remainingDays: (json['remainingDays'] as num).toInt(),
        currentGoods: (json['currentGoods'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        targetGoods: (json['targetGoods'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((e) => CityTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => MoveSnapshot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasActiveCitySession: json['hasActiveCitySession'] as bool? ?? false,
      );
}

class GameRecord {
  final String difficulty;
  final bool succeeded;
  final String endTime;
  final int usedDays;
  final int coins;
  final List<CityTransaction> transactions;
  final Map<String, int> finalGoods;

  const GameRecord({
    required this.difficulty,
    required this.succeeded,
    required this.endTime,
    required this.usedDays,
    required this.coins,
    required this.transactions,
    required this.finalGoods,
  });

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'succeeded': succeeded,
        'endTime': endTime,
        'usedDays': usedDays,
        'coins': coins,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'finalGoods': finalGoods,
      };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
        difficulty: json['difficulty'] as String? ?? 'Easy',
        succeeded: json['succeeded'] as bool? ?? false,
        endTime: json['endTime'] as String? ?? '',
        usedDays: (json['usedDays'] as num?)?.toInt() ?? 0,
        coins: (json['coins'] as num?)?.toInt() ?? 0,
        transactions: (json['transactions'] as List<dynamic>? ?? [])
            .map((e) => CityTransaction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        finalGoods: (json['finalGoods'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
}

