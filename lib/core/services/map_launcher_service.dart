import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_models.dart';

abstract class MapLauncherService {
  Future<bool> openExternalRoute(DeliveryOrder order);
}

class UrlLauncherMapLauncherService implements MapLauncherService {
  @override
  Future<bool> openExternalRoute(DeliveryOrder order) async {
    Uri? mapUrl;
    
    // 1. Try to use coordinates first
    if (order.deliveryLat != 0.0 && order.deliveryLng != 0.0) {
      mapUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${order.deliveryLat},${order.deliveryLng}');
    } 
    // 2. Fallback to encoded address
    else if (order.dropAddress.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(order.dropAddress);
      mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    }

    if (mapUrl != null && await canLaunchUrl(mapUrl)) {
      return await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
    }
    
    return false;
  }
}
