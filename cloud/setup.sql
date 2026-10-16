-- Run once in your Supabase project's SQL Editor. No credentials belong in this file.
create table if not exists public.workspace_documents (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  revision bigint not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.workspace_documents enable row level security;
revoke all on public.workspace_documents from anon, authenticated;
grant select on public.workspace_documents to authenticated;
drop policy if exists workspace_owner_read on public.workspace_documents;
create policy workspace_owner_read on public.workspace_documents for select to authenticated using (auth.uid() = user_id);
create or replace function public.save_workspace(document jsonb, expected_revision bigint)
returns setof public.workspace_documents
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(document) <> 'object' or octet_length(document::text) > 10000000 then
    raise exception 'Invalid document';
  end if;
  if expected_revision = 0 then
    return query insert into public.workspace_documents(user_id, payload, revision)
    values(auth.uid(), document, 1) on conflict do nothing returning *;
  else
    return query update public.workspace_documents set payload=document,
      revision=workspace_documents.revision+1,updated_at=now()
    where user_id=auth.uid() and revision=expected_revision returning *;
  end if;
end $$;
revoke all on function public.save_workspace(jsonb,bigint) from public;
grant execute on function public.save_workspace(jsonb,bigint) to authenticated;
