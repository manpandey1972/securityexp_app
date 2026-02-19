# Performance & Memory Optimization Implementation Plan

**Created:** February 3, 2026  
**Status:** Phase 1 & 2 Complete  
**Priority:** High → Medium → Low

---

## Executive Summary

Codebase review identified **9 memory leak issues** and **20+ performance issues** across the Flutter application. This document outlines a phased approach to address these findings with minimal risk to application stability.

---

## Phase 1: Critical Memory Leaks (High Priority) ✅ COMPLETED

**Estimated Time:** 1-2 hours  
**Risk Level:** Low  
**Impact:** Prevents crashes and reduces memory consumption  
**Completed:** February 3, 2026

### 1.1 Fix StreamSubscription Leak in Audio Widgets ✅

**Files Fixed:**
- `lib/features/chat/widgets/cached_media_widgets.dart`
- `lib/features/chat/widgets/audio_recording_overlay.dart`

**Changes Made:**
- Added `StreamSubscription` fields to store listener references
- Updated `dispose()` to cancel subscriptions before disposing player

### 1.2 Fix Shimmer Timing Issue ✅

**File:** `lib/features/home/presentation/state/home_state.dart`  
**Change:** `isLoadingExperts` initial value changed from `false` to `true`

---

## ~~Phase 1 Original Details (Reference)~~

<details>
<summary>Click to expand original plan</summary>

### 1.1 Fix StreamSubscription Leak in Audio Message Widget

**File:** `lib/features/chat/widgets/audio_message_widget.dart`  
**Issue:** Stream listeners on `onPositionChanged` and `onPlayerComplete` not cancelled in dispose

**Current Code (problematic):**
```dart
_audioPlayer.onPositionChanged.listen((position) {
  if (mounted) setState(() => _playbackPosition = position);
});

_audioPlayer.onPlayerComplete.listen((_) {
  if (mounted) { ... }
});
```

**Fix:**
```dart
// Add class fields
StreamSubscription<Duration>? _positionSubscription;
StreamSubscription<void>? _completeSubscription;

// In initState or initialization method
_positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
  if (mounted) setState(() => _playbackPosition = position);
});

_completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
  if (mounted) { ... }
});

// In dispose()
@override
void dispose() {
  _positionSubscription?.cancel();
  _completeSubscription?.cancel();
  super.dispose();
}
```

### 1.2 Fix Shimmer Timing Issue

**File:** `lib/features/home/presentation/state/home_state.dart`  
**Issue:** `isLoadingExperts` initialized to `false`, causing "No experts" flash before shimmer

**Fix:** Change line 19:
```dart
// Before
this.isLoadingExperts = false,

// After
this.isLoadingExperts = true,
```

---

</details>

## Phase 2: High-Impact Performance Fixes ✅ COMPLETED

**Estimated Time:** 2-3 hours  
**Risk Level:** Low-Medium  
**Impact:** Significant improvement in scroll performance and memory usage  
**Completed:** February 3, 2026

### 2.1 Remove `shrinkWrap: true` from ListViews ⏭️ DEFERRED

**Note:** After investigation, the `shrinkWrap: true` usages found are in modal/dialog contexts where they are appropriate. The originally cited files (`chat_detail_page.dart`, `media_manager_page.dart`) do not have problematic `shrinkWrap` usage.

### 2.2 Add Image Caching Parameters ✅

**Files Fixed:**
| File | Change |
|------|--------|
| `lib/features/support/widgets/message_bubble.dart` | Added `cacheWidth: 400, cacheHeight: 300` |
| `lib/features/admin/widgets/ticket_detail/ticket_attachments.dart` | Added `cacheWidth: 400, cacheHeight: 300` |
| `lib/features/authentication/pages/splash_screen.dart` | Added `cacheWidth: 240, cacheHeight: 240` |
| `lib/features/home/pages/home_page.dart` | Added `cacheWidth: 72, cacheHeight: 72` |

### 2.3 Move Heavy Computations Out of Build Methods ⏭️ DEFERRED

**Note:** Skills sorting is done via `SkillsService` which already caches results. The current implementation is acceptable. Can be optimized in a future refactoring sprint if performance profiling indicates a bottleneck.

---

## ~~Phase 2 Original Details (Reference)~~

<details>
<summary>Click to expand original plan</summary>

### 2.1 Remove `shrinkWrap: true` from ListViews

| File | Line | Action |
|------|------|--------|
| `lib/features/chat/pages/chat_detail_page.dart` | 69 | Replace with `Sliver` or constrained height |
| `lib/features/chat/pages/media_manager_page.dart` | 328 | Replace with `Sliver` or constrained height |

**Pattern to follow:**
```dart
// Before (bad)
ListView.builder(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  ...
)

// After (good) - Option 1: Constrained height
SizedBox(
  height: itemHeight * itemCount.clamp(0, maxVisible),
  child: ListView.builder(...)
)

// After (good) - Option 2: Sliver
CustomScrollView(
  slivers: [
    SliverList(delegate: SliverChildBuilderDelegate(...))
  ]
)
```

### 2.2 Add Image Caching Parameters

| File | Line | Image Type |
|------|------|------------|
| `lib/features/support/pages/help_screen.dart` | 271 | `Image.network` |
| `lib/features/chat/pages/text_viewer_page.dart` | 44 | `Image.network` |
| `lib/features/authentication/pages/splash_screen.dart` | 292 | `Image.asset` |
| `lib/features/authentication/pages/onboarding_page.dart` | 225 | `Image.asset` |

**Fix Pattern:**
```dart
// Before
Image.network(url)

// After
Image.network(
  url,
  cacheWidth: 300,  // Adjust based on display size
  cacheHeight: 300,
)

// For CachedNetworkImage
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 300,
  memCacheHeight: 300,
)
```

### 2.3 Move Heavy Computations Out of Build Methods

| File | Method | Computation |
|------|--------|-------------|
| `lib/features/profile/pages/user_profile_page.dart` | `_buildSkillsList` | Skills sorting |
| `lib/features/profile/pages/edit_profile_page.dart` | `_buildSkillsList` | Skills sorting |
| `lib/features/chat/pages/media_manager_page.dart` | `_filterByCategory` | File filtering |
| `lib/features/support/pages/faq_screen.dart` | build | FAQ filtering |
| `lib/features/home/widgets/expert_card.dart` | build | Skills mapping |

**Pattern:**
```dart
// Before (in build method)
final sortedCategories = grouped.keys.toList()..sort();

// After (cache in state or late final)
late final List<String> _sortedCategories;

@override
void initState() {
  super.initState();
  _computeSortedCategories();
}

void _computeSortedCategories() {
  _sortedCategories = grouped.keys.toList()..sort();
}
```

</details>

---

## Phase 3: Medium Priority Fixes ✅ COMPLETED

**Estimated Time:** 3-4 hours  
**Risk Level:** Low  
**Impact:** Improved scroll performance and reduced widget rebuilds  
**Completed:** February 4, 2026

### 3.1 Add `itemExtent` to Large ListViews ⏭️ DEFERRED

**Note:** After investigation, the list items in these files have variable heights due to:
- `Wrap` widgets for role badges in user list items
- Multi-line text with `maxLines: 2` in FAQ items
- Dynamic content in rating cards

Adding `itemExtent` would cause layout issues. These lists are not performance bottlenecks.

### 3.2 Fix Anonymous Listeners ✅

**File:** `lib/features/onboarding/pages/user_onboarding_page.dart`

**Changes Made:**
- Converted anonymous listeners on `_displayNameCtrl` and `_bioCtrl` to named methods
- Added `_onDisplayNameChanged()` and `_onBioChanged()` methods
- Added `removeListener()` calls in `dispose()` before disposing controllers

### 3.3 Fix Video Player Listeners ✅

**File:** `lib/features/chat/widgets/inline_video_preview.dart`

**Changes Made (both classes):**
- Added `VoidCallback? _videoListener` field to store listener reference
- Converted anonymous listener to stored callback
- Added `removeListener()` call in `dispose()` before disposing controller

---

## ~~Phase 3 Original Details (Reference)~~

<details>
<summary>Click to expand original plan</summary>

### 3.1 Add `itemExtent` to Large ListViews

| File | Line | List Purpose |
|------|------|--------------|
| `lib/features/admin/pages/manage_users_page.dart` | 142 | User list |
| `lib/features/admin/pages/manage_users_page.dart` | 378 | User list |
| `lib/features/support/pages/faq_screen.dart` | 379 | FAQ list |
| `lib/features/profile/pages/edit_profile_page.dart` | 308 | Skills list |
| `lib/features/chat/pages/media_manager_page.dart` | 705 | Media files |
| `lib/features/profile/widgets/ratings_tab_content.dart` | 157 | Reviews list |

**Fix:**
```dart
// Before
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(),
)

// After (if items have uniform height)
ListView.builder(
  itemExtent: 72.0,  // Exact item height
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(),
)
```

### 3.2 Fix Anonymous Listeners

**File:** `lib/features/profile/pages/user_details_page.dart`
```dart
// Before (anonymous - cannot be removed)
_displayNameCtrl.addListener(() {
  final viewModel = context.read<OnboardingViewModel>();
  if (_displayNameCtrl.text != viewModel.state.displayName) {
    viewModel.setDisplayName(_displayNameCtrl.text);
  }
});

// After (named - can be removed)
void _onDisplayNameChanged() {
  final viewModel = context.read<OnboardingViewModel>();
  if (_displayNameCtrl.text != viewModel.state.displayName) {
    viewModel.setDisplayName(_displayNameCtrl.text);
  }
}

@override
void initState() {
  super.initState();
  _displayNameCtrl.addListener(_onDisplayNameChanged);
}

@override
void dispose() {
  _displayNameCtrl.removeListener(_onDisplayNameChanged);
  _displayNameCtrl.dispose();
  super.dispose();
}
```

### 3.3 Fix Video Player Listener

**File:** `lib/features/chat/widgets/video_player_widget.dart`

Store listener reference and remove explicitly before dispose.

---

## Phase 4: Low Priority Fixes (Code Quality)

**Estimated Time:** 2-3 hours  
**Risk Level:** Very Low  
**Impact:** Minor performance improvements, better code hygiene

### 4.1 Add `const` to SizedBox Widgets

**Files affected:** 15+ files with 50+ instances

**If `AppSpacing` values are compile-time constants:**
```dart
// Before
SizedBox(height: AppSpacing.spacing16)

// After
const SizedBox(height: AppSpacing.spacing16)
```

**Bulk find/replace pattern:**
- Search: `SizedBox(height: AppSpacing.`
- Replace: `const SizedBox(height: AppSpacing.`

### 4.2 Fix ScrollController Listeners

| File | Action |
|------|--------|
| `lib/features/admin/pages/manage_users_page.dart` | Add `_scrollController.removeListener(_onScroll)` before dispose |
| `lib/features/support/pages/faq_screen.dart` | Add `_scrollController.removeListener(_onScroll)` before dispose |

### 4.3 Fix TabController Listeners

| File | Action |
|------|--------|
| `lib/features/admin/pages/admin_tickets_page.dart` | Convert anonymous listener to named method |
| `lib/features/admin/pages/admin_experts_page.dart` | Convert anonymous listener to named method |

### 4.4 Dispose TextEditingControllers in Dialogs

| File | Dialog Method |
|------|---------------|
| `lib/features/chat/pages/pdf_viewer_page.dart` | `_showPageJumpDialog()` |
| `lib/features/admin/pages/admin_ticket_detail_page_refactored.dart` | Resolution dialog |

**Fix Pattern:**
```dart
void _showDialog() {
  final controller = TextEditingController(text: 'initial');
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: TextField(controller: controller),
    ),
  ).then((_) => controller.dispose());  // Dispose after dialog closes
}
```

---

## Testing Checklist

After each phase, verify:

- [ ] App builds without errors
- [ ] No new lint warnings
- [ ] Affected features work correctly
- [ ] Memory usage stable (use DevTools)
- [ ] Scroll performance smooth (60fps)
- [ ] No regression in existing functionality

---

## Rollback Plan

Each phase can be reverted independently via git:

```bash
# Tag before each phase
git tag pre-phase-1-memory-fixes
git tag pre-phase-2-performance-fixes
git tag pre-phase-3-medium-priority
git tag pre-phase-4-code-quality

# Rollback if needed
git revert HEAD~n  # Where n = commits in phase
```

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Memory leaks | 9 identified | 0 |
| Build method computations | 5+ heavy | 0 |
| ListView with shrinkWrap | 2 | 0 |
| Images without cache params | 4+ | 0 |
| Uncancelled subscriptions | 2+ | 0 |

---

## Implementation Order

1. **Phase 1** - Do first (critical memory leaks)
2. **Phase 2** - Do second (high performance impact)
3. **Phase 3** - Can be done incrementally
4. **Phase 4** - Can be done during regular maintenance

**Total Estimated Time:** 8-12 hours across all phases
