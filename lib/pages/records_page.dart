import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../utils/app_service.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  void _showRecordDetail(BuildContext context, GameRecord record) {
    final finalGoodsEntries = record.finalGoods.entries
        .where((e) => e.value > 0)
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFFFBF0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/scenes/difficulty.png',
                      width: 26,
                      height: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record.difficulty} - ${record.succeeded ? "Succeed" : "Failed"}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                          Text(
                            record.endTime,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(),
                // Used days and Coins summary
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        iconPath: 'assets/images/scenes/remaining.png',
                        label: 'Used Days',
                        value: '${record.usedDays}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryChip(
                        iconPath: 'assets/images/scenes/gold.png',
                        label: 'Coins',
                        value: '${record.coins}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction List',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF873600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (record.transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No transactions recorded in this round.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          ...record.transactions.map(
                            (tx) => _TransactionCard(transaction: tx),
                          ),
                        const SizedBox(height: 14),
                        const Text(
                          'Final Goods List',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF873600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (finalGoodsEntries.isEmpty)
                          const Text(
                            'No goods held at the end of the round.',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: finalGoodsEntries
                                .map(
                                  (e) => _RecordGoodChip(
                                    name: e.key,
                                    quantity: e.value,
                                  ),
                                )
                                .toList(),
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

  @override
  Widget build(BuildContext context) {
    final records = AppService.instance.records;

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
                        'Game Records',
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
                // Records Card Container
                Expanded(
                  child: Center(
                    child: Container(
                      width: 460,
                      margin: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: records.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 48,
                                    color: Colors.black38,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'No game records yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: records.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = records[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  onTap: () => _showRecordDetail(context, item),
                                  leading: Image.asset(
                                    'assets/images/scenes/difficulty.png',
                                    width: 28,
                                    height: 28,
                                  ),
                                  title: Text(
                                    item.difficulty,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.endTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  trailing: Text(
                                    item.succeeded ? 'Succeed' : 'Failed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: item.succeeded
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFD32F2F),
                                    ),
                                  ),
                                );
                              },
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

class _SummaryChip extends StatelessWidget {
  final String iconPath;
  final String label;
  final String value;

  const _SummaryChip({
    required this.iconPath,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5D5B5)),
      ),
      child: Row(
        children: [
          Image.asset(iconPath, width: 22, height: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final CityTransaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final soldList = transaction.sold.entries.where((e) => e.value > 0).toList();
    final purchasedList =
        transaction.purchased.entries.where((e) => e.value > 0).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5D5B5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                AppService.cityIconPath(transaction.city),
                width: 24,
                height: 24,
                errorBuilder: (_, _, _) => const Icon(Icons.location_city, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                transaction.city,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (purchasedList.isNotEmpty) ...[
            const Text(
              'Purchased Goods:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: purchasedList
                  .map((e) => _RecordGoodChip(name: e.key, quantity: e.value))
                  .toList(),
            ),
            const SizedBox(height: 6),
          ],
          if (soldList.isNotEmpty) ...[
            const Text(
              'Sold Goods:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: soldList
                  .map((e) => _RecordGoodChip(name: e.key, quantity: e.value))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordGoodChip extends StatelessWidget {
  final String name;
  final int quantity;

  const _RecordGoodChip({required this.name, required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0CA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppService.goodIconPath(name), width: 20, height: 20),
          const SizedBox(width: 6),
          Text(
            '${AppService.formatGoodName(name)} ×$quantity',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

