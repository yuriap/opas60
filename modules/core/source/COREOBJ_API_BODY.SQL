CREATE OR REPLACE
PACKAGE BODY COREOBJ_API AS

  gCurrentParamsObject opas_objects.obj_id%type;

  function get_obj(p_obj_id           opas_objects.obj_id%type) return opas_objects%rowtype
  is
    l_obj opas_objects%rowtype;
  begin
    select * into l_obj from opas_objects where obj_id = p_obj_id;
    return l_obj;
  end;

  procedure lock_object(p_obj_id opas_objects.obj_id%type, p_mode varchar2 default 'NOWAIT', p_wait number default 60) AS
    l_crsr sys_refcursor;
  BEGIN
    if p_mode = 'NOWAIT' then
      for i in (select * from opas_objects where obj_id = p_obj_id for update nowait) loop null; end loop;
    elsif p_mode = 'WAIT' then
      open l_crsr for 'select obj_id from opas_objects where obj_id = p_obj_id for update wait '||p_wait;
      close l_crsr;
    end if;
  END lock_object;

  procedure add   (p_obj_id      out opas_objects.obj_id%type,
                   p_obj_prnt        opas_objects.obj_prnt%type,
                   p_obj_ot          opas_objects.obj_ot%type,
                   p_obj_name        opas_objects.obj_name%type,
                   p_obj_descr       opas_objects.obj_descr%type,
                   p_obj_created     opas_objects.obj_created%type default sysdate,
                   p_obj_expired     opas_objects.obj_expired%type default null,
                   p_obj_sortordr    opas_objects.obj_sortordr%type default 0,
                   p_obj_owner       opas_objects.obj_owner%type default 'PUBLIC',
                   p_is_public       opas_objects.is_public%type default 'Y')
  is
  begin
    INSERT INTO opas_objects
      (obj_prnt, obj_ot, obj_created, obj_expired, obj_name, obj_descr, obj_sortordr, obj_owner, is_public, is_readonly)
    VALUES
      (p_obj_prnt, p_obj_ot, p_obj_created, p_obj_expired, p_obj_name, p_obj_descr, p_obj_sortordr, p_obj_owner, p_is_public, default) returning obj_id into p_obj_id;
  end;

  procedure edit  (p_obj_id          opas_objects.obj_id%type,
                   p_obj_name        opas_objects.obj_name%type,
                   p_obj_descr       opas_objects.obj_descr%type,
                   p_obj_expired     opas_objects.obj_expired%type,
                   p_obj_sortordr    opas_objects.obj_sortordr%type,
                   p_obj_owner       opas_objects.obj_owner%type,
                   p_is_public       opas_objects.is_public%type,
                   p_is_readonly     opas_objects.is_readonly%type default 'N',
                   p_retention       number default -1)
  is
    l_created     opas_objects.obj_created%type;
    l_obj_expired opas_objects.obj_expired%type;
  BEGIN

    if p_retention > 0 then
      select obj_created into l_created from opas_objects where obj_id = p_obj_id;
      l_obj_expired := l_created + p_retention;
    elsif p_retention = 0 then -- keep forever
      l_obj_expired := null;
    elsif p_retention = -1 then -- keep forever
      l_obj_expired := p_obj_expired;
    end if;

    UPDATE opas_objects
       SET obj_expired = l_obj_expired,
           obj_name = p_obj_name,
           obj_descr = p_obj_descr,
           obj_sortordr = p_obj_sortordr,
           obj_owner = p_obj_owner,
           is_public = decode(p_obj_owner,'PUBLIC','Y',p_is_public),
           is_readonly = p_is_readonly
     WHERE obj_id = p_obj_id;
  end;

  procedure edit_descr  (p_obj_id          opas_objects.obj_id%type,
                         p_obj_name        opas_objects.obj_name%type,
                         p_obj_descr       opas_objects.obj_descr%type,
                         p_obj_owner       opas_objects.obj_owner%type default null)
  is
  begin
    UPDATE opas_objects
       SET obj_name = p_obj_name,
           obj_descr = p_obj_descr,
           obj_owner = nvl(p_obj_owner,obj_owner)
     WHERE obj_id = p_obj_id;
  end;

  procedure remove(p_obj_id opas_objects.obj_id%type)
  is
  begin
    delete from opas_objects where obj_id = p_obj_id;
  end;


  procedure copy  (p_src_obj_id       opas_objects.obj_id%type,
                   p_trg_obj_prnt     opas_objects.obj_prnt%type,
                   p_new_obj_id   out opas_objects.obj_id%type)
  is
  begin
    for i in (select * from opas_objects where obj_id = p_src_obj_id) loop
      INSERT INTO opas_objects
        (obj_prnt, obj_ot, obj_created, obj_expired, obj_name, obj_descr, obj_sortordr, obj_owner, is_public)
      VALUES
        (p_trg_obj_prnt, i.obj_ot, sysdate, i.obj_expired, i.obj_name, i.obj_descr, i.obj_sortordr, i.obj_owner, i.is_public) returning obj_id into p_new_obj_id;
    end loop;
  end;

  procedure move  (p_src_obj_id       opas_objects.obj_id%type,
                   p_trg_obj_prnt     opas_objects.obj_prnt%type)
  is
  begin
    UPDATE opas_objects
       SET obj_prnt = p_trg_obj_prnt
     WHERE obj_id = p_src_obj_id and p_trg_obj_prnt<>p_src_obj_id;
  end;

  procedure set_obj_size(p_obj_id     opas_objects.obj_id%type,
                         p_size       number)
  is
  begin
    UPDATE opas_objects
       SET obj_size = p_size
     WHERE obj_id = p_obj_id;
  end;

  procedure check_remove_ability(p_obj_id opas_objects.obj_id%type)
  is
    l_cnt number;
  BEGIN
    select count(1) into l_cnt
    from opas_objects
    where (is_readonly='Y' or (obj_owner != 'PUBLIC' and obj_owner != V('APP_USER') and is_public = 'N'))
    start with obj_id = p_obj_id
    connect by prior obj_id =  obj_prnt;

    if l_cnt>0 then
      raise_application_error(-20000,'Folder contains Read-only items or those belongs to someone else and not PUBLIC.');
    end if;
  end;

  procedure set_param (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                       p_par_name        OPAS_OBJECT_PARS.par_name%type,
                       p_NUM_PAR         OPAS_OBJECT_PARS.NUM_PAR%type default null,
                       p_VARCHAR_PAR     OPAS_OBJECT_PARS.VARCHAR_PAR%type default null,
                       p_DATE_PAR        OPAS_OBJECT_PARS.DATE_PAR%type default null,
                       p_DTTZ_PAR        OPAS_OBJECT_PARS.DTTZ_PAR%type default null)
  is
  begin
    merge
      into OPAS_OBJECT_PARS trg
      using (select p_obj_id obj_id, upper(p_par_name) par_name, p_NUM_PAR NUM_PAR, p_VARCHAR_PAR VARCHAR_PAR, p_DATE_PAR DATE_PAR, p_DTTZ_PAR DTTZ_PAR from dual) src
      on (trg.obj_id = src.obj_id and trg.par_name = src.par_name)
      when matched then update set
        trg.NUM_PAR = src.NUM_PAR,
        trg.VARCHAR_PAR = src.VARCHAR_PAR,
        trg.DATE_PAR = src.DATE_PAR,
        trg.DTTZ_PAR = src.DTTZ_PAR
      when not matched then insert
        (trg.obj_id, trg.par_name, trg.NUM_PAR, trg.VARCHAR_PAR, trg.DATE_PAR, trg.DTTZ_PAR)
        values
        (src.obj_id, src.par_name, src.NUM_PAR, src.VARCHAR_PAR, src.DATE_PAR, src.DTTZ_PAR);
  end;

  procedure get_param_i (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false,
                         p_par         out OPAS_OBJECT_PARS%rowtype)
  is
  begin
    select * into p_par from OPAS_OBJECT_PARS trg where trg.obj_id = p_obj_id and trg.par_name = upper(p_par_name);
  exception
    when no_data_found then
      begin
        if p_search_top then
          for i in (select p.*
                      from OPAS_OBJECT_PARS p,
                           (select obj_id, level lvl
                              from v$opas_objects
                             start with obj_id=p_obj_id
                           connect by prior obj_prnt = obj_id) objs
                             where p.obj_id=objs.obj_id
                               and p.par_name = upper(p_par_name)
                             order by lvl)
          loop
            p_par:=i;
            exit;
          end loop;
        end if;
      end;
  end;

  function  get_param_n (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return number
  is
    l_par              OPAS_OBJECT_PARS%rowtype;
  begin
    get_param_i(p_obj_id,p_par_name,p_search_top,l_par);
    return l_par.NUM_PAR;
  end;

  function  get_param_d (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return date
  is
    l_par              OPAS_OBJECT_PARS%rowtype;
  begin
    get_param_i(p_obj_id,p_par_name,p_search_top,l_par);
    return l_par.DATE_PAR;
  end;

  function  get_param_c (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return varchar2
  is
    l_par              OPAS_OBJECT_PARS%rowtype;
  begin
    get_param_i(p_obj_id,p_par_name,p_search_top,l_par);
    return l_par.VARCHAR_PAR;
  end;

  function  get_param_z (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return timestamp with time zone
  is
    l_par              OPAS_OBJECT_PARS%rowtype;
  begin
    get_param_i(p_obj_id,p_par_name,p_search_top,l_par);
    return l_par.DTTZ_PAR;
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type,
                                         p_obj_ot          opas_objects.obj_ot%type) return varchar2
  is
    l_status varchar2(100) := null;
  begin

    if g_ot_api.exists(p_obj_ot) and g_ot_api(p_obj_ot) is not null then
      execute immediate 'begin :res:='||g_ot_api(p_obj_ot)||'.get_object_status_to_display(:obj_id); end;' using out l_status, p_obj_id;
    end if;

    return l_status;
  exception
    when others then raise_application_error(-20000,'COREOBJ_API.get_object_status_to_display: '||p_obj_ot||' '||p_obj_id||' '||sqlerrm);
  end;

  function get_object_path(p_obj_id           opas_objects.obj_id%type,
                           p_including_object varchar2 default 'Y') return varchar2
  is
    l_path varchar2(1000) := null;
  begin
    with path_calc(obj_id,
    obj_name,
    obj_prnt,
    full_path) as
     (select obj_id, obj_name, obj_prnt, case when nvl(p_including_object,'~') = 'Y' then '/' || obj_name else null end full_path
        from opas_objects
       where obj_id = p_obj_id
      union all
      select o.obj_id,
             o.obj_name,
             o.obj_prnt,
             '/' || o.obj_name || p.full_path
        from opas_objects o, path_calc p
       where o.obj_id = p.obj_prnt)
    select full_path into l_path from path_calc where obj_prnt is null;
    return l_path;
    exception
      when no_data_found then return case when p_obj_id is null then null else 'Not found for: <'||p_obj_id||'>' end;
  end;

  procedure add_jparam(p_obj_id           opas_objects.obj_id%type,
                       p_pname      varchar2,
                       p_value      varchar2)
  is
  begin
    if gCurrentParamsObject = p_obj_id then
      gParams(p_pname):=p_value;
    else
      raise_application_error(-20000,'Parameters OBJ_ID mismatch current:specified '||gCurrentParamsObject||':'||p_obj_id);
    end if;
--coremod_log.log('add_jparam:'||p_pname||':'||p_value);
  end;

  procedure store_jparams(p_obj_id           opas_objects.obj_id%type)
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

    merge into opas_object_pars t
    using (select p_obj_id obj_id, jsParamName par_name, APEX_JSON.get_clob_output jsparams from dual) s
    on (t.obj_id = s.obj_id and t.par_name = s.par_name)
    when matched then update set jsparams = APEX_JSON.get_clob_output
    when not matched then insert (t.obj_id, t.par_name, t.jsparams)
      values (s.obj_id, s.par_name, s.jsparams);
--coremod_log.log('Stored rows:'||sql%rowcount);
    APEX_JSON.free_output;
    --commit;
  end;


  procedure extract_jparams(p_obj_id           opas_objects.obj_id%type)
  is
    l_json_text VARCHAR2(32767);
    l_count     PLS_INTEGER;
  begin
    gCurrentParamsObject := p_obj_id;
    gParams.delete;

    select jsparams into l_json_text from opas_object_pars where obj_id = p_obj_id and par_name=jsParamName;

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

  procedure get_jparam(p_obj_id           opas_objects.obj_id%type,
                       p_pname      varchar2,
                       p_value  out varchar2)
  is
  begin
    if COREOBJ_API.gParams.exists(p_pname) then
      p_value := COREOBJ_API.gParams(p_pname);
    else
      p_value := null;
    end if;
--coremod_log.log('get_jparam:'||p_pname||':'||p_value);
  end;

begin
  for i in (select * from opas_object_types) loop
    g_ot_icons(i.ot_id) := i.ot_icon;
    g_ot_api(i.ot_id) := i.ot_api_pkg;
  end loop;
  for i in (select * from OPAS_OBJECT_PAGES where ot_page_type='CREATE') loop
    g_ot_create_page(i.ot_id) := i.ot_app_page;
  end loop;
END COREOBJ_API;
/
