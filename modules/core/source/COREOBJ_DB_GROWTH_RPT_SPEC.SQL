

CREATE OR REPLACE
package COREOBJ_DB_GROWTH_RPT is

  chrtMain                    constant number := 1;
  chrtLimit                   constant number := 2;
  chrtAlert                   constant number := 3;

  chrtOccupied                constant number := 4;
  chrtAvailable               constant number := 5;
  chrtOccuProjection          constant number := 6;
  chrtAvailProjection         constant number := 7;

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
                                p_tablespace_name  varchar2,
                                p_start_snap       number,
                                p_end_snap         number);

  procedure prepare_out_of_space_data(p_dbg_id           opas_ot_dbg_monitor.dbg_id%type,
                                      p_days_to_avg      number default null,
                                      p_start_dp         opas_ot_dbg_datapoint.dbgdp_id%type default null,
                                      p_end_dp           opas_ot_dbg_datapoint.dbgdp_id%type default null,
                                      p_tablespace       varchar2,
                                      p_avg_delta    out number,
                                      p_out_of_space out timestamp);

end COREOBJ_DB_GROWTH_RPT;
/


