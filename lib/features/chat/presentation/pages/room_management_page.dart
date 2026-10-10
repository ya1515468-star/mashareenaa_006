import 'dart:ui' as ui;
import '../../../../core/services/snack_sfx.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/typography/local_glyph_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mashareena/core/services/supabase_service.dart';
import 'package:mashareena/core/services/media_upload_service.dart';
import 'package:uuid/uuid.dart';

class RoomManagementPage extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> initialControls;

  const RoomManagementPage({
    super.key,
    required this.roomId,
    required this.initialControls,
  });

  @override
  State<RoomManagementPage> createState() => _RoomManagementPageState();
}

class _RoomManagementPageState extends State<RoomManagementPage> {
  final _memberController = TextEditingController();
  final _sb = Supabase.instance.client;
  late bool _showMic;
  late bool _showGames;
  late bool _showMedia;
  late bool _locked;
  late bool _youtubeEnabled;
  late bool _tiktokEnabled;
  bool _busy = false;
  String? _message;
  Map<String, dynamic> _controls = const <String, dynamic>{};

  Map<String, dynamic> _adminContext = const <String, dynamic>{};
  bool _adminContextBusy = false;
  String? _adminContextError;
  final Map<String, String> _roomSounds = {
    'publicMessage': 'message',
    'privateMessage': 'notification',
    'mention': 'mention',
    'reply': 'message',
    'friendRequest': 'notification',
    'gift': 'notification',
    'notification': 'notification',
    'warning': 'mention',
    'call': 'call',
  };

  final Map<String, bool> _permissions = {
    'can_kick': false,
    'can_mute': false,
    'can_ban': false,
    'can_unban': false,
    'can_edit_profiles': false,
    'can_manage_media': false,
    'can_manage_members': false,
    'can_pin_messages': false,
    'can_use_mic': false,
    'can_manage_games': false,
    'can_manage_youtube': false,
    'can_manage_tiktok': false,
  };

  List<Map<String, dynamic>> _roomRoles = const <Map<String, dynamic>>[];
  String? _selectedRoleId;

  @override
  void initState() {
    super.initState();
    _controls = Map<String, dynamic>.from(widget.initialControls);
    _showMic = _controls['show_mic'] != false;
    _showGames = _controls['show_games'] != false;
    _showMedia = _controls['show_media'] != false;
    _locked = _controls['locked'] == true;
    _youtubeEnabled = _controls['youtube_enabled'] != false;
    _tiktokEnabled = _controls['tiktok_enabled'] != false;
    _loadRoomControls();
    _loadRoomSounds();
    _loadRoomRoles();
  }

  Future<void> _loadRoomControls() async {
    try {
      Map<String, dynamic> controls = <String, dynamic>{};
      try {
        final raw = await _sb.rpc(
          'get_my_room_controls',
          params: {'p_room_id': widget.roomId},
        );
        if (raw is Map) {
          controls = Map<String, dynamic>.from(raw);
        }
      } catch (_) {
        // Fall through to the canonical room-row fallback below.
      }

      // Reconcile owner/platform flags against the canonical chat_rooms row
      // even when the RPC returned a complete map. This prevents a stale UI
      // response from disabling an actual room owner.
      final canonicalRow = await _sb
          .from('chat_rooms')
          .select('owner_id,settings,is_active')
          .eq('id', widget.roomId)
          .maybeSingle();
      if (canonicalRow == null || canonicalRow['is_active'] == false) {
        throw StateError('ROOM_NOT_FOUND');
      }
      final canonicalOwnerId = canonicalRow['owner_id']?.toString();
      final canonicalIsOwner = canonicalOwnerId == _sb.auth.currentUser?.id;
      bool canonicalIsPlatformOwner = false;
      try {
        canonicalIsPlatformOwner = await _sb.rpc('is_my_platform_owner') == true;
      } catch (_) {}
      if (canonicalIsOwner || canonicalIsPlatformOwner) {
        final settings = canonicalRow['settings'] is Map
            ? Map<String, dynamic>.from(canonicalRow['settings'] as Map)
            : const <String, dynamic>{};
        controls = <String, dynamic>{
          ...controls,
          'is_room_owner': canonicalIsOwner,
          'is_platform_owner': canonicalIsPlatformOwner,
          'can_manage_room': true,
          'can_manage_members': true,
          'can_kick': true,
          'can_mute': true,
          'can_ban': true,
          'can_unban': true,
          'show_mic': settings['show_mic'] != false,
          'show_games': settings['show_games'] != false,
          'show_media': settings['show_media'] != false,
          'locked': settings['locked'] == true,
          'youtube_enabled': settings['youtube_enabled'] != false,
          'tiktok_enabled': settings['tiktok_enabled'] != false,
        };
      }

      if (controls.isEmpty ||
          (!controls.containsKey('can_manage_room') &&
              !controls.containsKey('is_room_owner'))) {
        final row = canonicalRow;
        if (row['is_active'] == false) {
          throw StateError('ROOM_NOT_FOUND');
        }

        final ownerId = row['owner_id']?.toString();
        final isRoomOwner = ownerId == _sb.auth.currentUser?.id;
        var isPlatformOwner = false;
        try {
          isPlatformOwner = await _sb.rpc('is_my_platform_owner') == true;
        } catch (_) {}

        final settings = row['settings'] is Map
            ? Map<String, dynamic>.from(row['settings'] as Map)
            : const <String, dynamic>{};
        controls = <String, dynamic>{
          ...controls,
          'is_room_owner': isRoomOwner,
          'is_platform_owner': isPlatformOwner,
          'can_manage_room': isRoomOwner || isPlatformOwner,
          'show_mic': settings['show_mic'] != false,
          'show_games': settings['show_games'] != false,
          'show_media': settings['show_media'] != false,
          'locked': settings['locked'] == true,
          'youtube_enabled': settings['youtube_enabled'] != false,
          'tiktok_enabled': settings['tiktok_enabled'] != false,
        };
      }

      if (!mounted) return;
      setState(() {
        _controls = controls;
        _showMic = controls['show_mic'] != false;
        _showGames = controls['show_games'] != false;
        _showMedia = controls['show_media'] != false;
        _locked = controls['locked'] == true;
        _youtubeEnabled = controls['youtube_enabled'] != false;
        _tiktokEnabled = controls['tiktok_enabled'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'تعذر تحميل صلاحيات الغرفة: $e');
    }
  }

  Future<void> _loadRoomSounds() async {
    try {
      final raw = await _sb.rpc(
        'get_room_notification_sounds',
        params: {'p_room_id': widget.roomId},
      );
      if (!mounted || raw is! Map) return;
      for (final key in _roomSounds.keys) {
        final value = raw[key]?.toString();
        if (value == 'message' ||
            value == 'notification' ||
            value == 'mention' ||
            value == 'call' ||
            value == 'none') {
          _roomSounds[key] = value!;
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _memberController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminContext() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty) {
      if (mounted) {
        setState(() => _adminContextError = 'أدخل UUID العضو أولًا.');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _adminContextBusy = true;
      _adminContextError = null;
    });

    try {
      final raw = await _sb.rpc(
        'get_room_member_admin_context',
        params: {'p_room_id': widget.roomId, 'p_user_id': uid},
      );

      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _adminContext = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adminContext = const <String, dynamic>{};
        _adminContextError = 'تعذر تحميل حالة العضو: $e';
      });
    } finally {
      if (mounted) setState(() => _adminContextBusy = false);
    }
  }

  Map<String, dynamic> get _adminTarget {
    final raw = _adminContext['target'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  Map<String, dynamic> get _adminActor {
    final raw = _adminContext['actor'];
    return raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
  }

  bool get _adminTargetExists => _adminTarget['is_member'] == true;

  bool get _adminIsBanned => _adminTarget['is_banned'] == true;

  bool get _adminIsMuted => _adminTarget['is_muted'] == true;

  bool _canAdminAction(String permission) {
    // The room-management screen is opened only after canonical room controls
    // are loaded. Keep the backend RPC as the authority; this UI check simply
    // prevents an owner from seeing disabled controls when member context is
    // stale or temporarily unavailable.
    if (_controls['is_platform_owner'] == true ||
        _controls['is_room_owner'] == true ||
        _adminContext['is_dragon'] == true) {
      return true;
    }
    // كان يقرأ العلم العام مباشرة (can_kick مثلًا) بلا أي مقارنة برتبة هذا
    // العضو المستهدف تحديدًا — عضو بصلاحية عامة كان يرى خيارات الطرد/الكتم/
    // الحظر حتى ضد عضو أعلى منه رتبة. الخادم يُرجع الآن نسخة "لهذا الهدف"
    // من كل صلاحية إجراء فعلي (can_kick_this_target...)، وهي المعتمدة هنا
    // كلما وُجدت؛ الصلاحيات العامة حقًا على مستوى الغرفة (إدارة الغرفة
    // نفسها، لا عضو محدَّد) ليس لها نسخة كهذه فتُستخدم كما هي.
    final targetKey = '${permission}_this_target';
    if (_adminActor.containsKey(targetKey)) {
      return _adminActor[targetKey] == true;
    }
    return _adminActor[permission] == true;
  }

  String _commandError(Object error) {
    if (error is PostgrestException) {
      final code = error.code?.trim();
      final message = error.message.trim();
      if (code != null && code.isNotEmpty) return '[$code] $message';
      return message;
    }
    return error.toString();
  }

  void _publishCommandResult(String label, {required bool success, String? detail}) {
    if (!mounted) return;
    final message = success
        ? '✓ $label: تم التنفيذ بنجاح'
        : '✕ $label: ${detail ?? 'فشل التنفيذ'}';
    setState(() => _message = message);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBarSfx(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loadRoomRoles() async {
    try {
      final raw = await _sb.rpc(
        'get_room_assignable_roles',
        params: {'p_room_id': widget.roomId},
      );
      if (!mounted) return;
      final roles = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      setState(() {
        _roomRoles = roles;
        if (_selectedRoleId == null ||
            !roles.any((r) => r['id']?.toString() == _selectedRoleId)) {
          _selectedRoleId = roles.isNotEmpty ? roles.first['id']?.toString() : null;
        }
      });
    } catch (e) {
      if (mounted) {
        _publishCommandResult(
          'تحميل رتب الغرفة',
          success: false,
          detail: _commandError(e),
        );
      }
    }
  }

  Future<void> _runModerationAction({
    required String action,
    int? durationMinutes,
    required String reason,
  }) async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty) {
      if (mounted) setState(() => _message = 'أدخل UUID العضو أولًا.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      switch (action) {
        case 'kick':
          await _sb.rpc(
            'kick_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_duration_minutes': durationMinutes,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'mute':
          await _sb.rpc(
            'mute_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_duration_minutes': durationMinutes,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'ban':
          await _sb.rpc(
            'ban_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_duration_minutes': durationMinutes,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'unmute':
          await _sb.rpc(
            'unmute_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'unban':
          await _sb.rpc(
            'unban_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'remove':
          await _sb.rpc(
            'remove_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'bury':
          await _sb.rpc(
            'bury_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        case 'unbury':
          await _sb.rpc(
            'unbury_room_member',
            params: {
              'p_room_id': widget.roomId,
              'p_user_id': uid,
              'p_reason': reason.isEmpty ? null : reason,
            },
          );
          break;
        default:
          throw StateError('UNKNOWN_MODERATION_ACTION');
      }

      if (!mounted) return;
      final label = switch (action) {
        'kick' => 'الطرد المؤقت',
        'mute' => 'الكتم',
        'ban' => 'الحظر',
        'unmute' => 'إلغاء الكتم',
        'unban' => 'إلغاء الحظر',
        'remove' => 'إزالة العضو',
        'bury' => 'إخفاء العضو',
        'unbury' => 'إلغاء الإخفاء',
        _ => 'الأمر',
      };
      _publishCommandResult(label, success: true);
      await _loadAdminContext();
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('تنفيذ الأمر', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(String actionLabel) async {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('سبب $actionLabel'),
        content: TextField(
          maxLines: 3,
          maxLength: 500,
          autofocus: true,
          onChanged: (value) => reason = value,
          decoration: const InputDecoration(
            hintText: 'اختياري: اكتب سبب الإجراء',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reason.trim()),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDurationAndExecute({
    required String action,
    required String title,
    required List<(String, int?)> options,
  }) async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty) {
      setState(() => _message = 'أدخل UUID العضو أولًا.');
      return;
    }
    if (!_adminTargetExists) {
      setState(
        () => _message = 'اضغط "تحميل حالة العضو" وتأكد أن العضو موجود.',
      );
      return;
    }

    final selected = await showModalBottomSheet<(String, int?)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option.$2 == null
                      ? Icons.all_inclusive_rounded
                      : Icons.timer_outlined,
                ),
                title: Text(option.$1),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final reason = await _askReason(title);
    if (reason == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد $title'),
        content: Text(
          selected.$2 == null
              ? 'سيتم تنفيذ $title لمدة دائمة على العضو.'
              : 'سيتم تنفيذ $title لمدة ${selected.$1}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runModerationAction(
      action: action,
      durationMinutes: selected.$2,
      reason: reason,
    );
  }

  Future<void> _executeImmediateAction({
    required String action,
    required String title,
  }) async {
    if (!_adminTargetExists) {
      setState(
        () => _message = 'اضغط "تحميل حالة العضو" وتأكد أن العضو موجود.',
      );
      return;
    }

    final reason = await _askReason(title);
    if (reason == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تأكيد $title'),
        content: Text('سيتم تنفيذ $title على هذا العضو الآن.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runModerationAction(
      action: action,
      durationMinutes: null,
      reason: reason,
    );
  }

  Widget _moderationActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      enabled: onTap != null && !_busy,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      onTap: onTap,
    );
  }

  Widget _buildModerationPanel() {
    final uid = _memberController.text.trim();
    final enabled = uid.isNotEmpty && _adminTargetExists && !_adminContextBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أوامر الإدارة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),

        const SizedBox(height: 10),
        TextField(
          controller: _memberController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'UUID العضو المستهدف',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1D112A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || _adminContextBusy ? null : _loadAdminContext,
          icon: _adminContextBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_search_rounded),
          label: const Text('تحميل حالة العضو'),
        ),
        if (_adminContextError != null) ...[
          const SizedBox(height: 6),
          Text(
            _adminContextError!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        if (_adminTarget.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D112A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              [
                'العضو: ${_adminTargetExists ? 'موجود' : 'غير موجود'}',
                'الدور: ${_adminTarget['role_name'] ?? 'غير معروف'}',
                if (_adminIsMuted) 'الحالة: مكتوم',
                if (_adminIsBanned) 'الحالة: محظور',
              ].join('\n'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _moderationActionTile(
          title: 'طرد مؤقت',
          subtitle: '1 د، 5 د، 15 د، 30 د، 1 س، 6 س، 24 س، 7 أيام، 30 يومًا',
          icon: Icons.logout_rounded,
          color: Colors.orangeAccent,
          onTap: enabled && _canAdminAction('can_kick')
              ? () => _chooseDurationAndExecute(
                    action: 'kick',
                    title: 'الطرد المؤقت',
                    options: const [
                      ('1 دقيقة', 1),
                      ('5 دقائق', 5),
                      ('15 دقيقة', 15),
                      ('30 دقيقة', 30),
                      ('ساعة', 60),
                      ('6 ساعات', 360),
                      ('24 ساعة', 1440),
                      ('7 أيام', 10080),
                      ('30 يومًا', 43200),
                    ],
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'كتم',
          subtitle:
              '1 د، 5 د، 15 د، 30 د، 1 س، 6 س، 24 س، 7 أيام، 30 يومًا، دائم',
          icon: Icons.volume_off_rounded,
          color: Colors.amberAccent,
          onTap: enabled && _canAdminAction('can_mute')
              ? () => _chooseDurationAndExecute(
                    action: 'mute',
                    title: 'الكتم',
                    options: const [
                      ('1 دقيقة', 1),
                      ('5 دقائق', 5),
                      ('15 دقيقة', 15),
                      ('30 دقيقة', 30),
                      ('ساعة', 60),
                      ('6 ساعات', 360),
                      ('24 ساعة', 1440),
                      ('7 أيام', 10080),
                      ('30 يومًا', 43200),
                      ('دائم', null),
                    ],
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'حظر',
          subtitle: 'ساعة، 6 ساعات، 24 ساعة، 7 أيام، 30 يومًا، دائم',
          icon: Icons.block_rounded,
          color: Colors.redAccent,
          onTap: enabled && _canAdminAction('can_ban')
              ? () => _chooseDurationAndExecute(
                    action: 'ban',
                    title: 'الحظر',
                    options: const [
                      ('ساعة', 60),
                      ('6 ساعات', 360),
                      ('24 ساعة', 1440),
                      ('7 أيام', 10080),
                      ('30 يومًا', 43200),
                      ('دائم', null),
                    ],
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'إلغاء الكتم',
          subtitle: 'إلغاء الكتم النشط فورًا',
          icon: Icons.volume_up_rounded,
          color: Colors.lightGreenAccent,
          onTap: enabled && _adminIsMuted && _canAdminAction('can_unmute')
              ? () => _executeImmediateAction(
                    action: 'unmute',
                    title: 'إلغاء الكتم',
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'إلغاء الحظر',
          subtitle: 'إلغاء الحظر النشط فورًا',
          icon: Icons.lock_open_rounded,
          color: Colors.lightBlueAccent,
          onTap: enabled && _adminIsBanned && _canAdminAction('can_unban')
              ? () => _executeImmediateAction(
                    action: 'unban',
                    title: 'إلغاء الحظر',
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'إزالة العضو من الغرفة',
          subtitle: 'إزالة نهائية من عضوية هذه الغرفة',
          icon: Icons.person_remove_alt_1_rounded,
          color: Colors.redAccent,
          onTap: enabled &&
                  _canAdminAction('can_manage_members')
              ? () => _executeImmediateAction(
                    action: 'remove',
                    title: 'إزالة العضو',
                  )
              : null,
        ),
        const Divider(color: Colors.white24, height: 22),
        _moderationActionTile(
          title: 'إخفاء/دفن العضو',
          subtitle: 'إجراء دائم حتى يتم إلغاؤه',
          icon: Icons.visibility_off_rounded,
          color: Colors.deepPurpleAccent,
          onTap: enabled &&
                  _canAdminAction('can_manage_room')
              ? () => _executeImmediateAction(
                    action: 'bury',
                    title: 'إخفاء العضو',
                  )
              : null,
        ),
        _moderationActionTile(
          title: 'إلغاء الإخفاء/الدفن',
          subtitle: 'إعادة العضو بعد الدفن',
          icon: Icons.visibility_rounded,
          color: Colors.cyanAccent,
          onTap: enabled &&
                  _canAdminAction('can_manage_room')
              ? () => _executeImmediateAction(
                    action: 'unbury',
                    title: 'إلغاء إخفاء العضو',
                  )
              : null,
        ),
      ],
    );
  }

  Future<void> _setRoomFeature(String key, bool value) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc(
        'set_room_setting',
        params: {'p_room_id': widget.roomId, 'p_key': key, 'p_enabled': value},
      );
      if (!mounted) return;
      await _loadRoomControls();
      if (!mounted) return;
      _publishCommandResult('إعداد الغرفة', success: true);
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('حفظ إعداد الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// يرفع صورة خلفية للغرفة من معرض الهاتف ويحفظها خادميًا. الرفع يحدث في
  /// مجلد المدير هو (نفس نمط "تغيير صورة العضو" الآمن)، وset_room_background
  /// هي من تتحقق من صلاحية إدارة الغرفة الحقيقية قبل قبول الرابط وحفظه —
  /// لا يوجد أي تخزين محلي، الخادم هو مصدر الخلفية الوحيد لكل من في الغرفة.
  Future<void> _pickAndSetRoomBackground(BuildContext context) async {
    final myUid = _sb.auth.currentUser?.id;
    if (myUid == null) return;
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _busy = true);
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final path = '$myUid/room_backgrounds/${widget.roomId}/${const Uuid().v4()}.$ext';
      final url = await MediaUploadService(bucket: 'media').uploadBytesAtPath(
        bytes: bytes,
        fileName: file.name,
        path: path,
        contentType: 'image/$ext',
      );
      await _sb.rpc('set_room_background',
          params: {'p_room_id': widget.roomId, 'p_background_url': url});
      if (!mounted) return;
      _publishCommandResult('خلفية الغرفة', success: true);
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('رفع خلفية الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWelcomeSettings() async {
    if (_controls['is_platform_owner'] != true) {
      if (mounted) setState(() => _message = 'إعداد بوت الترحيب متاح لمالك المنصة فقط.');
      return;
    }

    var messageText = 'أهلًا وسهلًا يـ {username}، نورت الغرفة ونتمنى لك وقتًا جميلًا معنا';
    String? imageUrl;
    String? originalImageUrl;
    bool enabled = true;
    bool loading = true;
    bool uploading = false;

    try {
      try {
        final raw = await _sb.rpc(
          'get_chat_welcome_settings',
          params: {'p_room_id': widget.roomId},
        );
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          messageText = map['message_template']?.toString() ?? messageText;
          final loaded = map['image_url']?.toString();
          imageUrl = loaded == null || loaded.isEmpty ? null : loaded;
          originalImageUrl = imageUrl;
          enabled = map['is_enabled'] != false;
        }
      } finally {
        loading = false;
      }
      if (!mounted) return;

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF171126),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final image = imageUrl;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'بوت الترحيب',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'هذا الأمر أصبح داخل خيارات الغرفة فقط. استخدم {username} لإظهار اسم العضو.',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: messageText,
                        onChanged: (value) => messageText = value,
                        maxLines: 3,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'نص الترحيب'),
                      ),
                      SwitchListTile.adaptive(
                        value: enabled,
                        onChanged: uploading ? null : (v) => setSheetState(() => enabled = v),
                        title: const Text('تفعيل عند دخول عضو', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      if (loading)
                        const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                      else
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: image == null
                              ? Image.asset('assets/chat/welcome/default_welcome.gif', fit: BoxFit.cover)
                              : Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/chat/welcome/default_welcome.gif',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const ['gif'],
                                  withData: true,
                                );
                                final file = result?.files.single;
                                if (file == null || file.bytes == null || file.bytes!.isEmpty) return;
                                if ((file.extension ?? '').toLowerCase() != 'gif') {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBarSfx(
                                      const SnackBar(content: Text('صورة الترحيب يجب أن تكون GIF.')),
                                    );
                                  }
                                  return;
                                }
                                if (file.bytes!.length > 8 * 1024 * 1024) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBarSfx(
                                      const SnackBar(content: Text('صورة الترحيب أكبر من 8MB.')),
                                    );
                                  }
                                  return;
                                }
                                ui.Codec? codec;
                                try {
                                  codec = await ui.instantiateImageCodec(file.bytes!);
                                  if (codec.frameCount < 2) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(sheetContext).showSnackBarSfx(
                                        const SnackBar(content: Text('يجب أن يكون GIF متحركًا ويحتوي على إطارين أو أكثر.')),
                                      );
                                    }
                                    return;
                                  }
                                } finally {
                                  codec?.dispose();
                                }

                                setSheetState(() => uploading = true);
                                final path = 'rooms/${widget.roomId}/${const Uuid().v4()}.gif';
                                try {
                                  await MediaUploadService(bucket: 'chat-welcome-images')
                                      .uploadBytesAtPath(
                                    bytes: file.bytes!,
                                    fileName: file.name,
                                    path: path,
                                    contentType: 'image/gif',
                                  );
                                  final url = SupabaseService.publicUrlFromBucketPath(
                                    'chat-welcome-images',
                                    path,
                                  );
                                  imageUrl = url;
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                } catch (e) {
                                  try {
                                    await SupabaseService.deleteStoragePath(
                                      bucket: 'chat-welcome-images',
                                      path: path,
                                    );
                                  } catch (_) {}
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBarSfx(
                                      SnackBar(content: Text('فشل رفع صورة الترحيب: $e')),
                                    );
                                  }
                                } finally {
                                  if (sheetContext.mounted) setSheetState(() => uploading = false);
                                }
                              },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(uploading ? 'جاري الرفع…' : 'رفع صورة الترحيب'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                setSheetState(() => uploading = true);
                                try {
                                  await _sb.rpc('update_chat_welcome_settings', params: {
                                    'p_room_id': widget.roomId,
                                    'p_message_template': messageText.trim(),
                                    'p_image_url': imageUrl ?? 'asset://assets/chat/welcome/default_welcome.gif',
                                    'p_is_enabled': enabled,
                                  });
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext, true);
                                  }
                                } catch (e) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext).showSnackBarSfx(
                                      SnackBar(content: Text('تعذر حفظ بوت الترحيب: $e')),
                                    );
                                  }
                                } finally {
                                  if (sheetContext.mounted) setSheetState(() => uploading = false);
                                }
                              },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('حفظ إعدادات البوت'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      final changedImage = imageUrl != null &&
          imageUrl != originalImageUrl &&
          !(imageUrl?.startsWith('asset://') ?? false);
      if (changedImage && saved != true) {
        try {
          await MediaUploadService(bucket: 'chat-welcome-images').deleteFile(imageUrl!);
        } catch (_) {}
      }
      final oldImageUrl = originalImageUrl;
      if (saved == true && oldImageUrl != null &&
          oldImageUrl.isNotEmpty &&
          !oldImageUrl.startsWith('asset://') &&
          oldImageUrl != imageUrl) {
        try {
          await MediaUploadService(bucket: 'chat-welcome-images').deleteFile(oldImageUrl);
        } catch (_) {}
      }
      if (saved == true) {
        _publishCommandResult('حفظ إعدادات بوت الترحيب', success: true);
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر فتح إعدادات بوت الترحيب: $e');
    }
  }

  /// الغرفة الأساسية (البند ٨): عضو جديد يدخلها أول مرة، ولا يملك أي
  /// عضو سواها قرارًا بديلًا إلا بعد زيارة غرفة أخرى فعليًا. لم يكن
  /// هناك أي تحكّم بهذا إطلاقًا؛ كانت الغرفة الظاهرة للجميع هي الأقدم
  /// تاريخ إنشاء بالصدفة لا بقرار.
  Future<void> _setAsDefaultRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('الغرفة الأساسية'),
        content: const Text('ستصبح هذه الغرفة الوجهة الأولى لكل عضو جديد ينضم للمنصة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تعيين')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _sb.rpc('owner_set_default_room', params: {'p_room_id': widget.roomId});
      if (mounted) _publishCommandResult('تعيين الغرفة الأساسية', success: true);
    } catch (e) {
      if (mounted) _publishCommandResult('تعيين الغرفة الأساسية', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الغرفة'),
        content: const Text(
          'سيتم حذف الغرفة نهائيًا. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc('delete_chat_room', params: {'p_room_id': widget.roomId});
      if (!mounted) return;
      _publishCommandResult('حذف الغرفة', success: true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _publishCommandResult('حذف الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تنظيف الغرفة'),
        content: const Text(
          'سيتم حذف رسائل الغرفة والبيانات المؤقتة فقط، مع إبقاء الأعضاء والأدوار والإعدادات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('تنظيف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc('clean_chat_room', params: {'p_room_id': widget.roomId});
      if (mounted) _publishCommandResult('تنظيف الغرفة', success: true);
    } catch (e) {
      if (mounted) _publishCommandResult('تنظيف الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPermissions() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final raw = await _sb.rpc(
        'get_room_member_permissions',
        params: {'p_room_id': widget.roomId, 'p_user_id': uid},
      );
      final row =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (!mounted) return;
      if (row.isEmpty) {
        setState(() {
          for (final key in _permissions.keys) {
            _permissions[key] = false;
          }
          _message = 'لا توجد صلاحيات محفوظة لهذا العضو بعد.';
        });
        return;
      }
      setState(() {
        for (final key in _permissions.keys) {
          _permissions[key] = row[key] == true;
        }
        _message = 'تم تحميل الصلاحيات الحالية.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'تعذر تحميل الصلاحيات: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantManager() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc(
        'grant_room_manager',
        params: {'p_room_id': widget.roomId, 'p_user_id': uid},
      );
      if (!mounted) return;
      _publishCommandResult('تعيين مدير الغرفة', success: true);
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('تعيين مدير الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeManager() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc(
        'revoke_room_manager',
        params: {'p_room_id': widget.roomId, 'p_user_id': uid},
      );
      if (!mounted) return;
      _publishCommandResult('إزالة مدير الغرفة', success: true);
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('إزالة مدير الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePermissions() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc(
        'set_room_admin_permissions',
        params: {
          'p_room_id': widget.roomId,
          'p_user_id': uid,
          for (final entry in _permissions.entries)
            'p_${entry.key}': entry.value,
        },
      );
      if (!mounted) return;
      _publishCommandResult('حفظ صلاحيات المدير', success: true);
    } catch (e) {
      if (!mounted) return;
      _publishCommandResult('حفظ صلاحيات المدير', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignSelectedRole() async {
    final uid = _memberController.text.trim();
    final roleId = _selectedRoleId;
    if (uid.isEmpty || roleId == null) {
      _publishCommandResult('تعيين الرتبة', success: false, detail: 'حدد العضو والرتبة أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc('promote_room_member', params: {
        'p_room_id': widget.roomId,
        'p_user_id': uid,
        'p_role_id': roleId,
      });
      if (!mounted) return;
      _publishCommandResult('تعيين/ترقية رتبة العضو', success: true);
      await _loadAdminContext();
    } catch (e) {
      if (mounted) _publishCommandResult('تعيين/ترقية رتبة العضو', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeSelectedRole() async {
    final uid = _memberController.text.trim();
    if (uid.isEmpty) {
      _publishCommandResult('إزالة الرتبة', success: false, detail: 'أدخل UUID العضو أولًا.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.rpc('remove_room_role', params: {
        'p_room_id': widget.roomId,
        'p_user_id': uid,
      });
      if (!mounted) return;
      _publishCommandResult('إزالة رتبة العضو', success: true);
      await _loadAdminContext();
    } catch (e) {
      if (mounted) _publishCommandResult('إزالة رتبة العضو', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setRoomSound(String event, String sound) async {
    try {
      await _sb.rpc(
        'set_room_notification_sound',
        params: {
          'p_room_id': widget.roomId,
          'p_event': event,
          'p_sound': sound,
        },
      );
      if (mounted) {
        setState(() => _roomSounds[event] = sound);
        _publishCommandResult('تعيين صوت $event', success: true);
      }
    } catch (e) {
      if (mounted) _publishCommandResult('تعيين صوت $event', success: false, detail: _commandError(e));
    }
  }

  String _audioContentType(String ext) => switch (ext) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'webm' => 'audio/webm',
        _ => 'application/octet-stream',
      };

  Future<void> _uploadRoomSound(String event) async {
    if (_busy) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'webm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) setState(() => _message = 'تعذر قراءة الملف الصوتي.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) setState(() => _message = 'الملف الصوتي أكبر من 5MB.');
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    if (!['mp3', 'wav', 'ogg', 'm4a', 'aac', 'webm'].contains(ext)) {
      if (mounted) setState(() => _message = 'صيغة الصوت غير مدعومة.');
      return;
    }
    setState(() {
      _busy = true;
      _message = 'جاري رفع صوت الغرفة…';
    });
    try {
      final path =
          'room_sounds/${widget.roomId}/${const Uuid().v4()}/$event.$ext';
      var uploaded = false;
      try {
        await MediaUploadService(bucket: 'chat-sounds').uploadBytesAtPath(
          bytes: bytes,
          fileName: file.name,
          path: path,
          contentType: _audioContentType(ext),
        );
        uploaded = true;
        final publicUrl = SupabaseService.publicUrlFromBucketPath('chat-sounds', path);
        await _setRoomSound(event, publicUrl);
      } catch (e, st) {
        if (uploaded) {
          try {
            await MediaUploadService(bucket: 'chat-sounds').deleteFile(path);
          } catch (cleanupError) {
            debugPrint('[RoomManagement] sound cleanup failed: $cleanupError');
          }
        }
        debugPrint('[RoomManagement] upload sound failed: $e');
        debugPrint(st.toString());
        rethrow;
      }
      if (mounted) _publishCommandResult('رفع صوت الغرفة', success: true);
    } catch (e) {
      if (mounted) _publishCommandResult('رفع صوت الغرفة', success: false, detail: _commandError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _roomSoundTile(String event, String label) {
    final current = _roomSounds[event] ?? 'none';
    final isUploaded =
        current.startsWith('http://') || current.startsWith('https://');
    final preset = isUploaded ? 'none' : current;
    return ListTile(
      title: LocalGlyphText(label, style: const TextStyle(color: Colors.white)),
      subtitle: isUploaded
          ? const Text(
              'صوت مرفوع من المنصة',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            )
          : null,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'رفع صوت',
            onPressed: _busy ? null : () => _uploadRoomSound(event),
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
          ),
          DropdownButton<String>(
            value: preset,
            dropdownColor: const Color(0xFF1D112A),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'message', child: Text('رسالة')),
              DropdownMenuItem(value: 'notification', child: Text('إشعار')),
              DropdownMenuItem(value: 'mention', child: Text('منشن/تحذير')),
              DropdownMenuItem(value: 'call', child: Text('مكالمة')),
              DropdownMenuItem(value: 'none', child: Text('بدون صوت')),
            ],
            onChanged: (v) {
              if (v != null) _setRoomSound(event, v);
            },
          ),
        ],
      ),
    );
  }

  Widget _featureSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    {required bool enabled}
  ) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (_busy || !enabled) ? null : onChanged,
      title: LocalGlyphText(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: LocalGlyphText(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _permissionSwitch(String key, String label) {
    return SwitchListTile.adaptive(
      dense: true,
      value: _permissions[key] == true,
      onChanged:
          _busy ? null : (value) => setState(() => _permissions[key] = value),
      title: LocalGlyphText(label, style: const TextStyle(color: Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controls = _controls;
    final canManage = controls['can_manage_room'] == true ||
        controls['is_platform_owner'] == true ||
        controls['is_room_owner'] == true;
    final canDelete = controls['is_platform_owner'] == true ||
        controls['is_room_owner'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0714),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A1185),
        foregroundColor: Colors.white,
        title: const Text('خيارات الغرفة'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!canManage)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF241733),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'خيارات الغرفة معروضة للقراءة فقط لأن حسابك لا يملك صلاحية إدارة الغرفة.',
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'تحديث صلاحيات وأوامر الغرفة',
              onPressed: _busy ? null : _loadRoomControls,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            ),
          ),
          if (_message != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF241733),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_message!, style: const TextStyle(color: Colors.white70)),
            ),
          const Text(
            'ميزات الغرفة',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _featureSwitch('المايك', 'إظهار أو إخفاء المايك العلوي في الغرفة.', _showMic, (v) {
            setState(() => _showMic = v);
            _setRoomFeature('show_mic', v);
          }, enabled: canManage),
          _featureSwitch('الألعاب', 'إظهار أو إخفاء لوحة الألعاب داخل الشات.', _showGames, (v) {
            setState(() => _showGames = v);
            _setRoomFeature('show_games', v);
          }, enabled: canManage),
          _featureSwitch('الوسائط', 'السماح بلوحات الوسائط داخل الشات.', _showMedia, (v) {
            setState(() => _showMedia = v);
            _setRoomFeature('show_media', v);
          }, enabled: canManage),
          _featureSwitch('قفل الغرفة', 'منع الأعضاء من إرسال رسائل جديدة مع إبقاء الإدارة متاحة.', _locked, (v) {
            setState(() => _locked = v);
            _setRoomFeature('locked', v);
          }, enabled: canManage),
          _featureSwitch('YouTube', 'السماح بتشغيل YouTube داخل الشات.', _youtubeEnabled, (v) {
            setState(() => _youtubeEnabled = v);
            _setRoomFeature('youtube_enabled', v);
          }, enabled: canManage),
          _featureSwitch('TikTok', 'السماح بتكامل TikTok داخل الشات.', _tiktokEnabled, (v) {
            setState(() => _tiktokEnabled = v);
            _setRoomFeature('tiktok_enabled', v);
          }, enabled: canManage),
          const SizedBox(height: 12),
          // خلفية الغرفة نفسها — لم تكن هذه الميزة موجودة إطلاقًا رغم وجود
          // عمود background_url في الجدول منذ البداية بلا أي استخدام.
          OutlinedButton.icon(
            onPressed: canManage ? () => _pickAndSetRoomBackground(context) : null,
            icon: const Icon(Icons.image_outlined),
            label: const Text('رفع خلفية الغرفة'),
          ),
          if (controls['is_platform_owner'] == true) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openWelcomeSettings,
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('إعداد بوت الترحيب'),
            ),
          ],
          if (canManage) ...[
            const Divider(color: Colors.white24, height: 30),
            const Text('أصوات وتنبيهات الغرفة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('يمكن لمالك المنصة أو مدير الغرفة اختيار صوت مستقل لكل نوع.', style: TextStyle(color: Colors.white54)),
            _roomSoundTile('publicMessage', 'رسائل العام'),
            _roomSoundTile('privateMessage', 'رسائل الخاص'),
            _roomSoundTile('mention', 'المنشن'),
            _roomSoundTile('reply', 'الرد والاقتباس'),
            _roomSoundTile('friendRequest', 'طلبات الصداقة'),
            _roomSoundTile('gift', 'الهدايا'),
            _roomSoundTile('notification', 'الإشعارات'),
            _roomSoundTile('warning', 'التحذيرات'),
            _roomSoundTile('call', 'المكالمات'),
            const Divider(color: Colors.white24, height: 30),
            _buildModerationPanel(),
            const Divider(color: Colors.white24, height: 30),
            const Text('رتبة العضو داخل الغرفة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),

            const SizedBox(height: 10),
            if (_roomRoles.isEmpty)
              OutlinedButton.icon(
                onPressed: _busy ? null : _loadRoomRoles,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحميل رتب الغرفة'),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleId,
                dropdownColor: const Color(0xFF1D112A),
                decoration: const InputDecoration(
                  labelText: 'الرتبة',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                items: [
                  for (final role in _roomRoles)
                    DropdownMenuItem<String>(
                      value: role['id']?.toString(),
                      child: Text('${role['name'] ?? role['role_key'] ?? 'رتبة'} — ${role['priority'] ?? 0}'),
                    ),
                ],
                onChanged: _busy ? null : (value) => setState(() => _selectedRoleId = value),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: _busy ? null : _assignSelectedRole, icon: const Icon(Icons.upgrade_rounded), label: const Text('تعيين/ترقية'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _removeSelectedRole, icon: const Icon(Icons.person_remove_alt_1_rounded), label: const Text('إزالة الرتبة'))),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            const Text('مدير الغرفة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('أدخل UUID للعضو ثم عيّنه كمدير أو أزل عنه الإدارة.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
            TextField(
              controller: _memberController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'UUID العضو',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1D112A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: _busy ? null : _grantManager, icon: const Icon(Icons.admin_panel_settings_rounded), label: const Text('تعيين مدير'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _revokeManager, icon: const Icon(Icons.remove_moderator_outlined), label: const Text('إزالة مدير'))),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _busy ? null : _loadPermissions, icon: const Icon(Icons.download_rounded), label: const Text('تحميل الصلاحيات الحالية')),
            if (canDelete) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _setAsDefaultRoom,
                icon: const Icon(Icons.home_rounded),
                label: const Text('اجعلها الغرفة الأساسية'),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(color: Colors.white24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: _busy ? null : _cleanRoom,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('تنظيف الغرفة بالكامل'),
            ),
            if (canDelete) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: _busy ? null : _deleteRoom,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('حذف الغرفة نهائيًا'),
              ),
            ],
            const SizedBox(height: 18),
            const Text('صلاحيات المدير', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            _permissionSwitch('can_kick', 'السماح بالطرد'),
            _permissionSwitch('can_mute', 'السماح بالكتم'),
            _permissionSwitch('can_ban', 'السماح بالحظر'),
            _permissionSwitch('can_unban', 'السماح بإلغاء الحظر'),
            _permissionSwitch('can_edit_profiles', 'تعديل بروفايلات الأعضاء'),
            _permissionSwitch('can_manage_media', 'إدارة الوسائط'),
            _permissionSwitch('can_manage_members', 'إدارة الأعضاء'),
            _permissionSwitch('can_pin_messages', 'تثبيت الرسائل'),
            _permissionSwitch('can_use_mic', 'إدارة المايك'),
            _permissionSwitch('can_manage_games', 'إدارة الألعاب'),
            _permissionSwitch('can_manage_youtube', 'إدارة YouTube'),
            _permissionSwitch('can_manage_tiktok', 'إدارة TikTok'),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _busy ? null : _savePermissions, icon: const Icon(Icons.save_rounded), label: const Text('حفظ صلاحيات المدير')),
          ],
        ],
      ),
    );
  }
}
