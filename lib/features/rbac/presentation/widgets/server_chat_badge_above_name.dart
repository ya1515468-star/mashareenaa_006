import 'package:flutter/material.dart';

import '../../../member_badges/presentation/widgets/member_badge_widget.dart';

/// العرض القانوني لشارة العضو: طبقة مستقلة فوق قالب الاسم فقط.
class ServerChatBadgeAboveName extends StatelessWidget {
  final String uid;
  final double size;
  final bool center;

  const ServerChatBadgeAboveName({
    super.key,
    required this.uid,
    this.size = 30,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    return MemberBadgeWidget(
      userId: uid,
      center: center,
      maxWidth: size.clamp(20.0, 56.0).toDouble(),
      maxHeight: (size * .86).clamp(18.0, 44.0).toDouble(),
    );
  }
}
