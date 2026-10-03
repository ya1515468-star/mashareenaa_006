import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../chat/presentation/widgets/mini_profile_popup.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/producers_market_provider.dart';
import '../../domain/entities/producer_reel_entity.dart';
import '../widgets/season_banner_widget.dart';
import '../widgets/reel_action_bar.dart';
import '../widgets/publish_reel_sheet.dart';
import '../../../../core/monitoring/error_monitor.dart';
import '../widgets/reel_comments_sheet.dart';
import '../../../../core/theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// سوق المنتجين — أهم قسم في المنصة
/// واجهة TikTok مُتخصَّصة لقطاع الألبسة السوري
/// خادمي بالكامل، المالك يتحكم في كل شيء
/// ═══════════════════════════════════════════════════════════════
class ProducersMarketPage extends ConsumerStatefulWidget {
  const ProducersMarketPage({super.key});

  @override
  ConsumerState<ProducersMarketPage> createState() =>
      _ProducersMarketPageState();
}

class _ProducersMarketPageState extends ConsumerState<ProducersMarketPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  String? _selectedCategory;
  bool _isOwner = false;

  // تأثيرات الجسيمات الفاخرة
  late final AnimationController _particleController;
  late final AnimationController _glowController;
  late final AnimationController _shimmerController;
  late final Animation<double> _glowAnim;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _loadOwnerFlag();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  Future<void> _loadOwnerFlag() async {
    try {
      final result = await Supabase.instance.client.rpc('is_my_platform_owner');
      if (mounted) setState(() => _isOwner = result == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  static const List<Map<String, dynamic>> _categories = [
    {'key': null, 'label': 'الكل', 'icon': '🌟'},
    {'key': 'packaging', 'label': 'أمبلاج', 'icon': '📦'},
    {'key': 'cutting', 'label': 'قطاعة', 'icon': '✂️'},
    {'key': 'washing', 'label': 'غسيل', 'icon': '🫧'},
    {'key': 'dyeing', 'label': 'صباغة', 'icon': '🎨'},
    {'key': 'embroidery', 'label': 'تطريز', 'icon': '🪡'},
    {'key': 'ironing', 'label': 'كوي', 'icon': '🔥'},
    {'key': 'printing', 'label': 'طباعة', 'icon': '🖨️'},
    {'key': 'fabric', 'label': 'أقمشة', 'icon': '🧵'},
    {'key': 'accessories', 'label': 'إكسسوار', 'icon': '💎'},
    {'key': 'pattern', 'label': 'باترون', 'icon': '📐'},
    {'key': 'other', 'label': 'أخرى', 'icon': '🏷️'},
  ];

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(producerReelsProvider(_selectedCategory));
    final bannerAsync = ref.watch(marketSeasonBannerProvider);
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── طبقة التأثير البصري الفاخر (جسيمات متحركة) ───────
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _MarketParticlePainter(_particleController.value),
              child: const SizedBox.expand(),
            ),
          ),

          // ─── المحتوى الرئيسي ────────────────────────────────────
          //
          // الشريط العلوي (بانر الموسم + شريط الفئات) كان يقتطع أعلى
          // الشاشة فيصغّر الفيديو. صار تراكبًا عائمًا شفافًا فوقه —
          // الفيديو يملأ الشاشة كاملة كما في تيك توك.
          SafeArea(
            child: Column(
              children: [
                // ─── ريلات TikTok-style ─────────────────────────
                Expanded(
                  child: reelsAsync.when(
                    data: (reels) {
                      if (reels.isEmpty) {
                        return _EmptyMarketState(onPublish: _showPublishSheet);
                      }
                      return PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        onPageChanged: (i) =>
                            setState(() => _currentIndex = i),
                        itemCount: reels.length,
                        itemBuilder: (context, i) => _ReelPlayer(
                          reel: reels[i],
                          isActive: i == _currentIndex,
                          glowAnim: _glowAnim,
                          isOwner: _isOwner,
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFD700)),
                    ),
                    error: (e, _) => Center(
                      child: Text('تعذّر تحميل سوق المنتجين: $e',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── التراكب العائم: الفئات + بانر المالك ──────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  bannerAsync.when(
                    data: (banner) => banner?.isActive == true
                        ? SeasonBannerWidget(
                            banner: banner!,
                            shimmerAnim: _shimmerAnim,
                            glowAnim: _glowAnim,
                            isOwner: _isOwner,
                            onEdit: _isOwner
                                ? () => _showSeasonBannerEditor()
                                : null,
                          )
                        : _isOwner
                            ? _OwnerAddBannerButton(
                                onTap: _showSeasonBannerEditor)
                            : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  _buildCategoryBar(p),
                ],
              ),
            ),
          ),

          // ─── زر النشر (يسار أسفل) ───────────────────────────────
          Positioned(
            bottom: 96,
            left: 16,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: _glowAnim.value * 0.7),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: child,
              ),
              child: FloatingActionButton(
                heroTag: 'publish_reel',
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                onPressed: _showPublishSheet,
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(dynamic p) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) => GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategory = cat['key'] as String?),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isSelected
                        ? const LinearGradient(colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                          ])
                        : null,
                    color: isSelected ? null : Colors.white10,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: _glowAnim.value * 0.5),
                              blurRadius: 10,
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['icon'] as String,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPublishSheet() async {
    final published = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PublishReelSheet(),
    );
    if (published != true || !mounted) return;
    // الريل الجديد يُدرَج أولًا (الأحدث أولًا)، لكن القائمة تبقى في نفس
    // الصفحة التي كان المستخدم يشاهدها، فلا يراه إلا بسحب يدوي للأعلى.
    // إبطال كل فئات المزوّد يضمن تحديث أي فئة قد يعود إليها المستخدم لاحقًا،
    // والقفز لرأس القائمة يُظهر المنشور الجديد فورًا دون أي سحب.
    ref
      ..invalidate(producerReelsProvider(_selectedCategory))
      ..invalidate(producerReelsProvider(null));
    if (_pageController.hasClients) {
      await _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  void _showSeasonBannerEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      builder: (_) => const _SeasonBannerEditorSheet(),
    );
  }
}

// ─── مشغّل الريل الفردي ───────────────────────────────────────────────────────
class _ReelPlayer extends ConsumerStatefulWidget {
  final ProducerReelEntity reel;
  final bool isActive;
  final Animation<double> glowAnim;
  final bool isOwner;

  const _ReelPlayer({
    required this.reel,
    required this.isActive,
    required this.glowAnim,
    required this.isOwner,
  });

  @override
  ConsumerState<_ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends ConsumerState<_ReelPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _vpc;
  bool _isPlaying = true;
  bool _showLikeAnim = false;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_heartController);

    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.reel.videoUrl.isNotEmpty) {
      try {
        _vpc = VideoPlayerController.networkUrl(
            Uri.parse(widget.reel.videoUrl));
        await _vpc!.initialize();
        _vpc!.setLooping(true);
        if (widget.isActive && _tabVisible) _vpc!.play();
        if (mounted) setState(() => _initialized = true);
      } catch (e, st) {
        // كان الفشل يُبتلَع صامتًا ويُعلَّم الودجت "مهيَّأ" رغم فشل
        // التهيئة فعليًا — فيبدو الفيديو "لا يعمل" بلا أي أثر يفسّر
        // لماذا، لا صورة ولا خطأ ولا صوت.
        unawaited(ErrorMonitor.report(e,
            stack: st, screen: 'producers_market_reel', source: 'video_init'));
        if (mounted) setState(() => _initialized = true);
      }
    } else {
      if (mounted) setState(() => _initialized = true);
    }
  }

  // يُعطَّل TickerMode حين يُخفى تبويب سوق المنتجين (home_shell)؛
  // عندها نوقف الفيديو والصوت، ونستأنف فقط إن عاد ظاهرًا وكان الريل نشطًا.
  bool _tabVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _tabVisible) return;
    _tabVisible = visible;
    if (!visible) {
      _vpc?.pause();
    } else if (widget.isActive) {
      _vpc?.play();
    }
  }

  @override
  void didUpdateWidget(_ReelPlayer old) {
    super.didUpdateWidget(old);
    // PageView.builder يعيد استعمال نفس الـState لعنصر مختلف عند
    // إعادة البناء (سلوك أداء طبيعي في Flutter) — فكان المتحكّم
    // القديم يبقى مرتبطًا برابط الفيديو السابق. هذا هو السبب الأرجح
    // لـ"الفيديو لا يعمل بعد مغادرة القسم والعودة إليه": نفس الودجت
    // أُعيد استخدامها لريل مختلف بمتحكّم يشير لفيديو غير الفيديو
    // الظاهر فعليًا.
    if (widget.reel.videoUrl != old.reel.videoUrl) {
      final stale = _vpc;
      _vpc = null;
      _initialized = false;
      stale?.pause();
      unawaited(stale?.dispose());
      unawaited(_initVideo());
      return;
    }
    if (widget.isActive != old.isActive) {
      if (widget.isActive && _tabVisible) {
        _vpc?.play();
      } else {
        _vpc?.pause();
      }
    }
  }

  @override
  void dispose() {
    _vpc?.dispose();
    _heartController.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    HapticFeedback.mediumImpact();
    ref
        .read(producerMarketControllerProvider.notifier)
        .likeReel(widget.reel.id);
    setState(() => _showLikeAnim = true);
    _heartController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showLikeAnim = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      onTap: () {
        setState(() => _isPlaying = !_isPlaying);
        _isPlaying ? _vpc?.play() : _vpc?.pause();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ─── خلفية الفيديو أو الثمبنيل ───────────────────────
          if (_initialized && _vpc?.value.isInitialized == true)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _vpc!.value.size.width,
                height: _vpc!.value.size.height,
                child: VideoPlayer(_vpc!),
              ),
            )
          else if (widget.reel.thumbnailUrl != null)
            CachedNetworkImage(
              imageUrl: widget.reel.thumbnailUrl!,
              fit: BoxFit.cover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A0530), Color(0xFF0A1A3A)],
                ),
              ),
            ),

          // ─── تدرج إضافي للقراءة ───────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ─── بيانات الريل (أسفل يمين) ─────────────────────────
          Positioned(
            bottom: 16,
            right: 12,
            left: 80,
            child: _ReelInfoOverlay(reel: widget.reel, isOwner: widget.isOwner),
          ),

          // ─── شريط التفاعل (يسار) ─────────────────────────────
          Positioned(
            bottom: 16,
            left: 8,
            child: ReelActionBar(
              reel: widget.reel,
              glowAnim: widget.glowAnim,
              onLike: () => ref
                  .read(producerMarketControllerProvider.notifier)
                  .likeReel(widget.reel.id),
              onComment: () => _showComments(),
              onSave: () => ref
                  .read(producerMarketControllerProvider.notifier)
                  .saveReel(widget.reel.id),
              onShare: () => ref
                  .read(producerMarketControllerProvider.notifier)
                  .shareReel(widget.reel.id),
              onDownload: () => ref
                  .read(producerMarketControllerProvider.notifier)
                  .downloadReel(widget.reel.id),
            ),
          ),

          // ─── أيقونة توقف/تشغيل ───────────────────────────────
          if (!_isPlaying)
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white54, size: 72),
            ),

          // ─── أنيميشن القلب عند الإعجاب المزدوج ──────────────
          if (_showLikeAnim)
            Center(
              child: AnimatedBuilder(
                animation: _heartController,
                builder: (_, __) => Transform.scale(
                  scale: _heartScale.value,
                  child: const Icon(Icons.favorite_rounded,
                      color: Color(0xFFFF3B5C), size: 100),
                ),
              ),
            ),

        ],
      ),
    );
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D1A),
      builder: (_) => ReelCommentsSheet(reelId: widget.reel.id),
    );
  }
}

// ─── معلومات الريل (التراكب السفلي) ──────────────────────────────────────────
class _ReelInfoOverlay extends StatelessWidget {
  final ProducerReelEntity reel;
  final bool isOwner;

  const _ReelInfoOverlay({required this.reel, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // اسم الناشر — بنفس مكوّن غرف الشات تمامًا، فيحمل معه الألوان
        // والشارات والألقاب والتأثيرات التي اشتراها العضو. لم يكن
        // يُعرض إطلاقًا في سوق المنتجين رغم أنه هوية الناشر.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded,
                  size: 15, color: Color(0xFFFFD700)),
              const SizedBox(width: 5),
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => MiniProfilePopup.show(context, reel.uid),
                  child: ServerUsernameDisplay(
                    uid: reel.uid,
                    fallbackName: 'عضو',
                    fallbackFontSize: 13,
                    showBadges: true,
                    compactBadges: true,
                    showTitle: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        // الفئة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
          ),
          child: Text(
            _categoryLabel(reel.category),
            style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
        // العنوان
        Text(
          reel.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // الوصف
        Text(
          reel.description,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (reel.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: reel.tags
                .take(4)
                .map((t) => Text('#$t',
                    style: const TextStyle(
                        color: Color(0xFF7EB8FF), fontSize: 11)))
                .toList(),
          ),
        ],
      ],
    );
  }

  String _categoryLabel(String key) {
    const map = {
      'packaging': 'أمبلاج 📦',
      'cutting': 'قطاعة ✂️',
      'washing': 'غسيل 🫧',
      'dyeing': 'صباغة 🎨',
      'embroidery': 'تطريز 🪡',
      'ironing': 'كوي 🔥',
      'printing': 'طباعة 🖨️',
      'fabric': 'أقمشة 🧵',
      'accessories': 'إكسسوار 💎',
      'pattern': 'باترون 📐',
      'other': 'أخرى 🏷️',
    };
    return map[key] ?? key;
  }
}



// ─── حالة السوق الفارغة ───────────────────────────────────────────────────────
class _EmptyMarketState extends StatelessWidget {
  final VoidCallback onPublish;
  const _EmptyMarketState({required this.onPublish});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧵', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('سوق المنتجين فارغ حالياً',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('كن أول من ينشر منتجاً لقطاع الألبسة!',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.add),
            label: const Text('نشر منتج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── زر مالك (إضافة بانر الموسم) ─────────────────────────────────────────────
class _OwnerAddBannerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OwnerAddBannerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5),
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFD700).withValues(alpha: 0.08),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFFFFD700), size: 16),
            SizedBox(width: 6),
            Text('إضافة بانر الموسم',
                style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── محرر بانر الموسم (للمالك فقط) ──────────────────────────────────────────
class _SeasonBannerEditorSheet extends ConsumerStatefulWidget {
  const _SeasonBannerEditorSheet();

  @override
  ConsumerState<_SeasonBannerEditorSheet> createState() =>
      _SeasonBannerEditorSheetState();
}

class _SeasonBannerEditorSheetState
    extends ConsumerState<_SeasonBannerEditorSheet> {
  final _titleCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _selectedSeason = 'winter';
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('✏️ تحرير بانر الموسم',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'عنوان الموسم (مثال: موسم شتاء 2027)',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dateCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'التاريخ (مثال: يناير 2027)',
              labelStyle: TextStyle(color: Colors.white54),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('نوع الموسم:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              _SeasonChip(
                emoji: '❄️',
                label: 'شتاء',
                selected: _selectedSeason == 'winter',
                onTap: () => setState(() => _selectedSeason = 'winter'),
              ),
              const SizedBox(width: 8),
              _SeasonChip(
                emoji: '☀️',
                label: 'صيف',
                selected: _selectedSeason == 'summer',
                onTap: () => setState(() => _selectedSeason = 'summer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save_outlined),
            label: const Text('حفظ البانر'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(producerMarketControllerProvider.notifier)
          .updateSeasonBanner(
            title: _titleCtrl.text.trim(),
            date: _dateCtrl.text.trim(),
            seasonGifUrl: _selectedSeason == 'winter'
                ? 'assets/effects/snow_fall.gif'
                : 'assets/effects/sun_shine.gif',
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SeasonChip extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _SeasonChip(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? const Color(0xFFFFD700).withValues(alpha: 0.25)
              : Colors.white10,
          border: selected
              ? Border.all(color: const Color(0xFFFFD700))
              : null,
        ),
        child: Text('$emoji $label',
            style: TextStyle(
                color: selected ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 13)),
      ),
    );
  }
}

// ─── رسّام جسيمات الخلفية الفاخرة ────────────────────────────────────────────
class _MarketParticlePainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = List.generate(
      40,
      (i) => _Particle(
            x: (i * 0.0713) % 1.0,
            y: (i * 0.0971) % 1.0,
            size: 1.0 + (i % 5) * 0.5,
            speed: 0.008 + (i % 7) * 0.002,
            phase: i * 0.251,
          ));

  _MarketParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.phase) % 1.0;
      final y = (p.y - t * p.speed * 10) % 1.0;
      final x = p.x + math.sin(t * math.pi * 2 + p.phase) * 0.03;
      final opacity = (math.sin(t * math.pi * 2) + 1) / 2 * 0.4;
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        Paint()
          ..color =
              const Color(0xFFFFD700).withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_MarketParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double x, y, size, speed, phase;
  const _Particle(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed,
      required this.phase});
}
