/// GreenHive UI Standards Enforcement
///
/// This file documents the UI design system standards and provides
/// utilities to help maintain consistency across the codebase.
///
/// ## Design System Components
///
/// ### Colors
/// Always use `AppColors` from `lib/shared/themes/app_colors.dart`
/// ❌ DON'T: `Colors.white`, `Colors.black`, `Color(0xFF123456)`
/// ✅ DO: `AppColors.white`, `AppColors.black`, `AppColors.primary`
///
/// ### Typography
/// Always use `AppTypography` from `lib/shared/themes/app_typography.dart`
/// ❌ DON'T: `TextStyle(fontSize: 16, fontWeight: FontWeight.bold)`
/// ✅ DO: `AppTypography.bodyEmphasis`, `AppTypography.headingSmall`
///
/// ### Spacing
/// Always use `AppSpacing` from `lib/shared/themes/app_spacing.dart`
/// ❌ DON'T: `EdgeInsets.all(16)`, `SizedBox(height: 24)`
/// ✅ DO: `EdgeInsets.all(AppSpacing.spacing16)`, `SizedBox(height: AppSpacing.spacing24)`
///
/// ### Border Radius
/// Always use `AppBorders` from `lib/shared/themes/app_borders.dart`
/// ❌ DON'T: `BorderRadius.circular(12)`
/// ✅ DO: `BorderRadius.circular(AppBorders.radius12)`, `AppBorders.borderRadiusNormal`
///
/// ### Icons
/// Always use `AppIconSizes` from `lib/shared/themes/app_icon_sizes.dart`
/// ❌ DON'T: `Icon(Icons.home, size: 24)`
/// ✅ DO: `Icon(Icons.home, size: AppIconSizes.standard)`
///
/// ## Quick Reference
///
/// ### Common Color Mappings
/// | Hardcoded | Use Instead |
/// |-----------|-------------|
/// | `Colors.white` | `AppColors.white` |
/// | `Colors.black` | `AppColors.black` |
/// | `Colors.transparent` | `Colors.transparent` |
/// | `Colors.red` | `AppColors.error` |
/// | `Colors.green` | `AppColors.success` |
/// | `Colors.amber` | `AppColors.ratingStar` |
/// | `Colors.blue` | `AppColors.info` |
/// | `Colors.grey` | `AppColors.textMuted` |
/// | `Colors.black26` | `AppColors.black.withValues(alpha: 0.26)` |
/// | `Colors.black54` | `AppColors.black.withValues(alpha: 0.54)` |
/// | `Colors.black87` | `AppColors.black.withValues(alpha: 0.87)` |
///
/// ### Common Spacing Mappings
/// | Hardcoded | Use Instead |
/// |-----------|-------------|
/// | `4` | `AppSpacing.spacing4` |
/// | `8` | `AppSpacing.spacing8` |
/// | `12` | `AppSpacing.spacing12` |
/// | `16` | `AppSpacing.spacing16` |
/// | `20` | `AppSpacing.spacing20` |
/// | `24` | `AppSpacing.spacing24` |
/// | `32` | `AppSpacing.spacing32` |
/// | `48` | `AppSpacing.spacing48` |
///
/// ### Common Typography Mappings
/// | Hardcoded | Use Instead |
/// |-----------|-------------|
/// | `fontSize: 10` | `AppTypography.captionTiny` |
/// | `fontSize: 12` | `AppTypography.captionSmall` |
/// | `fontSize: 14` | `AppTypography.bodySmall` |
/// | `fontSize: 16` | `AppTypography.bodyRegular` |
/// | `fontSize: 18` | `AppTypography.headingXSmall` |
/// | `fontSize: 20` | `AppTypography.headingSmall` |
/// | `fontSize: 24` | `AppTypography.headingMedium` |
///
/// ## Pre-commit Checks
///
/// Run the following command before committing to check for UI violations:
/// ```bash
/// ./scripts/check_ui_standards.sh
/// ```
library;

// This file is intentionally empty of code - it serves as documentation
// for the UI design system standards.

// Export all theme components for easy access
export 'package:securityexperts_app/shared/themes/app_colors.dart';
export 'package:securityexperts_app/shared/themes/app_typography.dart';
export 'package:securityexperts_app/shared/themes/app_spacing.dart';
export 'package:securityexperts_app/shared/themes/app_borders.dart';
export 'package:securityexperts_app/shared/themes/app_icon_sizes.dart';
