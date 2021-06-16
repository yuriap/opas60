insert into opas_db_links (DB_LINK_NAME,OWNER,STATUS,is_public) values ('$LOCAL$', 'PUBLIC', 'CREATED','Y');


INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSHIGH',4,'High priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSNORM',2,'Normal priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSLOW', 1,'Low priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','TASKRETENTION',3,'Retention time in days for task queue metadata.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','LOGRETENTION', 3,'Retention time in days for logs.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','ALERTRETVED',  8,'Retention time in days for viewed alerts.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','ALERTRETNVED', 30,'Retention time in days for non-viewed alerts.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','INSTRUMENTATION','INSTR_SQL_GATHER_STAT',null,'Start to gather SQL rowsource statistic for a given code.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','INSTRUMENTATION','INSTR_SQL_TRACE',null,'Start Extended SQL Trace for a given code.');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','LOGGING','LOGGING_LEVEL','INFO','Current logging level. INFO|DEBUG');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','SQL_DATA','SECONDARYTASKTIMEOUT', 3600,'Timeout for a secondary task of gathering SQL data, seconds');

--INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','ALERT','HIDEVIEWED', 1,'Hide viewed alerts after N days.');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','SQLSEARCHRETENTION', 60,'Retention time in minutes for SQL Searches.');
--new
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','ASHARANGE',      8,'Retention time in days for non referenced ASHA Cube ranges.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','NOTIFICATIONS', 48,'Retention time in hours for non-viewed notifications.');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','SCHEDULER','RUNAWAYDELAY', '+00 00:15:00','Max default scheduled job duration before forcebly stop it.');
--external execution
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','MAXEXTWORKERS', '5','Maximum number of simultaneously running worker jobs');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','EXTLOGGINGMODE',    'INFO','External execution server logging level. INFO|DEBUG');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','QRYPERWORKERSESS',    100,'Number of queries a worker can execute during one session');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','EXTEXECLOGRETENT',    1,'External server logs retention, hours');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','SRVINTERVAL',    'FREQ=SECONDLY; INTERVAL=5','Server coourdinator schedule');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','ALARMLOGININTERVAL',    30, 'Failed logins interval to alarm, minutes');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','WORKERAQCITERS',    1200,   'Max num of iteration of waiting for new query by Worker');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','WORKERAQCSLEEP',    0.1,    'Interval between iteration of waiting for new query by Worker');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','COORDAQCITERS',    240,     'Max num of iteration of waiting for new query by Coordinator');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','COORDAQCSLEEP',    0.5,     'Interval between iteration of waiting for new query by Coordinator');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','COORDGNSSLEEP',    0.1,     'Interval between iteration of waiting for new work by external server');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','TIMOUTCREATED',    7200,    'Timeout of waiting result: after request created, seconds');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','TIMOUTSTARTED',    3600,    'Timeout of waiting result: after , seconds');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','JDBCBATCHSIZE',    100,     'Batch processing size');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','SERVERTYPE',       'STANDALONE',     'Server Type: LOCALJVM, STANDALONE');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','PRELOADEDWRKRS',   '',      'DBLink list comma separated for prestarted workers');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXTERNAL','PRELOADEDWRKRSNUM','2',     'Number of prestarted workers per configured DBLink');



insert into opas_groups (group_id,group_name,group_descr) values (0, 'Administrators','Full set of rights');
insert into opas_groups (group_id,group_name,group_descr) values (1, 'Reas-write users','All application functions');
insert into opas_groups (group_id,group_name,group_descr) values (2, 'Read-only users','Read-only functions');
insert into opas_groups (group_id,group_name,group_descr) values (3, 'No access users','No access to any functionality');


rem @@expimp_compat


insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (100,'Folder'            ,'Folder object'                            ,'fa-folder'                           ,'COREOBJ_FOLDER');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (110,'Attachment'        ,'Stored attached file'                     ,'fa-file-archive-o'                   ,'COREOBJ_ATTACHMENTS');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (120,'Report'            ,'Stored whole report'                      ,'fa-file-text-o'                      ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (130,'DB Link Assignment','Configuration: DB Links assignment object','fa-database-heart'                   ,'COREOBJ_DBLINKS2OBJ');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (140,'SQL Performance Data','SQL Performance Data collection'        ,'fa-file-sql'                         ,'COREOBJ_SQL');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (150,'SQL List'          ,'Configuration: SQL white|black|known list','fa-clipboard-list'                   ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (160,'Memo'              ,'Memo attached to an object'               ,'fa-file-edit'                        ,'COREOBJ_MEMO');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (200,'SQL Trace'         ,'Application "SQl Trace" stored extended sql trace file and parsed representation'
                                                                                                                                                      ,'fa-database-clock'                    ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (300,'ASHA Cube'         ,'Application "ASHA" Cube data and diagrams','fa-cube'                             ,'COREOBJ_ASHA_CUBE');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (400,'AWR Dump'          ,'Application "AWRWH" AWR stored dump'      ,'fa-database-play'                    ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (500,'DB Growth Monitor' ,'Application "DB Growth Monitor" data'     ,'fa-combo-chart'                      ,'COREOBJ_DB_GROWTH');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (600,'Simple DB Monitor' ,'Simple Database monitor to measure scalar metric' ,'fa-eyedropper'               ,'COREOBJ_DB_MONITOR');

insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (700,'SQL Catcher'       ,'SQL Catcher to automatically collect SQL data' ,'fa-indent'                      ,'COREOBJ_SQL_CATCHER');
--
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (800,'SQL Comparison'    ,'SQL Comparison analytic tool'             ,'fa-balance-scale'                    ,'COREOBJ_SQL_COMP_REPORT');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (900,'SQL Forecast Report' ,'Tagged SQLs report for forecasting'     ,'fa-road'                             ,'COREOBJ_SQL_FORECAST');
--!
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (1000,'SQL Analyzer Report' ,'Rule-based SQL plan analyzer'           ,'fa-bug'                             ,'COREOBJ_SQL_ANALYZER');

INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1000,         100,   'CREATE',     'Create Folder');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1300,         130,   'OPEN',       'Open DB Links assignments');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1300,         130,   'CREATE',     'Create DB Links assignments');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1101,         110,   'OPEN',       'Open attached file');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1102,         110,   'CREATE',     'Upload attached file');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1400,         140,   'CREATE',     'Register new SQL query');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1401,         140,   'OPEN',       'Show SQL Data');
--INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1103,         110,   'EDIT',       'Edit attached file');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (5000,         500,   'CREATE',     'Register new Database Growth Monitor');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (5000,         500,   'OPEN',       'Show Database Growth Monitor');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (5003,         500,   'PREVIEW',    'Preview Database Growth Monitor');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (6000,         600,   'CREATE',     'Register new Simple DB Monitor');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (6000,         600,   'OPEN',       'Show Simple DB Monitor');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (6002,         600,   'PREVIEW',    'Preview Simple DB Monitor Graph');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (7000,         700,   'CREATE',     'Register new SQL Catcher');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (7000,         700,   'OPEN',       'Show SQL Catcher');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (8000,         800,   'CREATE',     'Register new SQL Comparison');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (8000,         800,   'OPEN',       'Show SQL Comparison');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (9000,         900,   'CREATE',     'SQL Forecast Report');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (9000,         900,   'OPEN',       'SQL Forecast Report');
--
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (10000,       1000,   'CREATE',     'SQL Analyzer Report');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (10000,       1000,   'OPEN',       'SQL Analyzer Report');
--
delete from opas_object_pages where ot_id=300;
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (3000,         300,   'CREATE',     'Create ASHA Cube');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (3000,         300,   'OPEN',       'Parameters of ASHA Cube');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (3003,         300,   'PREVIEW',    'Show ASHA Cube');

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','FILE_MIMETYPE','TXT'                     ,'Text file'   ,null,null,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','FILE_MIMETYPE','TEXT/HTML'               ,'HTML file'   ,null,null,null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','FILE_MIMETYPE','APPLICATION/OCTET-STREAM','Binary file' ,null,null,null,30);

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','FILE_TYPE','ATTACHMENT'                  ,'Attached file'   ,null,null,null,10);

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQL_TEXT'                   ,'SQL Text'                        ,'sql_text',     null,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SHARING'                    ,'Non shared reason'               ,'non_shared',   null,null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','VSQL'                       ,'V$SQL statistics'                ,'v_sql_stat',   null,null,30);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','EXADATA'                    ,'Exadata statistics'              ,'exadata',      null,null,40);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLMONV$'                   ,'SQL Monitor report'              ,'sql_mon',      null,null,50);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','WORKAREA'                   ,'SQL Workarea'                    ,'sql_workarea', null,null,60);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','OPTENV'                     ,'CBO environment'                 ,'cbo_env',      null,null,70);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLPLLAST'                  ,'Display cursor (last)'           ,'dp_last',      null,null,80); 
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLPLADV'                   ,'Display cursor (LAST ADVANCED)'  ,'dp_last_adv',  null,null,90);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLPLALL'                   ,'Display cursor (ALL)'            ,'dp_all',       null,null,100);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLPLADAPT'                 ,'Display cursor (ADAPTIVE)'       ,'dp_adaptive',  null,null,110);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLPLEP'                    ,'Explain Plan'                    ,'dp_ep',        null,null,115);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','SQLMONHST'                  ,'SQL Monitor report history'      ,'sql_mon_hist', null,null,130);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','VASH'                       ,'ASH summary'                     ,'ash_summ',     null,null,140);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_SQLSTAT'                ,'AWR SQL statistics'              ,'ash_sqlstat',  null,null,150);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_BINDS'                  ,'AWR SQL Binds'                   ,'ash_binds',    null,null,160);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_SQLPLAN'                ,'AWR Display cursor'              ,'ash_binds',     null,null,170);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_PLSQLSRC'               ,'AWR ASH PL/SQL source'           ,'ash_plsqlsrc', null,null,180);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_ASHINVOKER'             ,'AWR ASH Invocers'                ,'ash_invokers', null,null,190);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLREPSECT','AWR_ASHPLSTATS'             ,'AWR ASH plan staictics'          ,'ash_plsstat',  null,null,200);

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SDBMALERT', 'SINGLELIMIT'                ,'Single value limit'   ,null,null,null,10);

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'SIZELIMIT'                  ,'Total Size'           ,'bytes',null,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'DELTALIMIT'                 ,'Total Delta Size'     ,'bytes',null,null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'FREELIMIT'                  ,'Total Free Size'      ,'bytes',null,null,30);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'OUTOFSPACE'                 ,'Days to out of space' ,'dates',null,null,40);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'REGEXP'                     ,'Regular Expression'   ,'bytes',null,null,50);
--
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','CSQLTEXT'                  ,'SQL Texts'            ,'ccsqltxt',       null,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','EXECPLAN'                  ,'Execution Plans'      ,'ccexpln',        null,null,30);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','VSQLSTAT'                  ,'V$SQL statistics'     ,'ccvsqlst',       null,null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','AWRSTAT'                   ,'AWR statistics'       ,'ccawrst',        null,null,40);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','ASHWAIT'                   ,'ASH Wait Profiles'    ,'ccashwt',        null,null,50);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','ASHPLANSTAT'               ,'ASH Plan Stats'       ,'ccashplst',      null,null,60);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SQLCOMPSECT','SQLMON'                    ,'SQL Moitor Report'    ,'ccsqlmonrep',    null,null,70);

--Notifications
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','NOTIFTYPES','1'                          ,'Maintenance'   ,'fa-wrench',                'rgb(86,86,86)' ,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','NOTIFTYPES','2'                          ,'Task finished' ,'fa-server-check',          'rgb(34,177,76)',null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','NOTIFTYPES','3'                          ,'Information'   ,'fa-info-square-o',         'rgb(86,86,86)' ,null,30);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','NOTIFTYPES','4'                          ,'Exception'     ,'fa-exclamation-diamond-o', 'rgb(192,0,15)' ,null,40);


declare
  l_file_id number;
  l_file    varchar2(32765);
begin
  l_file := 
q'[
@../modules/core/files/opasawr.css
]';
   l_file_id := COREMOD_FILE_UTILS.create_file(
     P_MODNAME => COREMOD_API.gMODNAME,
     P_FILE_TYPE => 'CSS',
     P_FILE_NAME => 'opasawr.css',
     P_MIMETYPE => COREMOD_FILE_UTILS.mtTEXT,
     P_OWNER => 'PUBLIC');
   COREMOD_FILE_UTILS.store_content (  
     P_FILE_ID => l_file_id,
     P_CONTENT => l_file);  
  MERGE INTO opas_config t 
    using (select '&MODNM.' modname,'INTERNAL' cgroup,'OPASAWR.CSS' ckey,l_file_id cvalue,'CSS File opasawr.css for reports' descr from dual) s
	on (t.modname=s.modname and t.cgroup=s.cgroup and t.ckey=s.ckey)
	when matched then update set
	  t.cvalue=s.cvalue,
	  t.descr=s.descr
	when not matched then insert (t.modname,t.cgroup,t.ckey,t.cvalue,t.descr) VALUES (s.modname,s.cgroup,s.ckey,s.cvalue,s.descr);	 
end;
/

declare
  l_file_id number;
  l_file    varchar2(32765);
begin
  l_file := 
q'[
@../modules/core/files/create_patch_profile_template_sqlbin.sql
]';
   l_file_id := COREMOD_FILE_UTILS.create_file(
     P_MODNAME => COREMOD_API.gMODNAME,
     P_FILE_TYPE => 'PLSQL',
     P_FILE_NAME => 'create_patch_profile_template_sqlbin.sql',
     P_MIMETYPE => COREMOD_FILE_UTILS.mtTEXT,
     P_OWNER => 'PUBLIC');
   COREMOD_FILE_UTILS.store_content (  
     P_FILE_ID => l_file_id,
     P_CONTENT => l_file);  
  MERGE INTO opas_config t 
    using (select '&MODNM.' modname,'INTERNAL' cgroup,'SQLPROFILERTEMPL' ckey,l_file_id cvalue,'SQL Profile and SQL Patch template for single query' descr from dual) s
	on (t.modname=s.modname and t.cgroup=s.cgroup and t.ckey=s.ckey)
	when matched then update set
	  t.cvalue=s.cvalue,
	  t.descr=s.descr
	when not matched then insert (t.modname,t.cgroup,t.ckey,t.cvalue,t.descr) VALUES (s.modname,s.cgroup,s.ckey,s.cvalue,s.descr);	 
end;
/

----
INSERT INTO opas_groups2apexusr ( group_id, modname, apex_user) VALUES ( 0, 'OPASCORE', 'OPAS60ADM');
INSERT INTO opas_groups2apexusr ( group_id, modname, apex_user) VALUES ( 0, 'OPASCORE', upper('&namepref.'));


commit;