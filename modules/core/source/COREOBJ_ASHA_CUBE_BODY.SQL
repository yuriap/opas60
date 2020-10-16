

CREATE OR REPLACE
package body coreobj_asha_cube is

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status varchar2(100);
  begin
      select 'Cube: '||acube.status||'; Ranges: '||ranges.range_status
      into l_status
      from (select status from OPAS_OT_ASHACUBE where ASHACUBE_ID = p_obj_id) acube,
           (select listagg(status || ':' || cnt) within group(order by status) range_status
              from (select status, count(1) cnt from OPAS_OT_ASHACUBE_RANGES ra, OPAS_OT_ASHACUBE_REF refs
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
  begin

    delete from opas_ot_ashacube_ash r
     where asharange_id in (select asharange_id from opas_ot_ashacube_ref where ashacube_id = p_obj_id)
       and not exists (select 1 from opas_ot_ashacube_ref i where i.ASHARANGE_ID = r.ASHARANGE_ID and ashacube_id != p_obj_id);

    delete from opas_ot_ashacube_ranges r
     where asharange_id in (select asharange_id from opas_ot_ashacube_ref where ashacube_id = p_obj_id)
       and not exists (select 1 from opas_ot_ashacube_ref i where i.ASHARANGE_ID = r.ASHARANGE_ID and ashacube_id != p_obj_id);

    delete from opas_ot_ashacube_ref  where ashacube_id = p_obj_id;
    delete from opas_ot_ashacube where ashacube_id = p_obj_id;

    COREOBJ_API.remove(p_obj_id);
  end;

  procedure cleanup_ranges
  is
  begin
    delete from opas_ot_ashacube_ranges d
     where created + NUMTODSINTERVAL(COREMOD_API.getconf(P_KEY => 'ASHARANGE', P_MODULE => 'OPASCORE'), 'DAY') < systimestamp
       and not exists (select 1 from opas_ot_ashacube_ref r where r.asharange_id = d.asharange_id)
       and PRESERVE_POLICY = 'N';
    commit;
  end;

end coreobj_asha_cube;
/


