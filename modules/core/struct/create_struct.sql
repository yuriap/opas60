@@create_struct_core
@@create_struct_core_obj
@@create_struct_sql_reg
@@create_struct_dbg
@@create_struct_objects
@@create_struct_asha

---------------------------------------------------------------------------------------------
-- reports
--create table opas_ot_reports (
--report_id           number                                           primary key,
--parent_id           number                                           references opas_reports(report_id) on delete set null,
--modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
--tq_id               number                                           references opas_task_queue(tq_id) on delete set null,
--report_content      number                                           references opas_files ( file_id ),
--report_params_displ varchar2(1000),
--report_type         varchar2(100)                          not null);

--alter table opas_ot_reports add constraint fk_reports_obj foreign key (report_id) references opas_objects(obj_id);

--create index idx_opas_reports_mod   on opas_ot_reports(modname);
--create index idx_opas_reports_fcntn on opas_ot_reports(report_content);

--create table opas_ot_reports_pars (
--report_id           number                                 not null  references opas_reports(report_id) on delete cascade,
--par_name            varchar2(100)                          not null,
--num_par             number,
--varchar_par         varchar2(4000),
--date_par            date
--);

--create index idx_opas_reports_parstske on opas_reports_pars(report_id);
