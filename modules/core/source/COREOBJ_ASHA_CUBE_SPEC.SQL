CREATE OR REPLACE
package coreobj_asha_cube is

  procedure add;
  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

end coreobj_asha_cube;
/
