------ Users > Functions -------------------------------------------------------

create function sg_public.user_md5_email(user sg_public.user)
returns text as $$
  select md5(lower(trim(email)))
  from sg_private.user
  where user_id = user.id
  limit 1;
$$ language sql stable;
comment on function sg_public.user_md5_email(sg_public.user)
  is 'The user''s email address as an MD5 hash, for Gravatars. '
     'See https://bit.ly/2F6cR0M';
grant execute on function sg_public.user_md5_email(sg_public.user)
  to sg_anonymous, sg_user, sg_admin;













------ Cards & Subjects --------------------------------------------------

-- TODO given a subject, calculate its parents and children

-- Allow end users to make subjects:

create function sg_private.update_version_status()
returns trigger as $$
  declare
    role text;
  begin
    role := current_setting('jwt.claims.role')::text;
    if (role = 'sg_admin') then
      return new;
    end if;
    if (old.user_id <> current_setting('jwt.claims.user_id')) then
      raise exception 'A user may only change their own version status.'
        using errcode = '61C7AC84';
    end if;
    if (new.status <> 'declined') then
      raise exception 'A user may only change the version status to declined.'
        using errcode = '05F2D0E1';
    end if;
    if (old.status = 'accepted') then
      raise exception 'A user cannot change an accepted version.'
        using errcode = '62CF3D42';
    end if;
    return new;
  end;
$$ language plpgsql strict security definer;
comment on function sg_private.update_version_status()
  is 'A user may only change their own version status to declined.';
create trigger update_subject_version_status
  before update on sg_public.subject_version
  for each row execute procedure sg_private.update_version_status();
comment on trigger update_subject_version_status on sg_public.subject_version
  is 'A user may only decline their own un-accepted subject version.';
create trigger update_card_version_status
  before update on sg_public.card_version
  for each row execute procedure sg_private.update_version_status();
comment on trigger update_card_version_status on sg_public.card_version
  is 'A user may only decline their own un-accepted card version.';

create function sg_private.insert_subject_version_parent_child_cycle()
returns trigger as $$
  begin
    if exists(
      with recursive graph (entity_id, path, cycle) as (
        select
          sv.entity_id,
          array[sv.entity_id, new.entity_id],
          sv.entity_id = new.entity_id
        from sg_public.subject_version sv
        where new.version_id = sv.version_id
        union all
        select
          s.entity_id,
          g.path || s.entity_id,
          s.entity = any(g.path)
        from
          graph g,
          sg_public.subject_version_parent_child svpc,
          sg_public.subject s
        where
          g.entity_id = svpc.before_entity_id
          and svpc.version_id = s.version_id
          and not g.cycle
      )
      select *
    ) then
      raise exception 'Subject parent/child cannot form a cycle.'
        using errcode = '7876F332';
    else
      return new;
    end if;
  end;
$$ language plpgsql strict security definer;
create trigger insert_subject_version_parent_child_cycle
  before insert on sg_public.subject_version
  for each row execute procedure sg_private.insert_subject_version_parent_child_cycle();
comment on function sg_private.insert_subject_version_parent_child_cycle()
  is 'Ensure subject parent/child relations don''t form a cycle.';
comment on trigger insert_subject_version_parent_child_cycle
  on sg_public.subject_version
  is 'Ensure subject parent/child relations don''t form a cycle.';

create function sg_private.insert_subject_version_before_after_cycle()
returns trigger as $$
  begin
    if exists(
      with recursive graph (entity_id, path, cycle) as (
        select
          sv.entity_id,
          array[sv.entity_id, new.entity_id],
          sv.entity_id = new.entity_id
        from sg_public.subject_version sv
        where new.version_id = sv.version_id
        union all
        select
          s.entity_id,
          g.path || s.entity_id,
          s.entity = any(g.path)
        from
          graph g,
          sg_public.subject_version_before_after svba,
          sg_public.subject s
        where
          g.entity_id = svba.before_entity_id
          and svba.version_id = s.version_id
          and not g.cycle
      )
      select *
    ) then
      raise exception 'Subject before/after cannot form a cycle.'
        using errcode = 'D8182DC8';
    else
      return new;
    end if;
  end;
$$ language plpgsql strict security definer;
create trigger insert_subject_version_before_after_cycle
  before insert on sg_public.subject_version
  for each row execute procedure sg_private.insert_subject_version_before_after_cycle();
comment on function sg_private.insert_subject_version_before_after_cycle()
  is 'Ensure subject before/after relations don''t form a cycle.';
comment on trigger insert_subject_version_before_after_cycle
  on sg_public.subject_version
  is 'Ensure subject before/after relations don''t form a cycle.';

create function sg_public.search_cards(query text)
returns setof sg_public.card as $$
  select
    *,
    to_tsvector('english', unaccent(name)) ||
    to_tsvector('english', unaccent(tags)) ||
    to_tsvector('english', unaccent(data)) as document,
    ts_rank(document, websearch_to_tsquery('english', unaccent(query))) as rank
  from sg_public.card
  where document @@ websearch_to_tsquery('english', unaccent(query))
  order by rank desc;
$$ language sql;
comment on function sg_public.search_cards(text)
  is 'Search cards.';
grant execute on function sg_public.search_card(text)
  to sg_anonymous, sg_user, sg_admin;

create function sg_public.search_entities(query text)
returns setof (entity_id, name, body, kind) as $$
  select entity_id, name, body, 'subject' as kind
  from sg_public.search_subjects(query)
  union all
  select entity_id, name, data as body, 'card' as kind
  from sg_public.search_cards(query)
  order by rank desc;
$$ language sql;
comment on function sg_public.search_entities(text)
  is 'Search subject and cards.';
grant execute on function sg_public.search_entity(text)
  to sg_anonymous, sg_user, sg_admin;

create function sg_public.select_my_cards()
returns setof sg_public.card as $$
  select *
  from sg_public.card
  where entity_id in (
    select entity_id
    from sg_public.card_version
    where user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid
  );
$$ language sql stable;
comment on function sg_public.select_my_cards()
  is 'Select cards I created or worked on.';
grant execute on function sg_public.select_my_cards()
  to sg_user, sg_admin;

create function sg_public.select_my_subjects()
returns setof sg_public.subject as $$
  select *
  from sg_public.subject
  where entity_id in (
    select entity_id
    from sg_public.subject_version
    where user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid
  );
$$ language sql stable;
comment on function sg_public.select_my_subjects()
  is 'Select subjects I created or worked on.';
grant execute on function sg_public.select_my_subjects()
  to sg_user, sg_admin;

create function sg_public.edit_subject(
  entity_id uuid
  name text,
  tags text[],
  body text,
  members jsonb -- todo update
)
returns sg_public.subject_version as $$
  with previous as (
    select *
    from sg_public.subject
    where sg_public.subject.entity_id = entity_id
    limit 1
  ),
  subject_version as (
    insert into sg_public.subject_version
    (entity_id, previous_id, name, tags, body)
    values (entity_id, previous.version_id, name, tags, body)
  )
  insert into sg_public.subject_version_member
  (version_id, entity_id, entity_kind)
  select (subject_version.version_id,
    json_array_elements(members) as (entity_id, entity_kind));
$$ language 'plpgsql' volatile;
comment on function sg_public.edit_subject(
  uuid
  text,
  text[],
  text,
  jsonb
) is 'Edit an existing subject.';
grant execute on function sg_public.edit_subject(
  uuid
  text,
  text[],
  text,
  jsonb
) to sg_anonymous, sg_user, sg_admin;

create function sg_public.edit_card(
  entity_id uuid,
  name text,
  tags text[],
  subject_id uuid,
  kind text
  data jsonb
)
returns sg_public.card_version as $$
  with previous as (
    select *
    from sg_public.card
    where sg_public.card.entity_id = entity_id
    limit 1
  )
  insert into sg_public.card_version
  (entity_id, previous_id, name, tags, subject_id, kind, data)
  values (entity_id, previous.version_id, name, tags, subject_id, kind, data);
$$ language 'plpgsql' volatile;
comment on function sg_public.edit_card(
  uuid,
  text,
  text[],
  uuid,
  text
  jsonb
) is 'Edit an existing card.';
grant execute on function sg_public.edit_card(
  uuid,
  text,
  text[],
  uuid,
  text
  jsonb
) to sg_anonymous, sg_user, sg_admin;

-- Update & delete card and subject: admin.
grant update, delete on table sg_public.subject_version to sg_admin;
grant update (status) on table sg_public.subject_version to sg_user;
grant update, delete on table sg_public.subject_version_parent_child to sg_admin;
grant update, delete on table sg_public.subject_version_before_after to sg_admin;
grant update, delete on table sg_public.card_version to sg_admin;
grant update (status) on table sg_public.card_version to sg_user;








































------ Topics & Posts ----------------------------------------------------------

------ Topics & Posts > Types --------------------------------------------------

create type sg_public.post_kind as enum(
  'post',
  'proposal',
  'vote'
);
comment on type sg_public.post_kind
  is 'The three kinds of posts.';

------ Topics & Posts > Tables -------------------------------------------------

create table sg_public.topic (
  id uuid primary key default uuid_generate_v4(),
  created timestamp not null default current_timestamp,
  modified timestamp not null default current_timestamp,
  user_id uuid null references sg_public.user (id),
  name text not null,
  entity_id uuid not null,
  entity_kind sg_public.entity_kind not null,
  foreign key (entity_id, entity_kind)
    references sg_public.entity (entity_id, entity_kind)
);

comment on table sg_public.topic
  is 'The topics on an entity''s talk page.';
comment on column sg_public.id
  is 'The public ID of the topic.';
comment on column sg_public.created
  is 'When the user created the topic.';
comment on column sg_public.modified
  is 'When the user last modified the topic.';
comment on column sg_public.user_id
  is 'The user who created the topic.';
comment on column sg_public.entity_id
  is 'The entity the topic belongs to.';
comment on column sg_public.entity_kind
  is 'The kind of entity the topic belongs to.';

create table sg_public.post (
  id uuid primary key default uuid_generate_v4(),
  created timestamp not null default current_timestamp,
  modified timestamp not null default current_timestamp,
  user_id uuid null references sg_public.user (id)
    check (kind <> 'vote' or user_id is not null),
  topic_id uuid not null references sg_public.topic (id),
  kind sg_public.post_kind not null default 'post',
  body text null
    check (kind = 'vote' or body is not null),
  parent_id uuid null references sg_public.post (id)
    check (kind <> 'vote' or parent_id is not null),
  response boolean null
    check (kind <> 'vote' or response is not null)
  -- also see join table: sg_public.post_entity_version
  -- specific to kind = 'proposal'
);

comment on table sg_public.post
  is 'The posts on an entity''s talk page. Belongs to a topic.';
comment on column sg_public.post.id
  is 'The ID of the post.';
comment on column sg_public.post.created
  is 'When the user created the post.';
comment on column sg_public.post.modified
  is 'When the post last changed.';
comment on column sg_public.post.user_id
  is 'The user who created the post.';
comment on column sg_public.post.topic_id
  is 'The topic the post belongs to.';
comment on column sg_public.post.kind
  is 'The kind of post (post, proposal, vote).';
comment on column sg_public.post.body
  is 'The body or main content of the post.';
comment on column sg_public.post.parent_id
  is 'If the post is a reply, which post it replies to.';
comment on column sg_public.post.response
  is 'If the post is a vote, yes/no on approving.';

create table sg_public.post_entity_version (
  id uuid primary key default uuid_generate_v4(),
  created timestamp not null default current_timestamp,
  modified timestamp not null default current_timestamp,
  post_id uuid not null references sg_public.post (id),
  version_id uuid not null,
  entity_kind sg_public.entity_kind not null,
  foreign key (version_id, entity_kind)
    references sg_public.entity_version (version_id, entity_kind)
  unique (post_id, version_id)
);

comment on table sg_public.post_entity_version
  is 'A join table between a proposal (post) and its entity versions.';
comment on column sg_public.post_entity_version.id
  is 'The relationship ID.';
comment on column sg_public.post_entity_version.created
  is 'When a user created this post.';
comment on column sg_public.post_entity_version.modified
  is 'When a user last modified this post.';
comment on column sg_public.post_entity_version.post_id
  is 'The post ID.';
comment on column sg_public.post_entity_version.version_id
  is 'The entity ID of the entity version.';

------ Topics & Posts > Indexes ------------------------------------------------

create unique index post_vote_unique_idx
  on sg_public.post (user_id, parent_id)
  where kind = 'vote';
comment on index post_vote_unique_idx
  is 'A user may only vote once on a proposal.';

------ Topics & Posts > Functions ----------------------------------------------

create function sg_private.verify_post()
returns trigger as $$
  declare
    parent sg_public.post;
  begin
    if (new.parent_id) then
      parent := (
        select *
        from sg_public.post
        where id = new.parent_id
      );
      if (parent.topic_id <> new.topic_id) then
        raise exception 'A reply must belong to the same topic.'
          using errcode = '76177573';
      end if;
      if (new.kind = 'vote' and parent.kind <> 'proposal') then
        raise exception 'A vote may only reply to a proposal.'
          using errcode = '8DF72C56';
      end if;
      if (new.kind = 'vote' and parent.user_id = new.user_id) then
        raise exception 'A user cannot vote on their own proposal.'
          using errcode = 'E47E0411';
      end if;
    end if;
  end;
$$ language 'plpgsql';
comment on function sg_private.verify_post()
  is 'Verify valid data when creating or updating a post.';

create function sg_private.vote_to_status()
returns trigger as $$
  if new.kind <> 'proposal' and new.kind <> 'vote' then
    return new;
  end if;
  if old and (old.status = 'accepted' or old.status = 'declined') then
    return new;
  end if;
  if new.response = false then
    return new;
  end if;
  -- For now, just accept
  update sg_public.card_version
  set status = 'accepted'
  where version_id in (
    select version_id
    from sg_public.post_entity_version
    where post_id = new.id
      and entity_kind = 'card'
  );
  update sg_public.subject_version
  set status = 'accepted'
  where version_id in (
    select version_id
    from sg_public.post_entity_version
    where post_id = new.id
      and entity_kind = 'subject'
  );
  -- Later version:
  -- get all the users who voted on the proposal
  -- count the number of accepted versions total per user: points
  -- assign a score of 0->1 (non-linear) to each user: 1 - e ^ (-points / 40) (computed column?)
  -- determine the number of learners impacted (computed column?)
  -- -- for a subject, get all subjects upward + current, then sum the user_subject counts
  -- -- for a card, get the immediate subject, then subject procedure
  -- if numLearners > 0 and sum(noVotes) > log100(numLearners), change the status to blocked
  -- if sum(yesVotes) > log5(numLearners), change the status to accepted
  -- else, change the status to pending
$$ language 'plpgsql';
comment on function sg_private.vote_to_status()
  is 'When a new proposal or vote happens, change entity status if possible';

------ Topics & Posts > Triggers -----------------------------------------------

create trigger insert_topic_user_id
  before insert on sg_public.topic
  for each row execute procedure sg_private.insert_user_id_column();
comment on trigger insert_topic_user_id on sg_public.topic
  is 'Whenever I make a new topic, auto fill the `user_id` column';

create trigger insert_post_user_id
  before insert on sg_public.post
  for each row execute procedure sg_private.insert_user_id_column();
comment on trigger insert_post_user_id on sg_public.post
  is 'Whenever I make a new post, auto fill the `user_id` column';

create trigger insert_post_verify
  before insert on sg_public.post
  for each row execute procedure sg_private.verify_post();
comment on trigger insert_post_verify on sg_public.post
  is 'Whenever I make a new post, check that the post is valid.';

create trigger update_topic_modified
  before update on sg_public.topic
  for each row execute procedure sg_private.update_modified_column();
comment on trigger update_topic_modified on sg_public.topic
  is 'Whenever a topic changes, update the `modified` column.';

create trigger update_post_modified
  before update on sg_public.post
  for each row execute procedure sg_private.update_modified_column();
comment on trigger update_post_modified on sg_public.post
  is 'Whenever a post changes, update the `modified` column.';

create trigger update_post_verify
  before update on sg_public.post
  for each row execute procedure sg_private.verify_post();
comment on trigger update_post_verify on sg_public.post
  is 'Whenever I make a new post, check that the post is valid.';

create trigger update_post_entity_version_modified
  before update on sg_public.post_entity_version
  for each row execute procedure sg_private.update_modified_column();
comment on trigger update_post_entity_version_modified
  on sg_public.post_entity_version
  is 'Whenever a post entity version changes, update the `modified` column.';

create trigger vote_to_status
  after insert, update on sg_public.post
  for each row execute sg_private.vote_to_status();
comment on trigger vote_to_status
  on sg_public.post
  is 'When a new proposal or vote happens, change entity status if possible';

------ Topics & Posts > Permissions --------------------------------------------

-- Enable RLS.
alter table sg_public.topic enable row level security;
alter table sg_public.post enable row level security;

-- Select topic: any.
grant select on table sg_public.topic to sg_anonymous, sg_user, sg_admin;
create policy select_topic on sg_public.topic
  for select -- any user
  using (true);
comment on policy select_topic on sg_public.topic
  is 'Anyone can select topics.';

-- Insert topic: any.
grant insert (name, entity_id, entity_kind) on table sg_public.topic
  to sg_anonymous, sg_user, sg_admin;
create policy insert_topic on sg_public.topic
  for insert (name, entity_id, entity_kind) -- any user
  with check (true);

-- Update topic: user self (name), or admin.
grant update (name) on table sg_public.topic to sg_user;
grant update on table sg_public.topic to sg_admin;
create policy update_topic on sg_public.topic
  for update (name) to sg_user
  using (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy update_topic on sg_public.topic
  is 'A user can update the name of their own topic.';
create policy update_topic_admin on sg_public.topic
  for update to sg_admin
  using (true);
comment on policy update_topic on sg_public.topic
  is 'An admin can update the name of any topic.';

-- Delete topic: admin.
grant delete on table sg_public.topic to sg_admin;
create policy delete_topic_admin on sg_public.topic
  for delete to sg_admin
  using (true);
comment on policy delete_topic_admin on sg_public.topic
  is 'An admin can delete any topic.';

-- Select post: any.
grant select on table sg_public.post to sg_anonymous, sg_user, sg_admin;
create policy select_post on sg_public.post
  for select -- any user
  using (true);
comment on policy select_post on sg_public.post
  is 'Anyone can select posts.';

-- Insert post: any.
grant insert (topic_id, kind, body, parent_id, response) on table sg_public.post
  to sg_anonymous, sg_user, sg_admin;
create policy insert_post on sg_public.post
  for insert (topic_id, kind, body, parent_id, response) -- any user
  with check (true);

-- Update post: user self (body, response), or admin.
grant update (body, response) on table sg_public.post to sg_user;
grant update on table sg_public.post to sg_admin;
create policy update_post on sg_public.post
  for update (body, response) to sg_user
  using (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy update_post on sg_public.post
  is 'A user can update the body or response of their own post.';
create policy update_post_admin on sg_public.post
  for update to sg_admin
  using (true);
comment on policy update_post_admin on sg_public.post
  is 'An admin can update any post.';

-- Delete post: admin.
grant delete on table sg_public.post to sg_admin;
create policy delete_post_admin on sg_public.post
  for delete to sg_admin
  using (true);
comment on policy delete_post_admin on sg_public.post
  is 'An admin can delete any post.';

-- Select post_entity_version: any.
grant select on table sg_public.post_entity_version
  to sg_anonymous, sg_user, sg_admin;

-- Insert post_entity_version, see function above.

-- Update or delete post_entity_version: admin.
grant update, delete on table sg_public.post_entity_version
  to sg_admin;



















------ Notices & Follows -------------------------------------------------------

------ Notices & Follows > Types -----------------------------------------------

create type sg_public.notice_kind as enum(
  'version_pending',
  'version_blocked',
  'version_declined',
  'version_accepted',
  'insert_topic',
  'insert_post'
);
comment on type sg_public.notice_kind
  is 'The kinds of notices. Expanding.';

------ Notices & Follows > Tables ----------------------------------------------

create table sg_public.notice (
  id uuid primary key default uuid_generate_v4(),
  created timestamp not null default current_timestamp,
  modified timestamp not null default current_timestamp,
  user_id uuid not null references sg_public.user (id) on delete cascade,
  read boolean not null default false,
  kind sg_public.notice_kind not null,
  entity_id uuid not null,
  entity_kind sg_public.entity_kind not null,
  foreign key (entity_id, entity_kind)
    references sg_public.entity (entity_id, entity_kind)
);

comment on table sg_public.notice
  is 'A notice is a message that an entity has recent activity.';
comment on column table sg_public.notice.id
  is 'The ID of the notice.';
comment on column table sg_public.notice.created
  is 'When the system created the notice.';
comment on column table sg_public.notice.modified
  is 'When the notice last changed.';
comment on column table sg_public.notice.user_id
  is 'Which user the notice belongs to.';
comment on column table sg_public.notice.kind
  is 'The kind of notice.';
comment on column sg_public.notice.entity_id
  is 'The entity the notice informs.';
comment on column sg_public.notice.entity_kind
  is 'The kind of entity notice informs.';
comment on column table sg_public.notice.read
  is 'Whether or not the user has read the notice.';

create table sg_public.follow (
  id uuid primary key default uuid_generate_v4(),
  created timestamp not null default current_timestamp,
  modified timestamp not null default current_timestamp,
  user_id uuid not null references sg_public.user (id) on delete cascade,
  entity_id uuid not null,
  entity_kind sg_public.entity_kind not null,
  unique (user_id, entity_id),
  foreign key (entity_id, entity_kind)
    references sg_public.entity (entity_id, entity_kind)
);

comment on table sg_public.follow
  is 'A follow is an association between a user and an entity. '
     'The user indicates they want notices for the entity.'
comment on column sg_public.follow.id
  is 'The ID of the follow.';
comment on column sg_public.follow.created
  is 'When the user or system created the follow.';
comment on column sg_public.follow.modified
  is 'When the user or system modified the follow.';
comment on column sg_public.follow.user_id
  is 'The user the follow belongs to.';
comment on column sg_public.follow.entity_id
  is 'The entity the follow belongs to.';
comment on column sg_public.follow.entity_kind
  is 'The kind of entity the follow belongs to.';

------ Notices & Follows > Indexes ---------------------------------------------

------ Notices & Follows > Functions -------------------------------------------

------ Notices & Follows > Triggers --------------------------------------------

create trigger insert_follow_user_id
  before insert on sg_public.follow
  for each row execute procedure sg_private.insert_user_id_column();
comment on trigger insert_follow_user_id on sg_public.follow
  is 'Whenever I make a new follow, auto fill the `user_id` column';

create trigger update_notice_modified
  before update on sg_public.notice
  for each row execute procedure sg_private.update_modified_column();
comment on trigger update_notice_modified on sg_public.notice
  is 'Whenever a notice changes, update the `modified` column.';

create trigger update_follow_modified
  before update on sg_public.follow
  for each row execute procedure sg_private.update_modified_column();
comment on trigger update_follow_modified on sg_public.follow
  is 'Whenever a follow changes, update the `modified` column.';

------ Notices & Follows > Permissions -----------------------------------------

-- Enable RLS.
alter table sg_public.notice enable row level security;
alter table sg_public.follow enable row level security;

-- Select follow: user or admin self.
grant select on table sg_public.follow to sg_user, sg_admin;
create policy select_follow on sg_public.follow
  for select to sg_user, sg_admin
  using (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy select_follow on sg_public.follow
  is 'A user or admin can select their own follows.';

-- Insert follow: user or admin.
grant insert (entity_id, entity_kind) on table sg_public.follow
  to sg_user, sg_admin;
create policy insert_follow on sg_public.follow
  for insert (entity_id, entity_kind) to sg_user, sg_admin
  with check (true);

-- Update follow: none.

-- Delete follow: user or admin self.
grant delete on table sg_public.follow to sg_user, sg_admin;
create policy delete_follow on sg_public.follow
  for select to sg_user, sg_admin
  using (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy delete_follow on sg_public.follow
  is 'A user or admin can delete their own follows.';

-- Select notice: user or admin self.
grant select on table sg_public.notice to sg_user, sg_admin;
create policy select_notice on sg_public.notice
  for select to sg_user, sg_admin
  using (user_id = nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy select_notice on sg_public.notice
  is 'A user or admin can select their own notices.';

-- Insert notice: none.

-- Update notice: user or admin self (read).
grant update on table sg_public.notice to sg_user, sg_admin;
create policy update_notice on sg_public.notice
  for update (read) to sg_user, sg_admin
  using (nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy update_notice on sg_public.notice
  is 'A user or admin can mark a notice as read or unread.';

-- Delete notice: user or admin self.
grant delete on table sg_public.notice to sg_user, sg_admin;
create policy delete_notice on sg_public.notice
  for delete to sg_user, sg_admin
  using (nullif(current_setting('jwt.claims.user_id', true), '')::uuid);
comment on policy delete_notice on sg_public.notice
  is 'A user or admin can delete their own notices.';

create function sg_private.insert_version_notice()
returns trigger as $$
  insert into sg_public.notice
  (user_id, kind, entity_kind, entity_id)
  select (
    unnest(
      select distinct user_id
      from sg_public.follow
      where new.entity_id = sg_public.follow.entity_id
    ),
    'version_pending',
    replace(tg_table_name, '_version', ''),
    new.entity_id
  );
$$ language 'plpgsql';
comment on function sg_private.insert_version_notice()
  is 'After I insert a new version, notify followers.';

create function sg_private.update_version_notice()
returns trigger as $$
  if (new.status <> old.status) then
    insert into sg_public.notice
    (user_id, kind, entity_kind, entity_id)
    select (
      unnest(
        select distinct user_id
        from sg_public.follow
        where new.entity_id = sg_public.follow.entity_id
      ),
      'version_' || new.status,
      replace(tg_table_name, '_version', ''),
      new.entity_id
    );
  end if;
$$ language 'plpgsql';
comment on function sg_private.update_version_notice()
  is 'After I update a version status, notify followers.';

create trigger insert_subject_version_notice
  after insert on sg_public.subject_version
  for each row execute procedure sg_private.insert_version_notice();
comment on trigger insert_subject_version_notice on sg_public.subject_version
  is 'After I insert a new subject version, notify followers.';

create trigger insert_card_version_notice
  after insert on sg_public.card_version
  for each row execute procedure sg_private.insert_version_notice();
comment on trigger insert_card_version_notice on sg_public.card_version
  is 'After I insert a new card version, notify followers.';

create trigger update_subject_version_notice
  after update on sg_public.subject_version
  for each row execute procedure sg_private.update_version_notice();
comment on trigger update_subject_version_notice on sg_public.subject_version
  is 'After I update a subject version, notify followers.';

create trigger update_card_version_notice
  after update on sg_public.card_version
  for each row execute procedure sg_private.update_version_notice();
comment on trigger update_card_version_notice on sg_public.card_version
  is 'After I update a card version, notify followers.';

create function sg_private.insert_topic_notice()
returns trigger as $$
  insert into sg_public.notice
  (user_id, kind, entity_kind, entity_id)
  select (
    unnest(
      select distinct user_id
      from sg_public.follow
      where new.entity_id = sg_public.follow.entity_id
    ),
    'insert_topic',
    new.entity_kind,
    new.entity_id
  );
$$ language 'plpgsql';
comment on function sg_private.insert_topic_notice()
  is 'After I insert a new topic, notify followers.';
create trigger insert_topic_notice
  after insert on sg_public.topic
  for each row execute procedure sg_private.insert_topic_notice();
comment on trigger insert_topic_notice on sg_public.topic
  is 'After I insert a new topic, notify followers.'

create function sg_private.insert_post_notice()
returns trigger as $$
  declare
    topic sg_public.topic;
  begin
    topic := (
      select *
      from sg_public.topic
      where id = new.topic_id
      limit 1;
    );
    insert into sg_public.notice
    (user_id, kind, entity_kind, entity_id)
    select (
      unnest(
        select distinct user_id
        from sg_public.follow
        where topic.entity_id = sg_public.follow.entity_id
      ),
      'insert_post',
      topic.entity_kind,
      topic.entity_id
    );
  end;
$$ language 'plpgsql';
comment on function sg_private.insert_post_notice()
  is 'After I insert a new post, notify followers.';
create trigger insert_post_notice
  after insert on sg_public.post
  for each row execute procedure sg_private.insert_post_notice();
comment on trigger insert_post_notice on sg_public.post
  is 'After I insert a new post, notify followers.';

create function sg_private.follow_own_topic()
returns trigger as $$
  insert into sg_public.follow
  (entity_id, entity_kind)
  values
  (new.entity_id, new.entity_kind)
  on conflict do nothing;
$$ language 'plpgsql';
comment on function sg_private.follow_own_topic()
  is 'When I create a topic, I follow the entity.';
create trigger follow_own_topic
  after insert on sg_public.topic
  for each row execute procedure sg_private.follow_own_topic();
comment on trigger follow_own_topic on sg_public.topic
  is 'When I create a topic, I follow the entity.';

create function sg_private.follow_own_post()
returns trigger as $$
  declare
    topic sg_public.topic;
  begin
    topic := (
      select *
      from sg_public.topic
      where id = new.topic_id
      limit 1;
    );
    insert into sg_public.follow
    (entity_id, entity_kind)
    values
    (topic.entity_id, topic.entity_kind)
    on conflict do nothing;
    end;
$$ language 'plpgsql';
comment on function sg_private.follow_own_post()
  is 'When I create a post, I follow the entity.';
create trigger follow_own_post
  after insert on sg_public.post
  for each row execute procedure sg_private.follow_own_post();
comment on trigger follow_own_post on sg_public.post
  is 'When I create a post, I follow the entity.';
