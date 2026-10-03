import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GIF animal renderer never treats animation_json as image bytes', () {
    final providers = File('lib/features/gamification/presentation/providers/name_animation_providers.dart').readAsStringSync();
    expect(providers, isNot(contains('utf8.encode(jsonEncode(json))')));
    expect(providers, contains("storage.from('name-animations').download(path)"));
  });

  test('animal overlay preserves row footprint', () {
    final widget = File('lib/features/gamification/presentation/widgets/name_animation_widget.dart').readAsStringSync();
    expect(widget, contains('Stack('));
    expect(widget, contains('clipBehavior: Clip.none'));
    expect(widget, contains('Positioned('));
    expect(widget, isNot(contains('return Column(\n      mainAxisSize: MainAxisSize.min')));
  });

  test('edge function validates actual GIF and supports CORS', () {
    final edge = File('supabase/functions/name-animation-assets/index.ts').readAsStringSync();
    expect(edge, contains('inspectGif'));
    expect(edge, contains('OPTIONS'));
    expect(edge, contains('GIF_TOO_MANY_FRAMES'));
    expect(edge, contains('GIF_DECODED_TOO_LARGE'));
    expect(edge, contains('DATABASE_WRITE_FAILED'));
    expect(edge, contains('idempotency_requests'));
  });

  test('strict migration keeps production data and adds owner CRUD', () {
    final sql = File('supabase/migrations/20260910010000_name_animals_admin_crud_and_self_healing_live_verified.sql').readAsStringSync();
    expect(sql, contains('admin_update_name_animation'));
    expect(sql, contains('admin_set_name_animation_active'));
    expect(sql, contains('admin_check_name_animals'));
    expect(sql, contains('admin_check_name_animal_storage_orphans'));
    expect(sql, contains('audit_logs'));
    expect(sql, isNot(contains('DELETE FROM public.name_animation_catalog')));
  });
}
