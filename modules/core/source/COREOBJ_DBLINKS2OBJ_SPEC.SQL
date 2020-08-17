

CREATE OR REPLACE
PACKAGE COREOBJ_DBLINKS2OBJ AS

  procedure add_obj (p_obj_id       out opas_objects.obj_id%type,
                     p_obj_prnt        opas_objects.obj_prnt%type);

  procedure add     (p_obj_id     opas_objects.obj_id%type,
                     p_db_link    opas_db_links.db_link_name%type);
  procedure lock_object(p_obj_id  opas_objects.obj_id%type,
                     p_db_link    opas_db_links.db_link_name%type);
  procedure remove  (p_obj_id     opas_objects.obj_id%type,
                     p_db_link    opas_db_links.db_link_name%type default 'N/A',
                     p_cascade    varchar2 default 'N');
  procedure edit    (p_obj_id     opas_objects.obj_id%type,
                     p_db_link    opas_db_links.db_link_name%type,
                     p_default    opas_ot_dblinks2obj.default_dblink%type,
                     p_sortordr   opas_ot_dblinks2obj.sortordr%type);
  procedure copy    (p_src_obj_id       opas_objects.obj_id%type,
                     p_trg_obj_prnt     opas_objects.obj_prnt%type);
  --=================================================================
  function get_dbl_list(p_obj_id opas_objects.obj_id%type) return t_opasobj_dbltab;
  function get_default_dblink(p_obj_id opas_objects.obj_id%type) return v$opas_db_links.db_link_name%type;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

END COREOBJ_DBLINKS2OBJ;
/


