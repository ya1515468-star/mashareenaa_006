import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/supabase_service.dart';
import 'ai_assistant_sheet.dart';

/// أيقونة المساعد الذكي: عائمة دائمًا فوق كل أقسام التطبيق، يسحبها المستخدم
/// إلى أي مكان ويُحفظ موضعها. تُركَّب في MaterialApp.builder (خارج أي
/// Navigator/Overlay) — لذلك بلا tooltip، والورقة تُفتح عبر appNavigatorKey.
class AiAssistantFab extends StatefulWidget {
  const AiAssistantFab({super.key});
  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab> {
  static const _size = 54.0;
  static const _pad = 12.0; // مساحة زر الإغلاق حول الأيقونة
  // موضع كنسبة من مساحة الشاشة (يصمد أمام تغيّر الأبعاد).
  double _fx = 0.82;
  double _fy = 0.60;
  bool _dragging = false;
  // الإغلاق بالذاكرة فقط: يعود الزر بعد إعادة تسجيل الدخول أو إعادة تشغيل/تحديث التطبيق.
  bool _closed = false;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = SupabaseService.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn && _closed && mounted) {
        setState(() => _closed = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final x = p.getDouble('ai_fab_fx');
      final y = p.getDouble('ai_fab_fy');
      if (mounted && x != null && y != null) {
        setState(() {
          _fx = x.clamp(0.0, 1.0);
          _fy = y.clamp(0.0, 1.0);
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('ai_fab_fx', _fx);
      await p.setDouble('ai_fab_fy', _fy);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // يظهر للمستخدم المسجَّل فقط.
    return StreamBuilder(
      stream: SupabaseService.auth.onAuthStateChange,
      builder: (context, _) {
        if (SupabaseService.auth.currentSession == null || _closed) {
          return const SizedBox.shrink();
        }
        final size = MediaQuery.of(context).size;
        final maxX = (size.width - _size - _pad).clamp(0.0, double.infinity);
        final maxY = (size.height - _size - _pad).clamp(0.0, double.infinity);
        return Positioned(
          left: _fx * maxX,
          top: _fy * maxY,
          width: _size + _pad,
          height: _size + _pad,
          child: Stack(children: [
            Positioned(
              left: 0,
              bottom: 0,
              width: _size,
              height: _size,
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: AiAssistantSheet.open,
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (d) {
              if (maxX <= 0 || maxY <= 0) return;
              setState(() {
                _fx = ((_fx * maxX + d.delta.dx) / maxX).clamp(0.0, 1.0);
                _fy = ((_fy * maxY + d.delta.dy) / maxY).clamp(0.0, 1.0);
              });
            },
            onPanEnd: (_) {
              setState(() => _dragging = false);
              _save();
            },
            child: AnimatedScale(
              scale: _dragging ? 1.12 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7D32A6), Color(0xFFFFD700)],
                  ),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
              ),
            ),
          ),
            ),
            Positioned(
              right: 0,
              top: 0,
              width: 24,
              height: 24,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _closed = true),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Colors.black87),
                  child: const Icon(Icons.close, color: Colors.white, size: 15),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}
