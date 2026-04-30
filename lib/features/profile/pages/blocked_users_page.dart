import 'package:flutter/material.dart';
import 'package:securityexperts_app/core/logging/app_logger.dart';
import 'package:securityexperts_app/core/service_locator.dart';
import 'package:securityexperts_app/data/models/user.dart';
import 'package:securityexperts_app/data/repositories/user/user_repository.dart';
import 'package:securityexperts_app/shared/services/block_user_service.dart';
import 'package:securityexperts_app/shared/services/user_profile_service.dart';
import 'package:securityexperts_app/shared/themes/app_theme_dark.dart';

/// Lets the user view and unblock previously-blocked users.
///
/// Required by Apple App Store Guideline 1.2: blocking must be reversible
/// by the user (not only by an admin). Without this screen, once a user is
/// blocked the chat is hidden from the chat list and the user is filtered
/// out of the experts list, leaving no in-app path back to unblock.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  static const _tag = 'BlockedUsersPage';
  final _log = sl<AppLogger>();
  final _userRepository = sl<UserRepository>();

  /// Cache of blocked user profiles keyed by uid. Allows the list to keep
  /// rendering names/avatars after an unblock removes the id from the
  /// `blockedUserIds` list.
  final Map<String, User> _profileCache = {};
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    UserProfileService().addListener(_onProfileChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    UserProfileService().removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfiles() async {
    final ids = sl<BlockUserService>().blockedUserIds;
    for (final id in ids) {
      if (_profileCache.containsKey(id)) continue;
      try {
        final user = await _userRepository.getUserById(id);
        if (user != null) {
          _profileCache[id] = user;
        }
      } catch (e) {
        _log.warning(
          'Failed to load blocked user profile uid=$id: $e',
          tag: _tag,
        );
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _confirmUnblock(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Unblock User',
          style: AppTypography.bodyEmphasis.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Unblock $userName? They will be able to contact you again.',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Unblock',
              style: AppTypography.bodyEmphasis.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await sl<BlockUserService>().unblockUser(userId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$userName has been unblocked.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockedIds = sl<BlockUserService>().blockedUserIds;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blocked Users'),
        backgroundColor: AppColors.background,
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : blockedIds.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: blockedIds.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, index) {
                    final id = blockedIds[index];
                    final user = _profileCache[id];
                    final name = user?.name ?? 'Unknown user';
                    final avatarUrl = user?.profilePictureUrl;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceVariant,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: AppTypography.bodyEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _confirmUnblock(id, name),
                        child: Text(
                          'Unblock',
                          style: AppTypography.bodyEmphasis.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              "You haven't blocked anyone",
              style: AppTypography.bodyEmphasis.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Users you block will appear here. You can unblock them at any time.',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
