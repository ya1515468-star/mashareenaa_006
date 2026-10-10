import 'package:flutter/widgets.dart';

/// مفتاح Navigator الجذر: عناصر مركّبة فوق التطبيق كله (كالمساعد الذكي
/// العائم) تقع خارج أي Navigator/Overlay، فتفتح أوراقها السفلية عبر
/// سياق هذا المفتاح بدل سياقها هي.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
