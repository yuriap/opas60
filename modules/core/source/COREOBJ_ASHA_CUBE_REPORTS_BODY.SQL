

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_REPORTS AS

  g_LogLevel varchar2(10):='INFO';

--  gFiltereTimeLine varchar2(32765) := q'[
--flt_timeline as (select min(pnt) mi_pnt, max(pnt) ma_pnt, min(tim) mi_tim, max(tim) ma_tim from timeline t where t.pnt between <STARTPOINT> and <ENDPOINT>)]';

  g_CUBE_ID    varchar2(30) := 'P3003_CUBE_ID';
  g_GRPBY      varchar2(30) := 'P3003_GRPBY';
  g_WAITCLASS  varchar2(30) := 'WAITCLASS';
  g_INST_ID    varchar2(30) := 'INST_ID';
  g_STARTPOINT varchar2(30) := 'P3003_LEFT_MARGIN';
  g_ENDPOINT   varchar2(30) := 'P3003_RIGHT_MARGIN';
  g_FILTER     varchar2(30) := 'P3003_FILTER';
  g_INCLUDING_TAGS     varchar2(30) := 'P3003_INCLUDING_TAGS';
  g_EXCLUDING_TAGS     varchar2(30) := 'P3003_EXCLUDING_TAGS';
  g_DBLINK     varchar2(30) := 'P3003_DBLINK';
  g_METRIC1    varchar2(30) := 'P3003_METRIC1';
  g_METRIC2    varchar2(30) := 'P3003_METRIC2';
  g_METRIC3    varchar2(30) := 'P3003_METRIC3';
  g_AGG1       varchar2(30) := 'P3003_AGG1';
  g_AGG2       varchar2(30) := 'P3003_AGG2';
  g_AGG3       varchar2(30) := 'P3003_AGG3';
  g_WAIT_CLASSES       varchar2(30) := 'P3003_WAIT_CLASSES';
  g_DBG        varchar2(30) := 'P3003_DEF_DBG_PROJ';

  gParams COREOBJ_API.t_params;

  type t_param_tbl is table of varchar2(4000) index by varchar2(256);
  type t_param_rec is record (
    set_name varchar2(512),
    params   t_param_tbl);
  type t_ParamsSet is table of t_param_rec index by varchar2(256);
  gParamsSet t_ParamsSet;

  procedure set_param(p_name varchar2, p_value varchar2)
  is
  begin
    gParams(p_name) := p_value;
  end;

  function get_param(p_name varchar2) return varchar2
  is
  begin
    if gParams.exists(p_name) then
      return gParams(p_name);
    else
      return null;
    end if;
  end;

  procedure log(p_msg varchar2)
  is
  begin
      COREMOD_LOG.log (p_msg, P_LOGLEVEL => g_LogLevel, P_MODULE => 'ASHACUBECALC') ;
  end;

  procedure load_paramset(p_obj_id  opas_objects.obj_id%type)
  is
    l_empty boolean := true;
  begin
    gParamsSet.delete;
    for i in (
      select params.*
        from OPAS_OBJECT_PARS x,
             json_table(jsparams, '$.savedparams[*]' COLUMNS (set_id PATH '$.set_id',
                                                              set_name PATH '$.set_name',
                                                              NESTED PATH '$.params[*]' COLUMNS (par_name PATH '$.par_name',
                                                                                                 par_value PATH '$.par_value'
                                                                                                )
                                                             )
                       ) params
      where obj_id=p_obj_id and x.par_name='ASHACUBE_FLTPARAMSET'
    )
    loop
      gParamsSet(i.set_id).set_name := i.set_name;
      gParamsSet(i.set_id).params(i.par_name) := i.par_value;
      l_empty := false;
    end loop;

    if l_empty then
      gParamsSet(psDefault).set_name := psDefault;
      gParamsSet(psDefault).params(g_GRPBY) := 'MI';
    end if;
  end;

  procedure store_paramset(p_obj_id  opas_objects.obj_id%type)
  is
    l_setid varchar2(256);
    l_param_name varchar2(256);
  begin

    if gParamsSet.count>0 then
      l_setid := gParamsSet.first;

      APEX_JSON.initialize_clob_output;
      APEX_JSON.open_object;
      APEX_JSON.open_array('savedparams');
      loop
        APEX_JSON.open_object;
        APEX_JSON.write('set_id',  l_setid);
        APEX_JSON.write('set_name', case when l_setid = psDefault then l_setid else gParamsSet(l_setid).set_name end);
          ---------------------------------
          if gParamsSet(l_setid).params.count>0 then
            l_param_name := gParamsSet(l_setid).params.first;
            APEX_JSON.open_array('params');
            loop
              APEX_JSON.open_object;
              APEX_JSON.write('par_name',  l_param_name);
              APEX_JSON.write('par_value', gParamsSet(l_setid).params(l_param_name));
              APEX_JSON.close_object;
              l_param_name := gParamsSet(l_setid).params.next(l_param_name);
              exit when l_param_name is null;
            end loop;
            APEX_JSON.close_array;
          end if;
          ---------------------------------
        APEX_JSON.close_object;
        l_setid := gParamsSet.next(l_setid);
        exit when l_setid is null;
      end loop;

      APEX_JSON.close_array;
      APEX_JSON.close_object;

      COREOBJ_API.set_jparam(p_obj_id => p_obj_id,
                             p_pname =>  'ASHACUBE_FLTPARAMSET',
                             p_json =>   APEX_JSON.get_clob_output);

      APEX_JSON.free_output;
    end if;
  end;

  procedure get_param(p_paramset   varchar2,
                      p_pname      varchar2,
                      p_value  out varchar2,
                      p_default    varchar2 default null)
  is
  begin
    if COREOBJ_ASHA_CUBE_REPORTS.gParamsSet.exists(p_paramset) and COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(p_paramset).params.exists(p_pname) then
      p_value := nvl(COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(p_paramset).params(p_pname),p_default);
    else
      p_value := p_default;
    end if;
  end;

  procedure set_param(p_paramset   varchar2,
                      p_pname      varchar2,
                      p_value      varchar2)
  is
  begin
    COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(p_paramset).params(p_pname) := p_value;
  end;

  function new_set(p_obj_id  opas_objects.obj_id%type,
                   p_old_paramset    varchar2,
                   p_new_paramset_name   varchar2)  return varchar2
  is
    l_id varchar2(256);
    l_par_name varchar2(256);
  begin
    load_paramset(p_obj_id);
    l_id := SYS_GUID();
    COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(l_id).set_name := p_new_paramset_name;
    COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(l_id).params := COREOBJ_ASHA_CUBE_REPORTS.gParamsSet(p_old_paramset).params;
    store_paramset(p_obj_id);
    return l_id;
  end;

  procedure remove_set(p_obj_id  opas_objects.obj_id%type,
                       p_paramset_name  in out varchar2)
  is
  begin
    load_paramset(p_obj_id);
    gParamsSet.delete(p_paramset_name);
    store_paramset(p_obj_id);
    p_paramset_name := gParamsSet.first;
  end;

  function get_base_query(p_include_tags number default 1,
                          p_include_metrics number default 0,
                          p_include_stats number default 0) return varchar2
  is
    l_tag_include_query varchar2(32765) := q'[
including_sqls as
  (select /*+ materialize */ sql_id
     from OPAS_OT_SQL_SQL2TAGS,
         (select tag_name from OPAS_OT_SQL_TAGS start with tag_name in (select /*+ cardinality(x 1) */ column_value from table(coreobj_sql_tags.parse_tag_list(:P3003_INCLUDING_TAGS)) x )
         connect by prior tag_name = tag_prnt)including_tags
    where tag=tag_name)]';
    l_tag_exclude_query varchar2(32765) := q'[
excluding_sqls as
  (select /*+ materialize */ sql_id
     from OPAS_OT_SQL_SQL2TAGS,
         (select tag_name from OPAS_OT_SQL_TAGS start with tag_name in (select /*+ cardinality(x 1) */ column_value from table(coreobj_sql_tags.parse_tag_list(:P3003_EXCLUDING_TAGS)) x )
         connect by prior tag_name = tag_prnt) excluding_tags
    where tag=tag_name)]';
    l_main_queries varchar2(32765) := q'[
rng_dt as   (SELECT /*+ gather_plan_statistics */ min(rng.start_time_utc) start_dt, max(rng.end_time_utc) end_dt
               FROM opas_ot_ashacube_ref refs INNER JOIN opas_ot_ashacube_ranges rng ON refs.asharange_id = rng.asharange_id
              where refs.ashacube_id = :P3003_CUBE_ID),
rng_ids as  (SELECT rng.asharange_id, rng.start_time_utc, rng.end_time_utc
               FROM opas_ot_ashacube_ref refs INNER JOIN opas_ot_ashacube_ranges rng ON refs.asharange_id = rng.asharange_id
              where refs.ashacube_id = :P3003_CUBE_ID),
timeline as (select rownum pnt, trunc(start_dt + (level - 1) * <TIMEXPR>, '<TRUNC>') tim
               from rng_dt connect by start_dt + (level - 1) * <TIMEXPR> <= end_dt),
flt_timeline as (select min(pnt) mi_pnt, max(pnt) ma_pnt, min(tim) mi_tim, max(tim) ma_tim from timeline t where t.pnt between <STARTPOINT> and <ENDPOINT>),
stats_unranged as
            (select /*+ full(c) */ c.*, case when SAMPLE_TP = 'A' then 10 else 1 end tp_time
               from OPAS_OT_ASHACUBE_ASH c, rng_ids
              where c.asharange_id = rng_ids.asharange_id
                and c.SAMPLE_TIME_UTC between rng_ids.start_time_utc and rng_ids.end_time_utc
                and DBLINK = :P3003_DBLINK),
stats_ranged as
            (select /*+ full(c) */ /* use_nl(c) */ c.*, case when SAMPLE_TP = 'A' then 10 else 1 end tp_time
               from OPAS_OT_ASHACUBE_ASH c, rng_ids, flt_timeline  ft
              where c.asharange_id = rng_ids.asharange_id and c.SAMPLE_TIME_UTC between ft.mi_tim and ft.ma_tim and DBLINK = :P3003_DBLINK)]';
l_metrics_queries varchar2(32765) := q'[
metrics_ranged as
            (select /*+ use_nl(c) */ c.*, <METRICT_AGG>(value)over() whole_agg
               from OPAS_OT_ASHACUBE_METRICS c, rng_ids, flt_timeline  ft
              where c.asharange_id = rng_ids.asharange_id and c.END_TIME_UTC between ft.mi_tim and ft.ma_tim and DBLINK = :P3003_DBLINK and INST_ID=<INST_ID>)]';
l_stats_queries varchar2(32765) := q'[
stat_ranged as
            (select /*+ use_nl(c) */ c.TS_UTC, c.INST_ID, c.SID, n.display_name, c.VALUE
               from OPAS_OT_ASHACUBE_STATS c, rng_ids, flt_timeline  ft, OPAS_DB_STATISTICS n
              where c.statistic# = n.statistic# and c.asharange_id = rng_ids.asharange_id and c.TS_UTC between ft.mi_tim and ft.ma_tim
                and c.DBLINK = :P3003_DBLINK and c.INST_ID=<INST_ID>
                and n.DBLINK = :P3003_DBLINK)]';
  begin
    if p_include_tags = 1 and (nvl(get_param(g_INCLUDING_TAGS),'NOTAG') != 'NOTAG' or nvl(get_param(g_EXCLUDING_TAGS),'NOTAG') != 'NOTAG') then
      if nvl(get_param(g_INCLUDING_TAGS),'NOTAG') != 'NOTAG' then
        l_main_queries := l_tag_include_query || ',' || l_main_queries;
      end if;
      if nvl(get_param(g_EXCLUDING_TAGS),'NOTAG') != 'NOTAG' then
        l_main_queries := l_tag_exclude_query || ',' || l_main_queries;
      end if;
    end if;
    if p_include_metrics = 1 then
      l_main_queries := l_main_queries || ',' || l_metrics_queries;
    end if;
    if p_include_stats = 1 then
      l_main_queries := l_main_queries || ',' || l_stats_queries;
    end if;
    return q'[with ]' || l_main_queries;
  end;

  procedure preprocess_qry(p_query in out varchar2)
  is
    l_flt varchar2(32765);
  begin
    case
      when upper(get_param(g_GRPBY)) = 'MI' then
        p_query := replace(replace(p_query,'<TRUNC>', get_param(g_GRPBY)), '<TIMEXPR>', '1/24/60');
      when upper(get_param(g_GRPBY)) = 'HH' then
        p_query := replace(replace(p_query,'<TRUNC>', get_param(g_GRPBY)), '<TIMEXPR>', '1/24');
      when upper(get_param(g_GRPBY)) = 'DD' then
        p_query := replace(replace(p_query,'<TRUNC>', get_param(g_GRPBY)), '<TIMEXPR>', '1');
    else
      p_query := replace(replace(p_query,'<TRUNC>', 'MI'), '<TIMEXPR>', '1/24/60');
    end case;

    case
      when upper(get_param(g_WAITCLASS)) = 'CPU' then
        p_query := replace(p_query,'<WAITCLASS>', q'[(wait_class is null or wait_class='CPU')]');
    else
      p_query := replace(p_query,'<WAITCLASS>', q'[wait_class = ']'||nvl(get_param(g_WAITCLASS),'Application')||q'[']');
    end case;

    if get_param(g_FILTER) is not null or nvl(get_param(g_INCLUDING_TAGS),'NOTAG') != 'NOTAG' or nvl(get_param(g_EXCLUDING_TAGS),'NOTAG') != 'NOTAG' then
      if get_param(g_FILTER) is not null then
        l_flt := '(' || get_param(g_FILTER) || ') and';
      end if;
      if nvl(get_param(g_INCLUDING_TAGS),'NOTAG') != 'NOTAG' then
        l_flt := l_flt || '  sql_id in (select sql_id from including_sqls) and';
      end if;
      if nvl(get_param(g_EXCLUDING_TAGS),'NOTAG') != 'NOTAG' then
        l_flt := l_flt || '  sql_id not in (select sql_id from excluding_sqls)';
      end if;
      p_query := replace(p_query,'<FILTER>', rtrim(l_flt,' and'));
    else
      p_query := replace(p_query,'<FILTER>', q'[ 1=1 ]');
    end if;

    p_query := replace(replace(p_query,'<STARTPOINT>',nvl(get_param(g_STARTPOINT),'1')),'<ENDPOINT>',nvl(get_param(g_ENDPOINT),'0'));
    p_query := replace(p_query,'<INST_ID>',nvl(get_param(g_INST_ID),'1'));

  end;

  procedure read_item_parameters
  is
  begin
    set_param(g_GRPBY, v(g_GRPBY));
    set_param(g_CUBE_ID, v(g_CUBE_ID));
    set_param(g_STARTPOINT, v(g_STARTPOINT));
    set_param(g_ENDPOINT, v(g_ENDPOINT));
    set_param(g_FILTER, v(g_FILTER));
    set_param(g_INCLUDING_TAGS, v(g_INCLUDING_TAGS));
    set_param(g_EXCLUDING_TAGS, v(g_EXCLUDING_TAGS));
    set_param(g_DBLINK, v(g_DBLINK));
    set_param(g_METRIC1, v(g_METRIC1));
    set_param(g_METRIC2, v(g_METRIC2));
    set_param(g_METRIC3, v(g_METRIC3));
    set_param(g_AGG1, v(g_AGG1));
    set_param(g_AGG2, v(g_AGG2));
    set_param(g_AGG3, v(g_AGG3));
    set_param(g_WAIT_CLASSES, v(g_WAIT_CLASSES));
    set_param(g_DBG, v(g_DBG));
  end;

  function data_exists(p_wait_class varchar2) return boolean is
    l_sql varchar2(32765);
    l_result number;
  begin
    set_param(g_WAITCLASS, p_wait_class);
    read_item_parameters;

    l_sql := get_base_query(p_include_tags => 0) ||
      q'[ select /*+ qb_name(data_exists) */ count(1)
            from dual
           where exists (select 1
                           from OPAS_OT_ASHACUBE_ASH_WCS c, rng_ids, flt_timeline t
                          where c.asharange_id = rng_ids.asharange_id and <WAITCLASS>
                            and (t.mi_tim between rng_ids.start_time_utc and rng_ids.end_time_utc
                              or t.ma_tim between rng_ids.start_time_utc and rng_ids.end_time_utc))]';

    preprocess_qry(l_sql);
    --log(l_sql);
    --log(get_param(g_CUBE_ID));
    execute immediate l_sql into l_result using to_number(get_param(g_CUBE_ID)), to_number(get_param(g_CUBE_ID)), get_param(g_DBLINK), get_param(g_DBLINK);
    return l_result>0;
  exception
    when others then raise_application_error(-20000, l_sql||chr(10)||sqlerrm);
  end;

  function get_wait_class_list_qry return varchar2 is
    l_sql varchar2(32765);
    l_result number;
  begin

    read_item_parameters;

    l_sql := get_base_query(p_include_tags => 0) ||
      q'[ select /*+ qb_name(wait_class_list_qry) */ unique WAIT_CLASS d, WAIT_CLASS r
                           from OPAS_OT_ASHACUBE_ASH_WCS c, rng_ids, flt_timeline t
                          where c.asharange_id = rng_ids.asharange_id
                            and (t.mi_tim between rng_ids.start_time_utc and rng_ids.end_time_utc
                              or t.ma_tim between rng_ids.start_time_utc and rng_ids.end_time_utc)]';

    preprocess_qry(l_sql);
    --log(l_sql);
    return l_sql;
  exception
    when others then raise_application_error(-20000, l_sql||chr(10)||sqlerrm);
  end;

  function get_number_of_time_points(p_obj_id opas_objects.obj_id%type) return number
  is
    l_sql varchar2(32765);
    l_result number;
  begin
    read_item_parameters;

    l_sql := get_base_query(p_include_tags => 0) || q'[ select /*+ qb_name(number_of_time_points) */ count(1) from timeline]';

    preprocess_qry(l_sql);

    --log(l_sql);
    --log(p_obj_id);

    execute immediate l_sql into l_result using p_obj_id, p_obj_id, get_param(g_DBLINK), get_param(g_DBLINK);
    return l_result;
  exception
    when others then raise_application_error(-20000, sqlerrm||chr(10)||l_sql);
  end;

  function get_main_diag_raw_data_qry(p_filtered varchar2 default 'Y') return varchar2
  is
    l_sql varchar2(32765);
    l_result number;
  begin
    read_item_parameters;

    l_sql := get_base_query || q'[ select /*+ qb_name(main_diag_raw_data) */ * from stats_ranged ]' || case when p_filtered = 'Y' then q'[ where (<FILTER>)]' else null end;

    preprocess_qry(l_sql);
    return l_sql;
  exception
    when others then raise_application_error(-20000, l_sql||chr(10)||sqlerrm);
  end;

  function get_main_diag_stats_qry return varchar2
  is
    l_sql varchar2(32765);
    l_result number;
  begin
    read_item_parameters;

    l_sql := get_base_query(p_include_stats => 1) || q'[ select /*+ qb_name(main_diag_stats_data) */ * from stat_ranged ]';

    preprocess_qry(l_sql);
    --log(l_sql);
    return l_sql;
  exception
    when others then raise_application_error(-20000, l_sql||chr(10)||sqlerrm);
  end;

  function get_main_diag_timeline_qry(p_wait_class varchar2) return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    set_param(g_WAITCLASS, p_wait_class);
    read_item_parameters;

    l_sql  := get_base_query ||
q'[,
   stats as (select trunc(sample_time_utc,'<TRUNC>') tim, /*count(1)*/ sum(tp_time) sec
               from stats_unranged
              where (<FILTER>)
              group by trunc(sample_time_utc,'<TRUNC>'))
select /*+ qb_name(main_diag_timeline) */ TO_CHAR(t.tim,'YYYY/MM/DD HH24:MI:SS') sample_time,
       case when (t.pnt between <STARTPOINT> and <ENDPOINT> - 1) then 1 else 0 end sec
from timeline t,
     stats s
where t.tim = s.tim(+)
  and t.pnt between <STARTPOINT> and <ENDPOINT> - 1
  order by t.tim]';

    preprocess_qry(l_sql);
    --log(l_sql);
    RETURN l_sql||' deprecated!';
  END get_main_diag_timeline_qry;

  function get_main_diag_timeline_remainder_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
   stats as (select trunc(sample_time_utc,'<TRUNC>') tim, /*count(1)*/ sum(tp_time) sec
               from stats_unranged
              where (<FILTER>)
              group by trunc(sample_time_utc,'<TRUNC>'))
select /*+ qb_name(main_diag_timeline_remainder) */ TO_CHAR(t.tim,'YYYY/MM/DD HH24:MI:SS') sample_time,
       case when (t.pnt < <STARTPOINT> or t.pnt > <ENDPOINT>+1) then 1 else 0 end sec
from timeline t,
     stats s
where t.tim = s.tim(+)
  and (t.pnt < <STARTPOINT> or t.pnt > <ENDPOINT>+1)
  order by t.tim]';

    preprocess_qry(l_sql);
    --log(l_sql);
    RETURN l_sql||' deprecated!';
  END get_main_diag_timeline_remainder_qry;

  function get_main_diag_qry(p_wait_class varchar2) return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    set_param(g_WAITCLASS, p_wait_class);
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
stats_all as (select /*+ result_cache */ trunc(sample_time_utc,'<TRUNC>') tim, wait_class, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>)
              group by trunc(sample_time_utc,'<TRUNC>'), wait_class),
stats as    (select tim, sec
               from stats_all
              where <WAITCLASS>),
tot as      (select sum(sec) sec
               from stats_all)
select /*+ qb_name(main_diag) */ TO_CHAR(t.tim,'YYYY/MM/DD HH24:MI:SS') sample_time,
       nvl(s.sec,0) sec,
       dbms_xplan.format_number(nvl(sum(s.sec)over(),0))||'; '||nvl(round(100*sum(s.sec)over()/(select sec from tot),2),0)||'%' hint
from timeline t,
     stats s
where t.tim = s.tim(+)
  and t.pnt between <STARTPOINT> and <ENDPOINT> - 1
  order by t.tim]';

    preprocess_qry(l_sql);
    --log(l_sql);
    RETURN l_sql;
  END get_main_diag_qry;

  function get_main_diag_remainder_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
   stats as (select trunc(sample_time_utc,'<TRUNC>') tim, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where not (<FILTER>)
              group by trunc(sample_time_utc,'<TRUNC>'))
select /*+ qb_name(main_diag_remainder) */ TO_CHAR(t.tim,'YYYY/MM/DD HH24:MI:SS') sample_time,
       nvl(s.sec,0) sec
from timeline t,
     stats s
where t.tim = s.tim(+)
  and t.pnt between <STARTPOINT> and <ENDPOINT> - 1
  order by t.tim]';

    preprocess_qry(l_sql);

    RETURN l_sql;
  END get_main_diag_remainder_qry;

  function get_event_summ_qry(p_filtered varchar2 default 'N') return varchar2
  is
    l_sql varchar2(32765);
  BEGIN

    read_item_parameters;

l_sql := get_base_query ||
case when nvl(p_filtered,'N') = 'N' then
q'[,
stats as    (select nvl(wait_class,'CPU') wait_class, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>)
              group by nvl(wait_class,'CPU'))]'
else
q'[,
stats as    (select nvl(wait_class,'CPU') wait_class, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>)
              group by nvl(wait_class,'CPU')
             union all
             select 'Remainder' wait_class, count(1) sec
               from stats_ranged
              where not (<FILTER>))]'
end ||
q'[
select /*+ qb_name(event_summ) */ wait_class||' '||round(100*sec/sum(sec)over(),2)||'%' wait_class, sec, wait_class wait_class1, 'Event class' ser,
case
  when wait_class='CPU' then '#00FF00'
  when wait_class='User I/O' then '#0000FF'
  when wait_class='Administrative' then '#FFCC00'
  when wait_class='Application' then '#FF2EF8'
  when wait_class='Commit' then '#FF8400'
  when wait_class='Concurrency' then '#34AADC'
  when wait_class='Configuration' then '#5856D6'
  when wait_class='Idle' then '#C7C7CC'
  when wait_class='Network' then '#8E8E93'
  when wait_class='Other' then '#007AFF'
  when wait_class='Scheduler' then '#68B82E'
  when wait_class='System I/O' then '#FF0000'
  when wait_class='Cluster' then '#F7FF00'
  when wait_class='Remainder' then '#8A8A8A'
end colors
from stats order by 2 desc]';

    preprocess_qry(l_sql);
    --log(l_sql);

    RETURN l_sql;

  end;

  function get_top_events_qry(p_event_class_item varchar2 default null) return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
nm as (select /*+ result_cache */ name, display_name||'('||name||')' display_name from v$event_name where name != display_name),
stats as    (select nvl(event,'CPU') event, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>) <EVENTCLASS>
              group by nvl(event,'CPU'))
select /*+ qb_name(top_events) */ coalesce((select display_name from nm where name=event),event)||' ('||round(100*sec/tot,2)||'%)' event, sec, event event1
from (select event,sec,sum(sec)over() tot from stats s order by 2 desc) s
where rownum<=10]';


    if p_event_class_item is not null and p_event_class_item not in (g_WAIT_CLASSES) then
      raise_application_error(-20000,'Unsupported item: '||p_event_class_item);
    end if;

    if p_event_class_item is null or instr(get_param(p_event_class_item),'NOCLASS')>0 then
      l_sql :=  replace(l_sql,'<EVENTCLASS>','');
    else
      l_sql :=  replace(replace(l_sql,'<EVENTCLASS>',q'[and nvl(WAIT_CLASS,'CPU') in (select /*+ cardinality(x 1) qb_name(event_classes)*/ column_value from table(coreobj_sql_tags.parse_tag_list(:<ITEMNAME>)))]'),'<ITEMNAME>',p_event_class_item);
    end if;

    preprocess_qry(l_sql);
    --log(l_sql);
    RETURN l_sql;
  end;

  function get_top_modules_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[
,stats as    (select 'MODULE:' || nvl(module, 'N/A') || '; ACTION:' || nvl(ACTION, 'N/A') mod_act, /*count(1)*/ sum(tp_time) sec, module module1, ACTION ACTION1
               from stats_ranged
              where (<FILTER>)
              group by 'MODULE:' || nvl(module, 'N/A') || '; ACTION:' || nvl(ACTION, 'N/A'), module, ACTION)
select /*+ qb_name(top_modules) */ mod_act || '(' || round(100 * sec / tot, 2) || '%)' mod_act, sec, module1, ACTION1
from (select mod_act, sec, sum(sec)over() tot, module1, ACTION1 from stats s order by 2 desc) s
where rownum<=10]';

    preprocess_qry(l_sql);

    RETURN l_sql;
  end;

  function get_top_segments_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
stats as    (select dblink, CURRENT_OBJ#, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>)
                and CURRENT_OBJ# > 0
              group by dblink, CURRENT_OBJ#)
select /*+ qb_name(top_segments) */
                                   'Obj=' || CURRENT_OBJ# || ' ' || (select object_name
                              from OPAS_OT_DBG_OBJECTS   o,
                                   OPAS_OT_DBG_DATAPOINT p,
                                   OPAS_OT_DBG_MONITOR   m
                             where data_object_id = CURRENT_OBJ#
                               and o.VERSION_DP_ID = p.DBGDP_ID
                               and p.DBG_ID = m.DBG_ID <DBGFLT>
                               and m.DBLINK = s.dblink)  || '(' || round(100 * sec / tot, 2) || '%)' segment, sec, CURRENT_OBJ# CURRENT_OBJ1
from (select dblink, CURRENT_OBJ#, sec, sum(sec)over() tot from stats s order by 3 desc) s
where rownum<=10]';

    preprocess_qry(l_sql);

    l_sql := replace(l_sql, '<DBGFLT>', case when get_param(g_DBG) is null then '/*NODBG*/' else ' and m.DBG_ID = '||get_param(g_DBG) end);

    RETURN l_sql;
  end;
  function get_top_sessions_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
stats as    (select 'SID: '||SESSION_ID||','||SESSION_SERIAL#||',@'||INSTANCE_NUMBER ||'; USR/OS:'||nvl(USERNAME,to_char(USER_ID)) || '/' || nvl(OSUSER,'NA') ||
                        '; P/M/M/A:' || nvl(PROGRAM, 'NA') || '/' || nvl(MACHINE, 'NA') || '/' || nvl(module, 'NA') || '/' || nvl(ACTION, 'NA') ||
                        '; ECID/TERM:'|| nvl(ECID, 'NA') || nvl(TERMINAL, 'NA')
                        sess_id
                        , count(1) sec
               from stats_ranged
              where (<FILTER>)
              group by 'SID: '||SESSION_ID||','||SESSION_SERIAL#||',@'||INSTANCE_NUMBER ||'; USR/OS:'||nvl(USERNAME,to_char(USER_ID)) || '/' || nvl(OSUSER,'NA') ||
                        '; P/M/M/A:' || nvl(PROGRAM, 'NA') || '/' || nvl(MACHINE, 'NA') || '/' || nvl(module, 'NA') || '/' || nvl(ACTION, 'NA') ||
                        '; ECID/TERM:'|| nvl(ECID, 'NA') || nvl(TERMINAL, 'NA'))
select /*+ qb_name(top_sessions) */ substr(sess_id,1,245) || '(' || round(100 * sec / tot, 2) || '%)' sess_id, sec
from (select sess_id, sec, sum(sec)over() tot from stats s order by 2 desc) s
where rownum<=10]';

    preprocess_qry(l_sql);
--log(l_sql);
    RETURN l_sql;
  end;
  function get_top_by_sql_id_qry(p_col varchar2) return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
stats as (select nvl(sql_id,'N/A') sql_id, ]' || p_col || q'[ sec
               from stats_ranged
              where (<FILTER>)
              group by nvl(sql_id,'N/A'))
select /*+ qb_name(top_by_sql_id) */ sql_id || ' (' || dbms_xplan.format_number(sec) || ') '||COREOBJ_SQL_SEARCH.get_shorten_sql_text(sql_id,60,0) sql_id, sec, sql_id real_sql_id
from (select sql_id, sec, sum(sec)over() tot from stats s where sec > 0 order by 2 desc) s
where rownum<=10]';

    preprocess_qry(l_sql);
--log(l_sql);
    RETURN l_sql;
  end;

  function get_sql_timeline_qry(p_top_n number) return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query ||
q'[,
top_sqls as (select nvl(sql_id,'N/A') sql_id, /*count(1)*/ sum(tp_time) sec
               from stats_ranged
              where (<FILTER>)
              group by nvl(sql_id,'N/A')
              order by 2 desc)
,top_N_sqls as (select sql_id, '#' || rownum || ' (' || sec || ') ' || sql_id sql_id_ext
               from top_sqls
              where rownum<=<TOPN>
              )
  ,stats as (select trunc(sample_time_utc,'<TRUNC>') time_mark, y.sql_id, z.sql_id_ext, /*count(1)*/ sum(tp_time) sec
               from (select x.* from stats_ranged x where (<FILTER>)) y, top_N_sqls z
              where nvl(y.sql_id,'N/A') = z.sql_id
              group by trunc(sample_time_utc,'<TRUNC>'), y.sql_id, z.sql_id_ext)
select /*+ qb_name(timeline) */ time_mark, sql_id_ext|| ' ' ||COREOBJ_SQL_SEARCH.get_shorten_sql_text(sql_id,60,0) sql_id, 1 val, sql_id real_sql_id from stats s]';

    l_sql := replace(l_sql,'<TOPN>',nvl(p_top_n,20));
    preprocess_qry(l_sql);

    RETURN l_sql;
  end;

  function get_sql_blocker_analyzer_qry return varchar2
  is
    l_sql varchar2(32765);
  BEGIN
    read_item_parameters;

    l_sql := get_base_query || q'[
select /*+ qb_name(blocker_analyzer) */
    session_id, session_serial#, INSTANCE_NUMBER inst_id, event, sql_id, module, action,
    case when blocking_session is not null then blocking_session||';'||blocking_session_serial#||';'||blocking_inst_id else null end blocking_session,
    session_id||';'||session_serial#||';'||INSTANCE_NUMBER blocked_session,
    cnt, blocker_id, min_ts, max_ts, wait_class,
    case when blocking_session is not null then blocking_session||'A'||blocking_session_serial#||'A'||blocking_inst_id else null end blocking_session_lnk,
    session_id||'A'||session_serial#||'A'||INSTANCE_NUMBER blocked_session_lnk
from (
select
 session_id, session_serial#, INSTANCE_NUMBER, event || case
   when CURRENT_OBJ# > 0 then
    ' ' || dbms_rowid.rowid_create(rowid_type    => 1,
                                   object_number => CURRENT_OBJ#,
                                   relative_fno  => CURRENT_FILE#,
                                   block_number  => CURRENT_BLOCK#,
                                   row_number    => CURRENT_ROW#) || ' obj=' ||
    CURRENT_OBJ# || ' ' || (select object_name
                              from OPAS_OT_DBG_OBJECTS   o,
                                   OPAS_OT_DBG_DATAPOINT p,
                                   OPAS_OT_DBG_MONITOR   m
                             where data_object_id = CURRENT_OBJ#
                               and o.VERSION_DP_ID = p.DBGDP_ID
                               and p.DBG_ID = m.DBG_ID
                               and m.DBLINK = x2.dblink)
   else
    null
 end event,
 sql_id, module, action, blocking_session, blocking_session_serial#, blocking_inst_id, cnt,
 (select listagg(fv, ' - ') within group(order by fv)
    from (select rownum || '. ' || program || '; ' || machine || '; ' ||
                 module || '; ' || action || ' at: ' ||
                 to_char(sample_time, 'yyyy/mm/dd hh24:mi:ss.ff6') fv
            from (select * from stats_ranged where (<FILTER>)) b
           where b.session_id = x2.blocking_session
             and b.session_serial# = x2.blocking_session_serial#
             and b.INSTANCE_NUMBER = x2.blocking_inst_id
             and sample_time <= min_ts
           order by sample_time desc)
   where rownum <= 2) blocker_id,
 min_ts, max_ts, wait_class
  from (select x1.*, sum(cnt) over() tot
          from (select dblink, session_id, session_serial#, INSTANCE_NUMBER, sql_id, module, action,
                       blocking_session, blocking_session_serial#, blocking_inst_id, event,
                       CURRENT_OBJ#, CURRENT_FILE#, CURRENT_BLOCK#, CURRENT_ROW#, wait_class,
                       --count(1) cnt,
                       sum(tp_time) cnt,
                       min(sample_time) min_ts,
                       max(sample_time) max_ts
                  from (select * from stats_ranged where (<FILTER>)) x
                 where wait_class in ( 'Application', 'Concurrency', 'Other')
                 group by dblink, session_id, session_serial#, INSTANCE_NUMBER, sql_id, module, action,
                          blocking_session, blocking_session_serial#, blocking_inst_id, event,
                          CURRENT_OBJ#, CURRENT_FILE#, CURRENT_BLOCK#, CURRENT_ROW#, wait_class) x1) x2
 where cnt / tot > 0.0001) order by min_ts
]';

    preprocess_qry(l_sql);
    --log(l_sql);
    RETURN l_sql;
  end;

  function get_metric_qry(p_inst_id number, p_agg_item varchar2, p_metric_item varchar2) return varchar2
  is
    l_sql varchar2(32765);
    l_metric varchar2(100);
  BEGIN
    set_param(g_INST_ID, p_inst_id);
    read_item_parameters;

    l_sql := get_base_query(p_include_metrics => 1) ||
q'[,
stats_all as (select /*+ result_cache */ trunc(END_TIME_UTC,'<TRUNC>') tim, <METRICT_AGG>(value) sec, METRIC_ID,  GROUP_ID, whole_agg
               from metrics_ranged
              where GROUP_ID=<GROUP_ID> and METRIC_ID=<METRIC_ID>
              group by trunc(END_TIME_UTC,'<TRUNC>'), METRIC_ID,  GROUP_ID, whole_agg)
select /*+ qb_name(metric_qry) */ TO_CHAR(t.tim,'YYYY/MM/DD HH24:MI:SS') end_time,
       round(sec, 3) val
from timeline t,
     stats_all s
where t.tim = s.tim(+)
  and t.pnt between <STARTPOINT> and <ENDPOINT> - 1
  order by t.tim]';
--(select metric_name||' Group: '||group_name || ' ('||upper('<METRICT_AGG>')||'('||trim(dbms_xplan.format_number(s.whole_agg))||'))' from OPAS_DB_METRICS i where i.metric_id=s.metric_id and i.group_id=s.group_id) series_name
    l_metric := get_param(p_metric_item);
    if l_metric = 'N/A' then l_metric := null; end if;

    l_sql := replace(replace(l_sql,'<GROUP_ID>',nvl(substr(l_metric,1,instr(l_metric,'~')-1),'1')),
                                   '<METRIC_ID>',nvl(substr(l_metric,instr(l_metric,'~')+1),'1'));
    l_sql := replace(l_sql,'<METRICT_AGG>',nvl(get_param(p_agg_item),'avg'));

    preprocess_qry(l_sql);

    --log(l_sql);
    RETURN l_sql;
  END get_metric_qry;

  function get_metric_data_exists(p_inst_id number, p_agg_item varchar2, p_metric_item varchar2) return boolean
  is
    l_sql varchar2(32765);
    l_metric varchar2(100);
    l_res number;
  BEGIN
    set_param(g_INST_ID, p_inst_id);
    read_item_parameters;

    l_sql := get_base_query(p_include_metrics => 1) ||
q'[
select count(1) from dual where exists (select 1 from metrics_ranged where GROUP_ID=<GROUP_ID> and METRIC_ID=<METRIC_ID>)]';

    l_metric := get_param(p_metric_item);
    if l_metric = 'N/A' then l_metric := null; end if;

    l_sql := replace(replace(l_sql,'<GROUP_ID>',nvl(substr(l_metric,1,instr(l_metric,'~')-1),'1')),
                                   '<METRIC_ID>',nvl(substr(l_metric,instr(l_metric,'~')+1),'1'));
    l_sql := replace(l_sql,'<METRICT_AGG>',nvl(get_param(p_agg_item),'avg'));

    preprocess_qry(l_sql);

    --log(l_sql);
    execute immediate l_sql into l_res using get_param(g_CUBE_ID), get_param(g_CUBE_ID), get_param(g_DBLINK), get_param(g_DBLINK), get_param(g_DBLINK);
    return l_res = 1;
  END get_metric_data_exists;
/*
metrics_ranged as
            (select /+ use_nl(c)  c.*
               from OPAS_OT_ASHACUBE_METRICS c, rng_ids, flt_timeline  ft
              where c.asharange_id = rng_ids.asharange_id and c.END_TIME_UTC between ft.mi_tim and ft.ma_tim and DBLINK = :P3003_DBLINK)

select TO_CHAR(end_time,'YYYY/MM/DD HH24:MI:SS') end_time,round(value, 3) val,
      (select metric_name||' Group: '||group_name name
         from asha_cube_metrics_dic i where i.metric_id=o.metric_id and group_id=:P3003_METRIC_GROUP) series_name
  from asha_cube_metrics o
 where sess_id = :P3003_SESS_ID and (case when :P3003_SYSM_STATUS = 'Y' then to_number(:P3003_SYSM_95PCT_ADJ) else 1e20 end > value)
   and metric_id = :P3003_METRIC_ID
   and group_id  = :P3003_METRIC_GROUP
   and aggfnc    = :P3003_METRIC_AGG
   and inst_id   = 1
 order by end_time;
*/
END COREOBJ_ASHA_CUBE_REPORTS;
/


