CREATE OR REPLACE
PACKAGE COREOBJ_FOLDER AS

  procedure lock_object(p_obj_id opas_objects.obj_id%type);

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_folder_name      opas_objects.obj_name%type default null);

  procedure remove(p_obj_id           opas_objects.obj_id%type,
                   p_cascade          varchar2 default 'N');
  function folder_icon(p_obj_id           opas_objects.obj_id%type,
                       p_obj_ot           opas_objects.obj_ot%type,
                       p_curr_folder      opas_objects.obj_id%type) return varchar2;

  procedure get_init_navigation(p_folder  out opas_objects.obj_id%type,
                                p_obj_id  out opas_objects.obj_id%type);

  procedure set_nav_folder     (p_folder      opas_objects.obj_id%type);
  procedure calc_folder_size   (p_folder      opas_objects.obj_id%type);

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

END COREOBJ_FOLDER;
/
