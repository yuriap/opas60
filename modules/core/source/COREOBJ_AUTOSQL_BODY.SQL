CREATE OR REPLACE


package body coreobj_autosql is

  procedure edit_ags(p_ags_id     in out opas_ot_sql_auto_gather_sqls.ags_id%type,
                     p_dblink            opas_ot_sql_auto_gather_sqls.dblink%type,
                     p_filter_vsql       opas_ot_sql_auto_gather_sqls.filter_vsql%type,
                     p_filter_awrstat    opas_ot_sql_auto_gather_sqls.filter_awrstat%type,
                     p_filter_awrash     opas_ot_sql_auto_gather_sqls.filter_awrash%type,
                     p_row_limit         opas_ot_sql_auto_gather_sqls.row_limit%type,
                     p_time_limit        opas_ot_sql_auto_gather_sqls.time_limit%type,
                     p_sqltext_filter    opas_ot_sql_auto_gather_sqls.sqltext_filter%type,
                     p_description       opas_ot_sql_auto_gather_sqls.descr%type)
  is
  begin
    if p_ags_id is null then
      insert into opas_ot_sql_auto_gather_sqls
        (dblink, filter_vsql, filter_awrstat, filter_awrash, row_limit, time_limit, sqltext_filter, descr)
      values
        (p_dblink, p_filter_vsql, p_filter_awrstat, p_filter_awrash, p_row_limit, p_time_limit, p_sqltext_filter, p_description) returning ags_id into p_ags_id;
    else
      update opas_ot_sql_auto_gather_sqls
         set dblink = p_dblink,
             filter_vsql = p_filter_vsql,
             filter_awrstat = p_filter_awrstat,
             filter_awrash = p_filter_awrash,
             --schedule = p_schedule,
             row_limit = p_row_limit,
             time_limit = p_time_limit,
             sqltext_filter = p_sqltext_filter,
             descr = p_description
       where ags_id = p_ags_id;
    end if;
  end;

  procedure get_schedule  (p_ags_id       opas_ot_sql_auto_gather_sqls.ags_id%type,
                           p_schedule out opas_ot_sql_auto_gather_sqls.schedule%type)
  is
  begin
    COREMOD_SCHEDULER.inis_scheduler (
      P_SCH_ID     => p_schedule,
      P_SCHEDULE   => 'freq=daily; interval=1',
      P_START_DATE => trunc(sysdate,'hh')+1/24,
      P_PLSQL_CALL => 'begin coreobj_autosql.execute_autosql('||p_ags_id||'); end;',
      P_OWNER      =>  V('APP_USER'));

      update opas_ot_sql_auto_gather_sqls
         set schedule = p_schedule
       where ags_id = p_ags_id;
  end;

  procedure drop_ags(p_ags_id       opas_ot_sql_auto_gather_sqls.ags_id%type)
  is
    l_ags   opas_ot_sql_auto_gather_sqls%rowtype;
  BEGIN
    select * into l_ags from opas_ot_sql_auto_gather_sqls where ags_id = p_ags_id;
    if l_ags.SCHEDULE is not null then
      COREMOD_SCHEDULER.suspend_config (  P_SCH_ID => l_ags.SCHEDULE);
      COREMOD_SCHEDULER.cleanup_config (  P_SCH_ID => l_ags.SCHEDULE);
      COREMOD_SCHEDULER.drop_config    (  P_SCH_ID => l_ags.SCHEDULE);
    end if;
    delete from opas_ot_sql_auto_gather_sqls where ags_id = p_ags_id;
  end;

  procedure execute_autosql(p_ags_id opas_ot_sql_auto_gather_sqls.ags_id%type)
  is
    l_ags opas_ot_sql_auto_gather_sqls%rowtype;
    l_sql1 varchar2(32765);
    l_sql2 varchar2(32765);
    l_crsr sys_refcursor;
    l_fetch_limit number := 200;
    l_res         number;
    l_iter        number;
    l_iter_limit  number := 3;
    l_start_tim   number;

    l_dbid        number;
    l_snap1       number;
    l_snap2       number;

    l_sql_id      OPAS_OT_TMP_AGS_SQLS.sql_id%type;
    l_sql_text    clob;
    l_file_id     opas_files.file_id%type;
    l_dblink      opas_ot_sql_descriptions.first_discovered_at%type;

    procedure load_sqls(p_sql1 varchar2, p_sql2 varchar2, p_nm varchar2) is
      ll_sql varchar2(32765);
    begin
      delete from OPAS_OT_TMP_AGS_LIST;

      ll_sql := replace(p_sql1,'<DBLINK>',       l_ags.dblink);
      ll_sql := replace(ll_sql,'<VSQLFILTER>',   l_ags.filter_vsql);
      ll_sql := replace(ll_sql,'<AWRSTATFILTER>',l_ags.filter_awrstat);
      ll_sql := replace(ll_sql,'<AWRASHFILTER>', l_ags.filter_awrash);

      l_iter := 0;
      l_start_tim := dbms_utility.get_time;
      loop
        execute immediate ll_sql;
        commit;
        l_iter := l_iter + 1;
        delete from OPAS_OT_TMP_AGS_LIST where sql_id in (select sql_id from opas_ot_sql_descriptions);
        delete from OPAS_OT_TMP_AGS_LIST where sql_id in (select sql_id from OPAS_OT_TMP_AGS_SQLS);
        select count(1) into l_res from OPAS_OT_TMP_AGS_LIST;
        if l_iter >= l_iter_limit then
          coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||': iteration limit');
          exit;
        end if;
        if (dbms_utility.get_time - l_start_tim)/100 > l_ags.time_limit then
          coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||': time limit');
          exit;
        end if;
        if l_res > l_ags.row_limit then
          coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||': found enough');
          exit;
        end if;
      end loop;

      coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||': iterations made: '||l_iter);

      ll_sql := replace(p_sql2,'<DBLINK>',l_ags.dblink);
      execute immediate ll_sql;
      commit;
    exception
      when others then
        coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||'; '||sqlerrm);
        coremod_tasks.log('coreobj_autosql.execute_autosql '||p_nm||'; '||ll_sql);
        raise;
    end;
  begin
    select * into l_ags from opas_ot_sql_auto_gather_sqls where ags_id = p_ags_id;
    l_dblink := l_ags.dblink;
    l_ags.dblink := COREMOD_API.get_dblink_for_query(l_ags.dblink);
    --load vsql
    l_sql1 := 'insert into OPAS_OT_TMP_AGS_LIST (sql_id, plan_hash_value, force_matching_signature) select unique sql_id, plan_hash_value, force_matching_signature from GV$SQL<DBLINK> where 1=1 and <VSQLFILTER> and rownum <= '||l_fetch_limit;
    l_sql2 := 'insert into OPAS_OT_TMP_AGS_SQLS (sql_id, plan_hash_value, sql_text, force_matching_signature) select s.sql_id, s.plan_hash_value, s.SQL_FULLTEXT, s.force_matching_signature from GV$SQL<DBLINK> s where s.sql_id in (select q.sql_id from OPAS_OT_TMP_AGS_LIST q)';
    load_sqls(l_sql1, l_sql2, 'V$SQL');

    open l_crsr for replace(
  q'[select snap_id, next_snap_id, dbid
  from (select snap_id, next_snap_id, dbid, instance_number, row_number() over(partition by snap_id order by instance_number) rn
          from (select snap_id, lead(snap_id) over(order by snap_id) next_snap_id, dbid, instance_number from dba_hist_snapshot<DBLINK>)
         where next_snap_id is not null and snap_id <> next_snap_id) where rn = 1 order by snap_id desc]','<DBLINK>',l_ags.dblink);
    fetch l_crsr into l_snap1, l_snap2, l_dbid;
    close l_crsr;

    --load awrstat
    l_sql1 := 'insert into OPAS_OT_TMP_AGS_LIST (sql_id, plan_hash_value, force_matching_signature) select unique sql_id, plan_hash_value, force_matching_signature from dba_hist_sqlstat<DBLINK> where dbid=<DBID> and instance_number>0 and snap_id between <SNAPS> and <AWRSTATFILTER> and rownum <= '||l_fetch_limit;
    l_sql2 := 'insert into OPAS_OT_TMP_AGS_SQLS (sql_id, sql_text) select s.sql_id, s.SQL_TEXT from dba_hist_sqltext<DBLINK> s where s.sql_id in (select q.sql_id from OPAS_OT_TMP_AGS_LIST q)';

    l_sql1 := replace(replace(l_sql1,'<DBID>',l_dbid),'<SNAPS>',l_snap1 || ' and ' || l_snap2);
    load_sqls(l_sql1, l_sql2, 'AWRSTAT');
    update OPAS_OT_TMP_AGS_SQLS o set o.plan_hash_value = (select i.plan_hash_value from OPAS_OT_TMP_AGS_LIST i where i.sql_id=o.sql_id and rownum = 1) where o.plan_hash_value is null;
    commit;

    --load awrash
    l_sql1 := 'insert into OPAS_OT_TMP_AGS_LIST (sql_id, plan_hash_value, force_matching_signature) select unique sql_id, sql_plan_hash_value, force_matching_signature from dba_hist_active_sess_history<DBLINK> where dbid=<DBID> and instance_number>0 and snap_id between <SNAPS> and <AWRASHFILTER> and rownum <= '||l_fetch_limit;

    l_sql1 := replace(replace(l_sql1,'<DBID>',l_dbid),'<SNAPS>',l_snap1 || ' and ' || l_snap2);
    load_sqls(l_sql1, l_sql2, 'AWRASH');

    update OPAS_OT_TMP_AGS_SQLS o set o.plan_hash_value = (select i.plan_hash_value from OPAS_OT_TMP_AGS_LIST i where i.sql_id=o.sql_id and rownum = 1) where o.plan_hash_value is null;
    commit;

    --check similar + check uniq
    l_iter := 0;
    loop
      for i in (select plan_hash_value from OPAS_OT_TMP_AGS_SQLS where plan_hash_value<>0 group by plan_hash_value having count(1)>1)
      loop
        for j in (select sql_id,cast(substr(sql_text,1,4000) as varchar2(4000)) sql_text from (select * from OPAS_OT_TMP_AGS_SQLS where plan_hash_value = i.plan_hash_value order by dbms_random.value) where rownum=1)
        loop
          for k in (select x.rowid rd from OPAS_OT_TMP_AGS_SQLS x where plan_hash_value = i.plan_hash_value and sql_id <> j.sql_id)
          loop
            update OPAS_OT_TMP_AGS_SQLS xx set jaro_winkler_similarity = UTL_MATCH.jaro_winkler_similarity(j.sql_text,cast(substr(xx.sql_text,1,4000) as varchar2(4000))) where xx.rowid=k.rd;
          end loop;
        end loop;
      end loop;

      delete from OPAS_OT_TMP_AGS_SQLS where jaro_winkler_similarity > 80;
      l_iter := l_iter + 1;
      exit when l_iter >= 3;
      update OPAS_OT_TMP_AGS_SQLS set jaro_winkler_similarity = null;
    end loop;

    l_iter := 0;
    open l_crsr for
      q'[select sql_id, sql_text from OPAS_OT_TMP_AGS_SQLS where (]'||l_ags.sqltext_filter||')';
    loop
      fetch l_crsr into l_sql_id, l_sql_text;
      exit when l_crsr%notfound;

      l_iter := l_iter + 1;
      l_file_id := COREMOD_FILE_UTILS.create_file(P_MODNAME => COREMOD_API.gMODNAME,
                                                  P_FILE_TYPE => 'SQL Text',
                                                  P_FILE_NAME => l_sql_id,
                                                  P_MIMETYPE  => COREMOD_FILE_UTILS.mtTEXT,
                                                  P_OWNER     => 'AUTOSQL ROBOT');
      COREMOD_FILE_UTILS.store_content(l_file_id,l_sql_text);

      coreobj_sql.add_sql_description(p_sql_id => l_sql_id,
                                      p_created_by => 'AUTOSQL ROBOT',
                                      p_first_discovered => systimestamp,
                                      p_first_discovered_at => l_dblink,
                                      p_sql_text => l_file_id);
      coreobj_sql_tags.auto_tag_sql(p_sql_id => l_sql_id);
    end loop;
    close l_crsr;
    --load into reg
    --set tags
    commit;
    coremod_tasks.log('coreobj_autosql.execute_autosql '||l_iter||' added in total');
  exception
    when others then rollback;
      coremod_tasks.log('Error coreobj_autosql.execute_autosql ('||p_ags_id||'): '||sqlerrm);
      coremod_tasks.log('Error coreobj_autosql.execute_autosql error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error coreobj_autosql.execute_autosql ('||p_ags_id||'): '||sqlerrm);
  end;

end coreobj_autosql;
/


