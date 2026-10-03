import 'package:equatable/equatable.dart';

enum CallType { voice, video }

extension CallTypeX on CallType {
  String get wire => name;
  static CallType fromWire(String? s) => CallType.values
      .firstWhere((e) => e.wire == s, orElse: () => CallType.voice);
}

enum CallStatus { ringing, accepted, declined, ended, missed, failed }

extension CallStatusX on CallStatus {
  String get wire => name;
  static CallStatus fromWire(String? s) => CallStatus.values
      .firstWhere((e) => e.wire == s, orElse: () => CallStatus.ended);
}

/// جلسة اتصال. هذا الكيان يمثّل طبقة "الإشارة" (Signaling) فقط:
/// من يتصل بمن، نوع المكالمة، وحالتها الحالية — وهي البنية التي
/// يحتاجها أي مزوّد صوت/فيديو حقيقي (Agora, Zego, WebRTC...) ليبني
/// فوقها بث الوسائط الفعلي عبر مفاتيح API خاصة بالمشروع.
class CallEntity extends Equatable {
  final String id;
  final String callerUid;
  final String calleeUid;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;

  const CallEntity({
    required this.id,
    required this.callerUid,
    required this.calleeUid,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  String otherParticipant(String myUid) =>
      myUid == callerUid ? calleeUid : callerUid;

  @override
  List<Object?> get props =>
      [id, callerUid, calleeUid, type, status, createdAt];
}
