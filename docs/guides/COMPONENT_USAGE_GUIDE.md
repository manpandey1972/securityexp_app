# Quick Start Guide - New UI Components

## 🎯 New Components Available

### 1. AppIconButton - Modern Icon Buttons

#### Primary Variant (Green - for main actions)
```dart
AppIconButton.primary(
  icon: Icons.edit,
  onPressed: () => handleEdit(),
  tooltip: 'Edit',
)
```

#### Secondary Variant (Standard - default)
```dart
AppIconButton.secondary(
  icon: Icons.favorite,
  onPressed: () => handleLike(),
  size: AppButtonSizes.iconButtonSmall,
  tooltip: 'Like',
)
```

#### Ghost Variant (Minimal - for dense UIs)
```dart
AppIconButton.ghost(
  icon: Icons.more_vert,
  onPressed: () => handleMore(),
  iconSize: AppButtonSizes.iconMedium,
)
```

#### Destructive Variant (Red - for delete actions)
```dart
AppIconButton.destructive(
  icon: Icons.delete,
  onPressed: () => handleDelete(),
  tooltip: 'Delete',
  size: AppButtonSizes.iconButtonLarge,
)
```

#### Custom Variant (Your colors)
```dart
AppIconButton.custom(
  icon: Icons.star,
  onPressed: () => handleStar(),
  backgroundColor: Colors.amber.withValues(alpha: 0.2),
  foregroundColor: Colors.amber,
  tooltip: 'Star',
)
```

---

### 2. AppButtonSizes - Standardized Sizing

#### Using Button Heights
```dart
// Small button (32px)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(
      horizontal: AppButtonSizes.mediumPaddingX,
      vertical: AppButtonSizes.smallHeight / 2,
    ),
  ),
  child: Text('Small'),
)

// Medium button (44px)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(
      horizontal: AppButtonSizes.mediumPaddingX,
      vertical: AppButtonSizes.mediumHeight / 2,
    ),
  ),
  child: Text('Medium'),
)

// Large button (56px)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(
      horizontal: AppButtonSizes.largePaddingX,
      vertical: AppButtonSizes.largeHeight / 2,
    ),
  ),
  child: Text('Large'),
)
```

#### Using Icon Sizes
```dart
// Standard icon (20px)
Icon(Icons.edit, size: AppButtonSizes.iconStandard)

// Medium icon (24px)
Icon(Icons.delete, size: AppButtonSizes.iconMedium)

// Large icon (28px)
Icon(Icons.star, size: AppButtonSizes.iconLarge)
```

---

## 🎨 Theme Improvements

### Enhanced Button States
Buttons now have 3 feedback states:

```dart
// These are automatic via the theme!
// Users will see:
ElevatedButton(
  onPressed: () {},
  child: Text('Try hovering and pressing me!'),
)
// 1. Hover: 15% opacity
// 2. Pressed: 25% opacity
// 3. Focused: 10% opacity
```

### Input Field States
Input fields now react to interactions:

```dart
// Focused state: Icon turns green, border turns green
// Error state: Icon turns red, border turns red
// Enabled state: Normal styling

TextField(
  decoration: InputDecoration(
    hintText: 'Enter text',
    prefixIcon: Icon(Icons.email), // Reacts to state
  ),
)
```

### Dialog Enhancement
Dialogs appear more polished:

```dart
// Automatically has:
// - Better shadows (elevation 8)
// - Better typography (letter-spacing on title)
// - Better readability (1.5 line-height on content)
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text('Title'), // Looks better!
    content: Text('Message'), // More readable!
  ),
)
```

---

## 📋 Comparison: Before & After

### Icon Buttons
**Before:**
```dart
// Inconsistent approaches
IconButton(onPressed: () {}, icon: Icon(Icons.edit))
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    shape: BoxShape.circle,
  ),
  child: IconButton(onPressed: () {}, icon: Icon(Icons.delete)),
)
InkWell(onTap: () {}, child: Icon(Icons.more_vert))
```

**After:**
```dart
// Consistent, semantic variants
AppIconButton.primary(icon: Icons.edit, onPressed: () {})
AppIconButton.destructive(icon: Icons.delete, onPressed: () {})
AppIconButton.ghost(icon: Icons.more_vert, onPressed: () {})
```

### Button Sizing
**Before:**
```dart
// Magic numbers scattered everywhere
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  ),
)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
)
```

**After:**
```dart
// Centralized, consistent sizing
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(
      horizontal: AppButtonSizes.largePaddingX,
      vertical: AppButtonSizes.smallHeight / 2,
    ),
  ),
)
```

---

## ✨ Migration Guide

### Update Existing Code (Optional but Recommended)

**From:**
```dart
IconButton(
  onPressed: onPressed,
  icon: Icon(Icons.edit),
)
```

**To:**
```dart
AppIconButton.secondary(
  icon: Icons.edit,
  onPressed: onPressed,
)
```

**Benefits:**
- ✅ Consistent styling
- ✅ Better feedback on interaction
- ✅ Accessible tooltips
- ✅ Size variants available

---

## 🚀 Available Imports

### For AppIconButton
```dart
import 'package:greenhive_app/shared/widgets/app_icon_button.dart';
```

### For AppButtonSizes
```dart
import 'package:greenhive_app/shared/themes/app_button_sizes.dart';
```

### For All Theme Components
```dart
import 'package:greenhive_app/shared/themes/app_colors.dart';
import 'package:greenhive_app/shared/themes/app_typography.dart';
import 'package:greenhive_app/shared/themes/app_button_sizes.dart';
```

---

## 💡 Pro Tips

1. **Use factory constructors** - They're semantic and easy to read
   ```dart
   AppIconButton.primary(...) // Clear intent
   AppIconButton.destructive(...) // Immediate recognition
   ```

2. **Combine with sizes** - Create consistent layouts
   ```dart
   Row(
     children: [
       AppIconButton.primary(
         icon: Icons.edit,
         size: AppButtonSizes.iconButtonSmall,
         onPressed: () {},
       ),
       AppIconButton.destructive(
         icon: Icons.delete,
         size: AppButtonSizes.iconButtonSmall,
         onPressed: () {},
       ),
     ],
   )
   ```

3. **Tooltips enhance accessibility** - Always provide them
   ```dart
   AppIconButton.primary(
     icon: Icons.edit,
     onPressed: () {},
     tooltip: 'Edit profile',
   )
   ```

4. **Disabled state** - Pass isEnabled parameter
   ```dart
   AppIconButton.primary(
     icon: Icons.save,
     onPressed: () {},
     isEnabled: canSave, // Grays out when false
   )
   ```

---

## 🎯 Next Steps

The following components are ready for implementation:

1. **Reusable Button Components** - Wrapper components using AppButtonSizes
2. **Card Style Variants** - Elevated/filled/outlined card styles  
3. **Loading Button** - Button with loading indicator
4. **Search Field** - Input field with clear button
5. **Context Menu** - Reusable popup menu widget

---

**Created:** January 19, 2026
**Status:** Ready to use ✨
