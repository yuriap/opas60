

CREATE OR REPLACE
package body coreobj_asha_cube is

  gLockName varchar2(256) := 'OPASASHAPART';

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status varchar2(100);
  begin
      select acube.status||'; R: '||
      decode(ranges.range_status,null,'N/A',ranges.range_status || '; '|| to_char(START_TIME_UTC,'YYYY/Mon/DD HH24:MI') || '-' ||to_char(END_TIME_UTC,'YYYY/Mon/DD HH24:MI'))
      into l_status
      from (select DBLINK||' C: '||status status from OPAS_OT_ASHACUBE where ASHACUBE_ID = p_obj_id) acube,
           (select listagg(status || ':' || cnt, '; ') within group(order by status) range_status, min(START_TIME_UTC) START_TIME_UTC, max(END_TIME_UTC) END_TIME_UTC
              from (select status, count(1) cnt, min(START_TIME_UTC) START_TIME_UTC, max(END_TIME_UTC) END_TIME_UTC from OPAS_OT_ASHACUBE_RANGES ra, OPAS_OT_ASHACUBE_REF refs
                     where refs.ASHARANGE_ID = ra.ASHARANGE_ID and refs.ASHACUBE_ID = p_obj_id group by status)) ranges;

    return l_status;
  exception
    when no_data_found then return 'No data found';
  end;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null)
  is
  begin
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otASHA_CUBE,
      P_OBJ_NAME  => nvl(p_name, 'ASHA Cube ' ||to_char(sysdate,'YYYYMMDD HH24:MI')),
      P_OBJ_DESCR => p_descr,
      p_obj_owner => p_owner) ;
    INSERT INTO opas_ot_ashacube
           ( ashacube_id, dblink, start_time_utc, end_time_utc, status,                        created, modified)
    VALUES (P_OBJ_ID,     null,   null,           null,         COREOBJ_ASHA_CUBE_CALCS.csNEW, default, null);
  end;

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null)
  is
  begin
    COREOBJ_API.edit_descr  (p_obj_id  => p_obj_id,
                             p_obj_name => p_name,
                             p_obj_descr => p_descr,
                             p_obj_owner => p_owner);
  end;

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N')
  is
    l_dblink opas_db_links.db_link_name%type;
  begin

    delete from opas_ot_ashacube_ash r
     where asharange_id in (select asharange_id from opas_ot_ashacube_ref where ashacube_id = p_obj_id)
       and not exists (select 1 from opas_ot_ashacube_ref i where i.ASHARANGE_ID = r.ASHARANGE_ID and ashacube_id != p_obj_id);

    delete from opas_ot_ashacube_ranges r
     where asharange_id in (select asharange_id from opas_ot_ashacube_ref where ashacube_id = p_obj_id)
       and not exists (select 1 from opas_ot_ashacube_ref i where i.ASHARANGE_ID = r.ASHARANGE_ID and ashacube_id != p_obj_id);

    delete from opas_ot_ashacube_ref  where ashacube_id = p_obj_id;
    delete from opas_ot_ashacube where ashacube_id = p_obj_id returning DBLINK into l_dblink;

    COREOBJ_API.remove(p_obj_id, p_cascade);
    --!!!! TODO
    --stop running jobs
  end;

  function create_subpart_name (p_dblink opas_db_links.db_link_name%type,
                                p_max_date date) return varchar2
  is
  begin
    return p_dblink||'_'||to_char(p_max_date,'YYYYMMDD');
  end;

  procedure archive_table(p_dblink opas_db_links.db_link_name%type,
                          p_table_name varchar2,
                          p_part_col   varchar2)
  is
    l_part_name varchar2(128);
    l_sub_part_name varchar2(128);

    l_data_exists number;
    l_data_to_split varchar2(100);
    l_sql varchar2(32765);

    procedure split_subpartition(p_part_name varchar2,
                                 p_sub_part_name varchar2,
                                 p_date_before varchar2 default null)
    is
      l_crsr sys_refcursor;
      l_sql varchar2(32765); l_sql1 varchar2(32765);
      l_dd  varchar2(100);
      l_date date;
    begin
      l_sql1 := q'[select to_char(trunc(]'||p_part_col||q'[)+1,'YYYYMMDD') dd, trunc(]'||p_part_col||q'[)+1 from ]'||
                                                  p_table_name||q'[ subpartition (]'||
                                                  p_sub_part_name||q'[) ]'||
                                                  case when p_date_before is not null then ' where '||p_part_col||q'[ < to_date(']'||p_date_before||q'[','YYYYMMDD')-1]' else null end ||
                                                  'group by trunc('||p_part_col||q'[) order by 1]';
      coremod_tasks.log('coreobj_asha_cube.split_subpartition '||l_sql1);
      open l_crsr for l_sql1;
      loop
        fetch l_crsr into l_dd, l_date;
        exit when l_crsr%notfound;
        begin
          l_sql := 'alter table '||p_table_name||' split subpartition '||p_sub_part_name||q'[ at (TO_DATE(']' || l_dd || q'[', 'YYYYMMDD')) into (subpartition ]'||
                    --p_dblink||'_'||l_dd
                    create_subpart_name(p_dblink, l_date)
                    ||', subpartition '||p_sub_part_name||')';
          execute immediate l_sql;
        exception
          when others then
            --l_is_error := true;
            coremod_tasks.log('Error coreobj_asha_cube.archive_table '||p_table_name||' ('||p_dblink||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            coremod_tasks.log('Error coreobj_asha_cube.archive_table '||p_table_name||' ('||p_dblink||'): '||sqlerrm||chr(10)||l_sql);
            --raise;
        end;
      end loop;
      close l_crsr;
    end;
  begin
    l_part_name := get_part_name(p_table_name, '%'||upper(p_dblink)||'%');
    l_sub_part_name := get_subpart_name(p_table_name, l_part_name, '%MAXVALUE%');
coremod_tasks.log('coreobj_asha_cube.archive_table '||p_table_name||' ('||p_dblink||'): '|| l_part_name ||'; '||l_sub_part_name);

    if l_sub_part_name is not null then

      split_subpartition(l_part_name, l_sub_part_name);

      for i in (select * from user_tab_subpartitions where table_name = p_table_name and partition_name=l_part_name and subpartition_name<>l_sub_part_name order by subpartition_name)
      loop
        l_data_to_split := ltrim(i.subpartition_name,p_dblink||'_');
        l_sql := q'[select count(1) from dual where exists (select 1 from ]'||p_table_name||q'[ subpartition (]'||i.subpartition_name||q'[) where ]'||p_part_col||q'[ < to_date(:dt,'YYYYMMDD')-1)]';
coremod_tasks.log('coreobj_asha_cube.archive_table '||l_sql);
        execute immediate l_sql
           into l_data_exists using l_data_to_split;
        coremod_tasks.log('coreobj_asha_cube.archive_table '||p_table_name||' ('||p_dblink||'): '|| l_part_name ||'; '||i.subpartition_name||': detected "'||l_data_exists||'" data to split for date '||l_data_to_split);

        if l_data_exists > 0 then
          split_subpartition(l_part_name, i.subpartition_name, l_data_to_split);
        end if;
      end loop;
    end if;

  end;

  procedure drop_empty_partitions(p_dblink opas_db_links.db_link_name%type,
                                  p_table_name varchar2,
                                  p_part_col   varchar2)
  is
    l_part_name varchar2(128);
    l_sub_part_name varchar2(128);
    l_exists number;
    l_sql varchar2(32765);
  begin
    l_part_name := get_part_name(p_table_name, '%'||upper(p_dblink)||'%');
    l_sub_part_name := get_subpart_name(p_table_name, l_part_name, '%MAXVALUE%');

    for i in (select subpartition_name from user_tab_subpartitions where table_name=p_table_name and partition_name=l_part_name and subpartition_name<>l_sub_part_name)
    loop
      execute immediate 'select count(1) from dual where exists (select 1 from '|| p_table_name ||' subpartition('|| i.subpartition_name ||'))' into l_exists;
      if l_exists =  0 then
        l_sql := 'alter table '|| p_table_name ||' drop subpartition '||i.subpartition_name;
        execute immediate l_sql;
      end if;
    end loop;
  end;

  procedure maintain_index_subpart(p_table_name varchar2)
  is
  begin
    for i in (select * from user_ind_subpartitions where status<>'USABLE' and index_name in (select index_name from user_indexes where table_name=upper(p_table_name)))
    loop
      execute immediate 'alter index '||i.index_name||' rebuild subpartition '||i.subpartition_name;
    end loop;
  end;

  procedure archive_data_to_subpartition(p_dblink opas_db_links.db_link_name%type)
  is
    l_is_error boolean := false;

    l_part_name varchar2(128);
    l_sub_part_name varchar2(128);

    l_crsr sys_refcursor;
    l_dd  varchar2(100);
    l_sql varchar2(32765);
    l_data_exists number;
  begin
    coremod_api.lock_resource(p_resource_name => gLockName,
                              p_mode => 6,
                              p_timeout => 600,
                              p_release_on_commit => false);

    archive_table(p_dblink => p_dblink,
                  p_table_name => 'OPAS_OT_ASHACUBE_ASH',
                  p_part_col => 'SAMPLE_TIME_UTC');

    archive_table(p_dblink => p_dblink,
                  p_table_name => 'OPAS_OT_ASHACUBE_METRICS',
                  p_part_col => 'END_TIME_UTC');

    archive_table(p_dblink => p_dblink,
                  p_table_name => 'OPAS_OT_ASHACUBE_STATS',
                  p_part_col => 'TS_UTC');

    drop_empty_partitions(p_dblink => p_dblink,
                          p_table_name => 'OPAS_OT_ASHACUBE_ASH',
                          p_part_col => 'SAMPLE_TIME_UTC');

    drop_empty_partitions(p_dblink => p_dblink,
                          p_table_name => 'OPAS_OT_ASHACUBE_METRICS',
                          p_part_col => 'END_TIME_UTC');

    drop_empty_partitions(p_dblink => p_dblink,
                          p_table_name => 'OPAS_OT_ASHACUBE_STATS',
                          p_part_col => 'TS_UTC');

    maintain_index_subpart(p_table_name => 'OPAS_OT_ASHACUBE_ASH');
    maintain_index_subpart(p_table_name => 'OPAS_OT_ASHACUBE_METRICS');
    maintain_index_subpart(p_table_name => 'OPAS_OT_ASHACUBE_STATS');

    merge into OPAS_OBJECTS t
    using (
      select obj_id, sum(size_bytes) size_bytes from (
      SELECT
        o.obj_id,
        (select sum(bytes) from user_segments where partition_name = coreobj_asha_cube.create_subpart_name(asha.dblink,trunc(asha_rng.end_time_utc)+1)) size_bytes
      FROM
             opas_objects o
        INNER JOIN opas_ot_ashacube asha ON o.obj_id = asha.ashacube_id
        INNER JOIN opas_ot_ashacube_ref asha_ref ON asha.ashacube_id = asha_ref.ashacube_id
        INNER JOIN opas_ot_ashacube_ranges asha_rng ON asha_ref.asharange_id = asha_rng.asharange_id
      --where obj_id=23998
      group by
        o.obj_id,
        asha.dblink,
        trunc(asha_rng.end_time_utc))
      group by obj_id) s
    on (t.obj_id = s.obj_id)
    when matched then update set t.OBJ_SIZE = s.size_bytes;
    commit;

    coremod_api.release_resource;

    if l_is_error then raise_application_error(-20000,'Splitting error: see logs for more details'); end if;
  exception
    when others then
      coremod_api.release_resource;
      coremod_tasks.log('Error coreobj_asha_cube.archive_data_to_subpartition: '||l_sql);
      raise;
  end;

  procedure cleanup_ranges
  is
    l_links TABLEOFSTRINGS;
  begin
    delete from opas_ot_ashacube_ranges d
     where created + NUMTODSINTERVAL(COREMOD_API.getconf(P_KEY => 'ASHARANGE', P_MODULE => 'OPASCORE'), 'DAY') < systimestamp
       and not exists (select 1 from opas_ot_ashacube_ref r where r.asharange_id = d.asharange_id)
       and PRESERVE_POLICY = 'N';
    commit;

    select unique dblink bulk collect into l_links from OPAS_OT_ASHACUBE;
    for i in 1..l_links.count loop
      begin
        archive_data_to_subpartition(l_links(i));
      exception
        when others then COREMOD_TASKS.log('ASHA partitions archie error for '||l_links(i)||' '||sqlerrm);
      end;
    end loop;
  end;

/*
  procedure archive_data_to_subpartition_old(p_dblink opas_db_links.db_link_name%type)
  is
    l_is_error boolean := false;

    l_part_name varchar2(128);
    l_sub_part_name varchar2(128);

    l_crsr sys_refcursor;
    l_dd  varchar2(100);
    l_sql varchar2(32765);
    l_data_exists number;
  begin
    coremod_api.lock_resource(p_resource_name => gLockName,
                              p_mode => 6,
                              p_timeout => 600,
                              p_release_on_commit => false);

    l_part_name := get_part_name('OPAS_OT_ASHACUBE_ASH', '%'||upper(p_dblink)||'%');
    l_sub_part_name := get_subpart_name('OPAS_OT_ASHACUBE_ASH', l_part_name, '%MAXVALUE%');
coremod_tasks.log('coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_ASH ('||p_dblink||'): '|| l_part_name ||'; '||l_sub_part_name);
    if l_sub_part_name is not null then
      --for i in (select to_char(trunc(SAMPLE_TIME_UTC)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_ASH subpartition (l_sub_part_name) group by trunc(SAMPLE_TIME_UTC) order by 1)
      open l_crsr for q'[select to_char(trunc(SAMPLE_TIME_UTC)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_ASH subpartition (]'||l_sub_part_name||q'[) group by trunc(SAMPLE_TIME_UTC) order by 1]';
      loop
        fetch l_crsr into l_dd;
        exit when l_crsr%notfound;
        begin
          l_sql := 'alter table OPAS_OT_ASHACUBE_ASH split subpartition '||l_sub_part_name||q'[ at (TO_DATE(']' || l_dd || q'[', 'YYYYMMDD')) into (subpartition ]'||p_dblink||'_'||l_dd||', subpartition '||l_sub_part_name||')';
          execute immediate l_sql;
        exception
          when others then
            l_is_error := true;
            coremod_tasks.log('Error coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_ASH ('||p_dblink||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            raise;
        end;
      end loop;
      close l_crsr;
    end if;

    l_part_name := get_part_name('OPAS_OT_ASHACUBE_METRICS', '%'||upper(p_dblink)||'%');
    l_sub_part_name := get_subpart_name('OPAS_OT_ASHACUBE_METRICS', l_part_name, '%MAXVALUE%');
coremod_tasks.log('coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_METRICS ('||p_dblink||'): '|| l_part_name ||'; '||l_sub_part_name);
    if l_sub_part_name is not null then
      --for i in (select to_char(trunc(end_time_utc)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_METRICS subpartition (l_sub_part_name) group by trunc(end_time_utc) order by 1)
      open l_crsr for q'[select to_char(trunc(end_time_utc)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_METRICS subpartition (]'||l_sub_part_name||q'[) group by trunc(end_time_utc) order by 1]';
      loop
        fetch l_crsr into l_dd;
        exit when l_crsr%notfound;
        begin
          l_sql := 'alter table OPAS_OT_ASHACUBE_METRICS split subpartition '||l_sub_part_name||q'[ at (TO_DATE(']' || l_dd || q'[', 'YYYYMMDD')) into (subpartition ]'|| p_dblink ||'_'|| l_dd ||', subpartition '||l_sub_part_name||')';
          execute immediate l_sql;
        exception
          when others then
            l_is_error := true;
            coremod_tasks.log('Error coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_METRICS ('||p_dblink||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            raise;
        end;
      end loop;
      close l_crsr;
    end if;

    l_part_name := get_part_name('OPAS_OT_ASHACUBE_STATS', '%'||upper(p_dblink)||'%');
    l_sub_part_name := get_subpart_name('OPAS_OT_ASHACUBE_STATS', l_part_name, '%MAXVALUE%');
coremod_tasks.log('coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_STATS ('||p_dblink||'): '|| l_part_name ||'; '||l_sub_part_name);
    if l_sub_part_name is not null then
      --for i in (select to_char(trunc(ts_utc)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_STATS subpartition (l_sub_part_name) group by trunc(ts_utc) order by 1)
      open l_crsr for q'[select to_char(trunc(ts_utc)+1,'YYYYMMDD') dd from OPAS_OT_ASHACUBE_STATS subpartition (l_sub_part_name) group by trunc(ts_utc) order by 1]';
      loop
        fetch l_crsr into l_dd;
        exit when l_crsr%notfound;
        begin
          l_sql := 'alter table OPAS_OT_ASHACUBE_STATS split subpartition '||l_sub_part_name||q'[ at (TO_DATE(']' || l_dd || q'[', 'YYYYMMDD')) into (subpartition ]'|| p_dblink ||'_'|| l_dd ||', subpartition '||l_sub_part_name||')';
          execute immediate l_sql;
        exception
          when others then
            l_is_error := true;
            coremod_tasks.log('Error coreobj_asha_cube.archive_data_to_subpartition OPAS_OT_ASHACUBE_STATS ('||p_dblink||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            raise;
        end;
      end loop;
      close l_crsr;
    end if;

    coremod_api.release_resource;

    if l_is_error then raise_application_error(-20000,'Splitting error: see logs for more details'); end if;
  exception
    when others then
      coremod_api.release_resource;
      coremod_tasks.log('Error coreobj_asha_cube.archive_data_to_subpartition: '||l_sql);
      raise;
  end;
*/
end coreobj_asha_cube;
/


