import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/features/admin/services/admin_ticket_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_faq_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_skills_service.dart';
import 'package:securityexperts_app/features/admin/services/admin_user_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// Register all admin-feature dependencies.
void registerAdminDependencies(GetIt sl) {
  sl.registerLazySingleton<AdminTicketService>(() => AdminTicketService());
  sl.registerLazySingleton<AdminFaqService>(() => AdminFaqService());
  sl.registerLazySingleton<AdminSkillsService>(() => AdminSkillsService());
  sl.registerLazySingleton<AdminUserService>(() => AdminUserService());

  sl<AppLogger>().debug('[ServiceLocator] Admin feature services registered');
}
