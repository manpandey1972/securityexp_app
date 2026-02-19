# UI Components Review & Refactoring Recommendations

**Review Date:** January 22, 2026  
**Scope:** All UI widgets, shared components, themes, and visual patterns  
**Files Analyzed:** 50+ widget files across `lib/widgets/`, `lib/shared/widgets/`, `lib/features/*/widgets/`, `lib/pages/`

---

## 📊 Executive Summary

| Category | Grade | Key Finding |
|----------|-------|-------------|
| **Theme System Design** | A | Well-designed AppColors, AppTypography, AppSpacing, AppBorders |
| **Theme Adoption** | D | Most theme constants are unused (0-10% adoption rate) |
| **Code Duplication** | D+ | Same patterns duplicated 5-10 times across codebase |
| **Widget Architecture** | C | Some god-widgets (872+ lines), mixed responsibilities |
| **Consistency** | D | BorderRadius, spacing, buttons all inconsistent |

### Theme System Adoption Metrics

| Theme System | Defined In | Usages Found | Adoption Rate |
|-------------|------------|--------------|---------------|
| `AppColors` | app_colors.dart | ~300+ | ✅ ~95% |
| `AppTypography` | app_typography.dart | ~100+ | ✅ ~80% |
| `AppSpacing` | app_spacing.dart | ~20 | ❌ ~10% |
| `AppBorders` | app_borders.dart | 2 | ❌ ~1% |
| `AppCardStyle` | app_card_styles.dart | 0 | ❌ 0% |
| `AppButtonVariants` | app_button_variants.dart | 0 | ❌ 0% |

---

## 🔴 Critical Issues

### 1. AppCardStyle - Completely Unused (0% Adoption)

**Problem:** `AppCardStyle` class defines 10+ card decoration styles but has **zero usages** in the entire codebase.

**File:** `lib/shared/themes/app_card_styles.dart`

**Defined styles (unused):**
```dart
AppCardStyle.elevated       // Standard elevated card
AppCardStyle.outlined       // Outlined card
AppCardStyle.filled         // Filled background card
AppCardStyle.interactive    // Hover state card
AppCardStyle.highlight      // Primary accent card
AppCardStyle.success        // Success state
AppCardStyle.warning        // Warning state
AppCardStyle.error          // Error state
AppCardStyle.info           // Info state
AppCardStyle.tag            // Tag/chip style
```

**Instead, every widget creates inline BoxDecoration:**

```dart
// expert_card.dart - Manual implementation
decoration: BoxDecoration(
  color: AppColors.cardBackground,
  borderRadius: BorderRadius.circular(12),
)

// message_bubble.dart - Manual implementation  
decoration: BoxDecoration(
  color: widget.fromMe ? AppColors.messageBubbleGreen : AppColors.surface,
  borderRadius: BorderRadius.circular(12),
  boxShadow: [BoxShadow(...)],
)
```

**Impact:** Inconsistent card styling, harder maintenance, missed animation opportunities.

---

### 2. AppButtonVariants - Completely Unused (0% Adoption)

**Problem:** `AppButtonVariants` class provides standardized buttons but is **never used**.

**File:** `lib/shared/widgets/app_button_variants.dart`

**Defined variants (unused):**
```dart
AppButtonVariants.elevatedSmall()
AppButtonVariants.elevatedLarge()
AppButtonVariants.elevatedFullWidth()
AppButtonVariants.outlinedSmall()
AppButtonVariants.outlinedLarge()
AppButtonVariants.textSmall()
AppButtonVariants.textLarge()
AppButtonVariants.iconButton()
```

**Instead, buttons are created inline everywhere:**

```dart
// user_profile_page.dart
ElevatedButton(
  onPressed: ...,
  child: Text('Save Profile'),
)

// user_onboarding_page.dart
ElevatedButton(
  style: ElevatedButton.styleFrom(...),
  child: Text('Continue'),
)
```

**Impact:** Inconsistent button heights, padding, loading states, and accessibility.

---

### 3. Hardcoded BorderRadius Values (90+ Violations)

**Problem:** `AppBorders` defines radius constants but only **2 usages** found in entire codebase.

**File:** `lib/shared/themes/app_borders.dart`

**Defined constants (unused):**
```dart
AppBorders.radius8         // 8pt - subtle
AppBorders.radius12        // 12pt - standard
AppBorders.radius16        // 16pt - cards
AppBorders.radius20        // 20pt - large
AppBorders.radius24        // 24pt - extra large
AppBorders.radius32        // 32pt - maximum

AppBorders.borderRadiusSmall   // BorderRadius.circular(8)
AppBorders.borderRadiusNormal  // BorderRadius.circular(12)
AppBorders.borderRadiusMedium  // BorderRadius.circular(16)
```

**Hardcoded values found everywhere:**

| File | Hardcoded | Should Use |
|------|-----------|------------|
| expert_card.dart | `BorderRadius.circular(12)` | `AppBorders.borderRadiusNormal` |
| message_bubble.dart | `BorderRadius.circular(12)` | `AppBorders.borderRadiusNormal` |
| chat_page.dart | `BorderRadius.circular(14)` | `AppBorders.borderRadiusNormal` |
| chat_page.dart | `BorderRadius.circular(38)` | `AppBorders.borderRadiusCircle` |
| home_page.dart | `BorderRadius.circular(50)` | Create `AppBorders.borderRadiusPill` |
| video_widgets.dart | `BorderRadius.circular(30)` | `AppBorders.borderRadiusCircle` |

**Count:** 90+ instances of `BorderRadius.circular()` with hardcoded values.

---

### 4. Hardcoded SizedBox Spacing (200+ Violations)

**Problem:** `AppSpacing` is defined but **only ~20 usages** found vs 200+ hardcoded values.

**File:** `lib/shared/themes/app_spacing.dart`

**Defined constants (rarely used):**
```dart
AppSpacing.spacing4    // 4pt
AppSpacing.spacing8    // 8pt
AppSpacing.spacing12   // 12pt
AppSpacing.spacing16   // 16pt (most common)
AppSpacing.spacing24   // 24pt
AppSpacing.spacing32   // 32pt
```

**Violations found:**

```dart
// Everywhere - hardcoded spacing
const SizedBox(height: 12)   // ❌ Should be SizedBox(height: AppSpacing.spacing12)
const SizedBox(width: 8)     // ❌ Should be SizedBox(width: AppSpacing.spacing8)
const SizedBox(height: 24)   // ❌ Should be SizedBox(height: AppSpacing.spacing24)
const SizedBox(height: 16)   // ❌ Should be SizedBox(height: AppSpacing.spacing16)
```

---

## 🟠 High Priority Issues

### 5. Frosted Glass Pattern - Duplicated 6+ Times

**Problem:** Same backdrop blur pattern copied across 6+ files with slight variations.

**Affected files:**
- `lib/pages/home_page.dart` (bottom nav + app bar)
- `lib/widgets/experts_list_tab.dart` (search field)
- `lib/pages/chat_page.dart` (bottom sheet)
- `lib/pages/chat_conversation_page.dart` (bottom sheet)
- `lib/pages/user_profile_page.dart` (bottom sheet)
- `lib/widgets/chat/attachment_menu_sheet.dart`

**Duplicated pattern:**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(38),  // or 50
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),  // or 15
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface.withValues(alpha: 0.7),
            AppColors.surface.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(38),  // repeated!
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: ...,
    ),
  ),
)
```

**Recommendation:** Create reusable `FrostedContainer` widget:

```dart
// lib/shared/widgets/frosted_container.dart
class FrostedContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final EdgeInsets? padding;
  
  const FrostedContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blurSigma = 15,
    this.opacity = 0.7,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surface.withValues(alpha: opacity),
                AppColors.surface.withValues(alpha: opacity - 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

---

### 6. Drag Handle Pattern - Duplicated 5+ Times

**Problem:** Exact same drag handle code copied in 5+ bottom sheet implementations.

**Duplicated code:**
```dart
Container(
  width: 40,
  height: 4,
  decoration: BoxDecoration(
    color: AppColors.divider,
    borderRadius: BorderRadius.circular(2),
  ),
),
```

**Affected files:**
- `lib/pages/chat_page.dart`
- `lib/pages/chat_conversation_page.dart`
- `lib/pages/user_profile_page.dart`
- `lib/widgets/chat/attachment_menu_sheet.dart`

**Recommendation:** Create `DragHandle` widget:

```dart
// lib/shared/widgets/drag_handle.dart
class DragHandle extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;
  
  const DragHandle({
    super.key,
    this.width = 40,
    this.height = 4,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? AppColors.divider,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
```

---

### 7. Error/Empty State - Existing Widgets Not Used

**Problem:** `EmptyStateWidget` and `ErrorStateWidget` exist in shared widgets but are **not used** in tab widgets.

**Existing widgets (unused):**
- `lib/shared/widgets/empty_state_widget.dart` - Full-featured with factory constructors
- `lib/shared/widgets/error_state_widget.dart` - Error handling with retry

**Duplicated implementations instead:**

**`experts_list_tab.dart`** (lines 182-230):
```dart
Container(
  height: 400,
  decoration: BoxDecoration(
    gradient: RadialGradient(
      colors: [AppColors.error.withValues(alpha: 0.08), AppColors.appBackground],
    ),
  ),
  child: Center(
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, ...),
          child: Icon(Icons.error_outline, size: 72),
        ),
        Text('Oops!', style: ...),
        Text('Something went wrong', style: ...),
        TextButton(child: Text('Retry'), onPressed: ...),
      ],
    ),
  ),
),
```

**Same pattern in:** `chats_tab.dart`, `calls_tab.dart`, `products_tab.dart`

**Recommendation:** Replace with existing widgets:
```dart
// Before (70 lines duplicated)
Container(height: 400, decoration: ..., child: ...)

// After (1 line)
ErrorStateWidget.error(
  title: 'Oops!',
  description: 'Something went wrong',
  onAction: _retryLoad,
)
```

---

### 8. MessageBubble - God Widget (872 Lines)

**Problem:** `message_bubble.dart` is a monolithic widget with too many responsibilities.

**File:** `lib/widgets/chat/message_bubble.dart` - **872 lines**

**Current responsibilities (all in one widget):**
1. Message container/bubble rendering
2. Reply quote preview rendering
3. Timestamp formatting and display
4. Image content with preview
5. Video content with playback
6. Audio content with waveform
7. Link detection and preview
8. Context menu/popup menu
9. Download button handling
10. Edit indicator display
11. Read receipt display

**Recommendation:** Split into focused components:

```
lib/widgets/chat/
├── message_bubble/
│   ├── message_bubble.dart           # Container only (100 lines)
│   ├── message_content.dart          # Content type switch (150 lines)
│   ├── message_reply_quote.dart      # Reply preview (80 lines)
│   ├── message_timestamp.dart        # Time display (40 lines)
│   ├── message_context_menu.dart     # Popup menu (100 lines)
│   └── content/
│       ├── text_content.dart         # Text + links
│       ├── image_content.dart        # Image preview
│       ├── video_content.dart        # Video preview
│       └── audio_content.dart        # Audio waveform
```

---

## 🟡 Medium Priority Issues

### 9. Direct `Colors.` Usage Instead of AppColors

**Problem:** Some files use Flutter's `Colors.` directly instead of `AppColors`.

**Violations found:**

| File | Line | Violation |
|------|------|-----------|
| home_page.dart | 337 | `Colors.white.withValues(alpha: 0.3)` |
| home_page.dart | 342 | `Colors.black.withValues(alpha: 0.15)` |
| experts_list_tab.dart | 126 | `Colors.white.withValues(alpha: 0.3)` |
| experts_list_tab.dart | 131 | `Colors.black.withValues(alpha: 0.15)` |

**Recommendation:** Add to AppColors:
```dart
// app_colors.dart
static const Color overlayWhite30 = Color(0x4DFFFFFF);  // 30% white
static const Color overlayBlack15 = Color(0x26000000);  // 15% black
```

---

### 10. Inconsistent Icon Sizes

**Problem:** No standardized icon sizes defined. Sizes vary arbitrarily across widgets.

**Icon sizes found in codebase:**

| File | Size | Context |
|------|------|---------|
| message_bubble.dart | 20 | Download icon |
| chat_input_widget.dart | 28 | Action icons |
| expert_card.dart | 24 | Action icons |
| call_control_buttons.dart | 24 | Control icons |
| empty_state_widget.dart | 64 | Empty state icon |
| error_state_widget.dart | 72 | Error icon |
| loading_indicators.dart | 14 | Small icons |

**Recommendation:** Create `AppIconSizes` constants:

```dart
// lib/shared/themes/app_icon_sizes.dart
class AppIconSizes {
  AppIconSizes._();
  
  static const double tiny = 14.0;      // Inline indicators
  static const double small = 16.0;     // Badges, tags
  static const double medium = 20.0;    // List items
  static const double standard = 24.0;  // Default (Material)
  static const double large = 28.0;     // Action buttons
  static const double xlarge = 32.0;    // Headers
  static const double display = 48.0;   // Featured icons
  static const double hero = 64.0;      // Empty/error states
}
```

---

### 11. Inline TextStyle Instead of AppTypography

**Problem:** Some places create `TextStyle` directly instead of using `AppTypography`.

**Violations:**

```dart
// call_history_card.dart
style: TextStyle(color: AppColors.white)

// chat_message_list_item.dart
style: const TextStyle(color: AppColors.textSecondary)

// Should be:
style: AppTypography.bodyRegular.copyWith(color: AppColors.white)
```

---

### 12. Video Widgets - Duplicated Logic

**Problem:** `video_widgets.dart` contains two large widgets (~400 lines each) with similar logic.

**File:** `lib/widgets/chat/video_widgets.dart`

**Duplicated patterns:**
- Cache loading with fallback
- Playback controls UI
- Fullscreen handling
- Progress indicators

**Recommendation:** Extract common logic:

```dart
// lib/widgets/chat/video/
├── video_cache_loader.dart     # Cache logic
├── video_controls_overlay.dart # Playback UI
├── video_progress_bar.dart     # Seek bar
├── video_thumbnail_widget.dart # Thumbnail
└── video_player_page.dart      # Full player
```

---

## 🟢 Low Priority / Observations

### 13. ProfilePictureWidget - Business Logic in Widget

**Problem:** Widget contains logging logic that should be in a controller/viewmodel.

**File:** `lib/widgets/profile_picture_widget.dart`

```dart
// Lines 56-58 - Debug logging in widget
debugPrint('🖼️ ProfilePictureWidget: hasProfilePicture=${currentUser.hasProfilePicture}...');
debugPrint('🖼️ Loading image with cacheKey: $cacheKey');
```

**Recommendation:** Move logging to `ProfilePictureService` or a ViewModel.

---

### 14. Missing LoadingIndicators Adoption

**Problem:** `LoadingIndicators` class provides standardized loaders but most places use plain `CircularProgressIndicator()`.

**Available (underused):**
```dart
LoadingIndicators.circular(color: AppColors.primary, size: 40)
LoadingIndicators.dots()
LoadingIndicators.pulse()
LoadingIndicators.withText(message: 'Loading...')
```

**Instead we see:**
```dart
CircularProgressIndicator()  // No size, no color standardization
```

---

### 15. Shimmer Loading - Good Pattern, Inconsistent Usage

**Observation:** `ShimmerLoading` class is well-designed with factory methods but not consistently used.

**Available shimmer variants:**
```dart
ShimmerLoading.chatListItem()
ShimmerLoading.expertCard()
ShimmerLoading.productCard()
ShimmerLoading.rectangle()
ShimmerLoading.circle()
```

**Some places use these, others create custom shimmer inline.**

---

## 📋 Recommended Actions

### Phase 1: Quick Wins (1-2 days)

| # | Action | Files | Effort |
|---|--------|-------|--------|
| 1 | Create `FrostedContainer` widget | New file | 2h |
| 2 | Create `DragHandle` widget | New file | 30m |
| 3 | Create `AppIconSizes` constants | New file | 30m |
| 4 | Replace error states with `ErrorStateWidget` | 4 tabs | 2h |
| 5 | Replace empty states with `EmptyStateWidget` | 4 tabs | 2h |

### Phase 2: Theme Enforcement (2-3 days)

| # | Action | Files | Effort |
|---|--------|-------|--------|
| 6 | Replace `BorderRadius.circular()` with `AppBorders` | ~30 files | 4h |
| 7 | Replace hardcoded `SizedBox` with `AppSpacing` | ~40 files | 6h |
| 8 | Add `Colors.` to AppColors where needed | 5 files | 1h |
| 9 | Standardize icon sizes with `AppIconSizes` | ~20 files | 3h |

### Phase 3: Widget Refactoring (1 week)

| # | Action | Files | Effort |
|---|--------|-------|--------|
| 10 | Split `MessageBubble` into components | 1 → 6 files | 8h |
| 11 | Extract video widget common logic | 1 → 5 files | 6h |
| 12 | Adopt `AppButtonVariants` across pages | ~15 pages | 4h |
| 13 | Adopt `AppCardStyle` decorations | ~20 widgets | 4h |

### Phase 4: Linting & CI (Optional)

| # | Action | Description | Effort |
|---|--------|-------------|--------|
| 14 | Add lint rule for `Colors.` usage | Prefer AppColors | 2h |
| 15 | Add lint rule for hardcoded BorderRadius | Prefer AppBorders | 2h |
| 16 | Add lint rule for inline SizedBox | Prefer AppSpacing | 2h |

---

## 🏗️ Proposed Widget Directory Structure

```
lib/
├── shared/
│   ├── themes/
│   │   ├── app_colors.dart         ✅ Well-adopted
│   │   ├── app_typography.dart     ✅ Well-adopted
│   │   ├── app_spacing.dart        ❌ Needs enforcement
│   │   ├── app_borders.dart        ❌ Needs enforcement
│   │   ├── app_card_styles.dart    ❌ Never used
│   │   ├── app_button_sizes.dart
│   │   ├── app_icon_sizes.dart     🆕 New (recommended)
│   │   └── app_animations.dart
│   │
│   └── widgets/
│       ├── app_button_variants.dart  ❌ Never used
│       ├── app_dialog.dart
│       ├── app_icon_button.dart
│       ├── carousel_slider.dart
│       ├── context_menu.dart
│       ├── drag_handle.dart          🆕 New (recommended)
│       ├── empty_state_widget.dart   ✅ Exists, underused
│       ├── error_state_widget.dart   ✅ Exists, underused
│       ├── frosted_container.dart    🆕 New (recommended)
│       ├── loading_button.dart
│       ├── loading_indicators.dart   ✅ Good, underused
│       ├── search_input_field.dart
│       ├── shimmer_loading.dart      ✅ Good pattern
│       └── swipeable_list_item.dart
│
└── widgets/
    └── chat/
        └── message_bubble/           🆕 New structure
            ├── message_bubble.dart
            ├── message_content.dart
            ├── message_reply_quote.dart
            ├── message_timestamp.dart
            ├── message_context_menu.dart
            └── content/
                ├── text_content.dart
                ├── image_content.dart
                ├── video_content.dart
                └── audio_content.dart
```

---

## 📈 Success Metrics

After implementing recommendations, measure:

| Metric | Current | Target |
|--------|---------|--------|
| `AppSpacing` usages | ~20 | 200+ |
| `AppBorders` usages | 2 | 90+ |
| `AppCardStyle` usages | 0 | 20+ |
| `AppButtonVariants` usages | 0 | 30+ |
| `ErrorStateWidget` usages | 0 | 8+ |
| `EmptyStateWidget` usages | 0 | 8+ |
| MessageBubble lines | 872 | <150 |
| Duplicated frosted pattern | 6 | 0 |
| Duplicated drag handle | 5 | 0 |

---

## 🔧 Implementation Examples

### Example 1: Using FrostedContainer

**Before:**
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(50),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bottomNavBackground.withValues(alpha: 0.7),
            AppColors.bottomNavBackground.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(children: [...]),
    ),
  ),
)
```

**After:**
```dart
FrostedContainer(
  borderRadius: 50,
  opacity: 0.7,
  child: Row(children: [...]),
)
```

### Example 2: Using AppSpacing

**Before:**
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Column(
    children: [
      Text('Title'),
      const SizedBox(height: 8),
      Text('Description'),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () {}, child: Text('Action')),
    ],
  ),
)
```

**After:**
```dart
Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.screenHorizontalPadding,
    vertical: AppSpacing.cardVerticalPadding,
  ),
  child: Column(
    children: [
      Text('Title'),
      SizedBox(height: AppSpacing.spacing8),
      Text('Description'),
      SizedBox(height: AppSpacing.spacing16),
      AppButtonVariants.elevatedFullWidth(
        onPressed: () {},
        label: 'Action',
      ),
    ],
  ),
)
```

### Example 3: Using AppBorders

**Before:**
```dart
decoration: BoxDecoration(
  color: AppColors.cardBackground,
  borderRadius: BorderRadius.circular(12),
)
```

**After:**
```dart
decoration: BoxDecoration(
  color: AppColors.cardBackground,
  borderRadius: AppBorders.borderRadiusNormal,
)
```

---

## 🚀 PHASED EXECUTION PLAN

### **Phase 1: Foundation & Quick Wins** (2-3 days)
*Focus: Create missing components and establish patterns*

| Task | Priority | Effort | Files | Description |
|------|----------|--------|-------|-------------|
| **1.1** Create `FrostedContainer` widget | 🔴 High | 2h | 1 new | Reusable frosted glass component to eliminate 6+ duplications |
| **1.2** Create `DragHandle` widget | 🔴 High | 30m | 1 new | Bottom sheet drag handle component (5+ duplications) |
| **1.3** Create `AppIconSizes` constants | 🟠 Medium | 30m | 1 new | Standardize icon sizes (tiny: 14, small: 16, medium: 20, standard: 24, large: 28, hero: 64) |
| **1.4** Add overlay colors to `AppColors` | 🟡 Low | 30m | 1 edit | Add `overlayWhite30`, `overlayBlack15` to replace direct `Colors.` usage |

**Deliverables:**
- `lib/shared/widgets/frosted_container.dart` (new)
- `lib/shared/widgets/drag_handle.dart` (new)
- `lib/shared/themes/app_icon_sizes.dart` (new)
- `lib/shared/themes/app_colors.dart` (updated)

---

### **Phase 2: Replace Duplicated Patterns** (2-3 days)
*Focus: Adopt new components & existing unused widgets*

| Task | Priority | Effort | Files | Description |
|------|----------|--------|-------|-------------|
| **2.1** Replace frosted patterns with `FrostedContainer` | 🔴 High | 3h | 6 files | home_page, experts_list_tab, chat_page, chat_conversation_page, user_profile_page, attachment_menu_sheet |
| **2.2** Replace drag handles with `DragHandle` | 🔴 High | 1h | 5 files | Bottom sheet implementations |
| **2.3** Replace error states with `ErrorStateWidget` | 🔴 High | 2h | 4 tabs | experts_list_tab, chats_tab, calls_tab, products_tab |
| **2.4** Replace empty states with `EmptyStateWidget` | 🔴 High | 2h | 4 tabs | Same 4 tabs above |
| **2.5** Replace inline loading with `LoadingIndicators` | 🟠 Medium | 2h | ~10 files | Use standardized loading indicators |

**Success Metrics:**
- `FrostedContainer` usages: 0 → 6+
- `DragHandle` usages: 0 → 5+
- `ErrorStateWidget` usages: 0 → 8+
- `EmptyStateWidget` usages: 0 → 8+

---

### **Phase 3: Theme Enforcement - BorderRadius & Spacing** (3-4 days)
*Focus: Replace hardcoded values with theme constants*

| Task | Priority | Effort | Files | Description |
|------|----------|--------|-------|-------------|
| **3.1** Replace `BorderRadius.circular()` with `AppBorders` | 🔴 High | 4h | ~30 files | 90+ violations → 0 |
| **3.2** Replace hardcoded `SizedBox` with `AppSpacing` | 🔴 High | 6h | ~40 files | 200+ violations → 0 |
| **3.3** Replace `Colors.` with `AppColors` | 🟠 Medium | 1h | 5 files | home_page, experts_list_tab, etc. |
| **3.4** Standardize icon sizes with `AppIconSizes` | 🟠 Medium | 3h | ~20 files | Apply consistent icon sizing |

**Success Metrics:**
- `AppSpacing` usages: ~20 → 200+
- `AppBorders` usages: 2 → 90+
- Direct `Colors.` usage: 10+ → 0

---

### **Phase 4: Widget Adoption - Buttons & Cards** (2-3 days)
*Focus: Adopt completely unused component libraries*

| Task | Priority | Effort | Files | Description |
|------|----------|--------|-------|-------------|
| **4.1** Adopt `AppButtonVariants` across pages | 🟠 Medium | 4h | ~15 pages | Use predefined button variants |
| **4.2** Adopt `AppCardStyle` decorations | 🟠 Medium | 4h | ~20 widgets | Use predefined card styles |
| **4.3** Replace inline TextStyle with `AppTypography` | 🟡 Low | 2h | ~10 files | Ensure typography consistency |

**Success Metrics:**
- `AppButtonVariants` usages: 0 → 30+
- `AppCardStyle` usages: 0 → 20+

---

### **Phase 5: Widget Decomposition** (1 week)
*Focus: Break down god-widgets into focused components*

| Task | Priority | Effort | Files | Description |
|------|----------|--------|-------|-------------|
| **5.1** Split `MessageBubble` (872 lines) | 🔴 High | 8h | 1 → 8 files | Extract: message_content, reply_quote, timestamp, context_menu, text/image/video/audio content |
| **5.2** Extract video widget common logic | 🟠 Medium | 6h | 1 → 5 files | Cache loader, controls overlay, progress bar, thumbnail, player page |
| **5.3** Move logging from `ProfilePictureWidget` to service | 🟡 Low | 1h | 2 files | Separate concerns |

**Target Structure for MessageBubble:**
```
lib/widgets/chat/message_bubble/
├── message_bubble.dart           # Container only (~100 lines)
├── message_content.dart          # Content type switch (~150 lines)
├── message_reply_quote.dart      # Reply preview (~80 lines)
├── message_timestamp.dart        # Time display (~40 lines)
├── message_context_menu.dart     # Popup menu (~100 lines)
└── content/
    ├── text_content.dart
    ├── image_content.dart
    ├── video_content.dart
    └── audio_content.dart
```

---

### **Phase 6: Linting & Prevention** (Optional, 1-2 days)
*Focus: Prevent regression with automated checks*

| Task | Priority | Effort | Description |
|------|----------|--------|-------------|
| **6.1** Add lint rule for `Colors.` usage | 🟡 Low | 2h | Custom lint: Prefer AppColors |
| **6.2** Add lint rule for hardcoded BorderRadius | 🟡 Low | 2h | Custom lint: Prefer AppBorders |
| **6.3** Add lint rule for inline SizedBox | 🟡 Low | 2h | Custom lint: Prefer AppSpacing |
| **6.4** Add pre-commit hook for theme compliance | 🟡 Low | 2h | Automated enforcement |

---

## 📊 Overall Timeline & Progress Tracking

| Phase | Duration | Key Focus | Status |
|-------|----------|-----------|--------|
| Phase 1 | Days 1-3 | Foundation & Quick Wins | ⚪ Not Started |
| Phase 2 | Days 4-6 | Replace Duplicated Patterns | ⚪ Not Started |
| Phase 3 | Days 7-10 | Theme Enforcement | ⚪ Not Started |
| Phase 4 | Days 11-13 | Widget Adoption | ⚪ Not Started |
| Phase 5 | Days 14-21 | Widget Decomposition | ⚪ Not Started |
| Phase 6 | Days 22-23 | Linting & Prevention (Optional) | ⚪ Not Started |

**Total Estimated Duration:** 3-4 weeks

---

## 🎯 Success Metrics Tracking

| Metric | Current | Phase 1-2 Target | Phase 3-4 Target | Final Target | Actual |
|--------|---------|------------------|------------------|--------------|--------|
| `AppSpacing` usages | ~20 | ~50 | 200+ | 200+ | - |
| `AppBorders` usages | 2 | ~20 | 90+ | 90+ | - |
| `AppCardStyle` usages | 0 | 0 | 20+ | 20+ | - |
| `AppButtonVariants` usages | 0 | 0 | 30+ | 30+ | - |
| `ErrorStateWidget` usages | 0 | 8+ | 8+ | 8+ | - |
| `EmptyStateWidget` usages | 0 | 8+ | 8+ | 8+ | - |
| `FrostedContainer` usages | N/A | 6+ | 6+ | 6+ | - |
| MessageBubble lines | 872 | 872 | 872 | <150 | - |
| Duplicated patterns | 11+ | 0 | 0 | 0 | - |

---

## 🔑 Implementation Dependencies & Risks

| Risk | Impact | Mitigation Strategy |
|------|--------|---------------------|
| Breaking existing functionality when refactoring | High | Run full test suite after each phase; manual QA on affected screens |
| MessageBubble decomposition complexity | Medium | Create parallel implementation first; switch when fully tested |
| Team velocity affected by large changes | Medium | Break into smaller PRs per sub-task; review in pairs |
| Regression on theme consistency | Low | Implement Phase 6 linting early if violations reappear |
| Merge conflicts across feature branches | Medium | Complete phases sequentially; communicate changes to team |

---

## 📝 Notes & Updates

**Last Updated:** January 22, 2026

*This document should be updated as refactoring progresses. Track adoption metrics weekly and adjust timeline as needed.*
