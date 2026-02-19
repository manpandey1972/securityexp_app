/// Constants used across call room UI components
class CallRoomConstants {
  CallRoomConstants._();

  // Picture-in-Picture dimensions
  static const double pipWidth = 120.0;
  static const double pipHeight = 160.0;
  static const double pipMargin = 16.0;
  static const double pipBorderRadius = 12.0;
  static const double pipBorderWidth = 2.0;

  // Gesture thresholds
  static const double swipeThreshold = 100.0;

  // Avatar sizes
  static const double avatarSizeLarge = 120.0;
  static const double avatarSizeMedium = 64.0;
  static const double avatarSizeSmall = 40.0;
  static const double avatarIconSizeLarge = 64.0;
  static const double avatarIconSizeMedium = 32.0;
  static const double avatarIconSizeSmall = 40.0;

  // Spacing
  static const double topOffset = 48.0;
  static const double bottomOffset = 48.0;
  static const double controlsBottomReserve = 120.0;

  // Mute badge
  static const double muteBadgeIconSize = 20.0;
  static const double muteBadgeIconSizeSmall = 14.0;
  static const double muteBadgePaddingHorizontal = 16.0;
  static const double muteBadgePaddingVertical = 8.0;
  static const double muteBadgeBorderRadius = 16.0;

  // Animation durations
  static const Duration controlsAnimationDuration = Duration(milliseconds: 400);
  static const Duration breathingAnimationDuration = Duration(
    milliseconds: 2000,
  );
}
