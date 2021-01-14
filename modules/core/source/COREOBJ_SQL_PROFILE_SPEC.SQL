

CREATE OR REPLACE
PACKAGE COREOBJ_SQL_PROFILE AS

  tpSQLProfile constant number := 1;
  tpSQLPatch   constant number := 2;

  function get_binary_sql_text(p_file_id opas_files.file_id%type) return clob;

  function prepare_sql_profile_patch(p_sql_id         opas_ot_sql_descriptions.sql_id%type,
                                     p_type           number,
                                     p_hint           varchar2) return opas_files.file_id%type;

  function bulk_create_sql_profile(p_src_qry         varchar2, -- select sql_text from some_table
                                   p_hint            varchar2)
                                   return opas_files.file_id%type;

END COREOBJ_SQL_PROFILE;
/


