drop table opas_sql_descriptions;
drop table opas_lists2sqls;
drop table opas_sql_lists;
drop table ;
drop table ;
drop table ;
drop table ;
drop table ;
drop table ;

drop table opas_reports_pars;
drop table opas_reports;
drop table opas_dblinks2obj;

drop table opas_expimp_compat;
drop table opas_expimp_params;
drop table opas_expimp_metadata;
drop table opas_expimp_sessions;

drop table opas_log;
drop table opas_task_pars;
drop table opas_task_queue;
drop table opas_task;

drop table opas_object_oper;
drop table opas_object_references;
drop table opas_object_page_pars;
drop table opas_object_pages;
drop table opas_objects;
drop table opas_object_types;

drop table opas_dictionary;
drop table opas_query_storage;
drop table opas_db_links;
drop table opas_files;

drop table opas_groups2apexusr;
drop table opas_groups;

drop table opas_config;
drop table opas_modules;

drop view v$opas_expimp_sessions;
drop VIEW V$OPAS_TASK_QUEUE_LONGOPS;
drop VIEW V$OPAS_TASK_QUEUE;
drop VIEW V$OPAS_DB_LINKS;

drop TYPE tableofnumbers;
drop TYPE tableofstrings;
drop type clob_page;
drop type clob_line;

purge recyclebin;