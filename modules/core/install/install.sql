define MODNM=OPASCORE

@@version.sql
@@install_config.sql

--Core installation script
conn sys/&localsys.@&localdb. as sysdba

@@scheme_setup.sql

conn &localscheme./&localscheme.@&localdb.

@../modules/core/struct/create_struct.sql

@../modules/core/source/create_stored.sql

exec COREMOD_API.register(p_modname => 'OPASAPP', p_moddescr => 'Oracle Performance Analytic Suite Application', p_modver => '&OPASVER.', p_installed => sysdate);
exec COREMOD_API.register(p_modname => '&MODNM.', p_moddescr => 'Core Module', p_modver => '&MODVER.', p_installed => sysdate);


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

commit;

begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
							   p_task_priority => COREMOD_TASKS.tpNORM,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql (p_sql_data_point_id => <B1>) ; end;');
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_SQL_DISCOVER2',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
							   p_task_priority => COREMOD_TASKS.tpNORM,
                               p_task_body => 'begin COREOBJ_SQL_UTILS.discover_sql2 (p_sql_data_point_id => <B1>) ; end;');
							   
end;
/

/*
begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_REPORT',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
							   p_task_priority => COREMOD_TASKS.tpNORM,
                               p_task_body => 'begin coremod_report_utils.execute_report (p_report_id => <B1>) ; end;');
end;
/


begin
  COREMOD_TASKS.create_task (  p_taskname  => 'OPAS_UPLOAD_IMP_FILE',
                               p_modname   => '&MODNM.',
                               p_is_public => 'Y', 
                               p_task_body => 'begin COREMOD_EXPIMP.import_file (p_exp_sess_id => <B1>) ; end;');
end;
/



begin
  COREMOD_EXPIMP.init();
end;
/

*/