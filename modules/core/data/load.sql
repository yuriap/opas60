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

--new
INSERT INTO opas_config (modname,cgroup,ckey,cvalue,descr) VALUES ('&MODNM.','RETENTION','SQLSEARCHRETENTION', 60,'Retention time in minutes for SQL Searches.');

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
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (500,'DB Growth Monitor' ,'Application "DB Growth Monitor" data'     ,'fa-combo-chart'                      ,'COREOBJ_DB_GROWTH');
insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (600,'Simple DB Monitor' ,'Simple Database monitor to measure scalar metric' ,'fa-eyedropper'               ,'COREOBJ_DB_MONITOR');

insert into OPAS_OBJECT_TYPES (OT_ID,OT_NAME,OT_DESCR,OT_ICON, OT_API_PKG) values (700,'SQL Catcher'       ,'SQL Catcher to automatically collect SQL data' ,'fa-indent'                    ,'COREOBJ_SQL_CATCHER');


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

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','SDBMALERT', 'SINGLELIMIT'               ,'Single value limit'   ,null,null,null,10);

INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'SIZELIMIT'                 ,'Total Size'           ,'bytes',null,null,10);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'DELTALIMIT'                ,'Total Delta Size'     ,'bytes',null,null,20);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'FREELIMIT'                 ,'Total Free Size'      ,'bytes',null,null,30);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'OUTOFSPACE'                ,'Days to out of space' ,'dates',null,null,40);
INSERT INTO opas_dictionary (modname,dic_name,val,display_val,sparse1,sparse2,sparse3,dic_ordr) VALUES ('&MODNM.','DBGALERT',  'REGEXP'                    ,'Regular Expression'   ,'bytes',null,null,50);


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
INSERT INTO opas_groups2apexusr ( group_id, modname, apex_user) VALUES ( 0, 'OPASCORE', 'OPAS60ADM');

commit;