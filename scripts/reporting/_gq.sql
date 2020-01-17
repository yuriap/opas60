@opas60dev

set timing off
set feedback off

define DBLINK=&1
define PRNT=&2
define SQL_ID=&3
define CD=&4
define GATHERNEW=&5

variable OBJ_ID number
variable DIRNAME varchar2(1000)

begin
  COREOBJ_SQL_UTILS.getdatacmd (  
    P_OBJ_ID      => :OBJ_ID,
    P_OBJ_PRNT    => &PRNT.,
    P_SQL_ID      => '&SQL_ID.',
    P_DB_LINK     => '&DBLINK.',
    P_CURRENT_DIR => '&CD.',
	p_gather_new  => case when '&GATHERNEW'='NEW' then true else false end,
    P_DIRNAME     => :DIRNAME) ; 	  
end;
/

commit;

column REPORT format a160
select 
  case 
    when :OBJ_ID > 0 and '&GATHERNEW'='NEW' then 'Data point object id: '||:OBJ_ID||' in directory: '||:DIRNAME||' has been created.'
	when '&GATHERNEW'='EXISTING'            then 'Data point object id: '||:OBJ_ID||' in directory: '||:DIRNAME||' is read for report.'
    else 'N/A'
  end
 REPORT 
from dual;

column status format a160
set arraysize 1
select column_value STATUS from table(COREOBJ_SQL_REPORT_UTILS.gathering_status(:OBJ_ID)) where '&GATHERNEW'='NEW';

set trimspool on
set feedback off
set heading off
set lines 4000
set pages 0
set termout off

spool opas60_sqldp_&SQL_ID..html
select column_value from table(COREOBJ_SQL_REPORT_UTILS.print_report_html(:OBJ_ID));
spool off

exit