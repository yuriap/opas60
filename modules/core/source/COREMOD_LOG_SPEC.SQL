

CREATE OR REPLACE
package COREMOD_LOG is
  -- INFO
  -- DEBUG
  procedure log(p_msg clob, p_loglevel varchar2 default 'INFO', p_module varchar2 default 'DEFAULT');
  procedure log(p_msg varchar2, p_loglevel varchar2 default 'INFO', p_module varchar2 default 'DEFAULT');

  procedure cleanup_logs;

  procedure Start_SQL_GATHER_STAT(p_name varchar2);
  procedure Stop_SQL_GATHER_STAT(p_name varchar2);

  procedure Start_SQL_TRACE(p_name varchar2);
  procedure Stop_SQL_TRACE(p_name varchar2);

  procedure debug_on;
  procedure debug_off;
end;
/


