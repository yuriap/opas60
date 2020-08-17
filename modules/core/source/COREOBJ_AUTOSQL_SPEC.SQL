

CREATE OR REPLACE
package coreobj_autosql is

  procedure execute_autosql(p_ags_id opas_ot_sql_auto_gather_sqls.ags_id%type);

  procedure edit_ags(p_ags_id     in out opas_ot_sql_auto_gather_sqls.ags_id%type,
                     p_dblink            opas_ot_sql_auto_gather_sqls.dblink%type,
                     p_filter_vsql       opas_ot_sql_auto_gather_sqls.filter_vsql%type,
                     p_filter_awrstat    opas_ot_sql_auto_gather_sqls.filter_awrstat%type,
                     p_filter_awrash     opas_ot_sql_auto_gather_sqls.filter_awrash%type,
                     p_row_limit         opas_ot_sql_auto_gather_sqls.row_limit%type,
                     p_time_limit        opas_ot_sql_auto_gather_sqls.time_limit%type,
                     p_sqltext_filter    opas_ot_sql_auto_gather_sqls.sqltext_filter%type,
                     p_description       opas_ot_sql_auto_gather_sqls.descr%type);

  procedure get_schedule  (p_ags_id       opas_ot_sql_auto_gather_sqls.ags_id%type,
                           p_schedule out opas_ot_sql_auto_gather_sqls.schedule%type);
  procedure drop_ags(p_ags_id       opas_ot_sql_auto_gather_sqls.ags_id%type);

end coreobj_autosql;
/


