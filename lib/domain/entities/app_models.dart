String _normalizeEnumValue(String value) {
  return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  final present = _firstPresent([value]);
  return present == null ? fallback : '$present'.trim();
}

String _asScalarString(Object? value) {
  if (value is Map || value is Iterable) {
    return '';
  }
  return _asString(value);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

DateTime _asDateTime(Object? value, {DateTime? fallback}) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value.trim()) ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

String _joinName(Map<String, dynamic> user) {
  final fullName = _asString(
    _firstPresent([user['name'], user['full_name'], user['display_name']]),
  );
  if (fullName.isNotEmpty) {
    return fullName;
  }

  final parts = [
    _asString(user['first_name']),
    _asString(user['last_name']),
  ].where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? 'Rider' : parts.join(' ');
}

String _initialsForName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'R';
  }
  return parts.take(2).map((part) => part[0]).join().toUpperCase();
}

enum OrderPriority { vip, rush, standard }

enum OrderType { solo, stacked, scheduled }

enum DeliveryStage {
  assigned,
  accepted,
  reachedRestaurant,
  pickedUp,
  onTheWay,
  reachedCustomer,
  delivered,
}

enum DeliveryOutcome { completed, cancelled, failed }

enum AvailabilityStatus { offline, online, busy, onBreak }

enum NotificationType { order, payout, incentive, update, support }

OrderPriority orderPriorityFromJson(String value) =>
    switch (_normalizeEnumValue(value)) {
      'vip' => OrderPriority.vip,
      'rush' => OrderPriority.rush,
      _ => OrderPriority.standard,
    };

OrderType orderTypeFromJson(String value) =>
    switch (_normalizeEnumValue(value)) {
      'stacked' => OrderType.stacked,
      'scheduled' => OrderType.scheduled,
      _ => OrderType.solo,
    };

DeliveryStage deliveryStageFromJson(String value) =>
    switch (_normalizeEnumValue(value)) {
      'accepted' => DeliveryStage.accepted,
      'reached_restaurant' => DeliveryStage.reachedRestaurant,
      'rider_arrived_restaurant' => DeliveryStage.reachedRestaurant,
      'pickup_verified' => DeliveryStage.reachedRestaurant,
      'picked_up' => DeliveryStage.pickedUp,
      'on_the_way' => DeliveryStage.onTheWay,
      'out_for_delivery' => DeliveryStage.onTheWay,
      'reached_customer' => DeliveryStage.reachedCustomer,
      'delivery_verified' => DeliveryStage.reachedCustomer,
      'delivered' => DeliveryStage.delivered,
      _ => DeliveryStage.assigned,
    };

DeliveryOutcome deliveryOutcomeFromJson(String value) =>
    switch (_normalizeEnumValue(value)) {
      'cancelled' => DeliveryOutcome.cancelled,
      'failed' => DeliveryOutcome.failed,
      _ => DeliveryOutcome.completed,
    };

AvailabilityStatus availabilityStatusFromJson(String value) {
  switch (_normalizeEnumValue(value)) {
    case 'online':
      return AvailabilityStatus.online;
    case 'busy':
      return AvailabilityStatus.busy;
    case 'break':
    case 'on_break':
      return AvailabilityStatus.onBreak;
    default:
      return AvailabilityStatus.offline;
  }
}

NotificationType notificationTypeFromJson(String value) {
  switch (_normalizeEnumValue(value)) {
    case 'payout':
      return NotificationType.payout;
    case 'incentive':
    case 'bonus':
      return NotificationType.incentive;
    case 'update':
    case 'system_update':
      return NotificationType.update;
    case 'support':
      return NotificationType.support;
    default:
      return NotificationType.order;
  }
}

class AuthOtpChallenge {
  const AuthOtpChallenge({
    required this.expiresInSeconds,
    required this.channel,
  });

  final int expiresInSeconds;
  final String channel;
}

class RiderProfile {
  const RiderProfile({
    required this.name,
    required this.phone,
    required this.city,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.licenseStatus,
    required this.shiftPreference,
    required this.rating,
    required this.completedDeliveries,
    required this.activeDeliveries,
    required this.todayEarnings,
    required this.avatarInitials,
  });

  final String name;
  final String phone;
  final String city;
  final String vehicleType;
  final String vehicleNumber;
  final String licenseStatus;
  final String shiftPreference;
  final double rating;
  final int completedDeliveries;
  final int activeDeliveries;
  final double todayEarnings;
  final String avatarInitials;

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);
    final rider = _asMap(json['rider']);
    final vehicle = _asMap(json['vehicle']);
    final stats = _asMap(json['stats']);
    final earnings = _asMap(json['earnings']);
    final source = <String, dynamic>{...json, ...rider};
    final name = _asString(
      _firstPresent([
        json['name'],
        user['name'],
        user['full_name'],
        user['display_name'],
        _joinName(user),
      ]),
      fallback: 'Rider',
    );

    return RiderProfile(
      name: name,
      phone: _asString(
        _firstPresent([
          json['phone'],
          user['phone'],
          user['mobile'],
          user['phone_number'],
          source['phone'],
        ]),
        fallback: 'Phone not available',
      ),
      city: _asString(
        _firstPresent([json['city'], user['city'], source['city']]),
        fallback: 'City not set',
      ),
      vehicleType: _asString(
        _firstPresent([
          json['vehicleType'],
          json['vehicle_type'],
          vehicle['vehicle_type'],
          vehicle['type'],
          source['vehicle_type'],
        ]),
        fallback: 'Vehicle not set',
      ),
      vehicleNumber: _asString(
        _firstPresent([
          json['vehicleNumber'],
          json['vehicle_number'],
          json['vehicle_registration_number'],
          vehicle['vehicle_number'],
          vehicle['registration_number'],
          vehicle['registration_no'],
          source['vehicle_number'],
          source['vehicle_registration_number'],
        ]),
        fallback: 'Not added',
      ),
      licenseStatus: _asString(
        _firstPresent([
          json['licenseStatus'],
          json['license_status'],
          source['license_status'],
          source['kyc_status'],
          source['approval_status'],
        ]),
        fallback: 'Pending',
      ),
      shiftPreference: _asString(
        _firstPresent([
          json['shiftPreference'],
          json['shift_preference'],
          source['shift_preference'],
          source['availability_status'],
        ]),
        fallback: 'Flexible',
      ),
      rating: _asDouble(
        _firstPresent([
          json['rating'],
          source['rating'],
          source['avg_rating'],
          source['rating_avg'],
          stats['rating'],
        ]),
      ),
      completedDeliveries: _asInt(
        _firstPresent([
          json['completedDeliveries'],
          json['completed_deliveries'],
          source['completed_deliveries'],
          source['total_deliveries'],
          stats['completed_deliveries'],
        ]),
      ),
      activeDeliveries: _asInt(
        _firstPresent([
          json['activeDeliveries'],
          json['active_deliveries'],
          source['active_deliveries'],
          stats['active_deliveries'],
        ]),
      ),
      todayEarnings: _asDouble(
        _firstPresent([
          json['todayEarnings'],
          json['today_earnings'],
          source['today_earnings'],
          earnings['today'],
          earnings['today_earnings'],
        ]),
      ),
      avatarInitials: _asString(
        _firstPresent([json['avatarInitials'], json['avatar_initials']]),
        fallback: _initialsForName(name),
      ),
    );
  }

  RiderProfile copyWith({
    String? name,
    String? phone,
    String? city,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseStatus,
    String? shiftPreference,
    double? rating,
    int? completedDeliveries,
    int? activeDeliveries,
    double? todayEarnings,
    String? avatarInitials,
  }) {
    return RiderProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      licenseStatus: licenseStatus ?? this.licenseStatus,
      shiftPreference: shiftPreference ?? this.shiftPreference,
      rating: rating ?? this.rating,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      activeDeliveries: activeDeliveries ?? this.activeDeliveries,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      avatarInitials: avatarInitials ?? this.avatarInitials,
    );
  }
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.assignmentId,
    this.deliveryOrderId,
    required this.restaurantName,
    required this.customerName,
    required this.pickupAddress,
    required this.dropAddress,
    required this.restaurantPhone,
    required this.customerPhone,
    required this.restaurantLat,
    required this.restaurantLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.distanceKm,
    required this.etaMinutes,
    required this.payout,
    required this.tip,
    required this.itemsCount,
    required this.itemHighlights,
    required this.priority,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.orderCode,
    required this.customerOtp,
    required this.pickupOtpRequired,
    required this.deliveryOtpRequired,
    required this.notes,
    required this.createdAt,
    required this.countdownSeconds,
    required this.isMultiOrder,
    this.assignmentType = 'restaurant_owned',
  });

  final String id;
  final String? assignmentId;
  final int? deliveryOrderId;
  final String restaurantName;
  final String customerName;
  final String pickupAddress;
  final String dropAddress;
  final String restaurantPhone;
  final String customerPhone;
  final double restaurantLat;
  final double restaurantLng;
  final double deliveryLat;
  final double deliveryLng;
  final double distanceKm;
  final int etaMinutes;
  final double payout;
  final double tip;
  final int itemsCount;
  final List<String> itemHighlights;
  final OrderPriority priority;
  final OrderType type;
  final DeliveryStage status;
  final String paymentMethod;
  final String orderCode;
  final String customerOtp;
  final bool pickupOtpRequired;
  final bool deliveryOtpRequired;
  final String notes;
  final DateTime createdAt;
  final int countdownSeconds;
  final bool isMultiOrder;
  final String assignmentType;

  bool get isRestaurantOwned {
    switch (assignmentType.trim().toLowerCase()) {
      case 'restaurant_owned':
      case 'restaurant_own_rider':
        return true;
      default:
        return false;
    }
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] as String,
      assignmentId: json['assignmentId'] as String?,
      deliveryOrderId: json['deliveryOrderId'] as int?,
      restaurantName: json['restaurantName'] as String,
      customerName: json['customerName'] as String,
      pickupAddress: json['pickupAddress'] as String,
      dropAddress: json['dropAddress'] as String,
      restaurantPhone: json['restaurantPhone'] as String,
      customerPhone: json['customerPhone'] as String,
      restaurantLat: (json['restaurantLat'] as num?)?.toDouble() ?? 0.0,
      restaurantLng: (json['restaurantLng'] as num?)?.toDouble() ?? 0.0,
      deliveryLat: (json['deliveryLat'] as num?)?.toDouble() ?? 0.0,
      deliveryLng: (json['deliveryLng'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      etaMinutes: json['etaMinutes'] as int,
      payout: (json['payout'] as num).toDouble(),
      tip: (json['tip'] as num?)?.toDouble() ?? 0,
      itemsCount: json['itemsCount'] as int,
      itemHighlights: (json['itemHighlights'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      priority: orderPriorityFromJson(json['priority'] as String),
      type: orderTypeFromJson(json['type'] as String),
      status: deliveryStageFromJson(json['status'] as String),
      paymentMethod: json['paymentMethod'] as String,
      orderCode: json['orderCode'] as String,
      customerOtp: json['customerOtp'] as String? ?? '',
      pickupOtpRequired: json['pickupOtpRequired'] as bool? ?? false,
      deliveryOtpRequired: json['deliveryOtpRequired'] as bool? ?? false,
      notes: json['notes'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      countdownSeconds: json['countdownSeconds'] as int,
      isMultiOrder: json['isMultiOrder'] as bool? ?? false,
      assignmentType: json['assignmentType'] as String? ?? 'restaurant_owned',
    );
  }

  DeliveryOrder copyWith({
    String? id,
    String? assignmentId,
    int? deliveryOrderId,
    String? restaurantName,
    String? customerName,
    String? pickupAddress,
    String? dropAddress,
    String? restaurantPhone,
    String? customerPhone,
    double? restaurantLat,
    double? restaurantLng,
    double? deliveryLat,
    double? deliveryLng,
    double? distanceKm,
    int? etaMinutes,
    double? payout,
    double? tip,
    int? itemsCount,
    List<String>? itemHighlights,
    OrderPriority? priority,
    OrderType? type,
    DeliveryStage? status,
    String? paymentMethod,
    String? orderCode,
    String? customerOtp,
    bool? pickupOtpRequired,
    bool? deliveryOtpRequired,
    String? notes,
    DateTime? createdAt,
    int? countdownSeconds,
    bool? isMultiOrder,
    String? assignmentType,
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      deliveryOrderId: deliveryOrderId ?? this.deliveryOrderId,
      restaurantName: restaurantName ?? this.restaurantName,
      customerName: customerName ?? this.customerName,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropAddress: dropAddress ?? this.dropAddress,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      customerPhone: customerPhone ?? this.customerPhone,
      restaurantLat: restaurantLat ?? this.restaurantLat,
      restaurantLng: restaurantLng ?? this.restaurantLng,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      distanceKm: distanceKm ?? this.distanceKm,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      payout: payout ?? this.payout,
      tip: tip ?? this.tip,
      itemsCount: itemsCount ?? this.itemsCount,
      itemHighlights: itemHighlights ?? this.itemHighlights,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderCode: orderCode ?? this.orderCode,
      customerOtp: customerOtp ?? this.customerOtp,
      pickupOtpRequired: pickupOtpRequired ?? this.pickupOtpRequired,
      deliveryOtpRequired: deliveryOtpRequired ?? this.deliveryOtpRequired,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isMultiOrder: isMultiOrder ?? this.isMultiOrder,
      assignmentType: assignmentType ?? this.assignmentType,
    );
  }
}

class EarningsPoint {
  const EarningsPoint({required this.label, required this.amount});

  final String label;
  final double amount;

  factory EarningsPoint.fromJson(Map<String, dynamic> json) {
    return EarningsPoint(
      label: _asString(
        _firstPresent([json['label'], json['date'], json['day']]),
        fallback: 'Earnings',
      ),
      amount: _asDouble(
        _firstPresent([
          json['amount'],
          json['net_earning'],
          json['total_earnings'],
          json['earnings'],
        ]),
      ),
    );
  }
}

class EarningsReport {
  const EarningsReport({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.incentives,
    required this.tips,
    required this.bonus,
    this.deliveryFees = 0,
    required this.trend,
    required this.payoutHistory,
  });

  final double daily;
  final double weekly;
  final double monthly;
  final double incentives;
  final double tips;
  final double bonus;
  final double deliveryFees;
  final List<EarningsPoint> trend;
  final List<EarningsPoint> payoutHistory;

  factory EarningsReport.fromJson(Map<String, dynamic> json) {
    final totalEarnings = _asDouble(
      _firstPresent([json['total_earnings'], json['totalEarnings']]),
    );
    return EarningsReport(
      daily: _asDouble(
        _firstPresent([json['daily'], json['today_earnings'], totalEarnings]),
      ),
      weekly: _asDouble(
        _firstPresent([
          json['weekly'],
          json['weekly_earnings'],
          json['week_earnings'],
          totalEarnings,
        ]),
      ),
      monthly: _asDouble(
        _firstPresent([
          json['monthly'],
          json['monthly_earnings'],
          json['month_earnings'],
          totalEarnings,
        ]),
      ),
      incentives: _asDouble(
        _firstPresent([
          json['incentives'],
          json['incentive_earnings'],
          json['incentive_amount'],
        ]),
      ),
      tips: _asDouble(
        _firstPresent([json['tips'], json['tip_earnings'], json['tip_amount']]),
      ),
      bonus: _asDouble(
        _firstPresent([
          json['bonus'],
          json['bonus_earnings'],
          json['bonus_amount'],
        ]),
      ),
      deliveryFees: _asDouble(
        _firstPresent([
          json['deliveryFees'],
          json['delivery_fees'],
          json['delivery_earnings'],
          json['delivery_fee_earnings'],
        ]),
      ),
      trend: _earningsPointsFromJson(json['trend']),
      payoutHistory: _earningsPointsFromJson(
        _firstPresent([json['payoutHistory'], json['payout_history']]),
      ),
    );
  }

  EarningsReport copyWith({
    double? daily,
    double? weekly,
    double? monthly,
    double? incentives,
    double? tips,
    double? bonus,
    double? deliveryFees,
    List<EarningsPoint>? trend,
    List<EarningsPoint>? payoutHistory,
  }) {
    return EarningsReport(
      daily: daily ?? this.daily,
      weekly: weekly ?? this.weekly,
      monthly: monthly ?? this.monthly,
      incentives: incentives ?? this.incentives,
      tips: tips ?? this.tips,
      bonus: bonus ?? this.bonus,
      deliveryFees: deliveryFees ?? this.deliveryFees,
      trend: trend ?? this.trend,
      payoutHistory: payoutHistory ?? this.payoutHistory,
    );
  }
}

List<EarningsPoint> _earningsPointsFromJson(Object? value) {
  if (value is! List) {
    return const <EarningsPoint>[];
  }
  return value
      .map(_asMap)
      .where((item) => item.isNotEmpty)
      .map(EarningsPoint.fromJson)
      .toList(growable: false);
}

class DeliveryRecord {
  const DeliveryRecord({
    required this.id,
    required this.restaurantName,
    required this.customerName,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distanceKm,
    required this.earnings,
    required this.paymentMethod,
    required this.itemsCount,
    required this.outcome,
    required this.completedAt,
    required this.notes,
    required this.timeline,
    required this.durationMinutes,
  });

  final String id;
  final String restaurantName;
  final String customerName;
  final String pickupAddress;
  final String dropAddress;
  final double distanceKm;
  final double earnings;
  final String paymentMethod;
  final int itemsCount;
  final DeliveryOutcome outcome;
  final DateTime completedAt;
  final String notes;
  final List<String> timeline;
  final int durationMinutes;

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) {
    final order = _asMap(json['order']);
    final restaurant = _asMap(
      _firstPresent([order['restaurant'], json['restaurant']]),
    );
    final customer = _asMap(
      _firstPresent([order['customer'], json['customer']]),
    );
    final pickup = _asMap(
      _firstPresent([order['pickup_address'], json['pickup_address']]),
    );
    final deliveryAddress = _asMap(
      _firstPresent([order['delivery_address'], json['delivery_address']]),
    );
    final source = <String, dynamic>{...json, ...order};
    final completedAt = _asDateTime(
      _firstPresent([
        source['completedAt'],
        source['completed_at'],
        source['actual_delivery_time'],
        source['delivered_at'],
        source['created_at'],
        source['updated_at'],
      ]),
    );

    return DeliveryRecord(
      id: _asString(
        _firstPresent([
          source['id'],
          source['order_id'],
          source['order_number'],
          json['delivery_order_id'],
        ]),
        fallback: 'history-${completedAt.microsecondsSinceEpoch}',
      ),
      restaurantName: _asString(
        _firstPresent([
          source['restaurantName'],
          source['restaurant_name'],
          restaurant['name'],
        ]),
        fallback: 'Restaurant',
      ),
      customerName: _asString(
        _firstPresent([
          source['customerName'],
          source['customer_name'],
          customer['name'],
          customer['full_name'],
        ]),
        fallback: 'Customer',
      ),
      pickupAddress: _asString(
        _firstPresent([
          source['pickupAddress'],
          pickup['address'],
          pickup['address_line1'],
          _asScalarString(source['pickup_address']),
          source['restaurant_address'],
          restaurant['address'],
        ]),
        fallback: 'Pickup address not available',
      ),
      dropAddress: _asString(
        _firstPresent([
          source['dropAddress'],
          _asScalarString(source['drop_address']),
          deliveryAddress['address'],
          deliveryAddress['address_line1'],
          _asScalarString(source['delivery_address']),
          customer['address'],
        ]),
        fallback: 'Drop address not available',
      ),
      distanceKm: _asDouble(
        _firstPresent([source['distanceKm'], source['distance_km']]),
      ),
      earnings: _asDouble(
        _firstPresent([
          source['earnings'],
          source['net_earning'],
          source['amount'],
          source['amount_to_collect'],
          source['payout'],
          source['base_payout'],
          source['delivery_fee'],
          source['total_amount'],
        ]),
      ),
      paymentMethod: _asString(
        _firstPresent([
          source['paymentMethod'],
          source['payment_method'],
          source['payment_mode'],
        ]),
        fallback: 'Payment not available',
      ),
      itemsCount: _asInt(
        _firstPresent([
          source['itemsCount'],
          source['items_count'],
          source['item_count'],
        ]),
      ),
      outcome: deliveryOutcomeFromJson(
        _asString(
          _firstPresent([
            source['outcome'],
            source['delivery_status'],
            source['order_status'],
            source['status'],
          ]),
          fallback: 'completed',
        ),
      ),
      completedAt: completedAt,
      notes: _asString(
        _firstPresent([source['notes'], source['description'], source['body']]),
      ),
      timeline: _asTimeline(source['timeline']),
      durationMinutes: _asInt(
        _firstPresent([source['durationMinutes'], source['duration_minutes']]),
      ),
    );
  }

  factory DeliveryRecord.fromOrder(
    DeliveryOrder order, {
    required DeliveryOutcome outcome,
    required DateTime completedAt,
  }) {
    return DeliveryRecord(
      id: order.id,
      restaurantName: order.restaurantName,
      customerName: order.customerName,
      pickupAddress: order.pickupAddress,
      dropAddress: order.dropAddress,
      distanceKm: order.distanceKm,
      earnings: order.payout + order.tip,
      paymentMethod: order.paymentMethod,
      itemsCount: order.itemsCount,
      outcome: outcome,
      completedAt: completedAt,
      notes: order.notes,
      timeline: const [
        'Assigned',
        'Accepted',
        'Reached restaurant',
        'Picked up',
        'On the way',
        'Arrived at customer',
        'Delivered',
      ],
      durationMinutes: order.etaMinutes + 8,
    );
  }
}

List<String> _asTimeline(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) {
        if (item is Map) {
          return _asString(
            _firstPresent([item['label'], item['status'], item['title']]),
          );
        }
        return _asString(item);
      })
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isUnread,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isUnread;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: notificationTypeFromJson(json['type'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isUnread: json['isUnread'] as bool? ?? false,
    );
  }

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isUnread,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

class PayoutTransaction {
  const PayoutTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final String status;
  final DateTime createdAt;

  factory PayoutTransaction.fromJson(Map<String, dynamic> json) {
    return PayoutTransaction(
      id: _asString(
        _firstPresent([json['id'], json['transaction_id'], json['payout_id']]),
        fallback: 'payout-${DateTime.now().microsecondsSinceEpoch}',
      ),
      title: _asString(
        _firstPresent([json['title'], json['description'], json['type']]),
        fallback: 'Payout activity',
      ),
      amount: _asDouble(json['amount']),
      status: _asString(json['status'], fallback: 'POSTED'),
      createdAt: _asDateTime(
        _firstPresent([
          json['createdAt'],
          json['created_at'],
          json['requested_at'],
        ]),
      ),
    );
  }
}

class PayoutSummary {
  const PayoutSummary({
    required this.walletBalance,
    required this.pendingPayout,
    required this.settledPayout,
    required this.bankAccountMasked,
    required this.transactions,
  });

  final double walletBalance;
  final double pendingPayout;
  final double settledPayout;
  final String bankAccountMasked;
  final List<PayoutTransaction> transactions;

  factory PayoutSummary.fromJson(Map<String, dynamic> json) {
    return PayoutSummary(
      walletBalance: _asDouble(
        _firstPresent([json['walletBalance'], json['wallet_balance']]),
      ),
      pendingPayout: _asDouble(
        _firstPresent([json['pendingPayout'], json['pending_payout']]),
      ),
      settledPayout: _asDouble(
        _firstPresent([json['settledPayout'], json['settled_payout']]),
      ),
      bankAccountMasked: _asString(
        _firstPresent([json['bankAccountMasked'], json['bank_account_masked']]),
      ),
      transactions: _payoutTransactionsFromJson(json['transactions']),
    );
  }

  PayoutSummary copyWith({
    double? walletBalance,
    double? pendingPayout,
    double? settledPayout,
    String? bankAccountMasked,
    List<PayoutTransaction>? transactions,
  }) {
    return PayoutSummary(
      walletBalance: walletBalance ?? this.walletBalance,
      pendingPayout: pendingPayout ?? this.pendingPayout,
      settledPayout: settledPayout ?? this.settledPayout,
      bankAccountMasked: bankAccountMasked ?? this.bankAccountMasked,
      transactions: transactions ?? this.transactions,
    );
  }
}

List<PayoutTransaction> _payoutTransactionsFromJson(Object? value) {
  if (value is! List) {
    return const <PayoutTransaction>[];
  }
  return value
      .map(_asMap)
      .where((item) => item.isNotEmpty)
      .map(PayoutTransaction.fromJson)
      .toList(growable: false);
}

class RiderReview {
  const RiderReview({
    required this.id,
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.highlight,
  });

  final String id;
  final String reviewer;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String highlight;

  factory RiderReview.fromJson(Map<String, dynamic> json) {
    return RiderReview(
      id: json['id'] as String,
      reviewer: json['reviewer'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      highlight: json['highlight'] as String,
    );
  }
}

class ReviewInsights {
  const ReviewInsights({
    required this.averageRating,
    required this.performanceScore,
    required this.compliments,
    required this.reviews,
  });

  final double averageRating;
  final double performanceScore;
  final List<String> compliments;
  final List<RiderReview> reviews;

  factory ReviewInsights.fromJson(Map<String, dynamic> json) {
    return ReviewInsights(
      averageRating: (json['averageRating'] as num).toDouble(),
      performanceScore: (json['performanceScore'] as num).toDouble(),
      compliments: (json['compliments'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      reviews: (json['reviews'] as List<dynamic>)
          .map((item) => RiderReview.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SupportFaq {
  const SupportFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;

  factory SupportFaq.fromJson(Map<String, dynamic> json) {
    return SupportFaq(
      id: json['id'] as String,
      category: json['category'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

class ShiftSummary {
  const ShiftSummary({
    required this.status,
    required this.shiftStart,
    required this.shiftEnd,
    required this.breakMinutes,
    required this.preferredWindow,
    required this.activeHours,
    required this.statusMessage,
  });

  final AvailabilityStatus status;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final int breakMinutes;
  final String preferredWindow;
  final double activeHours;
  final String statusMessage;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      status: availabilityStatusFromJson(json['status'] as String),
      shiftStart: DateTime.parse(json['shiftStart'] as String),
      shiftEnd: DateTime.parse(json['shiftEnd'] as String),
      breakMinutes: json['breakMinutes'] as int,
      preferredWindow: json['preferredWindow'] as String,
      activeHours: (json['activeHours'] as num).toDouble(),
      statusMessage: json['statusMessage'] as String,
    );
  }

  ShiftSummary copyWith({
    AvailabilityStatus? status,
    DateTime? shiftStart,
    DateTime? shiftEnd,
    int? breakMinutes,
    String? preferredWindow,
    double? activeHours,
    String? statusMessage,
  }) {
    return ShiftSummary(
      status: status ?? this.status,
      shiftStart: shiftStart ?? this.shiftStart,
      shiftEnd: shiftEnd ?? this.shiftEnd,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      preferredWindow: preferredWindow ?? this.preferredWindow,
      activeHours: activeHours ?? this.activeHours,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class RiderHubState {
  const RiderHubState({
    required this.profile,
    required this.earnings,
    required this.notifications,
    required this.history,
    required this.payoutSummary,
    required this.reviews,
    required this.supportFaqs,
    required this.shiftSummary,
    required this.incomingOrders,
    required this.activeOrder,
    required this.queuedOrders,
  });

  final RiderProfile profile;
  final EarningsReport earnings;
  final List<AppNotificationItem> notifications;
  final List<DeliveryRecord> history;
  final PayoutSummary payoutSummary;
  final ReviewInsights reviews;
  final List<SupportFaq> supportFaqs;
  final ShiftSummary shiftSummary;
  final List<DeliveryOrder> incomingOrders;
  final DeliveryOrder? activeOrder;
  final List<DeliveryOrder> queuedOrders;

  RiderHubState copyWith({
    RiderProfile? profile,
    EarningsReport? earnings,
    List<AppNotificationItem>? notifications,
    List<DeliveryRecord>? history,
    PayoutSummary? payoutSummary,
    ReviewInsights? reviews,
    List<SupportFaq>? supportFaqs,
    ShiftSummary? shiftSummary,
    List<DeliveryOrder>? incomingOrders,
    DeliveryOrder? activeOrder,
    bool clearActiveOrder = false,
    List<DeliveryOrder>? queuedOrders,
  }) {
    return RiderHubState(
      profile: profile ?? this.profile,
      earnings: earnings ?? this.earnings,
      notifications: notifications ?? this.notifications,
      history: history ?? this.history,
      payoutSummary: payoutSummary ?? this.payoutSummary,
      reviews: reviews ?? this.reviews,
      supportFaqs: supportFaqs ?? this.supportFaqs,
      shiftSummary: shiftSummary ?? this.shiftSummary,
      incomingOrders: incomingOrders ?? this.incomingOrders,
      activeOrder: clearActiveOrder ? null : activeOrder ?? this.activeOrder,
      queuedOrders: queuedOrders ?? this.queuedOrders,
    );
  }
}
