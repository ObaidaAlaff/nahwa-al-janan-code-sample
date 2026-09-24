-- ============================================================================
-- Nahwa Al-Janan — schema & RLS excerpt (daily_reports, conversations)
--
-- Assembled from the project's real migration history for readability —
-- every statement below is copied verbatim from an actual migration, only
-- reordered and commented for this sample. Two things worth noting:
--
-- 1. Institution scoping was retrofitted, not designed in from day one:
--    the app started single-institution and institution_id was added to
--    23 tables in one migration when it needed to support multiple
--    Quran-memorization schools on the same backend.
-- 2. `user_role` in the JWT went through a real bug: the hook originally
--    wrote it to the reserved `role` claim, which PostgREST uses for
--    `SET ROLE` — every authenticated REST call started failing with 401
--    ("no such Postgres role as admin/student/..."). Fixed by renaming to
--    a plain custom claim, `user_role`. Kept both versions' comments below
--    to show the actual fix, not just the end state.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Core tables (baseline schema)
-- ────────────────────────────────────────────────────────────────────────────

-- The app's central feature: a student's daily memorization ("wird") log.
-- Eight portions (memorize / near review / far review / prayer / listening /
-- tafsir / similar-verses / tadabur), each with its own done-flag and page
-- range, plus an optional "juz-fixed" simplified mode for advanced tracks.
create table if not exists public.daily_reports (
  id uuid not null default gen_random_uuid() primary key,
  memorize_half smallint null,
  near_review_ranges text null,
  far_review_ranges text null,
  memorize_page_to integer null,
  near_review_from_2 integer null,
  near_review_to_2 integer null,
  far_review_from_2 integer null,
  far_review_to_2 integer null,
  prayer_page_2 integer null,
  tadabur_done boolean null default false,
  pledge_confirmed boolean null default false,
  listen_page integer null,
  tafsir_page integer null,
  memorize_page integer null,
  near_review_from integer null,
  near_review_to integer null,
  far_review_pages integer null,
  far_review_from integer null,
  listening_done boolean null default false,
  tafsir_done boolean null default false,
  memorize_done boolean null default false,
  near_review_done boolean null default false,
  far_review_done boolean null default false,
  prayer_done boolean null default false,
  similar_done boolean null default false,
  far_review_to integer null,
  prayer_page integer null,
  similar_page integer null,
  tadabur_page integer null,
  listen_page_to integer null,
  tafsir_page_to integer null,
  similar_page_to integer null,
  tadabur_page_to integer null,
  student_id uuid not null,
  grade numeric null,
  report_date date not null default CURRENT_DATE,
  created_at timestamptz null default now(),
  is_juz_fixed boolean not null default false,
  juz_number integer null,
  daily_achievement text null
);
comment on column public.daily_reports.near_review_ranges is 'JSON array of page ranges for near review, e.g. [{"from":242,"to":261}]';
comment on column public.daily_reports.far_review_ranges is 'JSON array of page ranges for far review,  e.g. [{"from":302,"to":310}]';

-- A chat/halaqah conversation. conv_type='custom' conversations are the
-- actual study circles; primary_teacher_id is the ownership field that
-- decides which halaqat show up in a teacher's reports/assessments/
-- follow-up dashboards — distinct from mere chat membership.
create table if not exists public.conversations (
  id uuid not null default gen_random_uuid() primary key,
  level_id uuid null,
  primary_teacher_id uuid null,
  image_url text null,
  conv_type text not null check (conv_type = ANY (ARRAY['all'::text, 'admins'::text, 'teachers_admins'::text, 'group'::text, 'custom'::text, 'istirahah'::text, 'tafseer'::text, 'telawa'::text])),
  title text not null,
  icon text null,
  created_at timestamptz null default now()
);
comment on column public.conversations.primary_teacher_id is 'المعلمة المسؤولة رسمياً عن هذه الحلقة (group/tafseer/telawa) — تُستخدم لتحديد أي حلقات تظهر في شاشات التقارير/التقييمات/المتابعة عند المعلمة، بدلاً من مجرد العضوية في group_members.';


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Multi-tenancy retrofit — institution_id added across 23 tables
-- ────────────────────────────────────────────────────────────────────────────

alter table public.daily_reports add column if not exists institution_id uuid references public.institutions(id);
alter table public.conversations add column if not exists institution_id uuid references public.institutions(id);


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Custom JWT claims — SECURITY DEFINER access-token hook
--    Injects institution_id / user_role / can_view_financial into every
--    session's JWT at login, so RLS policies can read them via auth.jwt()
--    without a subquery on every row.
-- ────────────────────────────────────────────────────────────────────────────

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claims jsonb;
  v_institution_id uuid;
  v_role text;
  v_can_view_financial boolean;
  v_is_platform_admin boolean;
  v_uid uuid;
begin
  v_uid := (event->>'user_id')::uuid;
  claims := event->'claims';

  select exists(select 1 from public.platform_admins pa where pa.auth_user_id = v_uid)
    into v_is_platform_admin;

  if v_is_platform_admin then
    claims := jsonb_set(claims, '{platform_admin}', 'true'::jsonb);
  else
    select u.institution_id, u.user_type, u.can_view_financial
      into v_institution_id, v_role, v_can_view_financial
    from public.users u
    where u.auth_user_id = v_uid;

    if v_institution_id is not null then
      claims := jsonb_set(claims, '{institution_id}', to_jsonb(v_institution_id::text));
    end if;
    if v_role is not null then
      -- BUGFIX: originally jsonb_set(claims, '{role}', ...) — collided with
      -- the JWT's reserved top-level "role" claim that PostgREST uses to
      -- SET ROLE in Postgres, breaking every authenticated REST call with
      -- 401 ("no such Postgres role as admin/student/..."). Renamed to a
      -- plain custom claim, user_role.
      claims := jsonb_set(claims, '{user_role}', to_jsonb(v_role));
    end if;
    claims := jsonb_set(claims, '{can_view_financial}', to_jsonb(coalesce(v_can_view_financial, false)));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Row-Level Security
-- ────────────────────────────────────────────────────────────────────────────

alter table public.daily_reports enable row level security;
alter table public.conversations enable row level security;

-- A student sees/writes only her own reports; staff (teacher/admin/
-- quality_admin — anyone whose user_role isn't 'student') see all reports
-- within their own institution. Institution scoping is checked on every
-- branch of the OR, not just once, so it can't be bypassed by the role
-- check short-circuiting.
create policy "own_or_staff" on public.daily_reports for all
  using (
    institution_id = (auth.jwt()->>'institution_id')::uuid
    and (
      (auth.jwt()->>'user_role') <> 'student'
      or student_id = (select id from public.users where auth_user_id = auth.uid())
    )
  )
  with check (
    institution_id = (auth.jwt()->>'institution_id')::uuid
    and (
      (auth.jwt()->>'user_role') <> 'student'
      or student_id = (select id from public.users where auth_user_id = auth.uid())
    )
  );

-- Conversations: always institution-scoped. Within that, a 'custom'
-- conversation (an actual halaqah) is only visible to admins or to users
-- who are members of it via group_members — non-custom conversation types
-- (announcements, tafseer, etc.) are visible institution-wide.
create policy "institution_scoped_select" on public.conversations for select
  using (
    institution_id = (auth.jwt()->>'institution_id')::uuid
    and (
      conv_type <> 'custom'
      or (auth.jwt()->>'user_role') = 'admin'
      or exists (
        select 1 from public.group_members gm
        where gm.conversation_id = conversations.id and gm.user_id = (
          select id from public.users where auth_user_id = auth.uid()
        )
      )
    )
  );
create policy "institution_scoped_write" on public.conversations for insert
  with check (institution_id = (auth.jwt()->>'institution_id')::uuid);
create policy "institution_scoped_update" on public.conversations for update
  using (institution_id = (auth.jwt()->>'institution_id')::uuid)
  with check (institution_id = (auth.jwt()->>'institution_id')::uuid);
create policy "institution_scoped_delete" on public.conversations for delete
  using (institution_id = (auth.jwt()->>'institution_id')::uuid);
