

CREATE OR REPLACE
PACKAGE COREOBJ_ASHA_CUBE_REPORTS AS

  psDefault                    constant varchar2(100) := 'Default';

  function get_main_diag_timeline_qry(p_wait_class varchar2) return varchar2;
  function get_main_diag_timeline_remainder_qry return varchar2;

  function get_main_diag_qry(p_wait_class varchar2) return varchar2;
  function get_main_diag_remainder_qry return varchar2;

  function get_event_summ_qry(p_filtered varchar2 default 'N') return varchar2;
  function get_main_diag_raw_data_qry(p_filtered varchar2 default 'Y') return varchar2;
  function get_main_diag_stats_qry return varchar2;

  function get_top_events_qry return varchar2;
  function get_top_modules_qry return varchar2;
  function get_top_segments_qry return varchar2;
  function get_top_sessions_qry return varchar2;

  function get_sql_timeline_qry(p_top_n number) return varchar2;

  function get_top_by_sql_id_qry(p_col varchar2) return varchar2;
  function get_sql_blocker_analyzer_qry return varchar2;

  function get_metric_qry(p_inst_id number, p_agg_item varchar2, p_metric_item varchar2) return varchar2;
  function get_metric_data_exists(p_inst_id number, p_agg_item varchar2, p_metric_item varchar2) return boolean;

  function data_exists(p_wait_class varchar2) return boolean;
  function get_number_of_time_points(p_obj_id opas_objects.obj_id%type) return number;

  procedure load_paramset(p_obj_id  opas_objects.obj_id%type);
  procedure store_paramset(p_obj_id  opas_objects.obj_id%type);

  procedure get_param(p_paramset   varchar2,
                      p_pname      varchar2,
                      p_value  out varchar2,
                      p_default    varchar2 default null);
  procedure set_param(p_paramset   varchar2,
                      p_pname      varchar2,
                      p_value      varchar2);
  function new_set(p_obj_id  opas_objects.obj_id%type,
                   p_old_paramset   varchar2,
                   p_new_paramset_name   varchar2)  return varchar2;
  procedure remove_set(p_obj_id  opas_objects.obj_id%type,
                       p_paramset_name in out varchar2);

END COREOBJ_ASHA_CUBE_REPORTS;
/


