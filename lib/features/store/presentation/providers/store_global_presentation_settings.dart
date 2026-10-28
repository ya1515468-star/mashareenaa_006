import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-authoritative visual settings shared by every tab in the chat store.
class StoreGlobalPresentationSettings {
  final double fontScale;
  final double emojiScale;
  final double cardScale;
  final double previewScale;

  const StoreGlobalPresentationSettings({
    required this.fontScale,
    required this.emojiScale,
    required this.cardScale,
    required this.previewScale,
  });

  static const defaults = StoreGlobalPresentationSettings(
    fontScale: 1.0,
    emojiScale: 1.0,
    cardScale: 1.0,
    previewScale: 1.0,
  );

  factory StoreGlobalPresentationSettings.fromMap(Map<String, dynamic> map) {
    double read(String key, double fallback, double min, double max) {
      final raw = map[key];
      final parsed = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
      return (parsed ?? fallback).clamp(min, max).toDouble();
    }

    return StoreGlobalPresentationSettings(
      fontScale: read('font_scale', 1.0, 0.70, 1.30),
      emojiScale: read('emoji_scale', 1.0, 0.60, 1.50),
      cardScale: read('card_scale', 1.0, 0.70, 1.30),
      previewScale: read('preview_scale', 1.0, 0.60, 1.40),
    );
  }
}

final storeGlobalPresentationSettingsProvider =
    FutureProvider<StoreGlobalPresentationSettings>((ref) async {
  try {
    final raw = await Supabase.instance.client.rpc(
      'get_store_global_presentation_settings',
    );
    if (raw is Map) {
      return StoreGlobalPresentationSettings.fromMap(
        Map<String, dynamic>.from(raw),
      );
    }
  } catch (_) {
    // Keep the store usable if the network is temporarily unavailable.
  }
  return StoreGlobalPresentationSettings.defaults;
});

/// Realtime changes invalidate the shared settings provider on connected clients.
final storeGlobalPresentationRealtimeProvider = Provider<void>((ref) {
  final client = Supabase.instance.client;
  final channel = client.channel('store-global-presentation-settings')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'store_global_presentation_settings',
      callback: (_) => ref.invalidate(storeGlobalPresentationSettingsProvider),
    );
  channel.subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel).then<void>((_) {}));
  });
});

class StorePresentationScope extends InheritedWidget {
  final StoreGlobalPresentationSettings settings;

  const StorePresentationScope({
    super.key,
    required this.settings,
    required super.child,
  });

  static StoreGlobalPresentationSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StorePresentationScope>()?.settings ??
      StoreGlobalPresentationSettings.defaults;

  @override
  bool updateShouldNotify(StorePresentationScope oldWidget) =>
      settings.fontScale != oldWidget.settings.fontScale ||
      settings.emojiScale != oldWidget.settings.emojiScale ||
      settings.cardScale != oldWidget.settings.cardScale ||
      settings.previewScale != oldWidget.settings.previewScale;
}
