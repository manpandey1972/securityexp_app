import 'package:flutter/material.dart';
import 'package:securityexperts_app/shared/themes/app_colors.dart';
import 'package:securityexperts_app/shared/themes/app_typography.dart';
import 'package:securityexperts_app/shared/widgets/profile_picture_widget.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/data/models/models.dart' as models;
import 'package:securityexperts_app/shared/themes/app_spacing.dart';

/// Modal dialog for incoming call notifications
/// Displays caller info, call type, and accept/decline buttons
/// Extracted from call_page.dart _showIncomingCallOverlay for better reusability
class IncomingCallDialog extends StatelessWidget {
  /// Caller's display name
  final String callerName;

  /// Caller's user ID
  final String callerId;

  /// Whether this is a video call
  final bool isVideoCall;

  /// Caller's user object (for profile picture)
  final models.User? callerUser;

  /// Called when the accept button is pressed
  final VoidCallback? onAccept;

  /// Called when the decline button is pressed
  final VoidCallback? onDecline;

  /// Custom decline button label
  final String declineButtonLabel;

  /// Custom accept button label
  final String acceptButtonLabel;

  /// Whether to show the caller's profile picture
  final bool showCallerPhoto;

  /// Custom leading widget (overrides profile picture if provided)
  final Widget? customLeading;

  /// Dialog title (defaults to "Video Call" or "Audio Call")
  final String? customTitle;

  /// Custom dialog message (defaults to "Incoming call from {callerName}")
  final String? customMessage;

  /// Animation duration for dialog entrance
  final Duration animationDuration;

  /// Whether to add ringing animation to the accept button
  final bool addRingAnimation;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.isVideoCall,
    this.callerUser,
    this.onAccept,
    this.onDecline,
    this.declineButtonLabel = 'Decline',
    this.acceptButtonLabel = 'Accept',
    this.showCallerPhoto = true,
    this.customLeading,
    this.customTitle,
    this.customMessage,
    this.animationDuration = const Duration(milliseconds: 300),
    this.addRingAnimation = true,
  });

  /// Get default title based on call type
  String _getTitle() {
    if (customTitle != null) return customTitle!;
    return isVideoCall ? 'Video Call' : 'Audio Call';
  }

  /// Get default message based on caller name
  String _getMessage() {
    if (customMessage != null) return customMessage!;
    return 'Incoming call from $callerName';
  }

  /// Build caller's profile section
  Widget _buildCallerInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Caller photo/icon (optional)
        if (showCallerPhoto || customLeading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildLeadingWidget(),
          ),

        // Title (Video/Audio Call)
        Text(
          _getTitle(),
          style: AppTypography.headingSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),

        SizedBox(height: AppSpacing.spacing16),

        // Message (Incoming call from {Name})
        Text(
          _getMessage(),
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: AppSpacing.spacing24),
      ],
    );
  }

  /// Build leading widget (profile picture or custom)
  Widget _buildLeadingWidget() {
    if (customLeading != null) {
      return customLeading!;
    }

    if (callerUser != null && showCallerPhoto) {
      return SizedBox(
        width: 80,
        height: 80,
        child: ProfilePictureWidget(
          user: callerUser!,
          size: 80,
          showBorder: true,
          variant: 'thumbnail',
        ),
      );
    }

    // Fallback icon
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isVideoCall ? Icons.videocam : Icons.call,
        color: AppColors.textPrimary,
        size: 40,
      ),
    );
  }

  /// Build accept button with optional pulsing animation
  Widget _buildAcceptButton() {
    if (!addRingAnimation) {
      return _buildAcceptButtonContent();
    }

    return _PulsingButton(child: _buildAcceptButtonContent());
  }

  /// Build accept button content
  Widget _buildAcceptButtonContent() {
    return AppButtonVariants.primary(
      onPressed: onAccept,
      label: acceptButtonLabel,
      height: 44,
    );
  }

  /// Build decline button
  Widget _buildDeclineButton() {
    return AppButtonVariants.destructive(
      onPressed: onDecline,
      label: declineButtonLabel,
      height: 44,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: AlwaysStoppedAnimation(1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
      child: Material(
        color: AppColors.background.withValues(alpha: 0.54),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.background.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caller info section
                  _buildCallerInfo(),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildDeclineButton()),
                      SizedBox(width: AppSpacing.spacing16),
                      Expanded(child: _buildAcceptButton()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing animation wrapper for the accept button
class _PulsingButton extends StatefulWidget {
  final Widget child;

  const _PulsingButton({required this.child});

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

/// Overlay version of IncomingCallDialog for use with Overlay.of()
class IncomingCallOverlay extends StatelessWidget {
  /// All IncomingCallDialog parameters
  final String callerName;
  final String callerId;
  final bool isVideoCall;
  final models.User? callerUser;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final String declineButtonLabel;
  final String acceptButtonLabel;
  final bool showCallerPhoto;
  final Widget? customLeading;
  final String? customTitle;
  final String? customMessage;

  const IncomingCallOverlay({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.isVideoCall,
    this.callerUser,
    this.onAccept,
    this.onDecline,
    this.declineButtonLabel = 'Decline',
    this.acceptButtonLabel = 'Accept',
    this.showCallerPhoto = true,
    this.customLeading,
    this.customTitle,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return IncomingCallDialog(
      callerName: callerName,
      callerId: callerId,
      isVideoCall: isVideoCall,
      callerUser: callerUser,
      onAccept: onAccept,
      onDecline: onDecline,
      declineButtonLabel: declineButtonLabel,
      acceptButtonLabel: acceptButtonLabel,
      showCallerPhoto: showCallerPhoto,
      customLeading: customLeading,
      customTitle: customTitle,
      customMessage: customMessage,
    );
  }
}
