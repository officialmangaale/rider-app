import '../entities/app_models.dart';

abstract class RiderRepository {
  Future<RiderHubState> bootstrap();

  Future<void> loginWithPassword({
    required String login,
    required String password,
  });

  Future<AuthOtpChallenge> sendLoginOtp({required String login});

  Future<void> verifyLoginOtp({
    required String login,
    required String otp,
  });

  Future<AuthOtpChallenge> requestPasswordReset({required String login});

  Future<void> resetPassword({
    required String login,
    required String otp,
    required String newPassword,
  });

  Future<void> logout();

  Future<void> acceptOrder(String assignmentId);

  Future<void> rejectOrder(String assignmentId, {String? reason});

  Future<void> setAvailabilityStatus(AvailabilityStatus status);

  Future<void> markNotificationRead(String id);

  Future<void> markAllNotificationsRead();

  Future<void> advanceActiveOrder(DeliveryOrder order, {String? otp});
}
