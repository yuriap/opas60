

CREATE OR REPLACE
PACKAGE COREOBJ_ATTACHMENTS AS

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type);

  procedure register(p_obj_id    opas_objects.obj_id%type,
                     p_file_type opas_files.file_type%type,
                     p_file_name opas_files.file_name%type,
                     p_mimetype  opas_files.file_mimetype%type,
                     p_modname   opas_files.modname%type default COREMOD_API.gMODNAME,
                     p_owner     opas_files.owner%type default 'PUBLIC',
                     p_descr     opas_objects.obj_descr%type--,
                     --p_file_id   out opas_files.file_id%type
                     );

  procedure lock_object(p_obj_id opas_objects.obj_id%type);
  function  lock_object(p_obj_id opas_objects.obj_id%type) return opas_ot_attachments%rowtype;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N');
/*
  procedure copy    (p_src_obj_id       opas_objects.obj_id%type,
                     p_trg_obj_prnt     opas_objects.obj_prnt%type);
*/
  function  get_size(p_obj_id opas_objects.obj_id%type) return number;
  procedure store_content(p_obj_id    opas_objects.obj_id%type,
                          p_content opas_files.file_contentb%type);

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

END COREOBJ_ATTACHMENTS;
/


