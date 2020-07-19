define MODNM=OPASCORE

@@version.sql
rem @@install_config.sql

--Core installation script
rem conn sys/&localsys.@&localdb. as sysdba
@&cloud_adm.

@@c_scheme_setup.sql

rem conn &localscheme./&localscheme.@&localdb.
@&cloud_opas.

@../modules/core/struct/create_struct.sql

@../modules/core/source/create_stored.sql

exec COREMOD_API.register(p_modname => '&MODNM.',   p_moddescr => 'Core Module',                                   p_modver => '&COREMODVER.',     p_installed => sysdate);
exec COREMOD_API.register(p_modname => 'OPASAPP',   p_moddescr => 'Oracle Performance Analytic Suite Application', p_modver => '&OPASVER.',        p_installed => sysdate);
exec COREMOD_API.register(p_modname => 'DB_GROWTH', p_moddescr => 'DB Growth Monitor',                             p_modver => '&DBGROWTHMODVER.', p_installed => sysdate);


@../modules/core/data/load.sql

exec coremod_tasks.create_task_job;
exec coremod_cleanup.create_cleanup_job;


begin
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPLOGS',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 24,
                                            p_task_body => 'begin coremod_log.cleanup_logs; end;');
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPTASKSDATA',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 24,
                                            p_task_body => 'begin coremod_tasks.cleanup_tasks; end;');
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPBLOBS',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 2,
                                            p_task_body => 'begin coremod_file_utils.clob2blob_cleanup; end;');
end;
/

--new
begin
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPDBGCHARTS',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 0.5,
                                            p_task_body => 'begin COREOBJ_DB_GROWTH_RPT.cleanup_chart_data; end;');
end;
/

begin
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPDBCHARTS',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 0.5,
                                            p_task_body => 'begin COREOBJ_DB_MONITOR.cleanup_chart_data; end;');
end;
/

--new
begin
  coremod_cleanup.register_cleanup_tasks (  P_TASKNAME => 'CLEANUPSQLSEARCH',
                                            P_MODNAME => '&MODNM.',
                                            p_frequency_h => 0.5,
                                            p_task_body => 'begin coreobj_sql_search.cleanup_sessions; end;');
end;
/

commit;

begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpNORM,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql (p_sql_data_point_id => <B1>); end;');
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER2',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpINTERNAL,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql2 (p_sql_data_point_id => <B1>); end;');
end;
/

--for recursive queries gathering
begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER_REC',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpLOW,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql (p_sql_data_point_id => <B1>); end;');
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER2_REC',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpINTERNAL,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql2 (p_sql_data_point_id => <B1>); end;');
end;
/


--for sql search
begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_LOCAL_SEARCH',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpHIGH,
                               p_task_body => 'begin COREOBJ_SQL_SEARCH.start_local_search(p_session_id => <B1>); end;');
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_EXTERNAL_SEARCH',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpHIGH,
                               p_task_body => 'begin COREOBJ_SQL_SEARCH.start_external_search(p_session_id => <B1>); end;');
end;
/

begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_TAGSQL',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpLOW,
                               p_task_body => 'begin coreobj_sql_tags.auto_tag_sql_task(p_tag_name => <B1>); end;');
end;
/


begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_CATCHER',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_priority => COREMOD_TASKS.tpLOW,
                               p_task_body => 'begin COREOBJ_SQL_CATCHER.task_catcher(p_obj_id => <B1>); end;');
end;
/

begin
  COREMOD_API.update_dblink_db_info (  P_DB_LINK_NAME => '$LOCAL$') ;
end;
/


/*
begin
  COREMOD_EXPIMP.init();
end;
/

*/