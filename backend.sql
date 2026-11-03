-- Run once in a NEW Supabase project's SQL Editor.
begin;
create table public.passport_classes (
 id uuid primary key default gen_random_uuid(),
 teacher_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 100),
 access_code text not null unique default replace(gen_random_uuid()::text, '-', ''),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.passport_answers (
 id uuid primary key default gen_random_uuid(),
 class_id uuid not null references public.passport_classes(id) on delete cascade,
 request_id uuid not null,
 student text not null check (char_length(student) between 1 and 150),
 grade text not null check (char_length(grade) between 1 and 100),
 lesson_date text not null check (char_length(lesson_date) between 1 and 30),
 topic text not null check (char_length(topic) between 1 and 200),
 answers jsonb not null,
 created_at timestamptz not null default now(),
 unique(class_id, request_id)
);
create index passport_answers_class_time on public.passport_answers(class_id, created_at desc);
create index passport_classes_teacher on public.passport_classes(teacher_id);
alter table public.passport_classes enable row level security;
alter table public.passport_answers enable row level security;
revoke all on public.passport_classes, public.passport_answers from anon, authenticated;
grant select, insert, update, delete on public.passport_classes to authenticated;
grant select, delete on public.passport_answers to authenticated;
create policy teacher_classes on public.passport_classes for all to authenticated
 using (teacher_id = (select auth.uid()))
 with check (teacher_id = (select auth.uid()));
create policy teacher_reads_answers on public.passport_answers for select to authenticated
 using (exists(select 1 from public.passport_classes c where c.id = class_id and c.teacher_id = (select auth.uid())));
create policy teacher_deletes_answers on public.passport_answers for delete to authenticated
 using (exists(select 1 from public.passport_classes c where c.id = class_id and c.teacher_id = (select auth.uid())));
create function public.submit_passport(p_code text, p_request_id uuid, p_passport jsonb)
 returns uuid language plpgsql security definer set search_path = '' as $$
declare cid uuid; result_id uuid; k text;
begin
 if p_passport is null or jsonb_typeof(p_passport) <> 'object' or octet_length(p_passport::text) > 80000 then
  raise exception 'INVALID_PASSPORT';
 end if;
 foreach k in array array['student','grade','date','topic','task','result','cause','solution','conclusion'] loop
  if jsonb_typeof(p_passport->k) is distinct from 'string'
    or length(btrim(p_passport->>k)) = 0
    or length(p_passport->>k) > 10000 then raise exception 'INVALID_FIELD'; end if;
 end loop;
 select id into cid from public.passport_classes where access_code = btrim(p_code) and active = true;
 if cid is null then raise exception 'INVALID_CLASS_CODE'; end if;
 insert into public.passport_answers(class_id, request_id, student, grade, lesson_date, topic, answers)
 values(cid, p_request_id, btrim(p_passport->>'student'), btrim(p_passport->>'grade'),
 p_passport->>'date', btrim(p_passport->>'topic'),
 jsonb_build_object('task',p_passport->>'task','result',p_passport->>'result','cause',p_passport->>'cause',
 'solution',p_passport->>'solution','conclusion',p_passport->>'conclusion'))
 on conflict(class_id, request_id) do nothing returning id into result_id;
 if result_id is null then
  select id into result_id from public.passport_answers where class_id = cid and request_id = p_request_id;
 end if;
 return result_id;
end; $$;
revoke all on function public.submit_passport(text,uuid,jsonb) from public;
grant execute on function public.submit_passport(text,uuid,jsonb) to anon, authenticated;
commit;
