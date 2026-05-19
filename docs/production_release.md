# Production release guide

Tài liệu này dùng cho app Flutter `thu_chi_viet_nam` khi chuẩn bị release Android/iOS.

## 1. File quan trọng cần có

### Cấu hình gốc

- `pubspec.yaml`: dependency, version `1.0.0+1`, assets `.env`.
- `.env`: cấu hình thật trên máy build, không commit.
- `.env.example`: file mẫu dùng placeholder.
- `.gitignore`: loại `.env`, build output, signing key.
- `analysis_options.yaml`: lint rule.
- `README.md`: hướng dẫn chạy nhanh.
- `docs/folder_tree.md`: cấu trúc thư mục.
- `docs/production_release.md`: checklist production.

### App entry, config, router

- `lib/main.dart`: khởi tạo Flutter, global error handler, Supabase dotenv.
- `lib/app.dart`: `MaterialApp.router`, theme, localization, global feedback.
- `lib/core/config/app_constants.dart`: hằng số app, locale, env keys.
- `lib/core/config/app_theme.dart`: Material 3 light/dark.
- `lib/core/router/app_router.dart`: GoRouter + ShellRoute + protected routes.
- `lib/core/router/app_routes.dart`: route constants.
- `lib/shared/widgets/app_shell.dart`: Bottom Navigation 4 tab + FAB thêm nhanh.
- `lib/shared/widgets/app_feedback.dart`: SnackBar, Dialog lỗi, loading overlay.

### Supabase, models, providers

- `lib/core/services/supabase_service.dart`: load `.env`, initialize Supabase, helper chung.
- `lib/core/providers/supabase_provider.dart`: Riverpod provider cho Supabase.
- `lib/core/models/user_profile.dart`
- `lib/core/models/household.dart`
- `lib/core/models/category.dart`
- `lib/core/models/transaction.dart`
- `lib/core/models/transaction_type.dart`
- `lib/core/models/models.dart`

### Features chính

- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/presentation/providers/auth_provider.dart`
- `lib/features/auth/presentation/providers/auth_state.dart`
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/auth/presentation/screens/register_screen.dart`
- `lib/features/auth/presentation/screens/splash_screen.dart`
- `lib/features/household/data/household_repository.dart`
- `lib/features/household/presentation/screens/create_household_screen.dart`
- `lib/features/household/presentation/screens/invite_code_screen.dart`
- `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- `lib/features/transactions/data/transaction_repository.dart`
- `lib/features/transactions/presentation/providers/transaction_provider.dart`
- `lib/features/transactions/presentation/screens/add_transaction_screen.dart`
- `lib/features/transactions/presentation/screens/transaction_history_screen.dart`
- `lib/features/categories/data/category_repository.dart`
- `lib/features/categories/presentation/providers/category_provider.dart`
- `lib/features/categories/presentation/screens/category_list_screen.dart`
- `lib/features/categories/presentation/widgets/category_form_bottom_sheet.dart`
- `lib/features/categories/presentation/widgets/category_visuals.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`

### Native mobile

- `android/app/build.gradle.kts`: application id, version, release signing.
- `android/key.properties`: signing config thật, không commit.
- `android/app/src/main/AndroidManifest.xml`: app label, launcher activity.
- `ios/Podfile`: CocoaPods.
- `ios/Runner/Info.plist`: display name, bundle settings, launch storyboard.
- `ios/Runner.xcworkspace`: mở bằng Xcode khi archive hoặc cấu hình signing.

## 2. Build Android trên MacBook M1

### Kiểm tra môi trường

```bash
flutter --version
flutter doctor -v
flutter pub get
```

Đảm bảo Android Studio, Android SDK, JDK và device/emulator đã được Flutter doctor nhận diện.

### Tạo keystore release

```bash
keytool -genkey -v \
  -keystore android/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Tạo file `android/key.properties`:

```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

`android/key.properties` và `*.jks` đã nằm trong `.gitignore`.
Release build sẽ yêu cầu file này; không dùng debug key cho production.

### Build APK release

```bash
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build/symbols/android-apk
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Build AAB cho Google Play

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android-aab
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Lưu thư mục `build/symbols/...` để giải mã stack trace khi production crash.

## 3. Build iOS IPA trên MacBook M1 Apple Silicon

### Kiểm tra môi trường

```bash
flutter doctor -v
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

Cài CocoaPods nếu máy chưa có:

```bash
sudo gem install cocoapods
pod --version
```

### Chuẩn bị signing

1. Mở `ios/Runner.xcworkspace` bằng Xcode.
2. Chọn target `Runner`.
3. Đặt Bundle Identifier production, ví dụ `com.thuchivietnam.thuChiVietNam`.
4. Chọn Apple Developer Team.
5. Bật Automatically manage signing hoặc dùng provisioning profile thủ công.

### Cài pod và build IPA

```bash
cd ios
pod install --repo-update
cd ..
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios
```

Output thường nằm ở:

```text
build/ios/ipa/*.ipa
```

Nếu cần export bằng cấu hình riêng, tạo `ios/ExportOptions.plist` rồi build:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

## 4. Clean toàn diện

Chạy khi đổi package native, CocoaPods lỗi, build cache bẩn hoặc trước release quan trọng.

```bash
flutter clean
rm -rf build
rm -rf .dart_tool
flutter pub get
```

Android:

```bash
cd android
./gradlew clean
cd ..
```

iOS:

```bash
cd ios
rm -rf Pods
rm -f Podfile.lock
rm -rf .symlinks
rm -rf Flutter/ephemeral
pod cache clean --all
pod install --repo-update
cd ..
```

Sau đó:

```bash
flutter pub get
flutter analyze
flutter test
```

## 5. Bảo mật production

- Không hardcode `SUPABASE_URL` hoặc `SUPABASE_ANON_KEY` trong Dart/native code.
- Chỉ đọc cấu hình qua `flutter_dotenv` từ `.env`.
- Không commit `.env`, `android/key.properties`, keystore, provisioning profile, certificate.
- Supabase anon key không phải secret tuyệt đối vì nó nằm trong app bundle và có thể bị trích xuất. Bảo mật thật nằm ở Row Level Security.
- Tuyệt đối không đưa `service_role` key vào mobile app.
- Bật và kiểm tra RLS cho `profiles`, `households`, `categories`, `transactions`.
- `profiles.role` là role tài khoản chung, lưu string lowercase `user`.
- Vai trò trong household như chủ household/thành viên được suy ra từ `households.owner_id`.
- Policy phải giới hạn dữ liệu theo `household_id` của user hiện tại.
- `households.monthly_budget` nên là số nguyên VND; app luôn gửi integer, rỗng thì gửi `0`.
- Bật Realtime chỉ cho bảng cần thiết: `categories`, `transactions`.
- Không log token, session, email nhạy cảm hoặc payload lỗi đầy đủ ở release.
- Nên bật crash reporting production như Firebase Crashlytics hoặc Sentry trước khi public.
- Khi thay đổi Supabase key hoặc nghi ngờ lộ key, rotate key và kiểm tra lại RLS/policies.

## 6. Cải tiến cuối trước khi public

### Performance

- Thêm index Supabase cho các truy vấn chính:
  - `transactions(household_id, transaction_date desc)`
  - `transactions(household_id, category_id)`
  - `categories(household_id, type, sort_order)`
  - `profiles(household_id)`
- Với lịch sử lớn, thêm pagination thay vì tải toàn bộ transactions.
- Debounce ô tìm kiếm ghi chú nếu danh sách nhiều.
- Giữ `StreamProvider.autoDispose` cho realtime để không giữ subscription khi rời màn.
- Lưu `build/symbols` khi dùng `--obfuscate`.

### UX

- Kiểm tra empty state cho dashboard, danh mục, lịch sử, profile.
- Giữ pull-to-refresh trên Dashboard, Giao dịch, Danh mục, Hồ sơ.
- Hiển thị loading overlay cho thao tác ghi dữ liệu quan trọng.
- Tối ưu copy invite code: copy xong có SnackBar xác nhận.
- Kiểm tra UI ở thiết bị nhỏ, font lớn, dark mode.

### Error handling

- Repository nên map lỗi Supabase sang thông báo tiếng Việt.
- Global `AppFeedback` hiển thị SnackBar/Dialog cho lỗi chung.
- Form phải có validation client-side trước khi gọi Supabase.
- Các màn có realtime stream cần có retry/refresh khi stream lỗi.

### Splash screen

- Flutter splash hiện có `SplashScreen` kiểm tra phiên đăng nhập.
- Native splash dùng `android/app/src/main/res/drawable/launch_background.xml` và `ios/Runner/Base.lproj/LaunchScreen.storyboard`.
- Trước production nên thay icon/launch image mặc định bằng branding thật.
- Có thể dùng package `flutter_native_splash` nếu muốn quản lý native splash đồng nhất.

## 7. Test Realtime trên 2 thiết bị

### Chuẩn bị Supabase

1. Bật Realtime cho bảng `categories` và `transactions`.
2. Kiểm tra RLS cho cả select/insert/update/delete theo household.
3. Đảm bảo hai user cùng household qua invite code.

### Kịch bản test

1. Cài app trên hai thiết bị thật hoặc một thiết bị thật + một simulator.
2. Thiết bị A đăng ký tài khoản, tạo household.
3. Thiết bị A vào Hồ sơ, copy invite code.
4. Thiết bị B đăng ký hoặc đăng nhập, nhập invite code để join household.
5. Thiết bị A mở Dashboard, thiết bị B mở Giao dịch.
6. Thiết bị B thêm một giao dịch chi.
7. Thiết bị A phải thấy Dashboard đổi số dư/tổng chi/giao dịch gần nhất trong vài giây.
8. Thiết bị A tạo/sửa/xóa danh mục.
9. Thiết bị B phải thấy danh mục realtime cập nhật khi mở Danh mục hoặc form thêm giao dịch.
10. Thiết bị B sửa/xóa giao dịch.
11. Thiết bị A phải thấy Dashboard và Lịch sử giao dịch cập nhật.
12. Tắt mạng một thiết bị, thêm dữ liệu ở thiết bị còn lại, bật mạng lại và kéo refresh để kiểm tra phục hồi.

### Tiêu chí đạt

- Không thấy dữ liệu household khác.
- Realtime cập nhật ổn định dưới 3 giây trong mạng tốt.
- Khi mất mạng hoặc lỗi policy, app hiển thị lỗi tiếng Việt và không crash.
- Copy invite code, đổi tên household, đăng xuất hoạt động trên cả Android và iOS.
