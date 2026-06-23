\set pguser `echo "$POSTGRES_USER"`

create schema if not exists _realtime;
alter schema _realtime owner to :pguser;

create schema if not exists realtime;
alter schema realtime owner to :pguser;
