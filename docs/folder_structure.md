# Production-grade folder structure

This document defines the **target** layout for the Attendance Kiosk app: **feature-first Clean Architecture**, **Riverpod**, **GoRouter**, **repository pattern**, **local persistence (Hive / Isar)**, **ML Kit + camera**, and **kiosk-ready** concerns (responsive UI, optional platform channels).

Convention: **features own their data/domain/presentation**; **core** is shared and feature-agnostic; **app** wires composition root (DI, router, theme).

---

## Repository root (selected)

```text
attendance_kiosk_app/
├── android/                    # Kiosk / Lock Task hooks, manifests, Gradle
├── ios/                        # Guided Access notes, entitlements, Info.plist
├── macos/ linux/ web/ windows/ # Only if you ship those platforms
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── docs/
│   ├── project_requirements.md
│   └── folder_structure.md     # this file
├── integration_test/           # E2E: registration → login → attendance flows
├── lib/
│   ├── app/                    # composition root (see below)
│   ├── core/                   # cross-cutting, no business features
│   ├── features/               # feature modules (see below)
│   └── main.dart               # bootstrap only (binding, ProviderScope, runApp)
├── test/                       # mirrors lib/ + fakes/mocks
├── pubspec.yaml
└── analysis_options.yaml
```

---

## `lib/app/` — application shell

Wires **global** concerns only; no feature business logic.

```text
lib/app/
├── attendance_app.dart         # MaterialApp.router + theme
├── di/
│   └── providers.dart          # optional: central Provider overrides / test hooks
├── router/
│   ├── app_router.dart         # GoRouter + ShellRoute
│   ├── route_paths.dart        # path constants
│   └── router_refresh.dart     # redirect refresh (auth / kiosk config)
└── theme/
    ├── app_theme.dart
    └── app_typography.dart     # optional: text theme tokens
```

---

## `lib/core/` — shared kernel

Stable, reusable building blocks. **Must not** import `features/*`.

```text
lib/core/
├── config/                     # env, build flavors, remote config placeholders
│   └── app_config.dart
├── errors/
│   ├── exceptions.dart         # data-layer throws
│   └── failures.dart           # domain / UI mapping
├── l10n/                       # optional: ARB outputs, locale resolution
├── logging/
│   └── app_logger.dart
├── ml/                         # technology-agnostic ports
│   └── face_detection_port.dart
├── network/                    # when APIs land: Dio/client, interceptors
│   ├── api_client.dart
│   └── network_info.dart
├── responsive/
│   ├── app_breakpoints.dart
│   └── responsive_builder.dart
├── security/                   # optional: secure storage, obfuscation hooks
├── storage/
│   ├── hive_boxes.dart
│   └── hive_initializer.dart   # or isar_initializer.dart
├── usecases/
│   └── usecase.dart
└── widgets/                    # design-system primitives
    ├── app_error_view.dart
    ├── app_loading.dart
    └── glass_panel.dart
```

---

## `lib/features/` — feature-first modules

Each feature follows **Clean Architecture** layers:

| Layer            | Responsibility |
|-----------------|----------------|
| `domain/`       | Entities, repository **contracts**, use cases (pure Dart) |
| `data/`         | DTOs/models, local/remote **datasources**, repository **implementations** |
| `presentation/` | Pages, widgets, Riverpod notifiers/providers |

### Registration (kiosk setup)

```text
lib/features/registration/
├── data/
│   ├── datasources/
│   │   └── kiosk_config_local_data_source.dart
│   ├── models/
│   │   └── kiosk_config_model.dart
│   └── repositories/
│       └── kiosk_config_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── kiosk_config.dart
│   ├── repositories/
│   │   └── kiosk_config_repository.dart
│   └── usecases/
│       ├── register_kiosk_usecase.dart
│       └── has_kiosk_config_usecase.dart
└── presentation/
    ├── pages/
    │   └── registration_page.dart
    └── providers/
        └── registration_providers.dart
```

### Auth (login; extend later with token refresh)

```text
lib/features/auth/
└── login/
    ├── data/
    │   ├── datasources/
    │   │   └── session_local_data_source.dart
    │   └── repositories/
    │       └── auth_repository_impl.dart
    ├── domain/
    │   ├── repositories/
    │   │   └── auth_repository.dart
    │   └── usecases/
    │       ├── login_usecase.dart
    │       └── logout_usecase.dart
    └── presentation/
        ├── pages/
        │   └── login_page.dart
        └── providers/
            └── login_providers.dart
```

### Shell (drawer / tablet rail, logout)

```text
lib/features/shell/
└── presentation/
    ├── pages/
    │   └── kiosk_shell_page.dart
    └── widgets/
        └── kiosk_drawer.dart
```

### Home dashboard

```text
lib/features/home/
└── presentation/
    ├── pages/
    │   └── home_dashboard_page.dart
    └── widgets/                # optional: dashboard sections
        └── ...
```

### Employees (Hive / Isar)

```text
lib/features/employees/
├── data/
│   ├── datasources/
│   │   └── employee_local_data_source.dart
│   ├── models/
│   │   └── employee_model.dart
│   └── repositories/
│       └── employee_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── employee.dart
│   ├── repositories/
│   │   └── employee_repository.dart
│   └── usecases/
│       ├── get_employees_usecase.dart
│       └── seed_employees_if_empty_usecase.dart
└── presentation/
    ├── pages/
    │   └── employees_page.dart
    └── providers/
        └── employee_providers.dart
```

### Attendance + ML Kit + camera

```text
lib/features/attendance/
├── data/
│   ├── datasources/            # future: attendance_remote_data_source.dart
│   ├── ml/
│   │   └── mlkit_face_detection_adapter.dart
│   └── repositories/         # future: attendance_repository_impl.dart
├── domain/
│   ├── entities/               # future: attendance_session.dart
│   ├── repositories/         # future: attendance_repository.dart
│   └── usecases/             # future: record_check_in_usecase.dart
└── presentation/
    ├── pages/
    │   └── attendance_page.dart
    ├── providers/
    │   └── attendance_providers.dart
    └── widgets/              # stack cards, live status, camera preview
        └── ...
```

### Kiosk platform (optional dedicated feature)

When Lock Task / iOS kiosk APIs move behind a clean boundary:

```text
lib/features/kiosk_mode/
├── data/
│   └── kiosk_mode_platform_gateway.dart   # MethodChannel / Pigeon impl
├── domain/
│   └── kiosk_mode_service.dart            # abstract contract
└── presentation/
    └── providers/
        └── kiosk_mode_providers.dart
```

---

## `test/` — mirror + speed

```text
test/
├── core/
│   └── usecases/
├── features/
│   ├── registration/
│   ├── auth/
│   ├── employees/
│   └── attendance/
├── mocks/
├── fakes/
└── widget_test.dart
```

**Golden tests** (optional): `test/goldens/` + `flutter_test` compare.

---

## `integration_test/`

Full flows: first install → registration → login → drawer navigation → employees list persistence.

---

## Principles (quick reference)

1. **Dependency rule**: `presentation` → `domain` ← `data`. `core` never depends on `features`.
2. **One feature = one vertical slice**; shared UI only if used by **3+** features (then move to `core/widgets`).
3. **Router** stays in `lib/app/router/`; features expose **paths** or **named routes** via small constants if needed.
4. **Riverpod**: providers next to the feature that owns the state; app-wide overrides live under `lib/app/di/`.
5. **ML / camera**: keep **ports** in `core/ml` or `feature/domain`; **Google ML Kit** adapters live under `features/attendance/data/ml/`.

This structure matches `docs/project_requirements.md` and scales when APIs, kiosk platform code, and richer attendance logic are added.
