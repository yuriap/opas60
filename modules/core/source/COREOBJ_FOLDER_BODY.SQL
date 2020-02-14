CREATE OR REPLACE
PACKAGE BODY COREOBJ_FOLDER AS

  procedure lock_object(p_obj_id opas_objects.obj_id%type) AS
  BEGIN
    COREOBJ_API.lock_object (  P_OBJ_ID => P_OBJ_ID); -- P_MODE => P_MODE, P_WAIT => P_WAIT) ;
  END lock_object;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_folder_name      opas_objects.obj_name%type default null) AS
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otFOLDER,
      P_OBJ_NAME  => nvl(p_folder_name,to_char(sysdate,'YYYYMMDD')),
      P_OBJ_DESCR => null) ;
  END add;

  procedure remove(p_obj_id           opas_objects.obj_id%type,
                   p_cascade          varchar2 default 'N')
  AS
  BEGIN
    COREOBJ_API.check_remove_ability(p_obj_id);

    for i in (select * from opas_objects o, opas_object_types ot where o.obj_ot=ot.ot_id and obj_prnt = p_obj_id) loop
      if p_cascade = 'N' then
        raise_application_error(-20000,'Folder is not empty');
      end if;
      execute immediate 'begin '||i.ot_api_pkg||q'[.remove(p_obj_id => :p_obj_id, p_cascade => :p_cascade); end; ]' using i.obj_id, p_cascade;
    end loop;
    COREOBJ_API.remove (  P_OBJ_ID => P_OBJ_ID) ;
  END remove;

  function folder_icon(p_obj_id           opas_objects.obj_id%type,
                       p_obj_ot           opas_objects.obj_ot%type,
                       p_curr_folder      opas_objects.obj_id%type) return varchar2
  is
    l_cnt number;
    l_return opas_object_types.ot_icon%type;
  begin
    if p_obj_ot=100 and p_curr_folder=p_obj_id then
      l_return := 'fa-folder-open-o';
    else
      select count(1) into l_cnt from v$opas_objects i where i.obj_prnt = p_obj_id and i.obj_ot in (COREOBJ_API.otDB_LINK_ASSIGNMENT,COREOBJ_API.otSQL_LIST);
      if l_cnt > 0 then
        l_return := 'fa-folder-wrench';
      else
        l_return := COREOBJ_API.g_ot_icons(p_obj_ot);
      end if;
    end if;
    return l_return;
  end;

  procedure get_init_navigation(p_folder  out opas_objects.obj_id%type,
                                p_obj_id  out opas_objects.obj_id%type)
  is
  begin
    begin
      select folder_id into p_folder from opas_last_nav_folder f, v$opas_objects o where apex_user = V('APP_USER') and f.folder_id = o.obj_id;
    exception
      when no_data_found then
        begin
          select min(obj_id) into p_folder from v$opas_objects where obj_ot = COREOBJ_API.otFOLDER and obj_prnt is null;
        exception
          when no_data_found then
            p_folder := null;
        end;
    end;
    p_obj_id := p_folder;
  end;

  procedure set_nav_folder   (p_folder      opas_objects.obj_id%type)
  is
    pragma autonomous_transaction;
  begin
    merge into opas_last_nav_folder t
    using (select V('APP_USER') usr, p_folder fldr from dual) s
    on (t.apex_user = s.usr)
    when matched then update set folder_id = s.fldr
    when not matched then insert (apex_user, folder_id) values (s.usr, s.fldr);
    commit;
  end;

  procedure calc_folder_size   (p_folder      opas_objects.obj_id%type)
  is
    l_size opas_objects.obj_size%type;
  begin
    select sum(obj_size) into l_size
    from opas_objects
    where obj_ot <> COREOBJ_API.otFOLDER
    start with obj_id = p_folder
    connect by prior obj_id = obj_prnt;

    update opas_objects
    set obj_size = l_size
    where obj_id = p_folder;
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
  begin
    return null;
  end;
END COREOBJ_FOLDER;
/
