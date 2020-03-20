CREATE OR REPLACE
package COREOBJ_DB_GROWTH_RPT is

  chrtMain                    constant number := 1;
  chrtLimit                   constant number := 2;
  chrtAlert                   constant number := 3;

  procedure prepare_chart_data(p_mode varchar2,
                               p_alert_queue_id  opas_alert_queue.alert_id%type,
                               p_alert_id in out opas_ot_dbg_monitor_al_cfg.alert_id%type,
                               p_dt_fmt          varchar2,
                               p_start_dt in out varchar2,
                               p_end_dt   in out varchar2,
                               p_chart_name  out varchar2,
                               p_chart_meas  out varchar2,
                               p_dbg_id      out opas_ot_dbg_monitor.dbg_id%type);

  procedure cleanup_chart_data;

  procedure setup_object_filter(p_dbg_id           number,
                                p_table_name_like  varchar2,
                                p_inverse          varchar2,
                                p_prnt_table       varchar2,
                                p_prnt_table_type  varchar2,
                                p_object_class     varchar2,
                                p_object_type      varchar2,
                                p_segment_type     varchar2,
                                p_object_name      varchar2,
                                p_subobject_name   varchar2,
                                p_tablespace_name  varchar2);

  procedure cleanup_object_filter;

end COREOBJ_DB_GROWTH_RPT;
/
