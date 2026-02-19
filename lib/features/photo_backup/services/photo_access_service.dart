import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:greenhive_app/core/logging/app_logger.dart';

final _sl = GetIt.instance;

/// Wrapper around `photo_manager` to fetch recent photos from the main gallery.
///
/// iOS only — returns empty results on other platforms.
class PhotoAccessService {
  static const String _tag = 'PhotoAccessService';

  final AppLogger _log = _sl<AppLogger>();

  /// Returns up to [limit] recent photos from the main gallery.
  /// Filters to images only — no videos, audio, or other types.
  ///
  /// Returns empty list on non-iOS platforms or if no photos are available.
  Future<List<AssetEntity>> getRecentPhotos({int limit = 50}) async {
    if (kIsWeb || !Platform.isIOS) {
      _log.debug('getRecentPhotos: skipped — not iOS', tag: _tag);
      return [];
    }

    try {
      _log.debug(
        'getRecentPhotos: requesting albums (limit: $limit)',
        tag: _tag,
      );

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      _log.debug(
        'getRecentPhotos: found ${albums.length} album(s)',
        tag: _tag,
      );

      if (albums.isEmpty) {
        _log.warning('getRecentPhotos: no photo albums found', tag: _tag);
        return [];
      }

      // Log all album names for debugging
      for (int i = 0; i < albums.length; i++) {
        final a = albums[i];
        final count = await a.assetCountAsync;
        _log.debug(
          'getRecentPhotos: album[$i] name="${a.name}" '
          'id="${a.id}" count=$count isAll=${a.isAll}',
          tag: _tag,
        );
      }

      // First album is "All Photos" / "Recents"
      final recentAlbum = albums.first;
      final totalCount = await recentAlbum.assetCountAsync;
      _log.debug(
        'getRecentPhotos: using album "${recentAlbum.name}" '
        '(total assets: $totalCount, fetching up to $limit)',
        tag: _tag,
      );

      final photos = await recentAlbum.getAssetListRange(
        start: 0,
        end: limit,
      );

      _log.info(
        'getRecentPhotos: fetched ${photos.length} photos from main gallery',
        tag: _tag,
      );
      return photos;
    } catch (e, stack) {
      _log.error(
        'getRecentPhotos: FAILED — $e\n$stack',
        tag: _tag,
      );
      return [];
    }
  }

  /// Request photo library permission and return the state.
  Future<PermissionState> requestPermission() async {
    if (kIsWeb || !Platform.isIOS) {
      _log.debug('requestPermission: skipped — not iOS', tag: _tag);
      return PermissionState.denied;
    }

    final state = await PhotoManager.requestPermissionExtend();
    _log.info(
      'requestPermission: result = $state '
      '(authorized=${state == PermissionState.authorized}, '
      'limited=${state == PermissionState.limited}, '
      'denied=${state == PermissionState.denied})',
      tag: _tag,
    );
    return state;
  }
}
