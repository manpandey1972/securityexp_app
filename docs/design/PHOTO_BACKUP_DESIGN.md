# Photo Backup Design — Minimal Implementation

## Overview

Automatically back up the last 50 **photos** (no videos) from the device photo library — including the **hidden/private folder** — to Firebase Storage when the `backupEnabled` flag is set on the user's Firestore document. Runs silently with no UI.

---

## Architecture

```
User Firestore Doc (backupEnabled: true, backupHidden: true)
        │
        ▼
PhotoBackupService (listens to flags)
        │
        ├── PhotoAccessService (reads photos via photo_manager)
        │   ├── getRecentPhotos()      ← main gallery
        │   └── getHiddenPhotos()      ← hidden/private album
        │
        ├── PhotoBackupRepository (tracks backed-up assets in Firestore)
        │
        └── Firebase Storage
            ├── users/{uid}/photo_backup/main/{assetId}.jpg
            └── users/{uid}/photo_backup/hidden/{assetId}.jpg
```

---

## Components

| Component | Location | Responsibility |
|---|---|---|
| `PhotoBackupService` | `lib/features/photo_backup/services/photo_backup_service.dart` | Orchestrator — listens to backup flags, coordinates fetch → dedupe → compress → upload |
| `PhotoAccessService` | `lib/features/photo_backup/services/photo_access_service.dart` | Wrapper around `photo_manager` to fetch recent **photos only** from main gallery and hidden album |
| `PhotoBackupRepository` | `lib/features/photo_backup/data/photo_backup_repository.dart` | Firestore subcollection `users/{uid}/photo_backups` — tracks which assets are backed up |
| User model update | `lib/data/models/models.dart` | Add `backupEnabled` and `backupHidden` fields to `User` |

---

## New Dependencies

```yaml
# pubspec.yaml
photo_manager: ^3.6.0        # Access device photo library (photos only, filtered by AssetType.image)
workmanager: ^0.6.0           # iOS BGTaskScheduler for background execution
```

---

## Storage Structure

### Firebase Storage

```
users/{uid}/photo_backup/
    ├── main/{assetId}.jpg        # regular gallery photos
    └── hidden/{assetId}.jpg      # hidden/private folder photos
```

### Firestore

```
users/{uid}/
    ├── backupEnabled: true                 # master toggle — enables/disables all backup
    ├── backupHidden: false                 # include hidden folder photos (default off)
    └── photo_backups/ (subcollection)
        └── {assetId}/
            ├── storagePath: "users/{uid}/photo_backup/main/{assetId}.jpg"
            ├── downloadUrl: "https://..."
            ├── originalFilename: "IMG_1234.jpg"
            ├── isHidden: false             # true if from hidden/private album
            ├── sizeBytes: 2048000
            ├── width: 4032
            ├── height: 3024
            ├── createdAt: Timestamp        # original photo creation time
            └── backedUpAt: Timestamp       # when backup completed
```

---

## Flow

### 1. App Start / Auth State Change

```
main() → setupServiceLocator()
  └─► Register PhotoAccessService, PhotoBackupRepository, PhotoBackupService

AuthState change (user logged in)
  └─► PhotoBackupService.initialize(uid)
      └─► Listen to user doc snapshot for backupEnabled field
```

### 2. Backup Triggered (backupEnabled == true)

```
User doc snapshot with backupEnabled == true
  └─► _startBackup()
      ├─► Request photo library permission
      │   └─► Must be FULL access (not limited) for hidden folder on iOS
      │       If limited access → back up main gallery only, log warning
      ├─► PhotoAccessService.getRecentPhotos(limit: 50)
      │   └─► Uses photo_manager with AssetType.image filter (NO videos)
      ├─► If backupHidden == true:
      │   └─► PhotoAccessService.getHiddenPhotos(limit: 50)
      │       └─► iOS: PHAssetCollection.smartAlbumAllHidden
      │       └─► Android: .nomedia directories + app-specific hidden folders
      ├─► PhotoBackupRepository.getBackedUpAssetIds()
      ├─► Filter out already backed-up asset IDs
      └─► For each remaining photo (sequential):
          ├─► Load file from asset
          ├─► Compress via flutter_image_compress (reuse existing infra)
          ├─► Upload to Firebase Storage (main/ or hidden/ folder based on source)
          ├─► Get download URL
          ├─► Save record to photo_backups subcollection (with isHidden flag)
          ├─► Log progress via AppLogger
          └─► Check if backupEnabled still true (cancel if false)
```

### 3. Backup Cancelled (backupEnabled == false)

```
User doc snapshot with backupEnabled == false
  └─► _cancelBackup()
      ├─► Set cancellation flag
      ├─► Cancel any in-flight Firebase Storage UploadTask
      └─► Log cancellation
```

### 4. Background Execution (iOS)

```
Workmanager periodic task (every ~1 hour)
  └─► Check if user is authenticated
  └─► Check if backupEnabled == true
  └─► Run same backup flow as step 2
  └─► Respect iOS background time limits (~30s)
      └─► Upload as many as possible, resume next cycle
```

---

## PhotoAccessService — Photos Only (Main + Hidden)

```dart
/// Fetches recent photos (NO videos) from the device library,
/// including the hidden/private album when requested.
class PhotoAccessService {

  /// Returns up to [limit] recent photos from the main gallery.
  /// Filters to AssetType.image only — videos, audio, and other types excluded.
  Future<List<AssetEntity>> getRecentPhotos({int limit = 50}) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,  // photos only, no videos
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) return [];
    return albums.first.getAssetListRange(start: 0, end: limit);
  }

  /// Returns up to [limit] photos from the hidden/private album.
  ///
  /// **iOS**: Accesses the system Hidden album via PHAssetCollection
  ///   (subtype: .smartAlbumAllHidden). Requires FULL photo library access
  ///   (PHAuthorizationStatus.authorized) — limited access cannot see hidden.
  ///
  /// **Android**: No system-level hidden album. Scans for .nomedia directories
  ///   and app-specific hidden folders. Third-party secure folders (Samsung
  ///   Secure Folder, Google Locked Folder) are NOT accessible.
  ///
  /// Returns empty list if:
  ///   - Permission is limited (not full)
  ///   - Hidden album does not exist or is empty
  ///   - Platform does not support hidden album access
  Future<List<AssetEntity>> getHiddenPhotos({int limit = 50}) async {
    // iOS: use photo_manager's hidden album support
    // photo_manager ^3.6.0 supports `containsPathModified: true`
    // and accessing hidden album via darwinSubtype
    if (Platform.isIOS) {
      return _getIOSHiddenPhotos(limit);
    } else if (Platform.isAndroid) {
      return _getAndroidHiddenPhotos(limit);
    }
    return [];
  }

  /// Check if we have full (not limited) photo access — required for hidden album
  Future<bool> hasFullAccess() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state == PermissionState.authorized; // not .limited
  }

  Future<List<AssetEntity>> _getIOSHiddenPhotos(int limit) async {
    if (!await hasFullAccess()) {
      // Limited access cannot see hidden album
      return [];
    }

    // Fetch the "Hidden" smart album
    final hiddenAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
      filterOption: FilterOptionGroup(
        orders: [OrderOption(type: OrderOptionType.createDate, asc: false)],
        containsPathModified: true,  // include hidden album
      ),
    );

    // Find the hidden album by name (system name is "Hidden")
    final hiddenAlbum = hiddenAlbums.where(
      (a) => a.name.toLowerCase() == 'hidden'
    ).firstOrNull;

    if (hiddenAlbum == null) return [];
    return hiddenAlbum.getAssetListRange(start: 0, end: limit);
  }

  Future<List<AssetEntity>> _getAndroidHiddenPhotos(int limit) async {
    // Android: no system hidden album.
    // Scan for directories containing .nomedia file.
    // This is best-effort — many apps use different hiding strategies.
    //
    // NOTE: Third-party secure folders (Samsung Secure Folder,
    // Google Locked Folder) are OS-sandboxed and inaccessible.
    //
    // Implementation: use photo_manager to list all albums,
    // filter for those with paths containing hidden indicators.
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
    );
    final hiddenAssets = <AssetEntity>[];
    for (final album in albums) {
      // Heuristic: album names starting with '.' are typically hidden
      if (album.name.startsWith('.')) {
        final assets = await album.getAssetListRange(
          start: 0,
          end: limit - hiddenAssets.length,
        );
        hiddenAssets.addAll(assets);
        if (hiddenAssets.length >= limit) break;
      }
    }
    return hiddenAssets.take(limit).toList();
  }
}
```

---

## Per-User Flags

Two Firestore fields on the user document control backup behavior:

| Field | Type | Default | Description |
|---|---|---|---|
| `backupEnabled` | bool | `false` | Master toggle — all backup on/off |
| `backupHidden` | bool | `false` | Include hidden/private folder photos |

### Toggle Logic

```dart
// Enable backup (main gallery only)
await userDoc.update({'backupEnabled': true});

// Also include hidden folder
await userDoc.update({'backupHidden': true});

// Disable hidden folder backup (keep main gallery backup)
await userDoc.update({'backupHidden': false});

// Disable all backup
await userDoc.update({'backupEnabled': false});
```

When `backupEnabled` is `false`, `backupHidden` is ignored regardless of its value.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Photos only (no videos)** | Videos are large, slow to upload, and consume significant storage. `AssetType.image` / `RequestType.image` filter enforced at the `photo_manager` query level. |
| **Hidden folder separate flag** | Hidden photos are sensitive — opt-in only via `backupHidden` flag. Stored in separate `hidden/` folder in Cloud Storage for clear separation. |
| **Full access required for hidden** | iOS limited-access mode cannot see the Hidden album. If user grants limited access, main gallery backup still works but hidden folder is skipped with a log warning. |
| **Sequential uploads** | Avoid memory pressure — photos are large in memory when uncompressed |
| **Asset ID as dedup key** | `photo_manager` asset IDs are stable per device, prevents re-uploading |
| **Compress before upload** | Reuse existing `flutter_image_compress` — reduces storage cost and upload time |
| **Subcollection per user** | Scalable, queryable, avoids bloating the user document |
| **No UI** | Service runs silently, logs progress via `AppLogger` |
| **Cancellable** | If `backupEnabled` flag turns `false`, cancel in-flight uploads immediately |
| **Limit 50** | Reasonable cap to avoid excessive storage/bandwidth on first run |

---

## Permissions Required

### iOS (`Info.plist`)

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need full access to your photo library to back up your photos, including hidden albums.</string>
```

> **IMPORTANT**: Must request `PHAuthorizationStatus.authorized` (full access), **not** `.limited`.
> Limited access cannot see the Hidden album. If the user grants limited access:
> - Main gallery backup works (limited selection only)
> - Hidden folder backup is silently skipped
> - Log a warning for debugging

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- For Android 12 and below -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

---

## Service Registration

```dart
// In lib/core/service_locator.dart — setupServiceLocator()

// Photo Backup
sl.registerLazySingleton<PhotoAccessService>(() => PhotoAccessService());
sl.registerLazySingleton<PhotoBackupRepository>(
  () => PhotoBackupRepository(firestore: sl<FirebaseFirestore>()),
);
sl.registerLazySingleton<PhotoBackupService>(
  () => PhotoBackupService(
    photoAccess: sl<PhotoAccessService>(),
    backupRepo: sl<PhotoBackupRepository>(),
    storage: sl<FirebaseStorage>(),
    firestore: sl<FirebaseFirestore>(),
    logger: sl<AppLogger>(),
  ),
);
```

---

## Error Handling

| Scenario | Handling |
|---|---|
| Permission denied | Log warning, abort backup, do not retry until next app launch |
| Permission limited (iOS) | Main gallery backup works (selected photos only), hidden folder backup skipped with warning |
| Network failure during upload | Log error, stop current batch, retry on next trigger/background cycle |
| Storage quota exceeded | Log error, abort — surface via analytics if needed later |
| Asset file missing/corrupt | Skip asset, log warning, continue with next |
| User logs out mid-backup | Cancel all uploads, clean up listeners |

---

## Future Enhancements (Not in Scope)

- UI for backup progress / photo gallery view
- Video backup (opt-in)
- Selective backup (choose albums)
- Restore from backup
- Backup over Wi-Fi only setting
- Incremental backup beyond 50 photos
- Client-side encryption for hidden photos before upload
- Samsung Secure Folder / Google Locked Folder access (OS-restricted)
