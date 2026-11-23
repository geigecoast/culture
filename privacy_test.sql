-- pgTAP tests for the privacy rules. Run with: supabase test db
begin;
select plan(5);

-- Three users: alice shares with friends, bob is her friend, carol is not, dave is blocked by alice.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'alice@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@example.test'),
  ('00000000-0000-0000-0000-00000000000c', 'carol@example.test'),
  ('00000000-0000-0000-0000-00000000000d', 'dave@example.test');
update public.profiles set attendance_visibility = 'friends' where id = '00000000-0000-0000-0000-00000000000a';
insert into public.friendships values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'accepted', now()),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000d', 'accepted', now());
insert into public.blocks values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000d', now());
insert into public.rsvps (user_id, event_id, state) values ('00000000-0000-0000-0000-00000000000a', 'evt-paris-002', 'going');

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000b"}';
select is((select count(*) from public.rsvps where user_id = '00000000-0000-0000-0000-00000000000a')::int, 1, 'friend sees opted-in attendance');

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c"}';
select is((select count(*) from public.rsvps where user_id = '00000000-0000-0000-0000-00000000000a')::int, 0, 'non-friend does not');

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000d"}';
select is((select count(*) from public.rsvps where user_id = '00000000-0000-0000-0000-00000000000a')::int, 0, 'blocked friend does not');

reset role;
update public.profiles set attendance_visibility = 'private' where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000b"}';
select is((select count(*) from public.rsvps where user_id = '00000000-0000-0000-0000-00000000000a')::int, 0, 'private attendance hidden from friends');

set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a"}';
select public.delete_my_account();
reset role;
select is((select count(*) from public.rsvps where user_id = '00000000-0000-0000-0000-00000000000a')::int, 0, 'account deletion removes attendance');

select * from finish();
rollback;
