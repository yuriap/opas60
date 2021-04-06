

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

  g_last_sql_rowcount number;

  function getMODNAME return varchar2 is begin return gMODNAME; end;

  function get_last_rowcount return number is begin return g_last_sql_rowcount; end;

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

  function getconf(p_key varchar2, p_module opas_modules.modname%type default gMODNAME) return varchar2 RESULT_CACHE
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

  function get_dic_displ_val(p_dic_name varchar2, p_dic_val varchar2) return varchar2
  is
    l_dv OPAS_DICTIONARY.display_val%type;
  begin
    select display_val into l_dv from OPAS_DICTIONARY t where dic_name=p_dic_name and val=p_dic_val;
    return l_dv;
  exception
    when others then return null;
  end;

  function external_mode return varchar2 is begin return COREMOD_API.getconf('EXTERNALMODE'); end;
  function external_mode_dblink return boolean is begin return external_mode = gemDBLINK; end;
  --function external_mode_sqlplus return boolean is begin return external_mode = gemSQLPLUS; end;
  function external_mode_javasrv return boolean is begin return external_mode = gemJAVASRV; end;

  function external_mode(p_db_link_name varchar2) return varchar2 RESULT_CACHE
  is
    l_dblink opas_db_links%rowtype;
  begin
    select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name);
    return l_dblink.DBLINK_MODE;
  end;
  function external_mode_dblink(p_db_link_name varchar2) return boolean
  is
  begin
    return p_db_link_name = gLocalDBLink or external_mode(p_db_link_name) = gemDBLINK;
  end;
  function external_mode_javasrv(p_db_link_name varchar2) return boolean
  is
  begin
    return external_mode(p_db_link_name) = gemJAVASRV;
  end;
  function dblink_available(p_db_link_name varchar2, p_since date) return boolean RESULT_CACHE
  is
    l_dblink opas_db_links%rowtype;
  begin
    select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name);
    return (l_dblink.DBLINK_MODE = gemDBLINK and l_dblink.STATUS = dblCREATED or
            l_dblink.DBLINK_MODE = gemJAVASRV and l_dblink.STATUS = dblEXTENABLED) and l_dblink.ENABLED >= nvl(p_since,l_dblink.ENABLED);
  end;

  procedure register_dblink(p_db_link_name varchar2,
                            p_owner varchar2,
                            p_is_public varchar2,
                            p_username varchar2,
                            p_password varchar2,
                            p_connectstring varchar2,
                            p_DBLINK_MODE varchar2,
                            p_ext_host varchar2)
  is
  begin
    insert into opas_db_links
      (DB_LINK_NAME,OWNER,STATUS,is_public,username,password,connstr,UPDATE_SCHED,DBLINK_MODE,EXT_HOST)
    values
      (upper(p_db_link_name), upper(p_owner),
       dblNEW, case when upper(p_owner)='PUBLIC' then 'Y' else case when p_is_public = 'Y' then 'Y' else 'N' end end, p_username,p_password,p_connectstring,'freq=monthly; interval=1;',
       p_DBLINK_MODE, p_ext_host);
  end;

  procedure enable_dblink4ext(p_db_link_name varchar2, p_server varchar2)
  is
  begin
      if p_server is null then
        raise_application_error(-20000,'Server host must be specified.');
      end if;
      drop_dblink(p_db_link_name => upper(p_db_link_name), p_suspend => true);
      sys.get_ext_exec_perm4java(sys_context('USERENV', 'CURRENT_USER'), p_server);
      update opas_db_links set
             STATUS = dblEXTENABLED,
             DBLINK_MODE = gemJAVASRV,
             EXT_HOST = p_server,
             ENABLED = sysdate
       where DB_LINK_NAME = upper(p_db_link_name);
  end;

  procedure edit_dblink    (p_db_link_name varchar2,
                            p_is_public varchar2,
                            p_username varchar2,
                            p_password varchar2,
                            p_connectstring varchar2,
                            p_DBLINK_MODE varchar2,
                            p_ext_host varchar2)
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
             connstr = p_connectstring,
             ENABLED = null
       where DB_LINK_NAME = upper(p_db_link_name);
    elsif nvl(p_DBLINK_MODE,'~^')<>nvl(l_dblink.DBLINK_MODE,'~^') or nvl(p_ext_host,'~^')<>nvl(l_dblink.EXT_HOST,'~^') then
      update opas_db_links set
             STATUS = dblMODIFIED,
             DBLINK_MODE = p_DBLINK_MODE,
             EXT_HOST = p_ext_host,
             ENABLED = null
       where DB_LINK_NAME = upper(p_db_link_name);
      drop_dblink(p_db_link_name => upper(p_db_link_name), p_suspend => true);
    end if;

    if l_dblink.is_public<>p_is_public and upper(l_dblink.owner)!='PUBLIC' then
      update opas_db_links set
             is_public = case when upper(owner)='PUBLIC' then 'Y' else case when p_is_public = 'Y' then 'Y' else 'N' end end
       where DB_LINK_NAME = upper(p_db_link_name);
    end if;
  end;

  procedure create_dblink(p_db_link_name varchar2, p_recreate boolean default false)
  is
    l_dblink     opas_db_links%rowtype;
    L_TASKNAME   OPAS_TASK.TASKNAME%type := 'OPAS_DBLINKDATA';
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
    l_nt_id      opas_notification.ID%type;
  begin
    if p_db_link_name=gDefaultSource then
      raise_application_error(-20000, gDefaultSource||' db link is not supposed to be created.');
    end if;

    select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name) for update nowait;
    if l_dblink.DBLINK_MODE = gemDBLINK then
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
      update opas_db_links set STATUS=dblCREATED, ENABLED = sysdate where DB_LINK_NAME=upper(p_db_link_name);
      commit;
      --update_dblink_db_info(upper(p_db_link_name));
      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_varchar_par => upper(p_db_link_name));
      COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'Database dossier gathering for DB Link "'||upper(p_db_link_name)|| '" finished with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => COREMOD_ALERTS.create_url(), 'f?p='||v('APP_ID')||':1401:<APP_SESSION>::::APP_OBJ_ID,APP_PREV_PAGE:'||l_obj_id||',10',
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => l_dblink.owner,
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
      commit;
    else
      raise_application_error(-20000, 'DB Link is not in "'||gemDBLINK||'" Mode');
    end if;
  end;

  procedure drop_dblink(p_db_link_name varchar2, p_suspend boolean default false)
  is
    l_domain     varchar2(128);
    l_cnt        number;
    l_nt_id      opas_notification.ID%type;
    --l_owner      opas_db_links.owner%type;
    l_dblink opas_db_links%rowtype;
  begin
    if p_db_link_name=gDefaultSource then
      raise_application_error(-20000, gDefaultSource||' db link is not supposed to be dropped.');
    else
      select * into l_dblink from opas_db_links where DB_LINK_NAME = upper(p_db_link_name);
      if l_dblink.STATUS<>dblSUSPENDED then
        update opas_db_links set STATUS=dblSUSPENDED, ENABLED = null where DB_LINK_NAME=upper(p_db_link_name);
        COREMOD_ALERTS.add_notification (
              nt_id =>      l_nt_id,
              NT_TEXT =>    'DB Link "'||upper(p_db_link_name)|| '" has been suspended.',
              --NT_LINK => COREMOD_ALERTS.create_url(), 'f?p='||v('APP_ID')||':1401:<APP_SESSION>::::APP_OBJ_ID,APP_PREV_PAGE:'||l_obj_id||',10',
              NT_TYPE_ID =>  COREMOD_ALERTS.nttMaintenance,
              NT_COLOR =>    COREMOD_ALERTS.ntcRed, --default
              NT_USERNAME => l_dblink.owner
              --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
              --NT_ACTIVATE => 1
              ) ;
      end if;
      select value into l_domain from v$parameter where name like '%domain%';
      select count(1) into l_cnt from user_db_links where db_link = upper(case when l_domain is null then p_db_link_name else p_db_link_name ||'.'|| l_domain end);
      if l_cnt>0 then
        begin
          if not p_suspend then
            update opas_db_links set STATUS=dblTODELETE, ENABLED = null where DB_LINK_NAME=upper(p_db_link_name);
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
      -- do nothing so far to prevent data loss
      --if not p_suspend then
      --  delete from opas_db_links where DB_LINK_NAME=upper(p_db_link_name);
      --end if;
      commit;
    end if;
  end;

  procedure test_dblink(p_db_link_name varchar2)
  is
    l_dblink varchar2(512);
    l_status OPAS_DB_LINKS.status%type;
    a number;
    l_mode   V$OPAS_DB_LINKS.DBLINK_MODE%type;
  begin
    if upper(p_db_link_name) <> gLocalDBLink then
      select ora_db_link, status, DBLINK_MODE into l_dblink, l_status, l_mode from V$OPAS_DB_LINKS where db_link_name=upper(p_db_link_name);
      if l_mode = gemDBLINK then
        if l_status != dblCREATED then raise_application_error(-20999, 'DB Link: '||p_db_link_name||' is not '||dblCREATED);end if;
        begin
          execute immediate 'select 1 from dual@'||l_dblink into a;
        exception
          when others then drop_dblink(p_db_link_name, p_suspend => true);
          raise;
        end;
      elsif l_mode = gemJAVASRV then
        if l_status != dblEXTENABLED then raise_application_error(-20999, 'DB Link: '||p_db_link_name||' is not '||dblEXTENABLED);end if;
        test_remote_db(upper(p_db_link_name));
      end if;
    else
      null;
    end if;
  end;

  function get_ora_dblink(p_db_link_name varchar2) return varchar2
  is
    l_dblink V$OPAS_DB_LINKS.ora_db_link%type;
    l_status V$OPAS_DB_LINKS.STATUS%type;
    l_mode   V$OPAS_DB_LINKS.DBLINK_MODE%type;
  begin
    select ora_db_link, STATUS, DBLINK_MODE into l_dblink, l_status, l_mode from V$OPAS_DB_LINKS where db_link_name=upper(p_db_link_name);
    if not(l_status = dblCREATED and l_mode = gemDBLINK) then
      raise_application_error(-20000,'The dblink '||p_db_link_name||' is in unusable state/mode: '||l_status||'/'||l_mode);
    end if;
    return l_dblink;
  end;

  function get_dblink_for_query(p_dblink varchar2) return varchar2
  is
  begin
    return case when p_dblink <> '$LOCAL$' then '@'||get_ora_dblink(p_dblink) else null end;
  end;

  function get_dblink_user(p_dblink varchar2) return varchar2
  is
    l_username OPAS_DB_LINKS.username%type;
  begin
    if  p_dblink = '$LOCAL$' then
      return user;
    else
      select username into l_username from OPAS_DB_LINKS where db_link_name=upper(p_dblink);
      return l_username;
    end if;
  end;

  function get_ora_dblink_cache_i(p_db_link_name varchar2, p_key varchar2, p_local_tab varchar2 default null) return varchar2
  is
    l_res          opas_db_link_cache.value%type;
    l_last_updated opas_db_link_cache.last_updated%type;
    l_sql          varchar2(32765);

    pragma autonomous_transaction;
  begin
    begin
      select value into l_res from opas_db_link_cache where dblink = p_db_link_name and key = p_key;
    exception
      when no_data_found then
        begin
          case
            when p_key like 'TABCOLLIST%' then
              begin
                l_sql := q'[select listagg(column_name,',') within group (order by column_name) from
                                    (select column_name from dba_tab_cols]' || get_dblink_for_query(p_db_link_name) || q'[ where table_name=upper(:p_tab_name) and owner='SYS'
                                     intersect
                                     select column_name from dba_tab_cols where table_name=upper(:p_tab_name) and owner='SYS' and DATA_TYPE not in ('XMLTYPE','LONG'))]';
                execute immediate l_sql into l_res using ltrim(p_key, 'TABCOLLIST_'), ltrim(p_key, 'TABCOLLIST_');

              exception
                when others then raise_application_error(-20000,'Unable to get DB Link Cache for Key|DB Link: '||p_key||'|'||p_db_link_name||chr(10)||' '||sqlerrm||chr(10)||l_sql);
              end;
            when p_key like 'LOCTABCOLS%' then
              begin
                l_sql := q'[select listagg(column_name,',') within group (order by column_name) from
                                    (select column_name from dba_tab_cols]' || get_dblink_for_query(p_db_link_name) || q'[ where table_name=upper(:p_tab_name) and owner='SYS'
                                     intersect
                                     select column_name from dba_tab_cols where table_name=upper(:p_tab_name) and DATA_TYPE not in ('XMLTYPE','LONG'))]';
                execute immediate l_sql into l_res using ltrim(p_key, 'LOCTABCOLS_'), p_local_tab;

              exception
                when others then raise_application_error(-20000,'Unable to get DB Link Cache for Key|Local Tab|DB Link: '||p_key||'|'||p_local_tab||'|'||p_db_link_name||chr(10)||' '||sqlerrm||chr(10)||l_sql);
              end;
          else
            raise_application_error(-20000,'Unsupported DB Link Cache Key: '||p_key);
          end case;
          if l_res is not null then
            INSERT INTO opas_db_link_cache ( dblink, key, value, last_updated ) VALUES (p_db_link_name, upper(p_key), l_res, systimestamp);
          end if;
          commit;
      end;
    end;

    return l_res;
  end;

  function get_ora_dblink_cache(p_db_link_name varchar2, p_key varchar2, p_local_tab varchar2 default null) return varchar2
  is
    l_res          opas_db_link_cache.value%type;
    l_last_updated opas_db_link_cache.last_updated%type;
  begin
    select value, last_updated into l_res, l_last_updated from opas_db_link_cache where dblink = p_db_link_name and key = upper(p_key);
    if l_last_updated < add_months(sysdate,-1) then raise no_data_found; end if;
    return l_res;
  exception
    when no_data_found then return get_ora_dblink_cache_i(p_db_link_name, p_key, p_local_tab);
  end;

  function get_dblink_dbid(p_dblink varchar2) return number
  is
    l_res number;
  begin
    select dbid into l_res from OPAS_DB_LINK_V$DB where dblink = p_dblink and is_actual='Y';
    return l_res;
  end;

  function get_tmp_load_query(p_db_link_name varchar2,
                              p_src_table_name_r varchar2,
                              p_src_table_name varchar2,
                              p_trg_table_name varchar2,
                              p_suff varchar2,
                              p_dbid number default null,
                              p_key_pref varchar2 default 'TABCOLLIST',
                              p_filter varchar2 default null,
                              p_timestamp_col varchar2 default null) return varchar2
  is
    l_sql           varchar2(32765);
  begin
      l_sql :=q'[INSERT /*+ OPAS60_DBLINK_<SUFF> */ INTO <TRG_TABLE> (<TSCOL> <SRC_DB_COL_LICT>)
              select <TSFNC> <SRC_DB_COL_LICT> from <SRC_TABLE>]' || COREMOD_API.get_dblink_for_query(p_db_link_name) || ' where (<FILTER>) <DBID>';
      if p_key_pref = 'TABCOLLIST' then
        l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_db_link_name,
                                                                                    P_KEY => replace(p_key_pref||'_<SRC_TABLE>','<SRC_TABLE>',p_src_table_name_r)));
      elsif p_key_pref = 'LOCTABCOLS' then
        l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_db_link_name,
                                                                                    P_KEY => replace(p_key_pref||'_<SRC_TABLE>','<SRC_TABLE>',p_src_table_name_r),
                                                                                    p_local_tab => p_trg_table_name));
      else
        raise_application_error(-20000,'Invalid p_key_pref: '||p_key_pref||'. Supported: TABCOLLIST, LOCTABCOLS');
      end if;
      l_sql := replace(l_sql,'<TRG_TABLE>',p_trg_table_name);
      l_sql := replace(l_sql,'<SRC_TABLE>',p_src_table_name);
      l_sql := replace(l_sql,'<SUFF>',p_suff);
      l_sql := replace(l_sql,'<FILTER>',nvl(p_filter,'1=1'));
      if p_dbid is not null then
        l_sql := replace(l_sql,'<DBID>', 'and dbid=' || p_dbid);
      else
        l_sql := replace(l_sql,'<DBID>','');
      end if;

      if p_timestamp_col is not null and p_timestamp_col in ('TS', 'LTS', 'TSTZ','TSUTC') then
        l_sql := replace(l_sql,'<TSCOL>',p_timestamp_col||',');
        l_sql := replace(l_sql,'<TSFNC>',case p_timestamp_col
                                           when 'TS' then 'cast(systimestamp as timestamp)'
                                           when 'LTS' then 'localtimestamp'
                                           when 'TSTZ' then 'systimestamp'
                                           when 'TSUTC' then 'sys_extract_utc(systimestamp)' else null end||',');
      else
        l_sql := replace(l_sql,'<TSCOL>',null);
        l_sql := replace(l_sql,'<TSFNC>',null);
      end if;

      return l_sql;
  end;

  procedure load_tmp_data(p_db_link_name varchar2,
                          p_src_table_name_r varchar2,
                          p_src_table_name varchar2,
                          p_trg_table_name varchar2,
                          p_suff varchar2,
                          p_dbid number default null,
                          p_key_pref varchar2 default 'TABCOLLIST',
                          p_filter varchar2 default null)
  is
    l_sql           varchar2(32765);
  begin

    l_sql := COREMOD_API.get_tmp_load_query(
      P_DB_LINK_NAME => load_tmp_data.P_DB_LINK_NAME,
      P_SRC_TABLE_NAME_R => load_tmp_data.P_SRC_TABLE_NAME_R,
      P_SRC_TABLE_NAME => load_tmp_data.P_SRC_TABLE_NAME,
      P_TRG_TABLE_NAME => load_tmp_data.P_TRG_TABLE_NAME,
      P_SUFF => load_tmp_data.P_SUFF,
      P_DBID => load_tmp_data.P_DBID,
      P_KEY_PREF => load_tmp_data.P_KEY_PREF,
      P_FILTER => load_tmp_data.P_FILTER);

      coremod_log.log('COREMOD_API.load_tmp_data:'||chr(10)||l_sql,'DEBUG');
      execute immediate l_sql;

      g_last_sql_rowcount := sql%rowcount;
  exception
      when others then
        coremod_tasks.log('Error in COREMOD_API.load_tmp_data loading p_db_link_name, p_src_table_name: '||p_db_link_name||', '||p_trg_table_name||':'||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||chr(10)||l_sql);
  end;

  procedure update_dblink_db_info(p_db_link_name varchar2)
  is
    l_sql           varchar2(32765);
    l_data_point_ts timestamp := systimestamp;
    l_dbid          OPAS_DB_LINKS.dbid%type;
    l_previous_upd  OPAS_DB_LINKS.DATA_UPDATED%type;

    l_snap number;
    l_version     OPAS_DB_METRICS2VER.VERSION%type;
    l_v$_metrics  TABLEOF2NUM;
    l_awr_metrics TABLEOF2NUM;

    l_qry_priority number := 3;
    l_qry_timeout  number := 300; --sec
    L_SELECT_LIST COREMOD_EXTPROC.t_columns;

    l_sql_get_snaps varchar2(4000)
      := q'[(select min_snap, dbid from (select min(snap_id) min_snap, min(dbid) dbid from dba_hist_snapshot<DBLINK> where dbid = (select dbid from v$database<DBLINK>) and end_interval_time > systimestamp - 1))]';
    l_sql_get_v4metrics varchar2(4000)
      := q'[insert into opas_dbl_tmp_metrics (GROUP_ID, METRIC_ID) select unique group_id, metric_id from gv$sysmetric_history<DBLINK>]';
    l_sql_get_awr_metric varchar2(4000)
      := q'[insert into opas_dbl_tmp_metrics (GROUP_ID, METRIC_ID) select unique group_id, metric_id from dba_hist_sysmetric_history<DBLINK> h where h.snap_id > :l_snap and h.dbid = :l_dbid and h.instance_number > 0]';
  begin
    COREMOD_TASKS.log('COREMOD_API.update_dblink_db_info: Updating database dossier for "'||p_db_link_name||'" ...');

    --test_dblink(p_db_link_name);

    COREMOD_EXTPROC.load_external_data (  P_TARGET_TABLE => 'OPAS_OT_TMP_C_SNAPS',
      P_SELECT_LIST => L_SELECT_LIST, --empty
      P_SQL_BODY =>    l_sql_get_snaps,
      P_DBLINK =>      p_db_link_name,
      P_PRIORITY =>    l_qry_priority,
      P_TIMEOUT =>     l_qry_timeout) ;

    --l_sql := replace(l_sql_get_snaps,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_db_link_name));
    --execute immediate l_sql into l_snap, l_dbid;
    SELECT min_snap, dbid into l_snap, l_dbid FROM opas_ot_tmp_c_snaps;
    l_sql := null;

    select DATA_UPDATED into l_previous_upd from OPAS_DB_LINKS where DB_LINK_NAME = upper(p_db_link_name);
    update OPAS_DB_LINKS set DATA_UPDATED = systimestamp+10 where DB_LINK_NAME = upper(p_db_link_name);
    commit;
    if COREMOD_API.external_mode_dblink(p_db_link_name) and COREMOD_API.get_dblink_for_query(p_db_link_name) is not null then
      execute immediate 'ALTER SESSION CLOSE DATABASE LINK '||ltrim(COREMOD_API.get_dblink_for_query(p_db_link_name),'@');
    end if;

    l_version := COREMOD_UTILS.get_remote_full_oracle_version(P_DBLINK => p_db_link_name);

    l_sql := replace(l_sql_get_v4metrics,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_db_link_name));
    execute immediate l_sql;
    l_sql := null;

    select TWO_NUMBERS(GROUP_ID, METRIC_ID)  bulk collect into l_v$_metrics from opas_dbl_tmp_metrics;
    delete from opas_dbl_tmp_metrics;

    l_sql := replace(l_sql_get_awr_metric,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_db_link_name));
    execute immediate l_sql using l_snap, l_dbid;
    l_sql := null;

    select TWO_NUMBERS(GROUP_ID, METRIC_ID)  bulk collect into l_awr_metrics from opas_dbl_tmp_metrics;
    delete from opas_dbl_tmp_metrics;

    insert into opas_dbl_tmp_metrics (SRC, GROUP_ID, GROUP_NAME, METRIC_ID, METRIC_NAME, METRIC_UNIT)
    select listagg(src, ',') within group(order by src) src,
           group_id,
           group_name,
           metric_id,
           metric_name,
           metric_unit
      from (select 'V$' src, group_id, group_name, metric_id, metric_name, metric_unit
              from v$metricname mn
             where (group_id, metric_id) in (select col1, col2 from table(l_v$_metrics))
            union all
            select 'AWR' src, group_id, group_name, metric_id, metric_name, metric_unit
              from v$metricname mn
             where (group_id, metric_id) in (select col1, col2 from table(l_awr_metrics)))
     group by group_id, group_name, metric_id, metric_name, metric_unit;

    merge into OPAS_DB_METRICS t
    using opas_dbl_tmp_metrics s
    on (t.GROUP_ID = s.GROUP_ID and t.METRIC_ID = s.METRIC_ID)
    when not matched then
    insert (GROUP_ID, GROUP_NAME, METRIC_ID, METRIC_NAME, METRIC_UNIT, SRC)
    values (s.GROUP_ID, s.GROUP_NAME, s.METRIC_ID, s.METRIC_NAME, s.METRIC_UNIT, s.SRC);

    merge into OPAS_DB_METRICS2VER t
    using opas_dbl_tmp_metrics s
    on (t.VERSION = l_version and t.GROUP_ID = s.GROUP_ID and t.METRIC_ID = s.METRIC_ID)
    when not matched then
    insert (VERSION, GROUP_ID, METRIC_ID)
    values (l_version, s.GROUP_ID, s.METRIC_ID);

    load_tmp_data(p_db_link_name, 'V_$DATABASE',                'V$DATABASE',                 'opas_dbl_tmp_v$database','V$DB');
    load_tmp_data(p_db_link_name, 'V_$PDBS',                    'V$PDBS',                     'opas_dbl_tmp_v$pdbs',    'V$PDBS');
    load_tmp_data(p_db_link_name, 'GV_$INSTANCE',               'GV$INSTANCE',                'opas_dbl_tmp_v$inst',    'GV$INST');
    load_tmp_data(p_db_link_name, 'DBA_REGISTRY_HISTORY',       'DBA_REGISTRY_HISTORY',       'opas_dbl_tmp_reghst',    'REGHST');
    load_tmp_data(p_db_link_name, 'DBA_REGISTRY_SQLPATCH',      'DBA_REGISTRY_SQLPATCH',      'opas_dbl_tmp_sqlptchhst','SQLPTCH');
/*
select
  listagg(src, ',') within group (order by src) src, group_id, metric_id, metric_name
from
(select unique 'V$' src, group_id, metric_id, metric_name from gv$sysmetric_history
union all
select unique 'AWR' src, group_id, metric_id, metric_name
 from dba_hist_sysmetric_history where dbid=2745483974 and instance_number>0
  and snap_id>(select min(snap_id) from dba_hist_snapshot where end_interval_time>systimestamp-8))
group by group_id, metric_id, metric_name
order by 1, 2,3
*/
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
      update opas_db_link_v$db set is_actual='N' where is_actual ='Y' and actual_since<>l_data_point_ts and dblink = p_db_link_name;
      update opas_db_links set dbid = (select dbid from opas_dbl_tmp_v$database) where DB_LINK_NAME = p_db_link_name returning dbid into l_dbid;
    end if;

    load_tmp_data(p_db_link_name, 'DBA_HIST_DATABASE_INSTANCE', 'DBA_HIST_DATABASE_INSTANCE', 'opas_dbl_tmp_awrinst',   'DBH_INST', l_dbid);

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
      update opas_db_link_v$pdbs set is_actual='N' where is_actual ='Y' and actual_since<>l_data_point_ts and dblink = p_db_link_name;
    end if;

    delete from opas_db_link_v$inst where exists (select 1 from opas_dbl_tmp_v$inst) and dblink = p_db_link_name;
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
        source_version, source_build_description, source_build_timestamp, target_version, target_build_description, target_build_timestamp,
        VERSION,BUNDLE_SERIES,BUNDLE_ID)
      VALUES (
        p_db_link_name, s.install_id, s.patch_id, s.patch_uid, s.patch_type, s.action, s.status, s.action_time, s.description, s.logfile, s.ru_logfile, s.flags, s.patch_descriptor, s.patch_directory,
        s.source_version, s.source_build_description, s.source_build_timestamp, s.target_version, s.target_build_description, s.target_build_timestamp,
        s.VERSION,s.BUNDLE_SERIES,s.BUNDLE_ID);

    if sql%rowcount > 0 then
      null; --TODO alert new sql patch
    end if;

    update OPAS_DB_LINKS set DATA_UPDATED = systimestamp, current_version=l_version where DB_LINK_NAME = upper(p_db_link_name);
    commit;
    COREMOD_TASKS.log('COREMOD_API.update_dblink_db_info: Update database dossier for "'||p_db_link_name||'" finished.');
  exception
    when others then
      coremod_tasks.log('Error COREMOD_API.update_dblink_db_info('||p_db_link_name||'): '||sqlerrm);
      coremod_tasks.log('Error COREMOD_API.update_dblink_db_info('||p_db_link_name||') error stack: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      if l_sql is not null then coremod_tasks.log('Error COREMOD_API.update_dblink_db_info('||p_db_link_name||'): '||l_sql); end if;
      rollback;
      update OPAS_DB_LINKS set DATA_UPDATED = l_previous_upd where DB_LINK_NAME = upper(p_db_link_name);
      commit;
      raise;
  end;

  procedure update_dblink_data
  is
    L_TASKNAME   OPAS_TASK.TASKNAME%type := 'OPAS_DBLINKDATA';
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
    l_nt_id      opas_notification.ID%type;
    l_next_date  timestamp;
  begin
    --coremod_log.log('DB Link data update job COREMOD_API.update_dblink_data start.');
    for i in (select * from OPAS_DB_LINKS where status=dblCREATED) loop
      DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
          calendar_string    => i.UPDATE_SCHED,
          start_date         => nvl(i.DATA_UPDATED,i.CREATED),
          return_date_after  => nvl(i.DATA_UPDATED,i.CREATED),
          next_run_date      => l_next_date);
      --coremod_log.log('DB Link data update job COREMOD_API.update_dblink_data: '||i.DB_LINK_NAME||' '||to_char(nvl(i.DATA_UPDATED,i.CREATED),'YYYY/MM/DD HH24:MI:SS')||' '||to_char(l_next_date,'YYYY/MM/DD HH24:MI:SS'));
      if l_next_date < systimestamp then
        l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_varchar_par => upper(i.DB_LINK_NAME));
        COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'Scheduled database dossier update for DB Link "'||upper(i.DB_LINK_NAME)|| '" finished with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => COREMOD_ALERTS.create_url(), 'f?p='||v('APP_ID')||':1401:<APP_SESSION>::::APP_OBJ_ID,APP_PREV_PAGE:'||l_obj_id||',10',
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => i.owner,
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
        COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
      end if;
    end loop;
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


