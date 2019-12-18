@opas60dev
set timing off
define COREMODPATH="..\modules\core\source\"

rem "

set heading off
set feedback off
set termout OFF
set trimspool on
set lines 5000
set pages 0
set echo off
set verify off

spool _tmp_get_src.sql
select 
'spool &COREMODPATH.'||object_name||'_SPEC.SQL'||chr(10)||
'prompt CREATE OR REPLACE '||chr(10)||
q'[select text from user_source where name=']'||object_name||q'[' and type='PACKAGE' order by line;]'||chr(10)||
'prompt /'||chr(10)||'spool off'||chr(10)||
'spool &COREMODPATH.'||object_name||'_BODY.SQL'||chr(10)||
'prompt CREATE OR REPLACE '||chr(10)||
q'[select text from user_source where name=']'||object_name||q'[' and type='PACKAGE BODY' order by line;]'||chr(10)||
'prompt /'||chr(10)||'spool off'
from user_objects 
where object_type like 'PACKAGE' 
and object_name like 'CORE%'
order by object_name, object_type;

spool off

@_tmp_get_src.sql

spool &COREMODPATH.\create_stored.sql

select 
'@@'||object_name||'_SPEC.SQL'||chr(10)||'show errors'||chr(10)
from user_objects 
where object_type like 'PACKAGE' 
and object_name like 'CORE%'
order by object_name, object_type;

select 
'@@'||object_name||'_BODY.SQL'||chr(10)||'show errors'||chr(10)
from user_objects 
where object_type like 'PACKAGE BODY' 
and object_name like 'CORE%'
order by object_name, object_type;

spool off

--=============================================================================================
--=============================================================================================
--=============================================================================================

define COREMODPATH="..\modules\sql_trace\source\"

rem "


--=============================================================================================
--=============================================================================================
--=============================================================================================

define COREMODPATH="..\modules\ash_analyzer\source\"

rem "


--=============================================================================================
--=============================================================================================
--=============================================================================================

define COREMODPATH="..\modules\awr_warehouse\source\"

rem "


--=============================================================================================
--=============================================================================================
--=============================================================================================

define COREMODPATH="..\modules\db_growth\source\"

rem "


--=============================================================================================
--=============================================================================================
--=============================================================================================