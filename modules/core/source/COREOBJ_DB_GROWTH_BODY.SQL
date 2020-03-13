CREATE OR REPLACE
package body COREOBJ_DB_GROWTH is

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_dbgm opas_ot_dbg_monitor%rowtype;
    l_status varchar2(32);
  begin
    select * into l_dbgm from opas_ot_dbg_monitor where dbg_id = p_obj_id;

    if l_dbgm.schedule is null then
      l_status := 'No schedule';
    else
      select status into l_status from OPAS_SCHEDULER where sch_id=l_dbgm.schedule;
    end if;
    return l_status;
  end;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type)
  is
  begin
    COREOBJ_API.add (  P_OBJ_ID => p_obj_id,
      P_OBJ_PRNT  => p_obj_prnt,
      P_OBJ_OT    => COREOBJ_API.otSIMPLE_DB_MONITOR,
      P_OBJ_NAME  => 'DB Growth Monitor '||to_char(sysdate,'YYYYMMDD'),
      P_OBJ_DESCR => null);

    insert into opas_ot_dbg_monitor
      (dbg_id, dblink, scheme_list, schedule)
    values
      (p_obj_id, null, null, null);

  end;

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_dblink           opas_ot_dbg_monitor.dblink%type,
                   p_scheme_list      opas_ot_dbg_monitor.scheme_list%type)
  is
  begin
    update opas_ot_dbg_monitor
       set dblink = p_dblink,
           scheme_list = p_scheme_list
     where dbg_id = p_obj_id;
  end;

  procedure drop_monitor(p_obj_id           opas_objects.obj_id%type)
  is
    l_mon   opas_ot_dbg_monitor%rowtype;
  BEGIN
    select * into l_mon from opas_ot_dbg_monitor where dbg_id = p_obj_id;
    if l_mon.schedule is not null then
      COREMOD_SCHEDULER.suspend_config (  P_SCH_ID => l_mon.schedule);
      COREMOD_SCHEDULER.cleanup_config (  P_SCH_ID => l_mon.schedule);
      COREMOD_SCHEDULER.drop_config    (  P_SCH_ID => l_mon.schedule);
    end if;
    delete from opas_ot_dbg_monitor where dbg_id = p_obj_id;
  end;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N')
  is
  begin
    drop_monitor(p_obj_id);
    COREOBJ_API.remove(p_obj_id);
  end;

  procedure get_schedule  (p_obj_id       opas_objects.obj_id%type,
                           p_schedule out opas_ot_dbg_monitor.schedule%type)
  is
    l_obj  opas_objects%rowtype := COREOBJ_API.get_obj(p_obj_id);
  begin
    COREMOD_SCHEDULER.inis_scheduler (
      P_SCH_ID     => p_schedule,
      P_SCHEDULE   => 'freq=daily; interval=1',
      P_START_DATE => trunc(sysdate,'hh')+1/24,
      P_PLSQL_CALL => 'begin COREOBJ_DB_GROWTH.take_snapshot('||p_obj_id||'); end;',
      P_OWNER      => l_obj.obj_owner);

    update opas_ot_dbg_monitor
       set schedule = p_schedule
     where dbg_id = p_obj_id;
  end;

  procedure take_snapshot_i(p_obj_id       opas_objects.obj_id%type)
  is
    l_dbgdp_id opas_ot_dbg_datapoint.dbgdp_id%type;
    l_dp_obj number := p_obj_id;

    l_dbgm opas_ot_dbg_monitor%rowtype;
    l_view_prefix        varchar2(10);
    l_view_prefix_filter varchar2(10);
    l_ora_dblink         varchar2(1000);
    l_dblink_user        varchar2(128);
    l_owner_column       varchar2(128);
    l_owner_column2      varchar2(128);
    l_owner_list         varchar2(4000);

    l_users     DBMS_UTILITY.uncl_array;
    l_tbln      BINARY_INTEGER;

    l_sql       varchar2(32765);
    l_tblsp_list varchar2(1024);
    l_tblsp_sql varchar2(4000) := q'[insert into opas_ot_dbg_ts_sizes (dbgdp_id,
                  ts_name, tot_occupied, bin_occupied, tot_free, curr_available, ext_available)
    select :p_dbgdp_id,
           q3.tablespace_name, tot_occupied, bin_occupied, tot_free, curr_available, ext_available from
          (select tablespace_name, sum(bytes) tot_occupied, sum(case when (segment_name like 'BIN%') then bytes else 0 end) bin_occupied
             from dba_segments<DBLINK>
            where tablespace_name in (<TSLIST>)
            group by tablespace_name) q1,
          (select tablespace_name, sum(bytes) tot_free
             from dba_free_space<DBLINK>
            where tablespace_name in (<TSLIST>)
            group by tablespace_name) q2,
          (select tablespace_name, sum(user_bytes) curr_available,
                  sum(case when autoextensible = 'YES' then maxbytes else user_bytes end) ext_available
             from dba_data_files<DBLINK>
            where tablespace_name in (<TSLIST>)
            group by tablespace_name) q3
    where q2.tablespace_name(+)=q3.tablespace_name and q1.tablespace_name(+)=q3.tablespace_name]';

    l_segment_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_objects
            (owner,  object_id,  data_object_id,  object_name,  subobject_name,  object_type,   tablespace_name,   created, size_bytes, segment_type)
    select <OWNER_COLUMN>,o.object_id,o.data_object_id,o.object_name, o.subobject_name,o.object_type, s.tablespace_name, o.created, s.bytes, s.segment_type
      from <VIEWPREF>_segments<DBLINK> s, <VIEWPREF>_objects<DBLINK> o
     where s.segment_name(+)=o.object_name
       <VIEWPREF_FILTERS> and s.owner(+)=o.owner and o.owner in (<OWNER_LIST>)
       and decode(s.partition_name,o.subobject_name,1,0)=1
       and o.object_type not in ('VIEW','SEQUENCE','FUNCTION','TYPE','TRIGGER','PACKAGE','PACKAGE BODY','PROCEDURE','JOB','RULE','SYNONYM','DATABASE LINK','SQL TRANSLATION PROFILE',
       'TYPE BODY','CHAIN','PROGRAM','RULE SET','EVALUATION CONTEXT','MATERIALIZED VIEW')
       and case
             when o.object_type='LOB' and s.segment_type='LOBSEGMENT' then 1
             when o.object_type='INDEX' and s.segment_type='LOBINDEX' then 1
             when o.object_type='TABLE' and s.segment_type='NESTED TABLE' then 1
             when o.object_type=s.segment_type then 1
             else 0
            end = 1]';

    l_table_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_tables (owner,table_name,cluster_name,iot_name,iot_type)
    select <OWNER_COLUMN>,table_name,cluster_name,iot_name,iot_type
    from <VIEWPREF>_tables<DBLINK> o <VIEWPREF_FILTERS> where o.owner in (<OWNER_LIST>)]';

    l_index_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_indexes (owner, index_name, index_type, table_owner, table_name, table_type)
    select  <OWNER_COLUMN>, index_name, index_type, table_owner, table_name, table_type
    from <VIEWPREF>_indexes<DBLINK> o
    where segment_created in ('YES','N/A') and TEMPORARY = 'N' <VIEWPREF_FILTERS> and owner in (<OWNER_LIST>) ]';

    l_lob_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_lobs (owner, table_name, column_name, segment_name, tablespace_name, index_name)
    select  <OWNER_COLUMN>, table_name, column_name, segment_name, tablespace_name, index_name
    from <VIEWPREF>_lobs<DBLINK> o where segment_created = 'YES' <VIEWPREF_FILTERS> and owner in (<OWNER_LIST>)]';

    l_lob_ps1_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_lob_ps (table_owner, table_name, column_name, lob_name, part_name,      lob_part_name,      lob_indpart_name, tablespace_name)
    select <OWNER_COLUMN>, table_name, column_name, lob_name, partition_name, lob_partition_name, lob_indpart_name, tablespace_name
    from <VIEWPREF>_lob_partitions<DBLINK>
    where segment_created = 'YES' <VIEWPREF_FILTERS> and table_owner in (<OWNER_LIST>)]';

    l_lob_ps2_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_lob_ps  (table_owner, table_name, column_name, lob_name, lob_part_name,      sub_part_name,     lob_subpart_name,      lob_indsubpart_name, tablespace_name)
    select <OWNER_COLUMN>, table_name, column_name, lob_name, lob_partition_name, subpartition_name, lob_subpartition_name, lob_indsubpart_name, tablespace_name
    from <VIEWPREF>_lob_subpartitions<DBLINK>
    where segment_created = 'YES' <VIEWPREF_FILTERS> and table_owner in (<OWNER_LIST>)]';

    l_nt_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_nt (owner, table_name, parent_table_name, parent_table_column)
    select <OWNER_COLUMN>, table_name, parent_table_name, parent_table_column from <VIEWPREF>_nested_tables<DBLINK> o <VIEWPREF_FILTERS> where owner in (<OWNER_LIST>)]';

    l_cluster_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_clusters (owner, cluster_name, cluster_type)
    select <OWNER_COLUMN>, cluster_name, cluster_type from <VIEWPREF>_clusters<DBLINK> o <VIEWPREF_FILTERS> where owner in (<OWNER_LIST>)]';

    l_xmltbl_sql varchar2(4000) := q'[insert into opas_ot_tmp_dbg_xml (owner, table_name, xmlschema_name, schema_owner, element_name, storage_type)
    select <OWNER_COLUMN>, table_name, xmlschema, schema_owner, element_name, storage_type from <VIEWPREF>_xml_tables<DBLINK> o <VIEWPREF_FILTERS> where owner in (<OWNER_LIST>)]';

    function preprocess_sql(p_sql_tmpl varchar2, p_owner_column varchar2) return varchar2
    is
    begin
      return replace(replace(replace(replace(replace(p_sql_tmpl,'<DBLINK>',l_ora_dblink),
                                                                '<VIEWPREF>',l_view_prefix),
                                                                '<VIEWPREF_FILTERS>',l_view_prefix_filter),
                                                                '<OWNER_COLUMN>',p_owner_column),
                                                                '<OWNER_LIST>',l_owner_list);
    end;

  begin
    delete from opas_ot_tmp_dbg_objects;
    delete from opas_ot_tmp_dbg_indexes;
    delete from opas_ot_tmp_dbg_lobs;
    delete from opas_ot_tmp_dbg_lob_ps;
    delete from opas_ot_tmp_dbg_nt;
    delete from opas_ot_tmp_dbg_tables;
    delete from opas_ot_tmp_dbg_clusters;
    commit;

    select * into l_dbgm from opas_ot_dbg_monitor where dbg_id = p_obj_id;

    DBMS_UTILITY.COMMA_TO_TABLE (
        list   => l_dbgm.scheme_list,
        tablen => l_tbln,
        tab    => l_users);

    l_dblink_user := COREMOD_API.get_dblink_user(l_dbgm.dblink);

    if l_users.count=1 and l_users(1) = l_dblink_user then
      l_view_prefix := 'user';
      l_view_prefix_filter := '-- ';
      l_owner_column := q'[']' || l_dblink_user || q'[']';
    else
      l_view_prefix := 'dba';
      l_view_prefix_filter := '';
      l_owner_column := q'[o.owner]';
      l_owner_column2 := q'[table_owner]';
    end if;

    for i in 1..l_tbln loop
      l_owner_list := l_owner_list || ',' || q'[']' || l_users(i) || q'[']';
    end loop;
    l_owner_list := ltrim(l_owner_list,',');

    l_ora_dblink := COREMOD_API.get_dblink_for_query(l_dbgm.dblink);

    insert into opas_ot_dbg_datapoint (dbg_id, snapped) values (l_dp_obj, systimestamp) returning dbgdp_id into l_dbgdp_id;

    l_sql := preprocess_sql(l_segment_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_table_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_index_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_lob_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_lob_ps1_sql, l_owner_column2);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_lob_ps2_sql, l_owner_column2);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_nt_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_cluster_sql, l_owner_column);
    execute immediate l_sql;

    l_sql := preprocess_sql(l_xmltbl_sql, l_owner_column);
    execute immediate l_sql;

    begin
      if l_dbgm.dblink = COREMOD_API.gLocalDBLink then
        l_tblsp_sql:=replace(l_tblsp_sql,'<DBLINK>',null);
      else
        l_tblsp_sql:=replace(l_tblsp_sql,'<DBLINK>',l_ora_dblink);
      end if;

      select listagg(''''||tablespace_name||'''',',')within group (order by tablespace_name)
        into l_tblsp_list
        from (select unique tablespace_name from opas_ot_tmp_dbg_objects where tablespace_name is not null);

      l_sql := replace(l_tblsp_sql, '<TSLIST>', l_tblsp_list);
      execute immediate l_sql using l_dbgdp_id;

    exception
      when others then COREMOD_LOG.log(sqlerrm); COREMOD_LOG.log(l_sql); COREMOD_LOG.log(l_tblsp_list);
    end;

    l_sql := null;

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_objects s
    on (t.object_id=s.object_id and decode(t.data_object_id,s.data_object_id,1,0)=1)
    when not matched then insert
      (t.version_dp_id, t.owner, t.object_id, t.data_object_id, t.object_name, t.subobject_name, t.object_type, t.tablespace_name, t.created, t.segment_type)
    values
      (l_dbgdp_id,      s.owner, s.object_id, s.data_object_id, s.object_name, s.subobject_name, s.object_type, s.tablespace_name, s.created, s.segment_type);

    merge into opas_ot_tmp_dbg_objects t
    using (select s.object_id, s.data_object_id, max(dbgobj_id) dp_id
             from opas_ot_dbg_objects s, opas_ot_dbg_datapoint dp
            where s.version_dp_id = dp.dbgdp_id
              and dp.dbg_id = l_dp_obj
            group by s.object_id, s.data_object_id) s
    on ( t.object_id=s.object_id and decode(t.data_object_id,s.data_object_id,1,0)=1)
    when matched then update set t.dbgobj_id = s.dp_id;

    insert into opas_ot_dbg_seg_sizes
         (   dbgdp_id,    dbgobj_id,    size_bytes)
    select l_dbgdp_id, ts.dbgobj_id, ts.size_bytes
      from opas_ot_tmp_dbg_objects ts where size_bytes is not null and dbgobj_id is not null;

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_clusters s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.cluster_name and t.object_type in ('CLUSTER'))
    when matched then update set
      t.prnt_table_owner=s.owner,
      t.prnt_table=s.cluster_name,
      t.prnt_table_type=t.object_type,
      t.object_class='CLUSTER TYPE: '||s.cluster_type;

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_tables s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.table_name and t.object_type in ('TABLE','TABLE PARTITION','TABLE SUBPARTITION'))
    when matched then update set
      t.prnt_table_owner=s.owner,
      t.prnt_table=coalesce(s.iot_name,s.table_name),
      t.prnt_table_type=nvl2(s.iot_type,'TABLE: INDEX ORGANIZED',case when s.cluster_name is null then 'TABLE: HEAP' else 'TABLE: CLUSTERED' end),
      t.object_class=coalesce(s.iot_type,'TABLE SEGMENT');

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_xml s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.table_name and t.object_type in ('TABLE'))
    when matched then update set
      t.prnt_table_owner=s.owner,
      t.prnt_table=s.table_name,
      t.prnt_table_type='TABLE: XML HEAP',
      t.object_class='TABLE SEGMENT';

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_indexes s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.index_name and t.object_type in ('INDEX','INDEX PARTITION','INDEX SUBPARTITION'))
    when matched then update set
      t.prnt_table_owner=s.table_owner,
      t.prnt_table=s.table_name,
      t.object_class=case when s.index_type in ( 'NORMAL', 'LOB' ) then 'INDEX: '||s.index_type else s.index_type end;

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_lobs s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.segment_name and t.object_type = 'LOB')
    when matched then update set
      t.prnt_table_owner=s.owner,
      t.prnt_table=s.table_name,
      t.prnt_table_col=s.column_name,
      t.object_class='LOBSEGMENT';

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_lob_ps s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.table_owner and t.object_name=s.lob_name and t.subobject_name=s.lob_part_name and t.object_type = 'LOB PARTITION')
    when matched then update set
      t.prnt_table_owner=s.table_owner,
      t.prnt_table=s.table_name,
      t.prnt_table_col=s.column_name,
      t.object_class='LOB PARTITION';

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_lob_ps s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.table_owner and t.object_name=s.lob_name and t.subobject_name=s.lob_subpart_name and t.object_type = 'LOB SUBPARTITION')
    when matched then update set
      t.prnt_table_owner=s.table_owner,
      t.prnt_table=s.table_name,
      t.prnt_table_col=s.column_name,
      t.object_class='LOB SUBPARTITION';

    merge into opas_ot_dbg_objects t
    using opas_ot_tmp_dbg_nt s
    on (t.version_dp_id = l_dbgdp_id and t.owner=s.owner and t.object_name=s.table_name and t.object_type = 'TABLE' and t.segment_type = 'NESTED TABLE')
    when matched then update set
      t.prnt_table_owner=s.owner,
      t.prnt_table=s.parent_table_name,
      t.prnt_table_col=s.parent_table_column,
      t.object_class='NESTED TABLE';

    update opas_ot_dbg_objects o
      set prnt_table_type='TABLE: NESTED'
      where version_dp_id = l_dbgdp_id and exists (select 1 from opas_ot_tmp_dbg_nt i where o.owner=i.owner and o.object_name=i.table_name)
        and prnt_table_type is null;


    update opas_ot_dbg_objects o
      set prnt_table=(select parent_table_name from opas_ot_tmp_dbg_nt i where o.prnt_table_owner=i.owner and o.prnt_table=i.table_name),
          prnt_table_type='TABLE: NESTED'
      where version_dp_id = l_dbgdp_id and exists (select 1 from opas_ot_tmp_dbg_nt i where o.prnt_table_owner=i.owner and o.prnt_table=i.table_name)
        and (prnt_table is null or prnt_table_type is null);


    update opas_ot_dbg_objects o
      set prnt_table_type=(select prnt_table_type from opas_ot_dbg_objects i where prnt_table_type is not null and i.prnt_table=o.prnt_table and rownum=1 and prnt_table_type<>'TABLE: NESTED')
      where version_dp_id = l_dbgdp_id and prnt_table_type is null;

    update opas_ot_dbg_objects o
      set prnt_table_type=(select IOT_TYPE from opas_ot_tmp_dbg_tables i where i.table_name=o.prnt_table and i.owner=o.owner and rownum=1)
      where version_dp_id = l_dbgdp_id and prnt_table_type is null;

    update opas_ot_dbg_objects o
      set   prnt_table = (select cluster_name from opas_ot_tmp_dbg_tables i where o.prnt_table_owner=i.owner and o.prnt_table=i.table_name and i.cluster_name is not null) ||': '||prnt_table,
            prnt_table_type='TABLE: CLUSTERED'
      where version_dp_id = l_dbgdp_id and prnt_table_type is null
        and exists (select 1 from opas_ot_tmp_dbg_tables i where o.prnt_table_owner=i.owner and o.prnt_table=i.table_name and i.cluster_name is not null);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error COREOBJ_DB_GROWTH.take_snapshot_i ('||p_obj_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      if l_sql is not null then
        coremod_tasks.log(l_sql);
        raise_application_error(-20000, 'COREOBJ_DB_GROWTH.take_snapshot_i('||p_obj_id||') failed. See logs for more details.');
      end if;
  end;

  function get_alert_graph_query(p_alert_id        opas_ot_dbg_monitor_al_cfg.alert_id%type,
                                 p_start_dt in out varchar2,
                                 p_end_dt   in out varchar2) return varchar2
  is
  begin
    for i in (select x.*
                from opas_ot_dbg_monitor_al_cfg x
               where alert_id = p_alert_id)
    loop
      null;
/*      case p_alert.alert_type
        when alrtSIZELIMIT then
          select sum(seg_occupied) into l_res from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp;
        when alrtDELTALIMIT then
          select s_last - s_prev into l_res from
          (select sum(seg_occupied) s_last from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp) lastdp,
          (select sum(seg_occupied) s_prev from opas_ot_dbg_ts_sizes where dbgdp_id = l_prev_dp) prevdp;
        when alrtFREELIMIT then
          select sum(tot_free) into l_res from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp;
          return case when l_res < p_alert.alert_limit then l_res else null end;
        when alrtOUTOFSPACE then
          select round(s_free/decode((s_last - s_prev),0,null,(s_last - s_prev)),3) into l_res from
          (select sum(seg_occupied) s_last from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp) lastdp,
          (select sum(seg_occupied) s_prev from opas_ot_dbg_ts_sizes where dbgdp_id = l_prev_dp) prevdp,
          (select sum(tot_free) s_free from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp);
          return case when l_res < p_alert.alert_limit then l_res else null end;
        when alrtREGEXP then
          l_sql := q'[with objects as
 (select *
    from opas_ot_dbg_objects o, opas_ot_dbg_datapoint dp
   where o.version_dp_id = dp.dbgdp_id
     and dp.dbg_id = :p_dbg_id
     and (]' || p_alert.alert_expr || q'[))
select res from (
select dbgdp_id, size_bytes - lag(size_bytes) over(order by snapped) res
  from (select dp.dbgdp_id, dp.snapped, sum(s.size_bytes) size_bytes
          from objects o, opas_ot_dbg_seg_sizes s, opas_ot_dbg_datapoint dp
         where o.dbgobj_id = s.dbgobj_id
           and s.dbgdp_id = dp.dbgdp_id
           and dp.dbg_id = :p_dbg_id
           and dp.dbgdp_id in (:p_dp1, :p_dp2)
         group by dp.dbgdp_id, dp.snapped)) where dbgdp_id = :p_dp2
     ]';
          execute immediate l_sql into l_res using in p_alert.dbg_id, p_alert.dbg_id, l_prev_dp, l_last_dp, l_last_dp;
        else
          l_res := null;
      end case;*/

    end loop;
    return null;
  end;

  function calc_alert_i(p_alert     opas_ot_dbg_monitor_al_cfg%rowtype) return number
  is
    l_last_dp opas_ot_dbg_datapoint.dbgdp_id%type;
    l_prev_dp opas_ot_dbg_datapoint.dbgdp_id%type;
    refcrsr sys_refcursor;
    l_sql varchar2(1000);
    l_res number;
  begin
      open refcrsr for select dbgdp_id from opas_ot_dbg_datapoint where dbg_id = p_alert.dbg_id order by snapped desc;
      fetch refcrsr into l_last_dp;
      fetch refcrsr into l_prev_dp;
      close refcrsr;

      case p_alert.alert_type
        when alrtSIZELIMIT then
          select sum(seg_occupied) into l_res from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp;
        when alrtDELTALIMIT then
          select s_last - s_prev into l_res from
          (select sum(seg_occupied) s_last from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp) lastdp,
          (select sum(seg_occupied) s_prev from opas_ot_dbg_ts_sizes where dbgdp_id = l_prev_dp) prevdp;
        when alrtFREELIMIT then
          select sum(tot_free) into l_res from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp;
          return case when l_res < p_alert.alert_limit then l_res else null end;
        when alrtOUTOFSPACE then
          select round(s_free/decode((s_last - s_prev),0,null,(s_last - s_prev)),3) into l_res from
          (select sum(seg_occupied) s_last from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp) lastdp,
          (select sum(seg_occupied) s_prev from opas_ot_dbg_ts_sizes where dbgdp_id = l_prev_dp) prevdp,
          (select sum(tot_free) s_free from opas_ot_dbg_ts_sizes where dbgdp_id = l_last_dp);
          return case when l_res < p_alert.alert_limit then l_res else null end;
        when alrtREGEXP then
          l_sql := q'[with objects as
 (select *
    from opas_ot_dbg_objects o, opas_ot_dbg_datapoint dp
   where o.version_dp_id = dp.dbgdp_id
     and dp.dbg_id = :p_dbg_id
     and (]' || p_alert.alert_expr || q'[))
select res from (
select dbgdp_id, size_bytes - lag(size_bytes) over(order by snapped) res
  from (select dp.dbgdp_id, dp.snapped, sum(s.size_bytes) size_bytes
          from objects o, opas_ot_dbg_seg_sizes s, opas_ot_dbg_datapoint dp
         where o.dbgobj_id = s.dbgobj_id
           and s.dbgdp_id = dp.dbgdp_id
           and dp.dbg_id = :p_dbg_id
           and dp.dbgdp_id in (:p_dp1, :p_dp2)
         group by dp.dbgdp_id, dp.snapped)) where dbgdp_id = :p_dp2
     ]';
          execute immediate l_sql into l_res using in p_alert.dbg_id, p_alert.dbg_id, l_prev_dp, l_last_dp, l_last_dp;
        else
          l_res := null;
      end case;
      return case when l_res > p_alert.alert_limit then l_res else null end;
  end;

  function calc_alert(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type) return number
  is
  begin
    for i in (select x.*
                from opas_ot_dbg_monitor_al_cfg x
               where alert_id = p_alert_id)
    loop
      return calc_alert_i(i);
    end loop;
  end;

  procedure take_test_snapshot(p_obj_id       opas_objects.obj_id%type)
  is
  BEGIN
    take_snapshot_i(p_obj_id);
    rollback;
  end;

  procedure take_snapshot(p_obj_id       opas_objects.obj_id%type)
  is
    ex_no_connection exception;
    pragma exception_init(ex_no_connection,-12154); --ORA-12154

    l_metric number;
    L_ALERT_ID number;
    l_msg      opas_dictionary.display_val%type;
    l_db       opas_ot_dbg_monitor.dblink%type;
    l_owner    opas_objects.obj_owner%type;
    l_ts       timestamp := systimestamp;
  begin
    take_snapshot_i(p_obj_id);
    commit;
    for i in (select * from opas_ot_dbg_monitor_al_cfg where dbg_id = p_obj_id) loop
      l_metric := calc_alert_i(i);
      if l_metric is not null then
        select obj_owner, dblink into l_owner, l_db from opas_objects o, opas_ot_dbg_monitor m where obj_id = p_obj_id and obj_id = dbg_id;
        if i.alert_type = alrtREGEXP then
          l_msg := i.alert_name;
        else
          select display_val into l_msg from opas_dictionary where dic_name='DBGALERT' and val = i.alert_type;
        end if;
          COREMOD_ALERTS.add_alert (
            P_ALERT_ID   => L_ALERT_ID,
            P_ALERT_TYPE => l_msg, --i.alert_type,
            p_created    => l_ts,
            P_OWNER      => l_owner,
            P_MESSAGE    => 'DBG Alert for "' || l_db ||'". Limit exceeded. Current: '||
                            l_metric||' ' || i.alert_measur || '; Limit: '||i.ALERT_LIMIT ||' ' || i.alert_measur ||'.',
            P_LINK_PAGE  => 5002,
            P_LINK_PARAM => i.alert_id) ;
      end if;
    end loop;
  exception
    when ex_no_connection then
      coremod_tasks.log('COREOBJ_DB_GROWTH.take_snapshot('||p_obj_id||'); '||sqlerrm);
  end;

  procedure add_alert_limit(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type,
                            p_dbg_id       opas_ot_dbg_monitor_al_cfg.dbg_id%type,
                            p_alert_name   opas_ot_dbg_monitor_al_cfg.alert_name%type,
                            p_alert_type   opas_ot_dbg_monitor_al_cfg.alert_type%type,
                            p_alert_expr   opas_ot_dbg_monitor_al_cfg.alert_expr%type,
                            p_alert_limit  opas_ot_dbg_monitor_al_cfg.alert_limit%type)
  is
    l_ts timestamp := systimestamp;
  begin
    if p_alert_id is not null then
      for i in (select x.*
                  from opas_ot_dbg_monitor_al_cfg x
                 where alert_id = p_alert_id
                   and (decode(alert_limit,p_alert_limit,1,0)=0
                     or decode(alert_expr,p_alert_expr,1,0)=0))
      loop

        update opas_ot_dbg_monitor_al_cfg set
               actual_start = l_ts,
               alert_expr = p_alert_expr,
               alert_limit = p_alert_limit
         where alert_id=i.alert_id;

        insert into opas_ot_dbg_monitor_al_cfg_hst
          (alert_id, dbg_id, alert_name, alert_type, alert_expr, alert_limit, actual_start, actual_end, alert_measur)
        values
          (i.alert_id, i.dbg_id, i.alert_name, i.alert_type, i.alert_expr, i.alert_limit, i.actual_start, l_ts, i.alert_measur);

      end loop;
    else
      insert into opas_ot_dbg_monitor_al_cfg
        (dbg_id, alert_name, alert_type, alert_expr, alert_limit, actual_start, alert_measur)
      values
        (p_dbg_id, p_alert_name, p_alert_type, p_alert_expr, p_alert_limit, l_ts, (select sparse1 from opas_dictionary where dic_name = 'DBGALERT' and val = p_alert_type));

    end if;

  end;

  procedure drop_alert_limit(p_alert_id     opas_ot_dbg_monitor_al_cfg.alert_id%type)
  is
  begin

    for i in (select x.*
                from opas_ot_dbg_monitor_al_cfg x
               where alert_id = p_alert_id)
    loop

      insert into opas_ot_dbg_monitor_al_cfg_hst
        (alert_id, dbg_id, alert_name, alert_type, alert_expr, alert_limit, actual_start, actual_end, alert_measur)
      values
        (i.alert_id, i.dbg_id, i.alert_name, i.alert_type, i.alert_expr, i.alert_limit, i.actual_start, systimestamp, i.alert_measur);

    end loop;
    delete from opas_ot_dbg_monitor_al_cfg where alert_id=p_alert_id;

  end;
end COREOBJ_DB_GROWTH;
/
