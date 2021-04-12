

CREATE OR REPLACE
PACKAGE COREMOD_UTILS AS

  function lsttochr(p_list tableofnumbers) return varchar2;
  function bool2str(p_bool boolean) return varchar2;

  function get_remote_oracle_version(p_dblink opas_db_links.db_link_name%type) return number;
  function get_remote_full_oracle_version(p_dblink opas_db_links.db_link_name%type) return varchar2;
  function get_remote_ts(p_dblink opas_db_links.db_link_name%type) return timestamp with time zone;

  procedure get_clob_remotelly(p_sql varchar2, p_dblink varchar2, p_output out clob, p_timeout number default 600);
  procedure execute_plsql_remotelly(p_sql varchar2, p_dblink varchar2, p_output out clob, p_is_output boolean default true, p_timeout number default 600);

END COREMOD_UTILS;
/


