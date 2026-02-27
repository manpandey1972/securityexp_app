import 'package:get_it/get_it.dart';
import 'package:securityexperts_app/features/ratings/data/repositories/rating_repository.dart';
import 'package:securityexperts_app/features/ratings/services/rating_service.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';

/// Register all rating-feature dependencies.
void registerRatingDependencies(GetIt sl) {
  sl.registerLazySingleton<RatingRepository>(() => RatingRepository());

  sl.registerLazySingleton<RatingService>(
    () => RatingService(
      repository: sl<RatingRepository>(),
      log: sl<AppLogger>(),
    ),
  );

  sl<AppLogger>().debug('[ServiceLocator] Rating feature services registered');
}
