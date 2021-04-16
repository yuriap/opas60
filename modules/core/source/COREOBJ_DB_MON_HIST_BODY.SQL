

CREATE OR REPLACE
package body coreobj_db_mon_hist is

  ctRegular  constant varchar2(10) := 'REGULAR';
  ctDelta    constant varchar2(10) := 'DELTA';
  ctRatio#1  constant varchar2(10) := 'RATIO#1';

  ssSnapshot constant varchar2(1) := 'S';
  ssReady    constant varchar2(1) := 'R';

  procedure init_histogram_job
  is
    l_schedule number;
  begin
    COREMOD_SCHEDULER.inis_scheduler (
      P_SCH_ID     => l_schedule,
      P_SCHEDULE   => 'freq=minutely; interval=5',
      P_START_DATE => trunc(sysdate,'dd')+1/24,
      P_PLSQL_CALL => 'begin coreobj_db_mon_hist.calc_histograms; end;',
      P_OWNER      => 'INTERNAL');
    commit;
    coremod_scheduler.validate_config(p_sch_id => l_schedule);
    commit;
    coremod_scheduler.activate_config(p_sch_id => l_schedule);
    commit;
  end;

  procedure calc_histograms
  is
    l_next_date TIMESTAMP WITH TIME ZONE;
    l_next_rem_date TIMESTAMP WITH TIME ZONE;
    l_sess_id   opas_ot_db_mon_hist_sess.sess_id%type;
    l_sess_id2  opas_ot_db_mon_hist_sess.sess_id%type;
    l_view_sql varchar2(32765);
    l_SELECT_LIST COREMOD_EXTPROC.t_columns;
  begin
    for i in (select * from opas_ot_db_mon_hist where status=stActive) loop
      DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
        calendar_string    => i.schedule,
        start_date         => i.start_date,
        return_date_after  => nvl(i.last_exec_ts,i.start_date),
        next_run_date      => l_next_date);
      coremod_log.log('schedule: '||i.schedule,'DEBUG');
      coremod_log.log('start_date: '||to_char(i.start_date,'YYYY/MM/DD HH24:MI:SS'),'DEBUG');
      coremod_log.log('last_exec_ts: '||to_char(i.last_exec_ts,'YYYY/MM/DD HH24:MI:SS'),'DEBUG');
      coremod_log.log('l_next_date: '||to_char(l_next_date,'YYYY/MM/DD HH24:MI:SS'),'DEBUG');
      if l_next_date is not null and l_next_date <= systimestamp then
        begin
          if i.calc_type = ctDelta then
            l_view_sql := --insert into opas_ot_db_mon_hist_data (sess_id, inst_id, range#, quantity)
q'[(with ranges as (<BUCKETS>)
select <SESS_ID> SESS_ID, d.inst_id, r.range#, val QUANTITY
  from (<STAT>) d, ranges r
 where d.end_range = r.range#_end)]';
          elsif i.calc_type = ctRegular then
            l_view_sql := --insert into opas_ot_db_mon_hist_data (sess_id, inst_id, range#, quantity)
q'[(with ranges as (<BUCKETS>)
select <SESS_ID> SESS_ID, d.inst_id, r.range#, count(1) QUANTITY
  from (<STAT>) d, ranges r
 where val between r.range#_start and r.range#_end
 group by d.inst_id, r.range#)]';
          elsif i.calc_type = ctRatio#1 then
            l_view_sql := --insert into opas_ot_db_mon_hist_data (sess_id, inst_id, range#, quantity)
q'[(with ranges as (<BUCKETS>),
ranges_with_instances as (
select r.range#, i.inst_id
from ranges r, gv$instance<DBLINK> i)
select <SESS_ID> SESS_ID, r.inst_id, r.range#, nvl(d.stats,0) QUANTITY
  from (<STAT>) d, ranges_with_instances r
where d.range#(+) = r.range#
  and d.inst_id(+) = r.inst_id)]';
          end if;

          l_next_rem_date := coremod_utils.get_remote_ts(p_dblink => i.dblink);

          insert into opas_ot_db_mon_hist_sess (dbmh_id, tim_tz, status)
               values (i.dbmh_id, l_next_rem_date, case i.calc_type when ctRegular then ssReady when ctDelta then ssSnapshot when ctRatio#1 then ssSnapshot else 'N/A' end)
               returning sess_id into l_sess_id;

          l_view_sql:=replace(replace(replace(l_view_sql,'<BUCKETS>',i.dbmh_buckets),
                                                         '<STAT>',i.dbmh_stat),
                                                         '<SESS_ID>',l_sess_id);

          --execute immediate l_view_sql;
          COREMOD_EXTPROC.load_external_data (
              P_TARGET_TABLE => 'OPAS_OT_DB_MON_HIST_DATA',
              P_SELECT_LIST => l_SELECT_LIST,
              P_SQL_BODY => l_view_sql,
              P_DBLINK => i.dblink,
              p_priority => 3,
              P_TIMEOUT => 300) ;

          update opas_ot_db_mon_hist set last_exec_ts = systimestamp where dbmh_id = i.dbmh_id;

--coremod_log.log('i.dbmh_id: '||i.dbmh_id);
          if i.calc_type in ( ctDelta, ctRatio#1 ) then
--coremod_log.log('i.calc_type: '||i.calc_type);
            for j in (select unique prev_sess_id, prev_tim_tz from (
                      select FIRST_VALUE(sess_id) OVER (ORDER BY tim_tz desc ROWS UNBOUNDED PRECEDING) prev_sess_id,
                             FIRST_VALUE(tim_tz) OVER (ORDER BY tim_tz desc ROWS UNBOUNDED PRECEDING) prev_tim_tz
                        from opas_ot_db_mon_hist_sess where dbmh_id = i.dbmh_id and status = ssSnapshot and sess_id <> l_sess_id)) loop
--coremod_log.log('j.prev_tim_tz: '||j.prev_tim_tz);
--coremod_log.log('i.last_exec_ts: '||i.last_exec_ts);
--coremod_log.log('l_next_date: '||l_next_date);
              if (systimestamp - j.prev_tim_tz) < 3 * ( l_next_date - i.last_exec_ts ) then
                insert into opas_ot_db_mon_hist_sess (dbmh_id, tim_tz, status)
                     values (i.dbmh_id, l_next_rem_date, ssReady)
                     returning sess_id into l_sess_id2;
--coremod_log.log('i.calc_type 2: '||i.calc_type);
                if i.calc_type in ( ctDelta ) then
                  insert into opas_ot_db_mon_hist_data
                    (sess_id, inst_id, range#, quantity)
                  select l_sess_id2, c.inst_id, c.range#,
                         c.quantity - p.quantity
                    from opas_ot_db_mon_hist_data p,
                         opas_ot_db_mon_hist_data c
                    where p.sess_id = j.prev_sess_id
                      and c.sess_id = l_sess_id
                      and p.inst_id = c.inst_id
                      and p.range# = c.range#
                      and c.quantity > p.quantity;
                end if;

                if i.calc_type in ( ctRatio#1 ) then
                  insert into opas_ot_db_mon_hist_data
                    (sess_id, inst_id, range#, quantity)
                  select * from (
                  select l_sess_id2, c.inst_id, c.range#,
                         case when (floor(c.quantity) - floor(p.quantity)) <> 0
                           then 1000000*((c.quantity - floor(c.quantity))*1e18 - (p.quantity - floor(p.quantity))*1e18)/(floor(c.quantity) - floor(p.quantity))
                           else 0
                           end quantity
                    from opas_ot_db_mon_hist_data p,
                         opas_ot_db_mon_hist_data c
                    where p.sess_id = j.prev_sess_id
                      and c.sess_id = l_sess_id
                      and p.inst_id = c.inst_id
                      and p.range# = c.range#
                      --and c.quantity > p.quantity
                      ) where quantity<>0
                      ;
--coremod_log.log(ctRatio#1||': '||sql%rowcount);
                end if;
              end if;
              --if i.calc_type in ( ctDelta ) then
              delete from opas_ot_db_mon_hist_sess where dbmh_id = i.dbmh_id and sess_id = j.prev_sess_id;
              --end if;
            end loop;
          end if;

          commit;
        exception
          when others then
            rollback;
            coremod_log.log('Error in execution DB Histogram('||i.dbmh_id||'): '||SQLERRM);
            coremod_log.log('Error in execution DB Histogram('||i.dbmh_id||'): '||l_view_sql);
        end;
      end if;
    end loop;
  end;

  procedure init_histograms(p_dbmh_id opas_ot_db_mon_hist.dbmh_id%type)
  is
    l_view_sql varchar2(32765):= q'[create or replace view v$opas_ot_db_mon_hst_<ID> as
select v.*, r.range#_start, r.range#_end from opas_ot_db_mon_hist_vals v, (<BUCKETS>) r
where v.range# = r.range# and v.dbmh_id = <ID> order by 1,2 desc, 4,5]';
  begin
    for i in (select * from opas_ot_db_mon_hist where dbmh_id = p_dbmh_id) loop
      l_view_sql:=replace(replace(l_view_sql,'<BUCKETS>',i.dbmh_buckets),'<ID>',p_dbmh_id);
      execute immediate l_view_sql;
    end loop;
  end;
end coreobj_db_mon_hist;
/


