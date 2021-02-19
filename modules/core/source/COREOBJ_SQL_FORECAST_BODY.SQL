

CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_FORECAST AS

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_descr            opas_objects.obj_descr%type default null) AS
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otSQL_FORECAST_REPORT,
      P_OBJ_NAME  => 'Forecast report '||to_char(sysdate,'YYYYMMDD'),
      P_OBJ_DESCR => p_descr,
      p_obj_owner => p_owner) ;
  END add;

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N') AS
  BEGIN
    COREOBJ_API.remove(p_obj_id, p_cascade);
  END remove;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2 AS
  BEGIN
    -- TODO: Implementation required for function COREOBJ_SQL_FORECAST.get_object_status_to_display
    RETURN NULL;
  END get_object_status_to_display;

  procedure add_history_record(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                               p_table_name       OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type,
                               p_folders          varchar2)
  is
  begin
    delete from opas_ot_sql_forecast_report where obj_id = p_obj_id and table_name = p_table_name;
    for i in (select column_value folder_id from table(coreobj_sql_tags.parse_tag_list(p_folders))) loop
      INSERT INTO opas_ot_sql_forecast_report
                (obj_id, table_name, folder_id)
         VALUES (p_obj_id, p_table_name, i.folder_id);
    end loop;
  end;



  procedure calc_tab_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                          p_table_name       OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type,
                          p_dblink opas_db_links.db_link_name%type)
  is
    l_sql varchar2(10000);
    l_cnt number;
  begin
    l_sql := q'[select /*+ full(a) */ count(1) from <TABNAME>]' || COREMOD_API.get_dblink_for_query(p_dblink) || q'[ a]';

    execute immediate replace(l_sql,'<TABNAME>',p_table_name) into l_cnt;

    merge into OPAS_OT_SQL_FORECAST_STAT t
    using (select p_obj_id obj_id, p_table_name TABLE_NAME, l_cnt NUM_ROWS from dual) s
    on (t.OBJ_ID = s.OBJ_ID and t.TABLE_NAME = s.TABLE_NAME)
    when matched then update set t.NUM_ROWS = s.NUM_ROWS
    when not matched then INSERT (obj_id,table_name,num_rows) VALUES (s.obj_id,s.table_name,s.num_rows);
  end;

  procedure calc_attr_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type,
                           p_attr             OPAS_OT_SQL_FORECAST_REPORT.TABLE_NAME%type)
  is
    l_attr varchar2(100) := ltrim(ltrim(ltrim(p_attr,'P_'),'R_'),'O_');
  begin
    merge into OPAS_OT_SQL_FORECAST_STAT t
    using (select p_obj_id obj_id, p_attr TABLE_NAME, NUM_ROWS from (select first_value(quantity)over(order by ts desc) NUM_ROWS from OBJECT_MODEL_STAT x where attr_id=l_attr) where rownum=1) s
    on (t.OBJ_ID = s.OBJ_ID and t.TABLE_NAME = s.TABLE_NAME)
    when matched then update set t.NUM_ROWS = s.NUM_ROWS
    when not matched then INSERT (obj_id,table_name,num_rows) VALUES (s.obj_id,s.table_name,s.num_rows);
  end;

  procedure add_all_tabs_to_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type)
  is
  begin
    for i in (with including_tags as
      (select tag_name, table_name, tag_description, (select tag_description from OPAS_OT_SQL_TAGS p where o.tag_prnt = p.tag_name ) tag_category, tag_prnt
         from OPAS_OT_SQL_TAGS o
        start with tag_name in (select column_value from table(coreobj_sql_tags.parse_tag_list('MAPPING'))) connect by prior tag_name = tag_prnt),
      including_sqls as
        (select /* materialize */ sql_id, tag_name, tag_description, table_name, tag_category, tag_prnt
           from OPAS_OT_SQL_SQL2TAGS, including_tags
          where tag=tag_name)
      select /*+ use_nl(ss1) use_nl(mon1) use_nl(awr1)*/
             unique tags.table_name
      from opas_objects o,
           opas_ot_sql_data_point_ref r,
           OPAS_OT_SQL_DATA sd,
           opas_ot_sql_descriptions d,
           including_sqls tags
      where o.obj_prnt = p_obj_id
      and o.obj_ot=140
      and o.obj_id=r.obj_id
      and r.sql_data_point_id = sd.sql_data_point_id
      and sd.sql_id = d.sql_id
      and d.sql_id = tags.sql_id
      and tags.table_name is not null)
    loop
      merge into OPAS_OT_SQL_FORECAST_STAT t
      using (select p_obj_id obj_id, i.table_name TABLE_NAME, null NUM_ROWS, sysdate GATHERED from dual) s
      on (t.OBJ_ID = s.OBJ_ID and t.TABLE_NAME = s.TABLE_NAME)
      when not matched then INSERT (obj_id,table_name,num_rows,GATHERED) VALUES (s.obj_id,s.table_name,s.num_rows,s.GATHERED);
    end loop;
  end;

  procedure add_all_tabs_from_stat(p_obj_id           OPAS_OT_SQL_FORECAST_REPORT.obj_id%type)
  is
  begin
      merge into OPAS_OT_SQL_FORECAST_REPORT t
      using (select obj_id, TABLE_NAME from OPAS_OT_SQL_FORECAST_STAT where obj_id = p_obj_id) s
      on (t.OBJ_ID = s.OBJ_ID and t.TABLE_NAME = s.TABLE_NAME)
      when not matched then INSERT (obj_id,table_name) VALUES (s.obj_id,s.table_name);
  end;

  procedure create_forecast_on_catcher(p_obj_id       out opas_objects.obj_id%type,
                                       p_catcher_id       opas_objects.obj_id%type)
  is
    l_prnt opas_objects.obj_prnt%type;
    l_nm   opas_objects.OBJ_NAME%type;
  begin
    select obj_prnt, OBJ_NAME into l_prnt, l_nm from opas_objects where obj_id = p_catcher_id;

    COREOBJ_SQL_FORECAST.add_all_tabs_to_stat (  P_OBJ_ID => p_catcher_id) ;

    COREOBJ_SQL_FORECAST.add (  P_OBJ_ID => create_forecast_on_catcher.P_OBJ_ID,
      P_OBJ_PRNT => l_prnt,
      --P_MODNAME => P_MODNAME,
      --P_OWNER => P_OWNER,
      P_DESCR => 'Based on "'||l_nm||'"') ;

    INSERT INTO opas_ot_sql_forecast_stat ( obj_id, table_name, num_rows, growth_coeff, GATHERED)
    select create_forecast_on_catcher.P_OBJ_ID obj_id, table_name, num_rows, growth_coeff, nvl(GATHERED, sysdate) GATHERED from opas_ot_sql_forecast_stat
    where obj_id = p_catcher_id;

    COREOBJ_SQL_FORECAST.add_all_tabs_from_stat(create_forecast_on_catcher.P_OBJ_ID);

    update opas_ot_sql_forecast_report set folder_id=p_catcher_id where obj_id=create_forecast_on_catcher.P_OBJ_ID;
  end;

END COREOBJ_SQL_FORECAST;
/


