String _normalizeEnumValue(String value) {
  return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
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

OrderPriority orderPriorityFromJson(String value) => switch (
  _normalizeEnumValue(value)
) {
  'vip' => OrderPriority.vip,
  'rush' => OrderPriority.rush,
  _ => OrderPriority.standard,
};

OrderType orderTypeFromJson(String value) => switch (_normalizeEnumValue(value)) {
  'stacked' => OrderType.stacked,
  'scheduled' => OrderType.scheduled,
  _ => OrderType.solo,
};

DeliveryStage deliveryStageFromJson(String value) => switch (
  _normalizeEnumValue(value)
) {
  'accepted' => DeliveryStage.accepted,
  'reached_restaurant' => DeliveryStage.reachedRestaurant,
  'pickup_verified' => DeliveryStage.reachedRestaurant,
  'picked_up' => DeliveryStage.pickedUp,
  'on_the_way' => DeliveryStage.onTheWay,
  'reached_customer' => DeliveryStage.reachedCustomer,
  'delivery_verified' => DeliveryStage.reachedCustomer,
  'delivered' => DeliveryStage.delivered,
  _ => DeliveryStage.assigned,
};

DeliveryOutcome deliveryOutcomeFromJson(String value) => switch (
  _normalizeEnumValue(value)
) {
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
    return RiderProfile(
      name: json['name'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      vehicleType: json['vehicleType'] as String,
      vehicleNumber: json['vehicleNumber'] as String,
      licenseStatus: json['licenseStatus'] as String,
      shiftPreference: json['shiftPreference'] as String,
      rating: (json['rating'] as num).toDouble(),
      completedDeliveries: json['completedDeliveries'] as int,
      activeDeliveries: json['activeDeliveries'] as int,
      todayEarnings: (json['todayEarnings'] as num).toDouble(),
      avatarInitials: json['avatarInitials'] as String,
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
  });

  final String id;
  final String? assignmentId;
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

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] as String,
      assignmentId: json['assignmentId'] as String?,
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
    );
  }

  DeliveryOrder copyWith({
    String? id,
    String? assignmentId,
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
  }) {
    return DeliveryOrder(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
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
    );
  }
}

class EarningsPoint {
  const EarningsPoint({required this.label, required this.amount});

  final String label;
  final double amount;

  factory EarningsPoint.fromJson(Map<String, dynamic> json) {
    return EarningsPoint(
      label: json['label'] as String,
      amount: (json['amount'] as num).toDouble(),
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
    required this.trend,
    required this.payoutHistory,
  });

  final double daily;
  final double weekly;
  final double monthly;
  final double incentives;
  final double tips;
  final double bonus;
  final List<EarningsPoint> trend;
  final List<EarningsPoint> payoutHistory;

  factory EarningsReport.fromJson(Map<String, dynamic> json) {
    return EarningsReport(
      daily: (json['daily'] as num).toDouble(),
      weekly: (json['weekly'] as num).toDouble(),
      monthly: (json['monthly'] as num).toDouble(),
      incentives: (json['incentives'] as num).toDouble(),
      tips: (json['tips'] as num).toDouble(),
      bonus: (json['bonus'] as num).toDouble(),
      trend: (json['trend'] as List<dynamic>)
          .map((item) => EarningsPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      payoutHistory: (json['payoutHistory'] as List<dynamic>)
          .map((item) => EarningsPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  EarningsReport copyWith({
    double? daily,
    double? weekly,
    double? monthly,
    double? incentives,
    double? tips,
    double? bonus,
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
      trend: trend ?? this.trend,
      payoutHistory: payoutHistory ?? this.payoutHistory,
    );
  }
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
    return DeliveryRecord(
      id: json['id'] as String,
      restaurantName: json['restaurantName'] as String,
      customerName: json['customerName'] as String,
      pickupAddress: json['pickupAddress'] as String,
      dropAddress: json['dropAddress'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      earnings: (json['earnings'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      itemsCount: json['itemsCount'] as int,
      outcome: deliveryOutcomeFromJson(json['outcome'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      notes: json['notes'] as String,
      timeline: (json['timeline'] as List<dynamic>)
          .map((item) => item as String)
          .toList(),
      durationMinutes: json['durationMinutes'] as int,
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
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
      walletBalance: (json['walletBalance'] as num).toDouble(),
      pendingPayout: (json['pendingPayout'] as num).toDouble(),
      settledPayout: (json['settledPayout'] as num).toDouble(),
      bankAccountMasked: json['bankAccountMasked'] as String,
      transactions: (json['transactions'] as List<dynamic>)
          .map(
            (item) => PayoutTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
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

