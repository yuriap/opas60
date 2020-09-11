

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_CALCS AS

  gParams               COREOBJ_API.t_params;

  gTargetTZ             varchar2(10);
  gTargetMinASHTS       timestamp with time zone;
  gTargetIncarnation    number;

  procedure load_v$ash
  AS
  begin
    --COREMOD_API.load_tmp_data('$LOCAL$', 'GV_$ACTIVE_SESSION_HISTORY', 'GV$ACTIVE_SESSION_HISTORY', 'OPAS_OT_TMP_GV$ASH', 'GV$ASH', 'rownum < 1e6');

    COREMOD_API.load_tmp_data (
      P_DB_LINK_NAME => '$LOCAL$',
      P_SRC_TABLE_NAME_R => 'GV_$ACTIVE_SESSION_HISTORY',
      P_SRC_TABLE_NAME => 'GV$ACTIVE_SESSION_HISTORY',
      P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
      P_SUFF => 'GV$ASH',
      p_key_pref => 'LOCTABCOLS',
      --P_DBID => null,
      P_FILTER => 'rownum < 1e6'
      );

  END load_v$ash;

  procedure set_lock(p_obj_id  opas_objects.obj_id%type)
  is
  begin
    COREMOD_API.lock_resource (
      P_RESOURCE_NAME => 'OPASASHACUBEGATHER'||p_obj_id,
      P_MODE => DBMS_LOCK.X_MODE,
      P_TIMEOUT => 180,
      P_RELEASE_ON_COMMIT => false) ;
  end;

  procedure load_params(p_obj_id  opas_objects.obj_id%type)
  is
  begin
    gParams.delete;
    gParams := coreobj_api.get_all_jparam(p_obj_id => p_obj_id);
  end;

  function gp(p_name varchar2) return varchar2
  is
    PRAGMA UDF;
  begin
    if gParams.exists(upper(p_name))
    then
      return gParams(upper(p_name));
    else
      return null;
    end if;
  end;

  procedure get_remote_min_ash_dt(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql :=
      q'[select TZ_OFFSET(dbtimezone), to_timestamp_tz(to_char(oldest_sample_time,'YYYYMMDDHH24MISS.FF3')||' '||TZ_OFFSET(dbtimezone),'YYYYMMDDHH24MISS.FF3 TZH:TZM') from V$ASH_INFO]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetTZ, gTargetMinASHTS;
    l_sql := q'[select incarnation# from v$database_incarnation]' || COREMOD_API.get_dblink_for_query(p_dblink) || q'[ where status='CURRENT']';
    execute immediate l_sql into gTargetIncarnation;
  end;

  procedure get_ash_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                            p_start_dt timestamp,
                            p_end_dt timestamp)
  is
  begin
    COREMOD_API.load_tmp_data (
      P_DB_LINK_NAME => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
      P_SRC_TABLE_NAME_R => 'GV_$ACTIVE_SESSION_HISTORY',
      P_SRC_TABLE_NAME => 'GV$ACTIVE_SESSION_HISTORY',
      P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
      P_SUFF => 'GV$ASH',
      p_key_pref => 'LOCTABCOLS',
      --P_DBID => null,
      P_FILTER => 'rownum < 1e6'
      );
  end;

  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type)
  is
    l_asharange_id opas_ot_ashacube_ranges.asharange_id%type;
  begin
    set_lock(p_obj_id);
    load_params(p_obj_id);
    get_remote_min_ash_dt(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    for i in (with input_pars as
         (select to_date(COREOBJ_ASHA_CUBE_CALCS.gp(pSTARTDT), COREOBJ_ASHA_CUBE_CALCS.gp(pDTFMT)) start_date,
                 to_date(COREOBJ_ASHA_CUBE_CALCS.gp(pENDDT),   COREOBJ_ASHA_CUBE_CALCS.gp(pDTFMT)) end_date
            from dual),
        adj_input_pars as
         (select start_date,
                 trunc(start_date, 'hh') +
                 floor(24 * 60 * (start_date - trunc(start_date, 'hh')) / 15) * 15 / 24 / 60 real_start_date,
                 trunc(end_date, 'hh') +
                 ceil(24 * 60 * (end_date - trunc(end_date, 'hh')) / 15) * 15 / 24 / 60 real_end_date,
                 end_date
            from input_pars),
        dt_boundaries0 as
         (select level rn,
                 trunc(real_start_date, 'hh') + level / (24 * 4) start_granula_dt,
                 trunc(real_start_date, 'hh') + (level + 1) / (24 * 4) end_granula_dt
            from dual, adj_input_pars
          connect by level <= ((real_end_date - real_start_date) * 24 * 4)),
        dt_boundaries as (
          select x.*,
                 FROM_TZ(to_timestamp(to_char(start_granula_dt,'YYYYMMDDHH24MI'),'YYYYMMDDHH24MI'),'00:00') start_granula_tz,
                 FROM_TZ(to_timestamp(to_char(start_granula_dt,'YYYYMMDDHH24MI'),'YYYYMMDDHH24MI'),'00:00') end_granula_tz
            from dt_boundaries0 x)
        select b.*, rng.*, rf.OBJ_ID
          from OPAS_OT_ASHACUBE_RANGE_REF rf,
               OPAS_OT_ASHACUBE_RANGES    rng,
               dt_boundaries              b
         where b.start_granula_dt = rng.START_TIME_UTC(+)
           and b.end_granula_dt = rng.END_TIME_UTC(+)
           and rng.ASHARANGE_ID = rf.ASHARANGE_ID(+)
           and rng.DBLINK(+) = COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)
         order by start_granula_dt desc)
    loop
      l_asharange_id := null;
      if gTargetMinASHTS <= i.start_granula_tz and i.asharange_id is null then
        INSERT INTO opas_ot_ashacube_ranges (
          dblink, sample_tp, start_time_utc, end_time_utc, incarnation#, status, created)
        VALUES (
          COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), 'V', i.start_granula_dt, i.end_granula_dt, gTargetIncarnation, 'NEW', systimestamp
        ) returning asharange_id into l_asharange_id;
        get_ash_granule(l_asharange_id, i.start_granula_dt, i.end_granula_dt);
      end if;
      INSERT INTO opas_ot_ashacube_range_ref ( obj_id, asharange_id) VALUES (p_obj_id, coalesce(l_asharange_id, i.asharange_id));
    end loop;

    COREMOD_API.release_resource;
  end;

END COREOBJ_ASHA_CUBE_CALCS;
/


