

CREATE OR REPLACE
package coreobj_asha_cube is

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null);

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null);

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N');

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

  procedure cleanup_ranges;
/*
  procedure archive_data_to_subpartition(p_dblink opas_db_links.db_link_name%type);
*/
  function create_subpart_name (p_dblink opas_db_links.db_link_name%type,
                                p_max_date date) return varchar2;

end coreobj_asha_cube;
/


