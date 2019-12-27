CREATE OR REPLACE
PACKAGE BODY COREOBJ_API AS

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
