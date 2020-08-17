

CREATE OR REPLACE
PACKAGE COREOBJ_DB_MONITOR AS

  procedure execute_simple_metric(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type);

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type);
  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N');

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_dblink           OPAS_OT_DB_MONITOR.dblink%type,
                   p_call_type        OPAS_OT_DB_MONITOR.call_type%type,
                   p_calc_code        OPAS_OT_DB_MONITOR.calc_code%type,
                   p_convert_code     OPAS_OT_DB_MONITOR.convert_code%type,
                   p_measure          OPAS_OT_DB_MONITOR.measure%type);

  procedure get_schedule  (p_obj_id   opas_objects.obj_id%type,
                           p_schedule out OPAS_OT_DB_MONITOR.schedule%type);

  function test_metric(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type) return number;

  function get_object_status_to_display (p_obj_id opas_objects.obj_id%type) return varchar2;

  procedure add_alert_limit(p_metric_id   opas_ot_db_monitor_alerts_cfg.metric_id%type,
                            p_alert_type  opas_ot_db_monitor_alerts_cfg.alert_type%type,
                            p_alert_limit  opas_ot_db_monitor_alerts_cfg.alert_limit%type);
  procedure drop_alert_limit(p_metric_id   opas_ot_db_monitor_alerts_cfg.metric_id%type/*,
                             p_alert_type  opas_ot_db_monitor_alerts_cfg.alert_type%type*/);

  procedure cleanup_chart_data;
  procedure prepare_charts_data(p_chart_list      varchar2,
                                p_dt_fmt          varchar2,
                                p_start_dt in out varchar2,
                                p_end_dt   in out varchar2);

  procedure save_dachboard_conf(p_graph_num       opas_ot_db_dashboard_graphs.graph_num%type,
                                p_chart_list      varchar2,
                                p_data_interv     opas_ot_db_dashboard.data_interv%type,
                                p_refresh_int     opas_ot_db_dashboard.refresh_int%type);
  procedure init_dashboard_data(p_dt_fmt           varchar2,
                                p_start_dt  in out varchar2,
                                p_end_dt    in out varchar2,
                                p_page_refresh out number);

END COREOBJ_DB_MONITOR;
/


