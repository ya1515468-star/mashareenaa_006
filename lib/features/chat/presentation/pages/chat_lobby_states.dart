part of 'chat_lobby_page.dart';

// حالات اللوبي: فارغ وخطأ
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _EmptyLobby extends StatelessWidget {
  const _EmptyLobby();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('ابدأ أول رسالة في الشات الرئيسي',
          style: TextStyle(color: Colors.white54)));
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'تعذر تحميل الشات الآن. تحقق من الاتصال ثم أعد المحاولة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54))));
}
