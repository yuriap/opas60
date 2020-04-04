---------------------------------------------------------------------------------------------
-- core objects
---------------------------------------------------------------------------------------------
-- attachments
create table opas_ot_attachments (
attach_id           number                                           primary key,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
attach_content      number                                           references opas_files ( file_id ));

alter table opas_ot_attachments add constraint fk_attach_obj foreign key (attach_id) references opas_objects(obj_id);

create index idx_opas_attach_mod   on opas_ot_attachments(modname);
create index idx_opas_attach_cntn  on opas_ot_attachments(attach_content);

---------------------------------------------------------------------------------------------
-- db links assignments
create table opas_ot_dblinks2obj (
trg_obj_id          number                                 not null  references opas_objects(obj_id) on delete cascade,
dblink              varchar2(128)                          not null  references opas_db_links (db_link_name) on delete cascade,
default_dblink      varchar2(1)      default 'N'           not null,
sortordr            number           default 0             not null);

create unique index idx_opas_dblinks2obj_trg on opas_ot_dblinks2obj(trg_obj_id,dblink);
create index idx_opas_dblinks2obj_dbl  on opas_ot_dblinks2obj(dblink);

create or replace type t_opasobj_dblrec is object(
d varchar2(512),
r varchar2(128));
/

create or replace type t_opasobj_dbltab is table of t_opasobj_dblrec;
/

---------------------------------------------------------------------------------------------
-- memo
create table opas_ot_memo (
memo_id           number                                             primary key,
memo_content      number                                             references opas_files ( file_id ));

alter table opas_ot_memo add constraint fk_memo_obj foreign key (memo_id) references opas_objects(obj_id);

create index idx_opas_memo_cntn  on opas_ot_memo(memo_content);
