CREATE OR REPLACE
package body coreobj_asha_cube is

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
  begin
    return 'TBD';
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
  begin
    COREOBJ_API.remove(p_obj_id);
  end;

  procedure cleanup_ranges
  is
  begin
    delete from opas_ot_ashacube_ranges d
     where created + NUMTODSINTERVAL(COREMOD_API.getconf(P_KEY => 'ASHARANGE', P_MODULE => 'OPASCORE'), 'DAY') > systimestamp
       and not exists (select 1 from opas_ot_ashacube_range_ref r where r.asharange_id = d.asharange_id);
    commit;
  end;

end coreobj_asha_cube;
/
