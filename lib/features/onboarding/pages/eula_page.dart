import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';
import 'package:securityexperts_app/shared/widgets/app_button_variants.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/data/services/firestore_instance.dart';

/// Base prefix for the local EULA acceptance key. The full key is
/// per-user: `${eulaAcceptedKeyPrefix}<uid>` (or `${eulaAcceptedKeyPrefix}anon`
/// for unauthenticated acceptance). Per-user keys prevent acceptance state
/// leaking across users that share a device/browser.
const String eulaAcceptedKeyPrefix = 'eula_accepted_v1_';

/// Returns the SharedPreferences key for the currently signed-in user.
String eulaAcceptedKeyForCurrentUser() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return '$eulaAcceptedKeyPrefix${uid ?? 'anon'}';
}

/// Full-screen EULA / Terms of Service acceptance page.
///
/// Must be accepted before a user can proceed into the app.
/// Acceptance is stored both locally (SharedPreferences) and in Firestore.
class EulaPage extends StatefulWidget {
  /// Called when the user accepts the EULA and we should navigate forward.
  final VoidCallback onAccepted;

  /// True when the signed-in user has no Firestore profile document yet.
  /// In that case we skip the inline Firestore mirror — the subsequent
  /// onboarding flow's `createUser` write carries `terms_accepted_at` into
  /// the initial user document. This avoids a Firestore web SDK stall that
  /// occurs when issuing a `set(merge:true)` create-write to a not-yet-
  /// existing document right after a fresh authentication.
  final bool isNewUser;

  const EulaPage({
    super.key,
    required this.onAccepted,
    this.isNewUser = false,
  });

  /// EULA gate: shows the EULA page only if the user hasn't accepted yet.
  ///
  /// Source-of-truth order:
  /// 1. If [profileTermsAcceptedAt] is non-null (Firestore), treat as accepted.
  /// 2. Else if a per-user local cache key exists, treat as accepted.
  /// 3. Otherwise push the EULA page.
  ///
  /// The local key is scoped to the current Firebase UID so acceptance
  /// does not leak across users sharing the same device or browser.
  ///
  /// Pass [isNewUser]=true when the caller knows the user has no Firestore
  /// profile yet (e.g. immediately after first sign-in before onboarding).
  static Future<void> showIfNeeded(
    BuildContext context, {
    required VoidCallback onAccepted,
    Timestamp? profileTermsAcceptedAt,
    bool isNewUser = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final perUserKey = eulaAcceptedKeyForCurrentUser();

    // If Firestore says terms are accepted, mirror to local per-user prefs.
    if (profileTermsAcceptedAt != null && !prefs.containsKey(perUserKey)) {
      await prefs.setString(
        perUserKey,
        profileTermsAcceptedAt.toDate().toIso8601String(),
      );
    }

    if (profileTermsAcceptedAt != null || prefs.containsKey(perUserKey)) {
      onAccepted();
      return;
    }

    if (!context.mounted) return;
    // push (not pushReplacement) so the caller route stays alive and can use
    // its own `mounted` flag inside `onAccepted`.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EulaPage(
          onAccepted: onAccepted,
          isNewUser: isNewUser,
        ),
      ),
    );
  }

  @override
  State<EulaPage> createState() => _EulaPageState();
}

class _EulaPageState extends State<EulaPage> {
  bool _agreed = false;
  bool _saving = false;
  final _log = sl<AppLogger>();
  static const _tag = 'EulaPage';

  Future<void> _accept() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);

    try {
      // 1. Store locally — this is the immediate source of truth.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        eulaAcceptedKeyForCurrentUser(),
        DateTime.now().toIso8601String(),
      );

      // 2. Persist to Firestore. Uses the named `green-hive-db` database
      //    (via FirestoreInstance) — NOT the default DB. Writing through
      //    `FirebaseFirestore.instance` would hit the wrong database and
      //    hang indefinitely.
      //
      //    Uses a client-side `Timestamp.now()` rather than
      //    `FieldValue.serverTimestamp()` to avoid stalling the Firestore
      //    web SDK on first writes to a not-yet-existing user document.
      //
      //    `set(merge: true)` covers both create (new user) and update
      //    (existing user accepting newer terms). A 10s timeout guards
      //    against indefinite network stalls. As a defense-in-depth, the
      //    onboarding `createUser` flow also includes `terms_accepted_at`
      //    sourced from SharedPreferences, so the field still lands even
      //    if this write fails for a new user.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        final acceptedAt = Timestamp.now();
        _log.info('Persisting terms_accepted_at for uid=$uid', tag: _tag);
        try {
          await FirestoreInstance()
              .db
              .collection('users')
              .doc(uid)
              .set(
                {
                  'terms_accepted_at': acceptedAt,
                  'updated_at': acceptedAt,
                },
                SetOptions(merge: true),
              )
              .timeout(const Duration(seconds: 10));
          _log.info('terms_accepted_at persisted for uid=$uid', tag: _tag);
        } on TimeoutException catch (e) {
          _log.warning(
            'Timed out persisting terms_accepted_at for uid=$uid: $e',
            tag: _tag,
          );
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Network is slow. Please check your connection and try again.',
                ),
              ),
            );
          }
          return;
        } catch (e) {
          _log.warning(
            'Could not persist terms_accepted_at for uid=$uid: $e',
            tag: _tag,
          );
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save acceptance. Please try again.'),
              ),
            );
          }
          return;
        }
      }

      // 3. Dismiss EULA page first so the caller's `mounted` checks resolve
      //    against the underlying route (which is still alive). Then invoke
      //    the caller's onAccepted to navigate to the destination.
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAccepted();
    } catch (e) {
      _log.error('EULA acceptance error: $e', tag: _tag);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Terms of Service'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.spacing24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GreenHive Community Guidelines & Terms of Service',
                    style: AppTypography.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacing16),
                  Text(
                    'Last updated: January 2025',
                    style: AppTypography.captionSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacing24),
                  _buildSection(
                    '1. Acceptance of Terms',
                    'By using GreenHive, you agree to be bound by these Terms of Service and our Community Guidelines. If you do not agree to these terms, you may not use our services.',
                  ),
                  _buildSection(
                    '2. Community Standards',
                    'GreenHive is a platform built on respect and trust. You agree not to:\n\n'
                        '• Post or share content that is abusive, hateful, harassing, threatening, or violent.\n'
                        '• Share sexually explicit or pornographic content.\n'
                        '• Bully, intimidate, or threaten other users.\n'
                        '• Impersonate any person or entity.\n'
                        '• Post spam, advertisements, or unsolicited promotional content.\n'
                        '• Share content that violates any applicable law or regulation.',
                  ),
                  _buildSection(
                    '3. User-Generated Content',
                    'You are solely responsible for content you post or share. GreenHive does not endorse any user-generated content. We reserve the right to remove content that violates our guidelines without notice.\n\n'
                        'We actively monitor the platform for objectionable content and will take action, including account suspension or termination, for violations.',
                  ),
                  _buildSection(
                    '4. Reporting & Enforcement',
                    'We provide tools to report abusive users and objectionable content. Reports are reviewed by our safety team. We are committed to responding to reports of abuse within 24 hours.\n\n'
                        'Accounts found to be in violation of our Community Standards may be suspended or permanently banned.',
                  ),
                  _buildSection(
                    '5. Blocking Users',
                    'You may block other users at any time. Blocked users cannot see your messages or initiate contact with you. We encourage you to use this feature to protect your experience on the platform.',
                  ),
                  _buildSection(
                    '6. Privacy',
                    'Your use of GreenHive is also governed by our Privacy Policy, which is incorporated by reference into these Terms. We collect and use data as described in our Privacy Policy.',
                  ),
                  _buildSection(
                    '7. Intellectual Property',
                    'You retain ownership of content you create. By posting content on GreenHive, you grant us a non-exclusive, royalty-free license to use, display, and distribute that content within the platform.',
                  ),
                  _buildSection(
                    '8. Termination',
                    'We may suspend or terminate your access to GreenHive at our sole discretion, without notice, for conduct that we believe violates these Terms or is harmful to other users, us, or third parties.',
                  ),
                  _buildSection(
                    '9. Disclaimer of Warranties',
                    'GreenHive is provided "as is" without warranties of any kind. We do not guarantee that the service will be uninterrupted, error-free, or that any defects will be corrected.',
                  ),
                  _buildSection(
                    '10. Contact',
                    'If you have questions about these Terms, please contact us through the Support section of the app.',
                  ),
                  const SizedBox(height: AppSpacing.spacing32),
                ],
              ),
            ),
          ),
          // Bottom bar with checkbox + button
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.spacing24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                          activeColor: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.spacing8),
                        Expanded(
                          child: Text(
                            'I have read and agree to the Terms of Service and Community Guidelines',
                            style: AppTypography.bodyRegular.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacing16),
                  AppButtonVariants.secondary(
                    onPressed: (_agreed && !_saving) ? _accept : null,
                    label: 'Continue',
                    isLoading: _saving,
                    isEnabled: _agreed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyEmphasis.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.spacing12),
          Text(
            body,
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
