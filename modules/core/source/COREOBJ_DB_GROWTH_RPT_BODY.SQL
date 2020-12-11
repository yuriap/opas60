

CREATE OR REPLACE
package body COREOBJ_DB_GROWTH_RPT is

  procedure gather_alert_chart_data(p_alert_type       opas_ot_dbg_monitor_al_cfg.alert_type%type,
                                    p_dbg_id           opas_ot_dbg_monitor_al_cfg.dbg_id%type,
                                    p_alert_id         opas_ot_dbg_monitor_al_cfg.alert_id%type,
                                    p_alert_expr       opas_ot_dbg_monitor_al_cfg.alert_expr%type,
                                    p_chart_id         number,
                                    p_start_dbgdp_id   opas_ot_dbg_datapoint.dbgdp_id%type,
                                    p_end_dbgdp_id     opas_ot_dbg_datapoint.dbgdp_id%type)
  is
    l_sql varchar2(4000);
  begin
      case p_alert_type
--==========================================================================
        when COREOBJ_DB_GROWTH.alrtSIZELIMIT then
          insert into opas_ot_dbg_charts
                    (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
            select p_alert_id, p_chart_id, dp.snapped, sum(t.seg_occupied), V('SESSION'), sysdate
              from OPAS_OT_DBG_TS_SIZES t, opas_ot_dbg_datapoint dp
             where t.dbgdp_id=dp.dbgdp_id and dp.dbg_id=p_dbg_id
               and dp.dbgdp_id between p_start_dbgdp_id and p_end_dbgdp_id
             group by dp.snapped;
--==========================================================================
        when COREOBJ_DB_GROWTH.alrtDELTALIMIT then
          insert into opas_ot_dbg_charts
                    (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
            select alert_id, chart_id, snapped, sz - lag(sz) over (order by snapped), V('SESSION'), sysdate
            from (select p_alert_id alert_id, p_chart_id chart_id, dp.snapped, sum(t.seg_occupied) sz
                    from OPAS_OT_DBG_TS_SIZES t, opas_ot_dbg_datapoint dp
                   where t.dbgdp_id=dp.dbgdp_id and dp.dbg_id=p_dbg_id
                     and dp.dbgdp_id between p_start_dbgdp_id and p_end_dbgdp_id
                   group by dp.snapped);
--==========================================================================
        when COREOBJ_DB_GROWTH.alrtFREELIMIT then
          insert into opas_ot_dbg_charts
                    (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
            select p_alert_id, p_chart_id, dp.snapped, sum(t.tot_free), V('SESSION'), sysdate
              from OPAS_OT_DBG_TS_SIZES t, opas_ot_dbg_datapoint dp
             where t.dbgdp_id=dp.dbgdp_id and dp.dbg_id=p_dbg_id
               and dp.dbgdp_id between p_start_dbgdp_id and p_end_dbgdp_id
             group by dp.snapped;
--==========================================================================
        when COREOBJ_DB_GROWTH.alrtOUTOFSPACE then
          insert into opas_ot_dbg_charts
                    (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
            select alert_id, chart_id, snapped,
                   round(s_free/decode((s_occu - lag(s_occu) over (order by snapped)),0,null,(s_occu - lag(s_occu) over (order by snapped))),3),
                   V('SESSION'), sysdate
            from (select p_alert_id alert_id, p_chart_id chart_id, dp.snapped,
                         sum(t.seg_occupied) s_occu,
                         sum(tot_free) s_free
                    from OPAS_OT_DBG_TS_SIZES t, opas_ot_dbg_datapoint dp
                   where t.dbgdp_id=dp.dbgdp_id and dp.dbg_id=p_dbg_id
                     and dp.dbgdp_id between p_start_dbgdp_id and p_end_dbgdp_id
                   group by dp.snapped);
--==========================================================================
        when COREOBJ_DB_GROWTH.alrtREGEXP then
          l_sql := q'[insert into opas_ot_dbg_charts
                    (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
            with objects as
             (select *
                from opas_ot_dbg_objects o, opas_ot_dbg_datapoint dp
               where o.version_dp_id = dp.dbgdp_id
                 and dp.dbg_id = :p_dbg_id
                 and (]' || p_alert_expr || q'[))
            select alert_id, chart_id, snapped, sz - lag(sz) over (order by snapped), V('SESSION'), sysdate
            from (select :p_alert_id alert_id, :p_chart chart_id, dp.snapped, sum(s.size_bytes) sz
                    from objects o, opas_ot_dbg_seg_sizes s, opas_ot_dbg_datapoint dp
                   where dp.dbg_id=:p_dbg_id
                     and dp.dbgdp_id between :l_start_dbgdp_id and :l_end_dbgdp_id
                     and o.dbgobj_id = s.dbgobj_id
                     and s.dbgdp_id = dp.dbgdp_id
                   group by dp.snapped)]';

          execute immediate l_sql using in p_dbg_id, p_alert_id, p_chart_id, p_dbg_id, p_start_dbgdp_id, p_end_dbgdp_id;
        else
          null;
      end case;
  end;

  procedure prepare_chart_data(p_mode varchar2,
                               p_alert_queue_id  opas_alert_queue.alert_id%type,
                               p_alert_id in out opas_ot_dbg_monitor_al_cfg.alert_id%type,
                               p_dt_fmt          varchar2,
                               p_start_dt in out varchar2,
                               p_end_dt   in out varchar2,
                               p_chart_name  out varchar2,
                               p_chart_meas  out varchar2,
                               p_dbg_id      out opas_ot_dbg_monitor.dbg_id%type)
  is
    l_dbgdp_id   opas_ot_dbg_datapoint.dbgdp_id%type;

    l_start_dbgdp_id   opas_ot_dbg_datapoint.dbgdp_id%type;
    l_end_dbgdp_id     opas_ot_dbg_datapoint.dbgdp_id%type;

    l_start_dt   opas_ot_dbg_datapoint.snapped%type;
    l_end_dt     opas_ot_dbg_datapoint.snapped%type;

    l_tmp_dbgdp_id     opas_ot_dbg_datapoint.dbgdp_id%type;
    l_tmp_dt           opas_ot_dbg_datapoint.snapped%type;

    l_crsr sys_refcursor;
    l_cycles number;
    l_alert_snap timestamp;

    l_link_param opas_alert_queue.link_param%type;
  begin
    if  /*(p_mode in (COREMOD_ALERTS.gmSHOWALERT, COREMOD_ALERTS.gmREFRESH) and p_alert_queue_id is not null and p_alert_id is null) or
        (p_mode in (COREMOD_ALERTS.gmPREVIEW, COREMOD_ALERTS.gmREFRESH)   and p_alert_queue_id is null     and p_alert_id is not null)*/
        (p_mode in (COREMOD_ALERTS.gmSHOWALERT) and p_alert_queue_id is not null and p_alert_id is null) or
        (p_mode in (COREMOD_ALERTS.gmREFRESH)) or
        (p_mode in (COREMOD_ALERTS.gmPREVIEW)   and p_alert_queue_id is null     and p_alert_id is not null)
    then
      null;
    else
      raise_application_error(-20000,'Invalid input for COREOBJ_DB_GROWTH_RPT.prepare_chart_data: p_mode: '||p_mode||'; p_alert_queue_id: "'||p_alert_queue_id||'"; p_alert_id: "'||p_alert_id||'"');
    end if;

    if p_mode in (COREMOD_ALERTS.gmSHOWALERT, COREMOD_ALERTS.gmREFRESH) and p_alert_queue_id is not null then
      select link_param into l_link_param from opas_alert_queue where alert_id = p_alert_queue_id;
      p_alert_id := substr(l_link_param,1,instr(l_link_param,'-')-1);
      l_dbgdp_id := substr(l_link_param,instr(l_link_param,'-')+1);

      select snapped into l_alert_snap from opas_ot_dbg_datapoint where dbgdp_id=l_dbgdp_id;
    end if;

    l_start_dt := to_date(p_start_dt, p_dt_fmt);
    l_end_dt := to_date(p_end_dt, p_dt_fmt);

    for i in (select * from
             (select x.alert_id, x.dbg_id, x.alert_name, x.alert_type, x.alert_measur, x.alert_expr, m.dblink
                from opas_ot_dbg_monitor_al_cfg x, opas_ot_dbg_monitor m
               where x.alert_id = p_alert_id and m.dbg_id = x.dbg_id
              union all
              select x.alert_id, x.dbg_id, x.alert_name, x.alert_type, x.alert_measur, x.alert_expr, m.dblink
                from opas_ot_dbg_monitor_al_cfg_hst x, opas_ot_dbg_monitor m
               where x.alert_id = p_alert_id and l_alert_snap between x.actual_start and x.actual_end and m.dbg_id = x.dbg_id)
             where rownum=1)
    loop
      p_dbg_id := i.dbg_id;
      delete from opas_ot_dbg_charts where alert_id = i.alert_id and apex_sess = V('SESSION');
      commit;

      select display_val into p_chart_name from opas_dictionary where dic_name='DBGALERT' and val = i.alert_type;
      p_chart_name := 'DB Growth: '||
                      p_chart_name ||
                      case when i.alert_type = COREOBJ_DB_GROWTH.alrtREGEXP and i.alert_name is not null then ' "'||i.alert_name||'"' else null end ||
                      ' for '||i.dblink;
      p_chart_meas := i.alert_measur;
--============================================================================================================================================
      if p_mode = COREMOD_ALERTS.gmSHOWALERT or (p_mode = COREMOD_ALERTS.gmREFRESH and p_alert_queue_id is not null) then

          if nvl(l_end_dt,l_alert_snap)   < l_alert_snap then l_end_dt   := null; end if;
          if nvl(l_start_dt,l_alert_snap) > l_alert_snap then l_start_dt := null; end if;

          open l_crsr for
            select dbgdp_id, trunc(snapped,'mi') from opas_ot_dbg_datapoint where dbg_id=i.dbg_id and snapped >= l_alert_snap order by snapped;
          l_cycles := 0;
          loop
            l_cycles := l_cycles + 1;
            fetch l_crsr into l_tmp_dbgdp_id, l_tmp_dt;

            if l_end_dt is null then
              exit when l_crsr%notfound or l_cycles > 11;
            else
              exit when l_crsr%notfound or l_tmp_dt > l_end_dt;
            end if;
            l_end_dbgdp_id := l_tmp_dbgdp_id;
            p_end_dt := to_char(l_tmp_dt, p_dt_fmt);
          end loop;

          open l_crsr for
            select dbgdp_id, trunc(snapped,'mi') from opas_ot_dbg_datapoint where dbg_id=i.dbg_id and snapped <= l_alert_snap order by snapped desc;
          l_cycles := 0;
          loop
            l_cycles := l_cycles + 1;
            fetch l_crsr into l_tmp_dbgdp_id, l_tmp_dt;
            if l_start_dt is null then
              exit when l_crsr%notfound or l_cycles > 11;
            else
              exit when l_crsr%notfound or l_tmp_dt < l_start_dt;
            end if;
            l_start_dbgdp_id := l_tmp_dbgdp_id;
            p_start_dt := to_char(l_tmp_dt, p_dt_fmt);
          end loop;
      end if;
--============================================================================================================================================
      if p_mode = COREMOD_ALERTS.gmPREVIEW or (p_mode = COREMOD_ALERTS.gmREFRESH and p_alert_id is not null and p_alert_queue_id is null) then

        select
               to_char(max(dp.snapped), p_dt_fmt),
               max(dp.dbgdp_id)
          into p_end_dt,
               l_end_dbgdp_id
          from opas_ot_dbg_datapoint dp, opas_ot_dbg_monitor_al_cfg a
         where dp.dbg_id = a.dbg_id
           and a.alert_id = p_alert_id
           and dp.snapped <= nvl(l_end_dt,systimestamp);

        if l_start_dt is not null then
          select
                 to_char(min(dp.snapped), p_dt_fmt),
                 min(dp.dbgdp_id)
            into p_start_dt,
                 l_start_dbgdp_id
            from opas_ot_dbg_datapoint dp, opas_ot_dbg_monitor_al_cfg a
           where dp.dbg_id = a.dbg_id
             and a.alert_id = p_alert_id
             and dp.snapped >= l_start_dt;
        else
          select
                 to_char(min(snapped), p_dt_fmt),
                 min(dbgdp_id)
            into p_start_dt,
                 l_start_dbgdp_id
            from ( select dp.snapped, dp.dbgdp_id, row_number() over (order by dp.snapped desc) rn
                     from opas_ot_dbg_datapoint dp, opas_ot_dbg_monitor_al_cfg a
                    where dp.dbg_id = a.dbg_id
                      and a.alert_id = p_alert_id)
           where rn < 101;
        end if;

      end if;

      gather_alert_chart_data(p_alert_type       => i.alert_type,
                              p_dbg_id           => i.dbg_id,
                              p_alert_id         => i.alert_id,
                              p_alert_expr       => i.alert_expr,
                              p_chart_id         => chrtMain,
                              p_start_dbgdp_id   => l_start_dbgdp_id,
                              p_end_dbgdp_id     => l_end_dbgdp_id);

      insert into opas_ot_dbg_charts
                (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
        select i.alert_id, chrtLimit, t.dtstamp, l.alert_limit, V('SESSION'), sysdate
          from opas_ot_dbg_charts t,
               (select alert_limit, actual_start, systimestamp actual_end from opas_ot_dbg_monitor_al_cfg where alert_id =  i.alert_id
                union all
                select alert_limit, actual_start, actual_end from opas_ot_dbg_monitor_al_cfg_hst where alert_id =  i.alert_id) l
         where t.alert_id = i.alert_id and apex_sess = V('SESSION') and chart_id = chrtMain
           and t.dtstamp between l.actual_start and l.actual_end;

      if p_mode = COREMOD_ALERTS.gmSHOWALERT or (p_mode = COREMOD_ALERTS.gmREFRESH and p_alert_queue_id is not null) then
        insert into opas_ot_dbg_charts
                  (alert_id, chart_id, dtstamp, chart_val, apex_sess, created)
          select i.alert_id, chrtAlert, t.dtstamp, decode(l_alert_snap,t.dtstamp, t.chart_val,0), V('SESSION'), sysdate
            from opas_ot_dbg_charts t
           where t.alert_id = i.alert_id and apex_sess = V('SESSION') and chart_id = chrtMain;
      end if;

    end loop;
    --return null;
  end;

  procedure cleanup_chart_data
  is
  begin
    delete from opas_ot_dbg_charts where created < sysdate-0.5/24;
    delete from opas_ot_dbg_report_pars where created < sysdate-0.5/24;
    commit;
  end;

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
                                p_end_snap         number)
  is
  begin
    delete from opas_ot_dbg_report_pars where apex_sess = V('SESSION');
    insert into opas_ot_dbg_report_pars
      (apex_sess, created,   dbgso_dbg_id, dbgso_table_name_like, dbgso_inverse, dbgso_prnt_table, dbgso_prnt_table_type,
       dbgso_object_class, dbgso_object_type, dbgso_segment_type, dbgso_object_name, dbgso_subobject_name, dbgso_tablespace_name,
       DBGSO_START_SNAP, DBGSO_END_SNAP)
    values
      (V('SESSION'), sysdate,    p_dbg_id,     p_table_name_like,     p_inverse,     p_prnt_table,     p_prnt_table_type,
           p_object_class,     p_object_type,     p_segment_type,     p_object_name,     p_subobject_name,     p_tablespace_name,
       p_start_snap, p_end_snap);
    commit;
  end;

  procedure prepare_out_of_space_data(p_dbg_id           opas_ot_dbg_monitor.dbg_id%type,
                                      p_days_to_avg      number default null,
                                      p_start_dp         opas_ot_dbg_datapoint.dbgdp_id%type default null,
                                      p_end_dp           opas_ot_dbg_datapoint.dbgdp_id%type default null,
                                      p_tablespace       varchar2,
                                      p_avg_delta    out number,
                                      p_out_of_space out timestamp)
  is
    l_seg_occupied_delta number;
    l_last_occupied  number;
    l_last_available number;
    l_last_snap      timestamp;
    l_iter           number := 0;
  begin
    delete from opas_ot_dbg_charts where apex_sess = V('SESSION') and chart_id in (chrtOccupied, chrtAvailable, chrtOccuProjection, chrtAvailProjection);

    if p_days_to_avg is not null then

      insert into opas_ot_dbg_charts
        (apex_sess, created, alert_id, chart_id, dtstamp, chart_val)
      select
         V('SESSION'), sysdate, null,  chrtOccupied,        snapped, sum(seg_occupied)
      from opas_ot_dbg_ts_sizes s,
           opas_ot_dbg_datapoint dp
      where s.dbgdp_id = dp.dbgdp_id
        and dp.dbg_id = p_dbg_id
        and dp.snapped > systimestamp - to_dsinterval(to_char(p_days_to_avg + 10) || ' 00:00:00')
        and s.ts_name = p_tablespace
        group by snapped;

      insert into opas_ot_dbg_charts
        (apex_sess, created, alert_id, chart_id, dtstamp, chart_val)
      select
         V('SESSION'), sysdate, null,  chrtAvailable,        snapped, sum(ext_available)
      from opas_ot_dbg_ts_sizes s,
           opas_ot_dbg_datapoint dp
      where s.dbgdp_id = dp.dbgdp_id
        and dp.dbg_id = p_dbg_id
        and dp.snapped > systimestamp - to_dsinterval(to_char(p_days_to_avg + 10) || ' 00:00:00')
        and s.ts_name = p_tablespace
        group by snapped;

      select round(avg(seg_occupied_delta)) into l_seg_occupied_delta
      from (
          select seg_occupied - lag(seg_occupied)over(order by snapped) seg_occupied_delta
          from (
              select snapped, sum(seg_occupied) seg_occupied
               from opas_ot_dbg_ts_sizes s,
                    opas_ot_dbg_datapoint dp
              where s.dbgdp_id = dp.dbgdp_id
                and dp.dbg_id = p_dbg_id
                and dp.snapped > systimestamp - to_dsinterval(to_char(p_days_to_avg + 1) || ' 00:00:00')
                and s.ts_name = p_tablespace
                group by snapped
                )
        ) where seg_occupied_delta is not null;
    --================================================================
    elsif p_start_dp is not null and p_end_dp is not null then

      insert into opas_ot_dbg_charts
        (apex_sess, created, alert_id, chart_id, dtstamp, chart_val)
      select
         V('SESSION'), sysdate, null,  chrtOccupied,        snapped, sum(seg_occupied)
      from opas_ot_dbg_ts_sizes s,
           opas_ot_dbg_datapoint dp
      where s.dbgdp_id = dp.dbgdp_id
        and dp.dbg_id = p_dbg_id
        and dp.dbgdp_id between p_start_dp and p_end_dp
        and s.ts_name = p_tablespace
        group by snapped;

      insert into opas_ot_dbg_charts
        (apex_sess, created, alert_id, chart_id, dtstamp, chart_val)
      select
         V('SESSION'), sysdate, null,  chrtAvailable,        snapped, sum(ext_available)
      from opas_ot_dbg_ts_sizes s,
           opas_ot_dbg_datapoint dp
      where s.dbgdp_id = dp.dbgdp_id
        and dp.dbg_id = p_dbg_id
        and dp.dbgdp_id between p_start_dp and p_end_dp
        and s.ts_name = p_tablespace
        group by snapped;

      select round(avg(seg_occupied_delta)) into l_seg_occupied_delta
      from (
          select seg_occupied - lag(seg_occupied)over(order by snapped) seg_occupied_delta
          from (
              select snapped, sum(seg_occupied) seg_occupied
               from opas_ot_dbg_ts_sizes s,
                    opas_ot_dbg_datapoint dp
              where s.dbgdp_id = dp.dbgdp_id
                and dp.dbg_id = p_dbg_id
                and dp.dbgdp_id between p_start_dp and p_end_dp
                and s.ts_name = p_tablespace
                group by snapped
                )
        ) where seg_occupied_delta is not null;
    end if;

    select chart_val, dtstamp into l_last_occupied, l_last_snap
    from opas_ot_dbg_charts where apex_sess = V('SESSION') and chart_id = chrtOccupied
    and dtstamp = (select max(dtstamp) from opas_ot_dbg_charts where apex_sess = V('SESSION') and chart_id = chrtOccupied);

    select chart_val into l_last_available
    from opas_ot_dbg_charts where apex_sess = V('SESSION') and chart_id = chrtAvailable
    and dtstamp = (select max(dtstamp) from opas_ot_dbg_charts where apex_sess = V('SESSION') and chart_id = chrtAvailable);

    if l_seg_occupied_delta > 0 then
      loop
        insert into opas_ot_dbg_charts
          (apex_sess,   created, alert_id, chart_id, dtstamp, chart_val)
        values
          (V('SESSION'), sysdate, null,    chrtOccuProjection,        l_last_snap, l_last_occupied);

        insert into opas_ot_dbg_charts
          (apex_sess,   created, alert_id, chart_id, dtstamp, chart_val)
        values
          (V('SESSION'), sysdate, null,    chrtAvailProjection,        l_last_snap, l_last_available);

        if l_iter > 365*3 then
          p_out_of_space := null;
        end if;

        exit when  l_last_occupied > l_last_available or l_iter > 365*3;

        p_out_of_space := l_last_snap;

        l_last_occupied := l_last_occupied + l_seg_occupied_delta;
        l_last_snap     := l_last_snap + to_dsinterval('01 00:00:00');
        l_iter          := l_iter + 1;

      end loop;
    end if;

    p_avg_delta := l_seg_occupied_delta;

    commit;
  end;

  function home_page_brief(p_dbg_id opas_ot_dbg_monitor.dbg_id%type) return varchar2
  is
  begin
    return replace(q'[select rownum rn, '<NAME>' name, x.msg message, <ORDR> ordr from (
    select to_char(trunc(tim,'mi'),'YYYY-Mon-DD HH24:MI') || ': Total:' || COREMOD_REPORT_UTILS.to_hr_num(val) || '; Delta:' || COREMOD_REPORT_UTILS.to_hr_num(delta) msg
    from (select tim, val, val - lag(val)over(order by tim) delta from
(select dp.snapped tim, sum(tot_occupied) val
  from OPAS_OT_DBG_TS_SIZES t, opas_ot_dbg_datapoint dp
  where t.dbgdp_id = dp.dbgdp_id
    and dp.SNAPPED > sysdate - 30
    and dp.dbg_id = <DBG_ID>
 group by dp.dbgdp_id, dp.snapped)) where delta is not null
 order by tim desc) x where rownum<=7]','<DBG_ID>', p_dbg_id);
  end;

end COREOBJ_DB_GROWTH_RPT;
/


