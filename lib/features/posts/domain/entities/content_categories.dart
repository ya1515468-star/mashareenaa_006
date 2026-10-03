/// أقسام المحتوى الموحّدة — تُستخدم لتصنيف المنشورات، وقابلة لإعادة
/// الاستخدام لاحقًا في السوق والمشاريع دون تكرار قائمة جديدة.
class ContentCategories {
  ContentCategories._();

  static const String general = 'general';
  static const String projects = 'projects';
  static const String marketplace = 'marketplace';
  static const String services = 'services';
  static const String garmentDesign = 'garment_design';
  static const String announcements = 'announcements';

  static const List<String> all = [
    general,
    projects,
    marketplace,
    services,
    garmentDesign,
    announcements,
  ];

  static String labelOf(String id) {
    switch (id) {
      case projects:
        return 'مشاريع';
      case marketplace:
        return 'سوق';
      case services:
        return 'خدمات';
      case garmentDesign:
        return 'تصميم أزياء';
      case announcements:
        return 'إعلانات';
      case general:
      default:
        return 'عام';
    }
  }
}
