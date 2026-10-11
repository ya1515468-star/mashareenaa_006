import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../data/agora_token_service.dart';
import '../../domain/entities/call_entity.dart';
import '../providers/call_provider.dart';

class ActiveCallPage extends ConsumerStatefulWidget {
  final String callId;
  final String otherUid;
  final CallType type;
  final bool isCaller;
  const ActiveCallPage(
      {super.key,
      required this.callId,
      required this.otherUid,
      required this.type,
      required this.isCaller});
  @override
  ConsumerState<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends ConsumerState<ActiveCallPage> {
  RtcEngine? _engine;

  /// كل الأطراف البعيدة المتصلة حاليًا.
  ///
  /// كان هذا `int? _remoteUid` — طرفًا واحدًا فقط — فكل من ينضم ثالثًا
  /// يدهس الثاني ويختفي. Agora يدعم المكالمات الجماعية أصلًا؛ القيد كان
  /// في هذا السطر وحده. LinkedHashSet ليحفظ ترتيب الانضمام.
  final Set<int> _remoteUids = <int>{};

  /// الطرف المعروض في الإطار الكبير. null = أول المنضمّين.
  /// النقر على أي إطار مصغّر يبدّله معه، كما في واتساب.
  int? _spotlightUid;

  /// عند true يظهر المستخدم نفسه في الإطار الكبير والطرف الآخر مصغّرًا.
  bool _selfSpotlight = false;
  bool _joined = false;
  bool _billingSettled = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speaker = true;
  DateTime? _connectedAt;
  Timer? _timer;
  bool _initializing = true;
  String? _error;

  String get _channel =>
      'call_${widget.callId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')}';
  /// Agora UID assigned by the SERVER when it mints the token.
  ///
  /// This used to be recomputed here in Dart with the same FNV-style hash the
  /// edge function uses, and the two never matched: in JS the intermediate
  /// multiply exceeds 2^53 and loses precision before truncation, while Dart's
  /// 64-bit ints compute it exactly. Every call therefore failed with
  /// UID_MISMATCH. The server is now the single source of this value.
  int _uid = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final permissions = await [
        Permission.microphone,
        if (widget.type == CallType.video) Permission.camera
      ].request();
      if (permissions.values.any((s) => !s.isGranted)) {
        throw StateError(
            'يجب السماح بالمايكروفون${widget.type == CallType.video ? ' والكاميرا' : ''} لإجراء المكالمة.');
      }
      if (!widget.isCaller) {
        final call = await ref.read(callByIdProvider(widget.callId).future);
        if (call?.status == CallStatus.ringing) {
          await ref
              .read(callControllerProvider.notifier)
              .updateStatus(callId: widget.callId, status: CallStatus.accepted);
        }
      }
      final credentials =
          await const AgoraTokenService().issue(channel: _channel, uid: _uid);
      _uid = credentials.uid;
      if (credentials.appId.isEmpty || credentials.token.isEmpty) {
        throw StateError('لم يتم ضبط Agora App ID/Token server.');
      }
      // On Flutter Web the Agora engine lives in a separate script that must
      // be loaded by web/index.html. When it is missing the plugin throws a
      // cryptic "Cannot read properties of undefined (reading
      // 'createIrisApiEngine')" from deep inside its own code, which says
      // nothing about the real cause. Translate it into a message that names
      // the actual problem.
      final RtcEngine engine;
      try {
        engine = createAgoraRtcEngine();
      } catch (e) {
        throw StateError(
          kIsWeb
              ? 'مكتبة Agora للويب غير محمّلة. أضف سكربت iris-web-rtc إلى '
                  'web/index.html ليعمل الاتصال على المتصفح. (التفاصيل: $e)'
              : 'تعذّر تهيئة محرك الاتصال: $e',
        );
      }
      _engine = engine;
      await engine.initialize(RtcEngineContext(
          appId: credentials.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (mounted) {
            setState(() {
              _joined = true;
              _connectedAt ??= DateTime.now();
            });
            _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (mounted) setState(() {});
            });
            // نظام الفوترة بالدقيقة (call_pricing/call_billing_sessions) كان
            // مبنيًا خادميًا بالكامل من جلسة سابقة، لكن لم يكن مربوطًا بأي
            // مكان في التطبيق — كل مكالمة كانت مجانية فعليًا بصرف النظر عن
            // الأسعار المُعدَّة. المتصل فقط يبدأ الفوترة (لا الطرف المستقبِل)
            // لتفادي تكرارها؛ الخادم يرفض برصيد غير كافٍ قبل أن تبدأ المكالمة
            // فعليًا لأي طرف غير المالك.
            if (widget.isCaller) {
              unawaited(_beginBilling());
            }
          }
        },
        onUserJoined: (_, remoteUid, __) {
          if (!mounted) return;
          setState(() {
            _remoteUids.add(remoteUid);
            _spotlightUid ??= remoteUid;
          });
        },
        onUserOffline: (_, remoteUid, __) {
          if (!mounted) return;
          setState(() {
            _remoteUids.remove(remoteUid);
            // إن غادر صاحب الإطار الكبير نرقّي التالي بدل ترك شاشة فارغة
            if (_spotlightUid == remoteUid) {
              _spotlightUid =
                  _remoteUids.isEmpty ? null : _remoteUids.first;
            }
          });
        },
        onTokenPrivilegeWillExpire: (_, __) async {
          final fresh = await const AgoraTokenService()
              .issue(channel: _channel, uid: _uid);
          _uid = fresh.uid;
          await engine.renewToken(fresh.token);
        },
        onError: (code, msg) {
          if (mounted) setState(() => _error = 'Agora $code: $msg');
        },
      ));
      await engine.enableAudio();
      // WhatsApp-style call quality: AI noise suppression + echo cancellation
      // on the audio path, and denoising on the video path. Each call is
      // wrapped separately because these are device/SDK-dependent — an
      // unsupported option on one device must not abort the whole call setup.
      try {
        await engine.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioChatroom,
        );
      } catch (_) {}
      try {
        // AI noise suppression (removes background noise, keeps speech).
        await engine.setAINSMode(
          enabled: true,
          mode: AudioAinsMode.ainsModeBalanced,
        );
      } catch (_) {}
      try {
        // تعزيز إضافي على مستوى محرك الصوت نفسه: إلغاء صدى صوتي (AEC)،
        // كبت ضوضاء (ANS)، وتحكّم تلقائي بمستوى الصوت (AGC). هذه معالجات
        // مستقلة عن AINS وتعمل معها لا بدلًا منها — AEC يمنع عودة صوت
        // السماعة إلى الميكروفون (أهم سبب للصدى في مكبّر الصوت)، وAGC
        // يوحّد مستوى الصوت بين متحدّث قريب وآخر بعيد عن الجهاز.
        await engine.setParameters('{"che.audio.enable.aec":true}');
        await engine.setParameters('{"che.audio.enable.ans":true}');
        await engine.setParameters('{"che.audio.enable.agc":true}');
        // كبت صدى عدواني للمكالمات عبر مكبّر الصوت تحديدًا.
        await engine.setParameters('{"che.audio.aec.suppression.level":2}');
      } catch (_) {}
      try {
        await engine.enableAudioVolumeIndication(
            interval: 400, smooth: 3, reportVad: true);
      } catch (_) {}
      if (widget.type == CallType.video) {
        await engine.enableVideo();
        try {
          // Video denoiser: cleans grain/noise in low light.
          await engine.setVideoDenoiserOptions(
            enabled: true,
            options: const VideoDenoiserOptions(
              mode: VideoDenoiserMode.videoDenoiserAuto,
              level: VideoDenoiserLevel.videoDenoiserLevelHighQuality,
            ),
          );
        } catch (_) {}
        // NOTE: a low-light-enhancement block was removed here. The enum
        // names it used (LowlightEnhanceMode/Level) do not exist in
        // agora_rtc_engine 6.5.4, so it failed to compile. Noise suppression,
        // echo cancellation and the video denoiser above all work and cover
        // the main quality wins; low-light can be added later against the
        // exact API this SDK version exposes.
        await engine.startPreview();
      }
      await engine.joinChannel(
          token: credentials.token,
          channelId: _channel,
          uid: _uid,
          options: ChannelMediaOptions(
              autoSubscribeAudio: true,
              autoSubscribeVideo: widget.type == CallType.video,
              publishMicrophoneTrack: true,
              publishCameraTrack: widget.type == CallType.video));
    } catch (e) {
      await _endBilling();
      try {
        await ref
            .read(callControllerProvider.notifier)
            .updateStatus(callId: widget.callId, status: CallStatus.ended);
      } catch (_) {}
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _beginBilling() async {
    try {
      await Supabase.instance.client.rpc('begin_call_billing', params: {
        'p_call_id': widget.callId,
        'p_callee_uid': widget.otherUid,
        'p_call_type': widget.type.wire,
      });
    } catch (e) {
      // رصيد غير كافٍ أو المكالمات معطّلة — تُنهى المكالمة فورًا بدل أن
      // تستمر مجانًا خطأً؛ لا يُترك الطرف الآخر معلَّقًا في مكالمة لن تُفوتر.
      if (mounted) {
        setState(() => _error = e.toString().contains('INSUFFICIENT_BALANCE_FOR_CALL')
            ? 'رصيدك لا يكفي لبدء هذه المكالمة.'
            : 'تعذّر بدء المكالمة: $e');
      }
      await _hangup();
    }
  }

  Future<void> _endBilling() async {
    if (_billingSettled) return;
    _billingSettled = true;
    try {
      await Supabase.instance.client
          .rpc('end_call_billing', params: {'p_call_id': widget.callId});
    } catch (_) {
      // لا تُفشل إغلاق المكالمة بسبب خطأ في التسوية — السجل يبقى غير مُسوًّى
      // وقابلًا للمراجعة الإدارية، لكن تجربة المستخدم (إنهاء المكالمة) لا
      // يجب أن تتعطّل بسببه.
    }
  }

  Future<void> _hangup() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _timer?.cancel();
    await _endBilling();
    await ref
        .read(callControllerProvider.notifier)
        .updateStatus(callId: widget.callId, status: CallStatus.ended);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_engine?.leaveChannel());
    unawaited(_engine?.release());
    // لو غادر المستخدم الشاشة بلا ضغط زر الإغلاق (رجوع الجهاز، إغلاق
    // التطبيق)، تبقى جلسة الفوترة معلَّقة للأبد بلا تسوية — تُسوَّى هنا
    // أيضًا كشبكة أمان أخيرة، بلا انتظار (dispose لا يمكن أن يكون async).
    unawaited(_endBilling());
    super.dispose();
  }

  // ═══ عرض الفيديو متعدّد الأطراف ══════════════════════════════════
  //
  // Agora يدعم المكالمات الجماعية أصلًا؛ ما كان ينقص هو أن الكود
  // يحتفظ بطرف واحد. الآن كل طرف له إطار، وواحد في الإطار الكبير،
  // والنقر على أي مصغّر يبدّله — نفس سلوك واتساب.

  /// الإطار الكبير: الطرف المختار، أو أنت إن اخترت نفسك.
  Widget _spotlightView() {
    if (_selfSpotlight || _remoteUids.isEmpty) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    final uid = _spotlightUid ?? _remoteUids.first;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _channel),
      ),
    );
  }

  /// شريط المصغّرات: كل طرف عدا صاحب الإطار الكبير، وأنت ضمنهم.
  Widget _thumbnailStrip() {
    final tiles = <Widget>[];

    // إطارك أنت — يظهر مصغّرًا ما دمت لست في الإطار الكبير
    if (!_selfSpotlight) {
      tiles.add(_thumbTile(
        key: const ValueKey('self'),
        label: 'أنت',
        isSelf: true,
        onTap: () => setState(() => _selfSpotlight = true),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ));
    }

    final spotlight = _selfSpotlight
        ? null
        : (_spotlightUid ?? (_remoteUids.isEmpty ? null : _remoteUids.first));
    for (final uid in _remoteUids) {
      if (uid == spotlight) continue;
      tiles.add(_thumbTile(
        key: ValueKey(uid),
        label: '#$uid',
        isSelf: false,
        onTap: () => setState(() {
          _selfSpotlight = false;
          _spotlightUid = uid;
        }),
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: uid),
            connection: RtcConnection(channelId: _channel),
          ),
        ),
      ));
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 108,
      height: (tiles.length * 150).toDouble().clamp(150, 460),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => tiles[i],
      ),
    );
  }

  Widget _thumbTile({
    required Key key,
    required String label,
    required bool isSelf,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 108,
        height: 142,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelf
                  ? const Color(0xFFFFD700).withValues(alpha: .7)
                  : Colors.white24,
              width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  color: Colors.black54,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherProfileAsync = ref.watch(profileByIdProvider(widget.otherUid));
    final profile = otherProfileAsync.valueOrNull;
    final myProfile = ref.watch(currentProfileProvider).valueOrNull;
    // كان لا يظهر إلا اسم الطرف الآخر فقط — لا اسم المستخدم نفسه، ولا توضيح
    // من هو المتصل ومن هو المتصل به. الآن يظهر الاسمان معًا مع تسمية واضحة.
    final callerName =
        widget.isCaller ? (myProfile?.displayName ?? 'أنت') : profile?.displayName ?? '';
    final calleeName =
        widget.isCaller ? profile?.displayName ?? '' : (myProfile?.displayName ?? 'أنت');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          // ─── الفيديو: إطار كبير + شريط مصغّرات قابلة للتبديل ───
          //
          // كان الترتيب مقلوبًا: كاميرتك أنت ملء الشاشة والطرف الآخر
          // مصغّرًا — عكس كل تطبيقات المكالمات. الآن الطرف الآخر كبير،
          // وأنت مصغّر، والنقر على أي مصغّر يبدّله مع الكبير كواتساب.
          if (widget.type == CallType.video && _joined) ...[
            // النقر على الإطار الكبير يعيد الطرف الآخر إليه إن كنت
            // أنت فيه — تبديل ذهابًا وإيابًا كما في واتساب.
            Positioned.fill(
              child: GestureDetector(
                onTap: _selfSpotlight && _remoteUids.isNotEmpty
                    ? () => setState(() => _selfSpotlight = false)
                    : null,
                child: _spotlightView(),
              ),
            ),
            if (_remoteUids.length > 1)
              Positioned(
                top: 16,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFD700)
                            .withValues(alpha: .5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.groups_rounded,
                        size: 15, color: Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Text('${_remoteUids.length + 1} مشاركين',
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            Positioned(
              top: 16,
              right: 12,
              child: _thumbnailStrip(),
            ),
          ],
          Positioned(
            top: 8,
            right: 0,
            left: 0,
            child: Center(
              child: Text(
                'المتصل: $callerName  ·  المتصل به: $calleeName',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (widget.type == CallType.voice || !_joined)
            Positioned.fill(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                ProfileAvatar(
                    avatarUrl: (widget.isCaller ? myProfile : profile)?.avatarUrl,
                    displayName: (widget.isCaller ? myProfile : profile)?.displayName ?? '',
                    radius: 44,
                    frameKey: (widget.isCaller ? myProfile : profile)?.avatarFrameKey),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.swap_horiz_rounded, color: Colors.white54, size: 26),
                ),
                ProfileAvatar(
                    avatarUrl: (widget.isCaller ? profile : myProfile)?.avatarUrl,
                    displayName: (widget.isCaller ? profile : myProfile)?.displayName ?? '',
                    radius: 44,
                    frameKey: (widget.isCaller ? profile : myProfile)?.avatarFrameKey),
              ]),
              const SizedBox(height: 16),
              if (profile?.uid != null) ServerUsernameDisplay(uid: profile!.uid, fallbackName: profile.displayName, fallbackFontSize: 24, center: true),
              const SizedBox(height: 8),
              Text(
                  _connectedAt == null
                      ? ''
                      : _formatDuration(
                          DateTime.now().difference(_connectedAt!)),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  _initializing
                      ? 'جارٍ الاتصال...'
                      : (_joined ? 'متصل' : 'بانتظار الاتصال'),
                  style: const TextStyle(color: Colors.white70))
            ]))),
          if (_error != null)
            Positioned(
                left: 16,
                right: 16,
                top: 12,
                child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)))),
          Positioned(
              left: 16,
              right: 16,
              bottom: 22,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _control(Icons.mic_off, !_muted, () async {
                  setState(() => _muted = !_muted);
                  await _engine?.muteLocalAudioStream(_muted);
                }),
                if (widget.type == CallType.video)
                  _control(Icons.videocam_off, !_cameraOff, () async {
                    setState(() => _cameraOff = !_cameraOff);
                    await _engine?.muteLocalVideoStream(_cameraOff);
                  }),
                _control(Icons.volume_up, _speaker, () async {
                  setState(() => _speaker = !_speaker);
                  await _engine?.setEnableSpeakerphone(_speaker);
                }),
                if (widget.type == CallType.video)
                  _control(Icons.cameraswitch, true, () async {
                    await _engine?.switchCamera();
                  }),
                _control(Icons.call_end, true, _hangup, danger: true),
              ])),
        ]),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _control(IconData icon, bool enabled, VoidCallback onTap,
      {bool danger = false}) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
            radius: 28,
            backgroundColor: danger ? AppColors.error : Colors.white12,
            child: IconButton(
                onPressed: onTap,
                icon: Icon(icon,
                    color: enabled ? Colors.white : Colors.white38))));
  }
}
