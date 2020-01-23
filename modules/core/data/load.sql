insert into opas_db_links (DB_LINK_NAME,OWNER,STATUS,is_public) values ('$LOCAL$', 'PUBLIC', 'CREATED','Y');


INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSHIGH',4,'High priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSNORM',2,'Normal priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','TASKEXEC','MAXTHREADSLOW', 1,'Low priority: Max number of simultaneously running tasks');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','TASKRETENTION',3,'Retention time in days for task queue metadata.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','LOGRETENTION', 3,'Retention time in days for logs.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','INSTRUMENTATION','INSTR_SQL_GATHER_STAT',null,'Start to gather SQL rowsource statistic for a given code.');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','INSTRUMENTATION','INSTR_SQL_TRACE',null,'Start Extended SQL Trace for a given code.');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','LOGGING','LOGGING_LEVEL','INFO','Current logging level. INFO|DEBUG');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','SQL_DATA','AWRTASKTIMEOUT', 3600,'Timeout for a secondary task of gathering AWR data, seconds');

insert into opas_groups (group_id,group_name,group_descr) values (0, 'Administrators','Full set of rights');
insert into opas_groups (group_id,group_name,group_descr) values (1, 'Reas-write users','All application functions');
insert into opas_groups (group_id,group_name,group_descr) values (2, 'Read-only users','Read-only functions');
insert into opas_groups (group_id,group_name,group_descr) values (3, 'No access users','No access to any functionality');


@@expimp_compat


insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (100,'Folder'            ,'Folder object'                            ,'fa-folder'                           ,'COREOBJ_FOLDER');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (110,'Attachment'        ,'Stored attached file'                     ,'fa-file-archive-o'                   ,'COREOBJ_ATTACHMENTS');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (120,'Report'            ,'Stored whole report'                      ,'fa-file-text-o'                      ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (130,'DB Link Assignment','Configuration: DB Links assignment object','fa-database-heart'                   ,'COREOBJ_DBLINKS2OBJ');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (140,'SQL Performance Data','SQL Performance Data collection'        ,'fa-file-sql'                         ,'COREOBJ_SQL');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (150,'SQL List'          ,'Configuration: SQL white|black|known list','fa-clipboard-list'                   ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (160,'Memo'              ,'Memo attached to an object'               ,'fa-file-edit'                        ,'COREOBJ_MEMO');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (200,'SQL Trace'         ,'Application "SQl Trace" stored extended sql trace file and parsed representation'
                                                                                                                                                      ,'fa-database-clock'                    ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (300,'ASHA Cube'         ,'Application "ASHA" Cube data and diagrams','fa-cube'                             ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (400,'AWR Dump'          ,'Application "AWRWH" AWR stored dump'      ,'fa-database-play'                    ,'');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (500,'DB Growth Tracker' ,'Application "DB Growth Tracker" data'     ,'fa-combo-chart'                      ,'');


INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1000,         100,   'CREATE',     'Create Folder');

INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1300,         130,   'OPEN',       'Open DB Links assignments');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1300,         130,   'CREATE',     'Create DB Links assignments');

INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1101,         110,   'OPEN',       'Open attached file');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1102,         110,   'CREATE',     'Upload attached file');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1400,         140,   'CREATE',     'Register new SQL query');
INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1401,         140,   'OPEN',       'Show SQL Data');
--INSERT INTO opas_object_pages (ot_app_page, ot_id, ot_page_type, ot_page_descr) VALUES (1103,         110,   'EDIT',       'Edit attached file');



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


----
/*
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','SQLCACHERETENTION', 30,'Retention time in days for SQL Cache.');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','REPORT','LONGSECTROWS', 10000,'Custom reports long sections length in rows');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','REPORT','NARROWSECT',   700,  'Custom reports narrow section width, pixels');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','REPORT','MIDDLESECT',   1000, 'Custom reports middle section width, pixels');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','REPORT','WIDESECT',     1500, 'Custom reports wide section width, pixels');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','REPORT','SUPERWIDESECT',1800, 'Custom reports super wide section width, pixels');

INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXPIMP','EXPIMPDIR','&OPASEXPIMP_DIR.', 'Directory object for EXP/IMP operation');
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','EXPIMP','EXPIMPVER','12.2', 'Compatibility level for EXP/IMP dump');




		   
INSERT INTO 
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','CUST_AWRCOMP'           ,'AWR query plan compare report (custom)'   ,157,null,null,10);

INSERT INTO    
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','CUST_SQLMULTIPLAN'      ,'Analyze SQLs with multiple plans (custom)',158,null,null,20);
		   
INSERT INTO 
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','CUST_SQL_AWR_REPORT'    ,'AWR SQL report (custom)'                  ,151,null,null,10);
INSERT INTO 
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','CUST_SQL_MEM_REPORT'    ,'SQL memory report (custom)'               ,152,null,null,20);		   
INSERT INTO 
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','AWR_REPORT'             ,'AWR report (standard)'                    ,153,null,null,30);
INSERT INTO 
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','AWR_SQL_REPORT'         ,'AWR SQL report (standard)'                ,154,null,null,40);
INSERT INTO  
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','AWR_DIFF'               ,'AWR diff (standard)'                      ,155,null,null,50);
INSERT INTO     
  opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr)
           VALUES ('&MODNM.','REPORT_TYPES','ASH_REPORT'             ,'ASH report (standard)'                    ,156,null,null,60);

@@upgrade_data_1.3.7_1.3.8.sql
@@upgrade_data_1.3.9_1.3.10.sql

set define ~

declare
  l_script clob;
begin
  l_script := 
q'[
@../modules/core/scripts/opasawr.css
]';
  delete from opas_scripts where script_id='PROC_AWRCSS';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRCSS','~MODNM.',l_script);  
  
  l_script := 
q'^
@../modules/core/scripts/__prn_tbl_html.sql
^';
  delete from opas_scripts where script_id='PROC_PRNHTMLTBL';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_PRNHTMLTBL','~MODNM.',l_script);  
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_PRNHTMLTBL');
  
  l_script := 
q'^
@../modules/core/scripts/__getftxt.sql
^';
  delete from opas_scripts where script_id='PROC_GETGTXT';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_GETGTXT','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_GETGTXT');
  
  l_script := 
q'^
@../modules/core/scripts/__nonshared1.sql
^';
  delete from opas_scripts where script_id='PROC_NON_SHARED';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_NON_SHARED','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_NON_SHARED');

  l_script := 
q'^
@../modules/core/scripts/__vsql_stat.sql
^';
  delete from opas_scripts where script_id='PROC_VSQL_STAT';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_VSQL_STAT','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_VSQL_STAT');

  l_script := 
q'^
@../modules/core/scripts/__offload_percent1.sql
^';
  delete from opas_scripts where script_id='PROC_OFFLOAD_PCT1';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_OFFLOAD_PCT1','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_OFFLOAD_PCT1');
  
  l_script := 
q'^
@../modules/core/scripts/__offload_percent2.sql
^';
  delete from opas_scripts where script_id='PROC_OFFLOAD_PCT2';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_OFFLOAD_PCT2','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_OFFLOAD_PCT2');
  
  l_script := 
q'^
@../modules/core/scripts/__sqlmon1.sql
^';
  delete from opas_scripts where script_id='PROC_SQLMON';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_SQLMON','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_SQLMON');
  
  l_script := 
q'^
@../modules/core/scripts/__sqlwarea.sql
^';
  delete from opas_scripts where script_id='PROC_SQLWORKAREA';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_SQLWORKAREA','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_SQLWORKAREA');

  l_script := 
q'^
@../modules/core/scripts/__optenv.sql
^';
  delete from opas_scripts where script_id='PROC_OPTENV';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_OPTENV','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_OPTENV');
  
  l_script := 
q'^
@../modules/core/scripts/__rac_plans.sql
^';
  delete from opas_scripts where script_id='PROC_RACPLAN';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_RACPLAN','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_RACPLAN');
  
  l_script := 
q'^
@../modules/core/scripts/__sqlmon_hist.sql
^';
  delete from opas_scripts where script_id='PROC_SQLMON_HIST';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_SQLMON_HIST','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_SQLMON_HIST');
  
  l_script := 
q'[
@../modules/core/scripts/__ash_p3
]';
  delete from opas_scripts where script_id='PROC_AWRASHP3';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHP3','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHP3');

  l_script := 
q'[
@../modules/core/scripts/__ash_p3_1
]';
  delete from opas_scripts where script_id='PROC_AWRASHP3_1';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHP3_1','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHP3_1');
  
end;
/

declare
  l_script clob;
begin
  l_script :=
q'{
@../modules/core/scripts/__sqlstat.sql
}';
  delete from opas_scripts where script_id='PROC_AWRSQLSTAT';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRSQLSTAT','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRSQLSTAT');
  
  l_script := 
q'[
@../modules/core/scripts/__ash_summ
]';
  delete from opas_scripts where script_id='PROC_AWRASHSUMM';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHSUMM','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHSUMM');
  
  l_script := 
q'[
@../modules/core/scripts/__ash_p1
]';
  delete from opas_scripts where script_id='PROC_AWRASHP1';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHP1','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHP1');
  
  l_script := 
q'[
@../modules/core/scripts/__ash_p1_1
]';
  delete from opas_scripts where script_id='PROC_AWRASHP1_1';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHP1_1','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHP1_1');
  
  l_script := 
q'[
@../modules/core/scripts/__ash_p2
]';
  delete from opas_scripts where script_id='PROC_AWRASHP2';
  insert into opas_scripts (script_id,modname,script_content) values ('PROC_AWRASHP2','~MODNM.',l_script);
  COREMOD_REPORT_UTILS.prepare_saved_sql_script (  P_SCRIPT_NAME => 'PROC_AWRASHP2');
  
end;
/



set define &


*/

INSERT INTO opas_groups2apexusr ( group_id, modname, apex_user) VALUES ( 0, 'OPASCORE', upper('&namepref.')||'ADM');

commit;