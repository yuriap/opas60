

CREATE OR REPLACE
PACKAGE COREOBJ_SQL_FORECAST AS

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_descr            opas_objects.obj_descr%type default null);

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N');

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

  procedure add_history_record(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                               p_table_name       OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type,
                               p_folders          varchar2);

  procedure calc_tab_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                          p_table_name       OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type,
                          p_dblink opas_db_links.db_link_name%type);

  procedure calc_attr_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                           p_attr             OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type);

  procedure add_all_tabs_to_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type);
  procedure add_all_tabs_from_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type);

END COREOBJ_SQL_FORECAST;
/


