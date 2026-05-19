import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_constants.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Cơ cấu chi tiêu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 1.35,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 44,
                    sectionsSpace: 3,
                    sections: [
                      PieChartSectionData(
                        value: 38,
                        title: 'Ăn uống',
                        color: Color(0xFF0F8B6F),
                        radius: 72,
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      PieChartSectionData(
                        value: 24,
                        title: 'Nhà cửa',
                        color: Color(0xFF2563EB),
                        radius: 72,
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      PieChartSectionData(
                        value: 18,
                        title: 'Con cái',
                        color: Color(0xFF7C3AED),
                        radius: 72,
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      PieChartSectionData(
                        value: 20,
                        title: 'Khác',
                        color: Color(0xFFC2410C),
                        radius: 72,
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.insights_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('Tỷ lệ tiết kiệm'),
              subtitle: const Text('Mục tiêu tháng này: 25%'),
              trailing: Text(
                '29%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
