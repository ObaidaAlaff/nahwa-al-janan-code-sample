# نحو الجنان (Nahwa Al-Janan) — Code Sample

## Overview

Nahwa Al-Janan is a Quran-memorization platform connecting teachers and students inside structured study circles (halaqat). Students log daily memorization ("wird") progress and review it on a calendar; teachers track assessments, follow-ups, and attendance for the halaqat they officially own; admins manage curriculum levels, quizzes, announcements, and finances — all on a real-time Postgres backend with strict role- and institution-based data access.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart), GetX (state management, routing, DI) |
| Backend | Supabase — Postgres, Auth, Realtime, Storage, Row-Level Security, RPC |
| Notifications | Firebase Cloud Messaging via a Supabase Edge Function |

## Architecture

The app follows a modular GetX pattern: each feature under `lib/app/modules/<feature>/` pairs a `Controller` (state + business logic) with a `View` (UI only), wired up by a `Binding`. Four parallel main shells — `main_admin`, and `main_student_teacher/{student,teacher,quality_admin}` — give each role its own navigation and dashboard, all resolved from a single login through one route table.

Controllers talk to Supabase directly rather than through a repository layer, and screens work with the raw `Map<String, dynamic>` that Supabase returns rather than typed model classes — there's a `lib/app/models/` folder in the full project, but it's an earlier, now-unused pattern; every real controller in this sample reads/writes maps directly, so that's what's shown here.

## Database & Security

Institution multi-tenancy was retrofitted onto an app that started single-institution: an `institution_id` column was added across 23 tables in one migration when the backend needed to support multiple Quran schools. A `SECURITY DEFINER` access-token hook injects `institution_id`, `user_role`, and `can_view_financial` into every session's JWT at login, so RLS policies can check them via `auth.jwt()` without a per-row subquery.

Every table's policies check institution scoping on every branch (not just once), then layer a role check on top — e.g. `daily_reports`: a student sees only her own reports, staff (any non-student role) see every report in their institution. `conversations` additionally checks `group_members` for `custom`-type conversations (the actual halaqat), while a `primary_teacher_id` column (separate from chat membership) is what a teacher's reports/assessments/follow-up *dashboards* filter by, so being added to a group chat doesn't imply data-ownership. See [`database/daily_reports_and_rls.sql`](database/daily_reports_and_rls.sql) — it also documents a real bug the migration history hit: the JWT hook originally wrote the business role into the reserved `role` claim, which PostgREST uses for `SET ROLE`, so every authenticated request started failing with 401 until it was renamed to a plain `user_role` claim.

## Key Features

- Daily memorization ("wird") reports — 8 portions per day, each validated against the student's memorization level and direction (ascending/descending), with a simplified "juz-fixed" mode for advanced tracks
- Monthly progress calendar — color-coded submitted/missed/holiday days, doubling as an activity heatmap
- Offline-first reporting — a report becomes a local draft with no connection and is confirmed against the live server once one returns
- Role-based dashboards for students, teachers, quality admins, and admins, each scoped to the halaqat they actually own
- Weekly top-3 leaderboard with an animated celebration-poster design, shown across every role's home screen
- In-app chat, quizzes/exams, polls & announcements, and financial reporting (admin-only, gated in both RLS and the JWT)

## Folder Structure

```
lib/
└── app/
    ├── core/widgets/
    │   └── weekly_top_card.dart
    ├── modules/
    │   ├── auth/
    │   │   └── auth_controller.dart
    │   ├── main_student_teacher/
    │   │   ├── user_calendar_controller.dart
    │   │   └── user_calendar_view.dart
    │   └── report_detail/
    │       └── report_detail_controller.dart
    └── routes/
        └── app_pages.dart
database/
└── daily_reports_and_rls.sql
```

## Key Files

| File | Responsibility |
|---|---|
| [`report_detail_controller.dart`](lib/app/modules/report_detail/report_detail_controller.dart) | The app's core feature — daily wird report form state, expected-next-page calculation per memorization level/direction, full validation, and offline-draft fallback. |
| [`user_calendar_controller.dart`](lib/app/modules/main_student_teacher/user_calendar_controller.dart) | Monthly progress-calendar data: Supabase queries plus a rolling 30-day offline cache. |
| [`user_calendar_view.dart`](lib/app/modules/main_student_teacher/user_calendar_view.dart) | The calendar screen itself — color-coded activity grid and the selected day's full report. |
| [`weekly_top_card.dart`](lib/app/core/widgets/weekly_top_card.dart) | Distinctive animated leaderboard widget, reused across all four role dashboards. |
| [`auth_controller.dart`](lib/app/modules/auth/auth_controller.dart) | Multi-tenant, multi-role login — username + institution code, then role-based routing to one of four home shells. |
| [`app_pages.dart`](lib/app/routes/app_pages.dart) | GetX route table across all four roles. |
| [`daily_reports_and_rls.sql`](database/daily_reports_and_rls.sql) | Core table definitions, the custom JWT-claims hook, and the RLS policies that enforce institution + role scoping. |

## Screenshots

> Screenshots to be added to `screenshots/`.

## Platforms

Published on the App Store, Google Play, and the web.

## Note

This is a curated excerpt from a larger codebase, selected to demonstrate architecture, database/RLS design, and UI quality — not the full project. Some imports reference files outside this sample (other controllers, views, services); they're omitted here for scope, not because they don't exist.
