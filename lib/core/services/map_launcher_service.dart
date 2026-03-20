import '../../domain/entities/app_models.dart';

abstract class MapLauncherService {
  Future<bool> openExternalRoute(DeliveryOrder order);
}

class PlaceholderMapLauncherService implements MapLauncherService {
  @override
  Future<bool> openExternalRoute(DeliveryOrder order) async => false;
}
