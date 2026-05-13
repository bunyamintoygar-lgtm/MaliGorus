import 'package:flutter/material.dart';

class ListingUtils {
  static IconData getIconData(String? iconName) {
    switch (iconName) {
      case 'campaign':
        return Icons.campaign_rounded;
      case 'handshake':
        return Icons.handshake_rounded;
      case 'auto_stories':
        return Icons.auto_stories_rounded;
      case 'location_city':
        return Icons.location_city_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'rocket_launch':
        return Icons.rocket_launch_rounded;
      case 'business_center':
      case 'business_center_rounded':
        return Icons.business_center_rounded;
      case 'school_rounded':
        return Icons.school_rounded;
      case 'apartment_rounded':
        return Icons.apartment_rounded;
      case 'sell_rounded':
        return Icons.sell_rounded;
      case 'assignment_rounded':
        return Icons.assignment_rounded;
      case 'groups_rounded':
        return Icons.groups_rounded;
      case 'home_work_rounded':
        return Icons.home_work_rounded;
      default:
        return Icons.business_center_rounded;
    }
  }

  static Color getColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.green;
    try {
      if (hexColor.startsWith('#')) {
        hexColor = hexColor.substring(1);
      }
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.green;
    }
  }
}
