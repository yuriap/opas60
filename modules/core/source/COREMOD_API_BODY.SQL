CREATE OR REPLACE
package body COREMOD_API as

  type t_lops_rec is record(
    g_rindex    BINARY_INTEGER,
    g_slno      BINARY_INTEGER,
    g_totalwork number,
    g_sofar     number,
    g_obj       BINARY_INTEGER,
    g_op_name   varchar2(100),
    g_target_desc varchar2(100),
    g_units     varchar2(100)
  );

  type t_lops_tab is table of t_lops_rec index by pls_integer;

  g_lops_tab t_lops_tab;
  g_lops_idx number := 0;

  -- lock handle
  g_handle varchar2(512);

  function getMODNAME return varchar2 is begin return gMODNAME; end;

  procedure register(p_modname opas_modules.MODNAME%type,
                     p_moddescr opas_modules.MODDESCR%type default null,
                     p_modver opas_modules.MODVER%type,
                     p_installed opas_modules.INSTALLED%type default sysdate)
  is
  begin
    merge into opas_modules t using (select p_modname modname, p_moddescr moddescr, p_modver modver, p_installed installed from dual) s
    on (t.modname = s.modname)
    when matched then update set
      t.moddescr = nvl(s.moddescr,t.moddescr),
      t.modver = s.modver,
      t.installed = s.installed
    when not matched then insert
      (t.modname, t.moddescr, t.modver, t.installed)
    values
      (s.modname, s.moddescr, s.modver, s.installed);
    commit;
  end;

  procedure init_longops(p_op_name varchar2, p_target_desc varchar2, p_units varchar2, p_totalwork number, p_lops_ind out pls_integer)
  is
  begin
    g_lops_idx:=g_lops_idx+1;

    g_lops_tab(g_lops_idx).g_op_name     := p_op_name;
    g_lops_tab(g_lops_idx).g_target_desc := p_target_desc;
    g_lops_tab(g_lops_idx).g_units       := p_units;

    g_lops_tab(g_lops_idx).g_rindex      := dbms_application_info.set_session_longops_nohint;
    g_lops_tab(g_lops_idx).g_sofar       := 0;
    g_lops_tab(g_lops_idx).g_totalwork   := p_totalwork;
    dbms_application_info.set_session_longops(g_lops_tab(g_lops_idx).g_rindex,
                                              g_lops_tab(g_lops_idx).g_slno,
                                              g_lops_tab(g_lops_idx).g_op_name,
                                              g_lops_tab(g_lops_idx).g_obj,
                                              0,
                                              g_lops_tab(g_lops_idx).g_sofar,
                                              g_lops_tab(g_lops_idx).g_totalwork,
                                              g_lops_tab(g_lops_idx).g_target_desc,
                                              g_lops_tab(g_lops_idx).g_units);

    p_lops_ind:=g_lops_idx;
  end;

  procedure start_longops_section(p_module_name varchar2, p_action_name varchar2)
  is
  begin
    DBMS_APPLICATION_INFO.SET_MODULE ( module_name => p_module_name, action_name => p_action_name);
    coremod_tasks.log(rtrim(p_module_name||'/'||p_action_name,'/'));
  end;

  procedure end_longops_section(p_sofar number default 1, p_lops_ind pls_integer)
  is
  begin
    if p_sofar = 1 then
      g_lops_tab(p_lops_ind).g_sofar := g_lops_tab(p_lops_ind).g_sofar + p_sofar;
    else
      g_lops_tab(p_lops_ind).g_sofar := p_sofar;
    end if;
    dbms_application_info.set_session_longops(g_lops_tab(p_lops_ind).g_rindex,
                                              g_lops_tab(p_lops_ind).g_slno,
                                              g_lops_tab(p_lops_ind).g_op_name,
                                              g_lops_tab(p_lops_ind).g_obj,
                                              0,
                                              g_lops_tab(p_lops_ind).g_sofar,
                                              g_lops_tab(p_lops_ind).g_totalwork,
                                              g_lops_tab(p_lops_ind).g_target_desc,
                                              g_lops_tab(p_lops_ind).g_units);
  end;

  function getconf(p_key varchar2, p_module opas_modules.modname%type) return varchar2 RESULT_CACHE
  is
    l_res opas_config.cvalue%type;
  begin
    select cvalue into l_res from opas_config where ckey=p_key and modname=p_module;
    return l_res;
  end;

/*
  function getscript(p_script_id varchar2) return clob
  is
    l_res clob;
  begin
    select script_content into l_res from opas_scripts where script_id=p_script_id;
    return l_res;
  exception
    when no_data_found then raise_application_error(-20000,'Script "'||p_script_id||'" not found.');
  end;
*/
  function getmodver(p_module opas_modules.modname%type) return varchar2 RESULT_CACHE
  is
    l_res opas_config.cvalue%type;
  begin
    select modver into l_res from opas_modules where modname=p_module;
    return l_res;
  end;

  procedure register_dblink(p_db_link_name varchar2,
                            p_owner varchar2,
                            p_is_public varchar2,
                            p_username varchar2,
                            p_password varchar2,
                            p_connectstring varchar2)
  is
  begin
    insert into opas_db_links
      (DB_LINK_NAME,OWNER,STATUS,is_public,username,password,connstr)
    values
      (upper(p_db_link_name), upper(p_owner),
       dblNEW, case when upper(p_owner)='PUBLIC' then 'Y' else case when p_is_public = 'Y' then 'Y' else 'N' end end, p_username,p_password,p_connectstring);
  end;

  procedure edit_dblink    (p_db_link_name varchar2,
                            p_is_public varchar2,
                            p_username varchar2,
                            p_password varchar2,
                            p_connectstring varchar2)
  is
    l_dblink opas_db_links%rowtype;
  begin
    select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name) for update nowait;

    if nvl(p_username,'~^')<>nvl(l_dblink.username,'~^') or
       nvl(p_password,nvl(l_dblink.password,'~^'))<>nvl(l_dblink.password,'~^') or
       nvl(p_connectstring,'~^')<>nvl(l_dblink.connstr,'~^')
    then
      update opas_db_links set
             STATUS = dblMODIFIED,
             username = p_username,
             password = nvl(p_password,password),
             connstr = p_connectstring
       where DB_LINK_NAME = upper(p_db_link_name);
    end if;

    if l_dblink.is_public<>p_is_public and upper(l_dblink.owner)!='PUBLIC' then
      update opas_db_links set
             is_public = case when upper(owner)='PUBLIC' then 'Y' else case when p_is_public = 'Y' then 'Y' else 'N' end end
       where DB_LINK_NAME = upper(p_db_link_name);
    end if;
  end;

  procedure create_dblink(p_db_link_name varchar2, p_recreate boolean default false)
  is
    l_dblink opas_db_links%rowtype;
  begin
    if p_db_link_name=gDefaultSource then
      raise_application_error(-20000, gDefaultSource||' db link is not supposed to be created.');
    else
      select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name) for update nowait;
      if p_recreate then
        declare
          l_domain varchar2(128);
        begin
          select value into l_domain from v$parameter where name like '%domain%';
          execute immediate 'drop database link ' || case when l_domain is null then p_db_link_name else p_db_link_name ||'.'|| l_domain end;
        exception
          when others then
            COREMOD_LOG.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
            COREMOD_LOG.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            COREMOD_LOG.log(sqlerrm);
        end;
      end if;
        execute immediate q'[CREATE DATABASE LINK ]'||l_dblink.db_link_name||q'[ CONNECT TO ]'||l_dblink.username||q'[ IDENTIFIED BY ]'||l_dblink.password||q'[ USING ']'||l_dblink.connstr||q'[']';
      update opas_db_links set STATUS=dblCREATED where DB_LINK_NAME=upper(p_db_link_name);
      commit;
    end if;
  end;

  procedure drop_dblink(p_db_link_name varchar2, p_suspend boolean default false)
  is
    l_domain varchar2(128);
    l_cnt number;
  begin
    if p_db_link_name=gDefaultSource then
      raise_application_error(-20000, gDefaultSource||' db link is not supposed to be created.');
    else
      select value into l_domain from v$parameter where name like '%domain%';
      select count(1) into l_cnt from user_db_links where db_link = upper(case when l_domain is null then p_db_link_name else p_db_link_name ||'.'|| l_domain end);
      if l_cnt>0 then
        begin
          if p_suspend then
            update opas_db_links set STATUS=dblSUSPENDED where DB_LINK_NAME=upper(p_db_link_name);
          else
            update opas_db_links set STATUS=dblTODELETE where DB_LINK_NAME=upper(p_db_link_name);
          end if;
          execute immediate 'drop database link ' || case when l_domain is null then p_db_link_name else p_db_link_name ||'.'|| l_domain end;
        exception
          when others then
            COREMOD_LOG.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
            COREMOD_LOG.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            COREMOD_LOG.log(sqlerrm);
            raise;
        end;
      end if;
      if not p_suspend then
        delete from opas_db_links where DB_LINK_NAME=upper(p_db_link_name);
      end if;
      commit;
    end if;
  end;

  procedure test_dblink(p_db_link_name varchar2)
  is
    l_dblink varchar2(512);
    l_status OPAS_DB_LINKS.status%type;
    a number;
  begin
    select ora_db_link, status into l_dblink, l_status from V$OPAS_DB_LINKS where db_link_name=upper(p_db_link_name);
    if l_status = dblSUSPENDED then raise_application_error(-20999, 'DB Link: '||p_db_link_name||' is suspended');end if;
    begin
      execute immediate 'select 1 from dual@'||l_dblink into a;
    exception
      when others then drop_dblink(p_db_link_name, p_suspend => true);
      raise;
    end;
  end;

  function get_ora_dblink(p_db_link_name varchar2) return varchar2
  is
    l_dblink V$OPAS_DB_LINKS.ora_db_link%type;
    l_status V$OPAS_DB_LINKS.STATUS%type;
  begin
    select ora_db_link, STATUS into l_dblink, l_status from V$OPAS_DB_LINKS where db_link_name=upper(p_db_link_name);
    if l_status <> 'CREATED' then
      raise_application_error(-20000,'The dblink '||p_db_link_name||' is in unusable state: '||l_status);
    end if;
    return l_dblink;
  end;

  function get_dblink_for_query(p_dblink varchar2) return varchar2
  is
  begin
    return case when p_dblink <> '$LOCAL$' then '@'||COREMOD_API.get_ora_dblink(p_dblink) else null end;
  end;

  function get_ora_dblink_cache_i(p_db_link_name varchar2, p_key varchar2) return varchar2
  is
    l_res          opas_db_link_cache.value%type;
    l_last_updated opas_db_link_cache.last_updated%type;
    l_sql          varchar2(32765);

    pragma autonomous_transaction;
  begin
    case
      when p_key like 'TABCOLLIST%' then
        begin
          l_sql := q'[select listagg(column_name,',') within group (order by column_name) from (select column_name from dba_tab_cols]' || get_dblink_for_query(p_db_link_name) || q'[ where table_name=upper(:p_tab_name) and owner='SYS'
                               intersect select column_name from dba_tab_cols where table_name=upper(:p_tab_name) and owner='SYS' and DATA_TYPE not in 'XMLTYPE')]';
          execute immediate l_sql into l_res using ltrim(p_key, 'TABCOLLIST_'), ltrim(p_key, 'TABCOLLIST_');
        exception
          when others then raise_application_error(-20000,'Unable to get DB Link Cache for Key|DB Link: '||p_key||'|'||p_db_link_name||chr(10)||' '||sqlerrm||chr(10)||l_sql);
        end;
    else
      raise_application_error(-20000,'Unsupported DB Link Cache Key: '||p_key);
    end case;

    if l_res is not null then
      INSERT INTO opas_db_link_cache ( dblink, key, value, last_updated ) VALUES (p_db_link_name, upper(p_key), l_res, systimestamp);
      commit;
    end if;
    return l_res;
  end;

  function get_ora_dblink_cache(p_db_link_name varchar2, p_key varchar2) return varchar2
  is
    l_res          opas_db_link_cache.value%type;
    l_last_updated opas_db_link_cache.last_updated%type;
  begin
    select value, last_updated into l_res, l_last_updated from opas_db_link_cache where dblink = p_db_link_name and key = upper(p_key);
    if l_last_updated < add_months(sysdate,-1) then raise no_data_found; end if;
    return l_res;
  exception
    when no_data_found then return get_ora_dblink_cache_i(p_db_link_name, p_key);
  end;

  procedure update_dblink_db_info(p_db_link_name varchar2)
  is
    l_sql        varchar2(32765);
    l_data_point_ts timestamp := systimestamp;
    procedure load_tmp_data(p_src_table_name_r varchar2, p_src_table_name varchar2, p_trg_table_name varchar2, p_suff varchar2) is
    begin
      l_sql :=q'[INSERT /*+ OPAS60_DBLINK_<SUFF> */ INTO <TRG_TABLE> (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from <SRC_TABLE>]' || COREMOD_API.get_dblink_for_query(p_db_link_name);
      l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_db_link_name, P_KEY => replace('TABCOLLIST_<SRC_TABLE>','<SRC_TABLE>',p_src_table_name_r)));
      l_sql := replace(l_sql,'<TRG_TABLE>',p_trg_table_name);
      l_sql := replace(l_sql,'<SRC_TABLE>',p_src_table_name);
      l_sql := replace(l_sql,'<SUFF>',p_suff);
      execute immediate l_sql;
      l_sql := null;
    exception
      when others then
        coremod_tasks.log('Error update_dblink_db_info loading p_src_table_name: '||p_trg_table_name||':'||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||chr(10)||l_sql);
    end;
  begin
    load_tmp_data('V_$DATABASE',                'V$DATABASE',                 'opas_dbl_tmp_v$database','V$DB');
    load_tmp_data('V_$PDBS',                    'V$PDBS',                     'opas_dbl_tmp_v$pdbs',    'V$PDBS');
    load_tmp_data('GV_$INSTANCE',               'GV$INSTANCE',                'opas_dbl_tmp_v$inst',    'GV$INST');
    load_tmp_data('DBA_HIST_DATABASE_INSTANCE', 'DBA_HIST_DATABASE_INSTANCE', 'opas_dbl_tmp_awrinst',   'DBH_INST');
    load_tmp_data('DBA_REGISTRY_HISTORY',       'DBA_REGISTRY_HISTORY',       'opas_dbl_tmp_reghst',    'REGHST');
    load_tmp_data('DBA_REGISTRY_SQLPATCH',      'DBA_REGISTRY_SQLPATCH',      'opas_dbl_tmp_sqlptchhst','SQLPTCH');

    merge into opas_db_link_v$db t
      using opas_dbl_tmp_v$database s
      on (t.dblink = p_db_link_name and
          s.dbid = t.dbid and
          s.name = t.name and
          s.created = t.created and
          s.resetlogs_time = t.resetlogs_time and
          s.log_mode = t.log_mode and
          s.protection_mode = t.protection_mode and
          s.database_role = t.database_role and
          s.platform_id = t.platform_id and
          s.flashback_on = t.flashback_on)
       when not matched then insert (
         dblink, is_actual, actual_since, t.dbid, name, created, resetlogs_change#, resetlogs_time, prior_resetlogs_change#, prior_resetlogs_time, log_mode,
         checkpoint_change#, archive_change#, controlfile_type, controlfile_created, controlfile_sequence#, controlfile_change#, controlfile_time, open_resetlogs,
         version_time, open_mode, protection_mode, protection_level, remote_archive, activation#, switchover#, database_role, archivelog_change#, archivelog_compression, switchover_status,
         dataguard_broker, guard_status, supplemental_log_data_min, supplemental_log_data_pk, supplemental_log_data_ui, force_logging, platform_id, platform_name, recovery_target_incarnation#,
         last_open_incarnation#, current_scn, flashback_on, supplemental_log_data_fk, supplemental_log_data_all, db_unique_name, STANDBY_BECAME_PRIMARY_SCN, fs_failover_status,
         fs_failover_current_target, fs_failover_threshold, fs_failover_observer_present, fs_failover_observer_host, controlfile_converted, primary_db_unique_name,
         supplemental_log_data_pl, min_required_capture_change#, cdb, con_id, pending_role_change_tasks, con_dbid, force_full_db_caching)
         VALUES (
         p_db_link_name, 'Y', l_data_point_ts, s.dbid, s.name, s.created, s.resetlogs_change#, s.resetlogs_time, s.prior_resetlogs_change#, s.prior_resetlogs_time, s.log_mode,
         s.checkpoint_change#, s.archive_change#, s.controlfile_type, s.controlfile_created, s.controlfile_sequence#, s.controlfile_change#, s.controlfile_time, s.open_resetlogs,
         s.version_time, s.open_mode, s.protection_mode, s.protection_level, s.remote_archive, s.activation#, s.switchover#, s.database_role, s.archivelog_change#, s.archivelog_compression, s.switchover_status,
         s.dataguard_broker, s.guard_status, s.supplemental_log_data_min, s.supplemental_log_data_pk, s.supplemental_log_data_ui, s.force_logging, s.platform_id, s.platform_name, s.recovery_target_incarnation#,
         s.last_open_incarnation#, s.current_scn, s.flashback_on, s.supplemental_log_data_fk, s.supplemental_log_data_all, s.db_unique_name, s.STANDBY_BECAME_PRIMARY_SCN, s.fs_failover_status,
         s.fs_failover_current_target, s.fs_failover_threshold, s.fs_failover_observer_present, s.fs_failover_observer_host, s.controlfile_converted, s.primary_db_unique_name,
         s.supplemental_log_data_pl, s.min_required_capture_change#, s.cdb, s.con_id, s.pending_role_change_tasks, s.con_dbid, s.force_full_db_caching);
    if sql%rowcount > 0 then
      update opas_db_link_v$db set is_actual='N' where is_actual ='Y' and actual_since<>l_data_point_ts;
      update opas_db_links set dbid = (select dbid from opas_dbl_tmp_v$database where DB_LINK_NAME = p_db_link_name);
    end if;

    MERGE INTO opas_db_link_v$pdbs t
      using opas_dbl_tmp_v$pdbs s
      on (
        t.dblink = p_db_link_name and
        t.con_id = s.con_id and
        t.dbid = s.dbid and
        t.con_uid = s.con_uid and
        t.guid = s.guid and
        t.name = s.name)
      when not matched then insert (
        dblink, is_actual, actual_since, con_id, dbid, con_uid, guid, name, open_mode, restricted, open_time, create_scn, total_size, block_size, recovery_status, snapshot_parent_con_id, application_root,
        application_pdb, application_seed, application_root_con_id, application_root_clone, proxy_pdb, local_undo, undo_scn, undo_timestamp, creation_time, diagnostics_size, pdb_count, audit_files_size,
        max_size, max_diagnostics_size, max_audit_size, last_changed_by, template, tenant_id, upgrade_level, guid_base64)
      VALUES (
        p_db_link_name, 'Y', l_data_point_ts, s.con_id, s.dbid, s.con_uid, s.guid, s.name, s.open_mode, s.restricted, s.open_time, s.create_scn, s.total_size, s.block_size, s.recovery_status, s.snapshot_parent_con_id, s.application_root,
        s.application_pdb, s.application_seed, s.application_root_con_id, s.application_root_clone, s.proxy_pdb, s.local_undo, s.undo_scn, s.undo_timestamp, s.creation_time, s.diagnostics_size, s.pdb_count, s.audit_files_size,
        s.max_size, s.max_diagnostics_size, s.max_audit_size, s.last_changed_by, s.template, s.tenant_id, s.upgrade_level, s.guid_base64);
    if sql%rowcount > 0 then
      update opas_db_link_v$pdbs set is_actual='N' where is_actual ='Y' and actual_since<>l_data_point_ts;
    end if;

    delete from opas_db_link_v$inst where exists (select 1 from opas_dbl_tmp_v$inst);
    INSERT INTO opas_db_link_v$inst (
      dblink, inst_id, instance_number, instance_name, host_name, version, version_legacy, version_full, startup_time, status, parallel,
      thread#, archiver,log_switch_wait, logins, shutdown_pending, database_status, instance_role,active_state, blocked, con_id, instance_mode,
      edition, family, database_type)
    select p_db_link_name, inst_id, instance_number, instance_name, host_name, version, version_legacy, version_full, startup_time, status, parallel,
      thread#, archiver,log_switch_wait, logins, shutdown_pending, database_status, instance_role,active_state, blocked, con_id, instance_mode,
      edition, family, database_type
    from opas_dbl_tmp_v$inst;

    merge into OPAS_DB_LINK_DBH_INST t
      using OPAS_DBL_TMP_AWRINST s
      on (
          t.dblink = p_db_link_name and
          t.DBID = s.DBID and
          t.INSTANCE_NUMBER = s.INSTANCE_NUMBER and
          t.STARTUP_TIME = s.STARTUP_TIME and
          t.PARALLEL = s.PARALLEL and
          t.INSTANCE_NAME = s.INSTANCE_NAME and
          t.HOST_NAME = s.HOST_NAME and
          t.PLATFORM_NAME = s.PLATFORM_NAME and
          t.VERSION = s.VERSION and
          t.DB_NAME = s.DB_NAME)
      when not matched then insert (
        dblink, dbid, instance_number, startup_time, parallel, version, db_name, instance_name, host_name, last_ash_sample_id, platform_name, cdb,
        edition, db_unique_name, database_role, cdb_root_dbid, con_id, startup_time_tz)
      VALUES (p_db_link_name, s.dbid, s.instance_number, s.startup_time, s.parallel, s.version, s.db_name, s.instance_name, s.host_name, s.last_ash_sample_id, s.platform_name, s.cdb,
        s.edition, s.db_unique_name, s.database_role, s.cdb_root_dbid, s.con_id, s.startup_time_tz);

    merge into  opas_db_link_reghst t
      using OPAS_DBL_TMP_REGHST s
      on (
        t.dblink = p_db_link_name and
        decode(t.action_time, s.action_time,1,0)=1 and
        t.action = s.action and
        decode(t.namespace,s.namespace,1,0)=1 and
        decode(t.version,s.version,1,0)=1
      )
    when not matched then insert (
      dblink, action_time, action, namespace, version, id, comments, bundle_series)
      VALUES (
      p_db_link_name, s.action_time, s.action, s.namespace, s.version, s.id, s.comments, s.bundle_series);

    if sql%rowcount > 0 then
      null; --TODO alert new patch
    end if;

    merge into OPAS_DB_LINK_SQLPTCHHST t
      using OPAS_DBL_TMP_SQLPTCHHST s
      on (
        t.dblink = p_db_link_name and
        t.PATCH_ID = s.PATCH_ID and
        t.PATCH_UID = s.PATCH_UID and
        decode(t.INSTALL_ID,s.INSTALL_ID,1,0)=1
      )
      when not matched then insert (
        dblink, install_id, patch_id, patch_uid, patch_type, action, status, action_time, description, logfile, ru_logfile, flags, patch_descriptor, patch_directory,
        source_version, source_build_description, source_build_timestamp, target_version, target_build_description, target_build_timestamp)
      VALUES (
        p_db_link_name, s.install_id, s.patch_id, s.patch_uid, s.patch_type, s.action, s.status, s.action_time, s.description, s.logfile, s.ru_logfile, s.flags, s.patch_descriptor, s.patch_directory,
        s.source_version, s.source_build_description, s.source_build_timestamp, s.target_version, s.target_build_description, s.target_build_timestamp);

    if sql%rowcount > 0 then
      null; --TODO alert new sql patch
    end if;
    commit;
  end;

  function get_def_source return varchar2 is begin return gDefaultSource; end;
  function get_def_owner return varchar2 is begin return gDefaultOwner; end;


  function lock_resource(p_resource_name varchar2, p_mode number default DBMS_LOCK.X_MODE, p_timeout number default 0, p_release_on_commit boolean default true) return varchar2
  is
    l_res    integer;
  begin
    DBMS_LOCK.ALLOCATE_UNIQUE (
      lockname         => 'OPAS'||p_resource_name,
      lockhandle       => g_handle);

    l_res:=DBMS_LOCK.REQUEST(
      lockhandle         => g_handle,
      lockmode           => p_mode,
      timeout            => p_timeout,
      release_on_commit  => p_release_on_commit);

    if l_res <> 0 then
      raise_application_error(-20000, 'Resource '||p_resource_name||' can not be locked right now. Return code: '||l_res);
    end if;

    return g_handle;
  end;

  procedure lock_resource(p_resource_name varchar2, p_mode number default DBMS_LOCK.X_MODE, p_timeout number default 0, p_release_on_commit boolean default true)
  is
    l_handle varchar2(512);
  begin
    l_handle:=lock_resource(p_resource_name,p_mode,p_timeout,p_release_on_commit);
  end;

  procedure release_resource(p_handle varchar2)
  is
    l_res integer;
  begin
    l_res := DBMS_LOCK.RELEASE(p_handle);
  end;

  procedure release_resource
  is
  begin
    release_resource(g_handle);
  end;

end COREMOD_API;
/
