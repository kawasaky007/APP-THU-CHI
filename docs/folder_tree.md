# Folder tree

```text
thu_chi_viet_nam/
├── android/
├── ios/
├── lib/
│   ├── app.dart
│   ├── main.dart
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_constants.dart
│   │   │   └── app_theme.dart
│   │   ├── models/
│   │   │   ├── category.dart
│   │   │   ├── household.dart
│   │   │   ├── models.dart
│   │   │   ├── transaction.dart
│   │   │   ├── transaction_type.dart
│   │   │   └── user_profile.dart
│   │   ├── providers/
│   │   │   └── supabase_provider.dart
│   │   ├── router/
│   │   │   ├── app_router.dart
│   │   │   └── app_routes.dart
│   │   └── services/
│   │       └── supabase_service.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/auth_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       │   ├── auth_provider.dart
│   │   │       │   └── auth_state.dart
│   │   │       ├── screens/
│   │   │       │   ├── login_screen.dart
│   │   │       │   ├── register_screen.dart
│   │   │       │   └── splash_screen.dart
│   │   │       └── widgets/auth_screen_layout.dart
│   │   ├── categories/
│   │   │   ├── data/category_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/category_provider.dart
│   │   │       ├── screens/category_list_screen.dart
│   │   │       └── widgets/
│   │   │           ├── category_form_bottom_sheet.dart
│   │   │           └── category_visuals.dart
│   │   ├── dashboard/
│   │   │   └── presentation/pages/dashboard_page.dart
│   │   ├── household/
│   │   │   ├── data/household_repository.dart
│   │   │   └── presentation/
│   │   │       ├── providers/household_provider.dart
│   │   │       └── screens/
│   │   │           ├── create_household_screen.dart
│   │   │           └── invite_code_screen.dart
│   │   ├── profile/
│   │   │   └── presentation/screens/profile_screen.dart
│   │   ├── reports/
│   │   │   └── presentation/pages/reports_page.dart
│   │   ├── settings/
│   │   │   └── presentation/pages/settings_page.dart
│   │   └── transactions/
│   │       ├── data/transaction_repository.dart
│   │       └── presentation/
│   │           ├── pages/transactions_page.dart
│   │           ├── providers/transaction_provider.dart
│   │           └── screens/
│   │               ├── add_transaction_screen.dart
│   │               └── transaction_history_screen.dart
│   └── shared/
│       └── widgets/
│           ├── app_feedback.dart
│           └── app_shell.dart
├── test/
│   └── widget_test.dart
├── docs/
│   ├── folder_tree.md
│   └── production_release.md
├── .env
├── .env.example
├── pubspec.yaml
└── README.md
```

`android/` và `ios/` được sinh bởi Flutter để hỗ trợ build mobile native. Các feature tiếp theo nên được tách theo cùng pattern `features/<feature>/data|domain|presentation`.
