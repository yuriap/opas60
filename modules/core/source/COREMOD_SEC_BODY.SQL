

CREATE OR REPLACE
package body COREMOD_SEC as

  function is_mod_installed(p_modname opas_modules.MODNAME%type) return boolean RESULT_CACHE
  is
    l_cnt number;
  begin
    select count(1) into l_cnt from opas_modules where MODNAME=p_modname;
    return l_cnt>0;
  end;

  function is_role_assigned(p_modname OPAS_GROUPS2APEXUSR.modname%type, p_group_name opas_groups.group_name%type) return boolean
  is
    l_ual number;
    l_gal number;
  begin
    select min(group_id) into l_ual
      from OPAS_GROUPS2APEXUSR g2u
     where g2u.apex_user = V('APP_USER')
       and g2u.modname=p_modname;

    select group_id into l_gal from opas_groups where group_name=p_group_name;
    --user access level less or eqial to group access level
    return l_gal>=l_ual;
  end;

  function is_role_assigned_n(p_modname OPAS_GROUPS2APEXUSR.modname%type, p_group_name opas_groups.group_name%type) return number
  is
  begin
    return case when is_role_assigned(p_modname,p_group_name) then 1 else 0 end;
  end;

  procedure save_role_assignment(p_modname_lst t_mod_list, p_group_id_lst t_grp_id_list, p_apex_user OPAS_GROUPS2APEXUSR.apex_user%type)
  is
    l_handle varchar2(512);
  begin
    if p_modname_lst.count<>p_group_id_lst.count then
      raise_application_error(-20000,'Invalid lists of modules and groups specified.');
    end if;

    if p_modname_lst.count>0 then
      l_handle:=COREMOD_API.lock_resource('SETUSERPERM'||p_apex_user);

      for i in 1..p_modname_lst.count loop
        delete from OPAS_GROUPS2APEXUSR
         where apex_user=p_apex_user
           and modname=p_modname_lst(i);
        if p_group_id_lst(i) is not null then
          insert into OPAS_GROUPS2APEXUSR (group_id, modname, apex_user) values (p_group_id_lst(i),p_modname_lst(i), p_apex_user);
        end if;
      end loop;
      COREMOD_API.release_resource(l_handle);
    end if;
  end;

  function can_create(p_folder_id opas_objects.obj_id%type) return boolean
  is
    l_folder opas_objects%rowtype := COREOBJ_API.get_obj(p_folder_id);
  begin
    /*
    coremod_log.log('p_folder_id: '||p_folder_id);
    coremod_log.log('l_folder.obj_owner: '||l_folder.obj_owner);
    coremod_log.log('V(APP_USER): '||V('APP_USER'));
    coremod_log.log('l_folder.is_readonly: '||l_folder.is_readonly);
    coremod_log.log('is_role_assigned(OPASCORE,Reas-write users): '||COREMOD_UTILS.bool2str(is_role_assigned('OPASCORE','Reas-write users')));
    */
    return is_role_assigned('OPASCORE','Reas-write users') and (l_folder.obj_owner = V('APP_USER') or l_folder.obj_owner = 'PUBLIC') and l_folder.is_readonly = 'N';
  end;

  function can_edit  (p_obj_id    opas_objects.obj_id%type) return boolean
  is
    l_obj opas_objects%rowtype := COREOBJ_API.get_obj(p_obj_id);
  begin
    return is_role_assigned('OPASCORE','Reas-write users') and (l_obj.obj_owner = V('APP_USER') or l_obj.obj_owner = 'PUBLIC');
  end;

  function can_remove(p_obj_id    opas_objects.obj_id%type) return boolean
  is
  begin
    return can_edit(p_obj_id);
  end;

  function can_remove_c(p_obj_id    opas_objects.obj_id%type) return varchar2
  is
  begin
    return case when can_remove(p_obj_id) then 'TRUE' else 'FALSE' end;
  end;

  function can_move  (p_obj_id    opas_objects.obj_id%type,
                      p_folder_id opas_objects.obj_id%type) return boolean
  is
    l_obj  opas_objects%rowtype := COREOBJ_API.get_obj(p_obj_id);
    l_fldr opas_objects%rowtype := COREOBJ_API.get_obj(p_folder_id);
  begin
    return is_role_assigned('OPASCORE','Reas-write users') and (l_obj.obj_owner = V('APP_USER') or l_obj.obj_owner = 'PUBLIC') and (l_fldr.obj_owner = V('APP_USER') or l_fldr.obj_owner = 'PUBLIC');
  end;

  function can_move_folder_content (p_folder_id opas_objects.obj_id%type) return boolean
  is
  begin
    return can_edit(p_folder_id);
  end;
end COREMOD_SEC;
/


