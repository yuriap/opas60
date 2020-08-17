

CREATE OR REPLACE
package COREOBJ_DB_GROWTH is

--select rpad('  alrt'||upper(x.val),30,' ')||'constant varchar2(30) := '''||rpad(upper(x.val||''';'),20,' ')||' -- '||x.display_val from opas_dictionary x where dic_name='DBGALERT' order by dic_ordr;

  alrtSIZELIMIT               constant varchar2(30) := 'SIZELIMIT';          -- Total Size
  alrtDELTALIMIT              constant varchar2(30) := 'DELTALIMIT';         -- Total Delta Size
  alrtFREELIMIT               constant varchar2(30) := 'FREELIMIT';          -- Total Free Size
  alrtOUTOFSPACE              constant varchar2(30) := 'OUTOFSPACE';         -- Days to out of space
  alrtREGEXP                  constant varchar2(30) := 'REGEXP';             -- Regular Expression

  procedure init_dbg;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type);
  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N');
  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_dblink           opas_ot_dbg_monitor.dblink%type,
                   p_scheme_list      opas_ot_dbg_monitor.scheme_list%type,
                   p_size_limit       opas_ot_dbg_monitor.size_limit%type default null);
  procedure add_subpartition;

  procedure take_snapshot(p_obj_id       opas_objects.obj_id%type);
  procedure take_test_snapshot(p_obj_id       opas_objects.obj_id%type);

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

  procedure get_schedule  (p_obj_id       opas_objects.obj_id%type,
                           p_schedule out opas_ot_dbg_monitor.schedule%type);

  procedure add_alert_limit(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type,
                            p_dbg_id       opas_ot_dbg_monitor_al_cfg.dbg_id%type,
                            p_alert_name   opas_ot_dbg_monitor_al_cfg.alert_name%type,
                            p_alert_type   opas_ot_dbg_monitor_al_cfg.alert_type%type,
                            p_alert_expr   opas_ot_dbg_monitor_al_cfg.alert_expr%type,
                            p_alert_limit  opas_ot_dbg_monitor_al_cfg.alert_limit%type);

  procedure drop_alert_limit(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type);

  function calc_alert(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type) return number;

end COREOBJ_DB_GROWTH;
/


