import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/features/support/data/repositories/support_repository.dart';
import 'package:securityexperts_app/features/support/data/repositories/support_attachment_repository.dart';
import 'package:securityexperts_app/features/support/services/device_info_service.dart';
import 'package:securityexperts_app/features/support/services/support_service.dart';
import 'package:securityexperts_app/features/support/services/support_analytics.dart';
import 'package:securityexperts_app/features/support/services/faq_service.dart';
import 'package:securityexperts_app/shared/services/notification_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// Register all support-feature dependencies.
void registerSupportDependencies(GetIt sl) {
  sl.registerLazySingleton<SupportRepository>(() => SupportRepository());

  sl.registerLazySingleton<SupportAttachmentRepository>(
    () => SupportAttachmentRepository(),
  );

  sl.registerLazySingleton<DeviceInfoService>(() => DeviceInfoService());

  sl.registerLazySingleton<SupportService>(
    () => SupportService(
      repository: sl<SupportRepository>(),
      attachmentRepository: sl<SupportAttachmentRepository>(),
      deviceInfoService: sl<DeviceInfoService>(),
      notificationService: sl<NotificationService>(),
      log: sl<AppLogger>(),
    ),
  );

  sl.registerLazySingleton<SupportAnalytics>(() => SupportAnalytics());
  sl.registerLazySingleton<FaqService>(() => FaqService());

  sl<AppLogger>().debug('[ServiceLocator] Support feature services registered');
}
