import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';

class CategoryVisuals {
  CategoryVisuals._();

  static const colorOptions = [
    '#0F8B6F',
    '#2563EB',
    '#7C3AED',
    '#C2410C',
    '#DC2626',
    '#0891B2',
    '#16A34A',
    '#CA8A04',
  ];

  static const iconOptions = [
    CategoryIconOption(name: 'salary', icon: Icons.payments_outlined),
    CategoryIconOption(name: 'bonus', icon: Icons.card_giftcard_outlined),
    CategoryIconOption(name: 'food', icon: Icons.restaurant_outlined),
    CategoryIconOption(name: 'home', icon: Icons.home_outlined),
    CategoryIconOption(name: 'transport', icon: Icons.directions_car_outlined),
    CategoryIconOption(name: 'shopping', icon: Icons.shopping_bag_outlined),
    CategoryIconOption(name: 'health', icon: Icons.health_and_safety_outlined),
    CategoryIconOption(name: 'education', icon: Icons.school_outlined),
    CategoryIconOption(name: 'entertainment', icon: Icons.movie_outlined),
    CategoryIconOption(name: 'saving', icon: Icons.savings_outlined),
    CategoryIconOption(name: 'bill', icon: Icons.receipt_long_outlined),
    CategoryIconOption(name: 'other', icon: Icons.category_outlined),
  ];

  static Color colorFromHex(String hex) {
    final value = hex.replaceAll('#', '').trim();
    if (value.length != 6) {
      return const Color(0xFF0F8B6F);
    }
    final parsedColor = int.tryParse('FF$value', radix: 16);
    if (parsedColor == null) {
      return const Color(0xFF0F8B6F);
    }
    return Color(parsedColor);
  }

  static IconData iconFromName(String name) {
    return iconOptions
        .firstWhere(
          (option) => option.name == name,
          orElse: () => iconOptions.last,
        )
        .icon;
  }

  static String labelForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Thu';
      case TransactionType.expense:
        return 'Chi';
    }
  }

  static Color toneForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return const Color(0xFF0F8B6F);
      case TransactionType.expense:
        return const Color(0xFFC2410C);
    }
  }
}

class CategoryIconOption {
  const CategoryIconOption({required this.name, required this.icon});

  final String name;
  final IconData icon;
}
