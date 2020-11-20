

CREATE OR REPLACE
PACKAGE BODY COREMOD_APPSTATE AS

  gParams COREOBJ_API.t_params;

  procedure set_jparam(p_pname      varchar2,
                       p_value      varchar2)
  is
  begin
    extract_jparams();
    gParams(p_pname):=p_value;
    store_jparams();
  end;

  procedure set_jparam_m(p_pname      varchar2,
                         p_value      varchar2)
  is
  begin
    gParams(p_pname):=p_value;
  end;

  procedure store_jparams
  is
    l_indx varchar2(100);
    --pragma autonomous_transaction;
  begin
    APEX_JSON.initialize_clob_output;
    APEX_JSON.open_object;
    APEX_JSON.open_array('params');
--coremod_log.log('store_jparams.p_obj_id:'||p_obj_id);
--coremod_log.log('gParams.count:'||gParams.count);
    l_indx := gParams.first;
    loop
      if gParams(l_indx) is not null then
        APEX_JSON.open_object;
        APEX_JSON.write('param_name', l_indx);
        APEX_JSON.write('param_value', gParams(l_indx));
        APEX_JSON.close_object;
      end if;
--coremod_log.log('gParams('||l_indx||')='||gParams(l_indx));
      l_indx := gParams.next(l_indx);
      exit when l_indx is null;
    end loop;

    APEX_JSON.close_array;
    APEX_JSON.close_object;

    merge into opas_app_state t
    using (select V('APP_USER') apex_user, APEX_JSON.get_clob_output jsparams from dual) s
    on (t.apex_user = s.apex_user)
    when matched then update set jsparams = APEX_JSON.get_clob_output
    when not matched then insert (t.apex_user, t.jsparams)
      values (s.apex_user, s.jsparams);
--coremod_log.log('Stored rows:'||sql%rowcount);
    APEX_JSON.free_output;
    --commit;
  end;


  procedure extract_jparams
  is
    l_json_text VARCHAR2(32767);
    l_count     PLS_INTEGER;
  begin
    gParams.delete;

    select jsparams into l_json_text from opas_app_state where apex_user = V('APP_USER');

    APEX_JSON.parse(l_json_text);
    l_count := APEX_JSON.get_count(p_path => 'params');

    FOR i IN 1 .. l_count LOOP
      gParams(APEX_JSON.get_varchar2(p_path => 'params[%d].param_name', p0 => i)) := APEX_JSON.get_varchar2(p_path => 'params[%d].param_value', p0 => i);
    END LOOP;
--coremod_log.log('extract_jparams.p_obj_id:'||p_obj_id);
--coremod_log.log('gParams.count:'||gParams.count);
  exception
      when no_data_found then null;
  end;

  procedure get_jparam(p_pname      varchar2,
                       p_value  out varchar2,
                       p_default    varchar2 default null)
  is
  begin
    extract_jparams();

    if gParams.exists(p_pname) then
      p_value := gParams(p_pname);
    else
      p_value := p_default;
    end if;
--coremod_log.log('get_jparam:'||p_pname||':'||p_value);
  end;

  procedure get_jparam_m(p_pname      varchar2,
                         p_value  out varchar2,
                         p_default    varchar2 default null)
  is
  begin

    if gParams.exists(p_pname) then
      p_value := gParams(p_pname);
    else
      p_value := p_default;
    end if;
--coremod_log.log('get_jparam:'||p_pname||':'||p_value);
  end;
END COREMOD_APPSTATE;
/


