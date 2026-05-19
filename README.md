# Quản lý Thu Chi Vợ Chồng

Ứng dụng Flutter `thu_chi_viet_nam` dùng Flutter 3.41.9, Supabase, Riverpod, GoRouter, Material 3 và `flutter_dotenv`.

## Cấu hình môi trường

1. Tạo file `.env` từ file mẫu:

   ```bash
   cp .env.example .env
   ```

2. Điền thông tin Supabase:

   ```env
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   ```

3. File `.env` đã được thêm vào `.gitignore`. Chỉ commit `.env.example`.
   Không hardcode Supabase key trong Dart/native code.

## Chạy ứng dụng

```bash
flutter pub get
flutter run
```

Ứng dụng hỗ trợ Android và iOS. Trên Mac M1, hãy mở iOS Simulator hoặc cắm thiết bị thật trước khi chạy `flutter run`.

## Production

Checklist file quan trọng, bảo mật, clean, build APK/AAB/IPA và kịch bản test Realtime nằm ở:

```text
docs/production_release.md
```
