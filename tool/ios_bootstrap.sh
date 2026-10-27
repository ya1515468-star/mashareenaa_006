#!/usr/bin/env bash
# توليد وضبط مشروع iOS لتطبيق مشاريعنا.
#
# لماذا سكربت لا مجلّد مُلتزَم:
# مشروع iOS لم يكن موجودًا في المستودع إطلاقًا (أندرويد والويب فقط)، وملف
# Runner.xcodeproj/project.pbxproj يولّده Flutter بصيغة دقيقة يصعب كتابتها
# يدويًا بلا أخطاء. هذا السكربت يولّده بـflutter create ثم يطبّق ضبطنا،
# فالنتيجة قابلة لإعادة الإنتاج حرفيًا وموثَّقة في المستودع.
#
# يُنفَّذ في البناء السحابي قبل bناء iOS، ويمكن تشغيله محليًا على macOS.
# آمن للتكرار: لا يمسّ مجلّد ios/ إن كان موجودًا ومضبوطًا مسبقًا.
set -euo pipefail

BUNDLE_ID="com.mashareena.mashareena"
APP_NAME="مشاريعنا"
MIN_IOS="13.0"   # agora_rtc_engine 6.5.4 و camera و record تتطلّب 13 فأعلى

if [ ! -d ios ]; then
  echo "▶ توليد مشروع iOS…"
  flutter create --platforms=ios --org com.mashareena --project-name mashareena .
else
  echo "▶ مجلّد ios/ موجود — يُضبط فقط."
fi

PLIST=ios/Runner/Info.plist
PBX=ios/Runner.xcodeproj/project.pbxproj
test -f "$PLIST" || { echo "✗ لم يُعثر على $PLIST"; exit 1; }
test -f "$PBX"   || { echo "✗ لم يُعثر على $PBX"; exit 1; }

echo "▶ ضبط معرّف الحزمة والحد الأدنى لنظام iOS…"
# معرّف الحزمة يجب أن يطابق أندرويد وملف provisioning لاحقًا.
sed -i.bak -E "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID};/g" "$PBX"
sed -i.bak -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${MIN_IOS};/g" "$PBX"
rm -f "${PBX}.bak"

if [ -f ios/Podfile ]; then
  sed -i.bak -E "s/^# *platform :ios.*/platform :ios, '${MIN_IOS}'/" ios/Podfile
  sed -i.bak -E "s/^platform :ios, '[0-9.]+'/platform :ios, '${MIN_IOS}'/" ios/Podfile
  grep -q "^platform :ios" ios/Podfile || sed -i.bak "1i platform :ios, '${MIN_IOS}'" ios/Podfile
  rm -f ios/Podfile.bak
fi

echo "▶ كتابة أوصاف الأذونات في Info.plist…"
# App Store يرفض أي تطبيق يطلب هذه الأذونات بلا وصف يشرح سببها للمستخدم.
# الأوصاف بالعربية لأنّ واجهة التطبيق عربية ويراها المستخدم كما هي.
set_plist() {  # مفتاح، نوع، قيمة
  /usr/libexec/PlistBuddy -c "Delete :$1" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :$1 $2 $3" "$PLIST"
}

set_plist NSCameraUsageDescription string \
  "يستخدم التطبيق الكاميرا لالتقاط صور المنتجات والباترونات وللمكالمات المرئية."
set_plist NSMicrophoneUsageDescription string \
  "يستخدم التطبيق المايكروفون للرسائل الصوتية والمكالمات الصوتية والمرئية."
set_plist NSPhotoLibraryUsageDescription string \
  "يحتاج التطبيق إلى مكتبة الصور لاختيار صور المنتجات والباترونات وصورة الملف الشخصي."
set_plist NSPhotoLibraryAddUsageDescription string \
  "يحفظ التطبيق الصور التي تنشئها أو تنزّلها في مكتبة صورك."
set_plist NSLocationWhenInUseUsageDescription string \
  "يستخدم الموقع لعرض الورش والخدمات القريبة منك داخل التطبيق فقط."
set_plist NSUserTrackingUsageDescription string \
  "لا يتتبّع التطبيق نشاطك في تطبيقات أخرى؛ يُطلب هذا الإذن فقط عند تفعيل ميزات تحتاجه."

# اسم العرض بالعربية على الشاشة الرئيسية.
/usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PLIST"

# العربية لغة أساسية + دعم اتجاه RTL.
/usr/libexec/PlistBuddy -c "Delete :CFBundleDevelopmentRegion" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string ar" "$PLIST"

# الخلفية: المكالمات الصوتية وتشغيل الصوت تحتاج هذه الأوضاع وإلا انقطعت.
/usr/libexec/PlistBuddy -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:0 string audio" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UIBackgroundModes:1 string voip" "$PLIST"

# منع النقل غير المشفَّر، مطابقةً لإعداد أندرويد (usesCleartextTraffic=false).
/usr/libexec/PlistBuddy -c "Delete :NSAppTransportSecurity" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool false" "$PLIST"

# الرابط العميق لتأكيد البريد — نفس المخطَّط المسجَّل في أندرويد.
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string ${BUNDLE_ID}" "$PLIST"

/usr/libexec/PlistBuddy -c "Print" "$PLIST" >/dev/null
echo "✅ مشروع iOS جاهز — الحزمة ${BUNDLE_ID}، الحد الأدنى iOS ${MIN_IOS}"
