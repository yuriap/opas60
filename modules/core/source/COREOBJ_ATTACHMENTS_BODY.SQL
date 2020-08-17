

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ATTACHMENTS AS

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type) AS
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otATTACHMENT,
      P_OBJ_NAME  => 'File_'||to_char(sysdate,'YYYYMMDD'),
      P_OBJ_DESCR => null) ;
  END add;

  procedure register(p_obj_id    opas_objects.obj_id%type,
                     p_file_type opas_files.file_type%type,
                     p_file_name opas_files.file_name%type,
                     p_mimetype  opas_files.file_mimetype%type,
                     p_modname   opas_files.modname%type default COREMOD_API.gMODNAME,
                     p_owner     opas_files.owner%type default 'PUBLIC',
                     p_descr     opas_objects.obj_descr%type--,
                     --p_file_id   out opas_files.file_id%type
                     ) AS
    l_file_id opas_files.file_id%type;
  BEGIN
    l_file_id := COREMOD_FILE_UTILS.create_file(P_MODNAME => p_modname,
                                                P_FILE_TYPE => p_file_type,
                                                P_FILE_NAME => p_file_name,
                                                P_MIMETYPE => p_mimetype,
                                                P_OWNER => p_owner);

    INSERT INTO opas_ot_attachments
     ( attach_id, modname, attach_content)
    VALUES
     ( p_obj_id, p_modname, l_file_id);

    for i in (select * from opas_objects where obj_id = p_obj_id) loop
      COREOBJ_API.edit (
        P_OBJ_ID => i.obj_id,
        P_OBJ_NAME => p_file_name,
        P_OBJ_DESCR => p_descr,
        P_OBJ_EXPIRED => i.OBJ_EXPIRED,
        P_OBJ_SORTORDR => i.OBJ_SORTORDR,
        P_OBJ_OWNER => p_owner,
        P_IS_PUBLIC => i.IS_PUBLIC,
        P_RETENTION => -1) ;
    end loop;
  END register;

  function  lock_object(p_obj_id opas_objects.obj_id%type) return opas_ot_attachments%rowtype
  is
    l_result opas_ot_attachments%rowtype;
  begin
    select * into l_result from opas_ot_attachments where attach_id = p_obj_id for update nowait;
    return l_result;
  end;

  procedure lock_object(p_obj_id opas_objects.obj_id%type) AS
    l_result opas_ot_attachments%rowtype;
  BEGIN
    l_result := lock_object(p_obj_id);
  END lock_object;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N') AS
    l_result opas_ot_attachments.attach_content%type;
  BEGIN
    COREOBJ_API.lock_object(p_obj_id);
    --l_result := lock_object(p_obj_id);
    COREOBJ_API.check_remove_ability(p_obj_id);
    delete from opas_ot_attachments where attach_id = p_obj_id returning attach_content into l_result;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_result) ;
    COREOBJ_API.remove(p_obj_id);
  END remove;

/*
  procedure copy    (p_src_obj_id       opas_objects.obj_id%type,
                     p_trg_obj_prnt     opas_objects.obj_prnt%type) AS
    l_result     opas_ot_attachments%rowtype;
    l_file_id    opas_files.file_id%type;

    L_NEW_OBJ_ID opas_objects.obj_id%type;
  BEGIN
    l_result := lock_object(p_src_obj_id);
    COREOBJ_API.copy (
      P_SRC_OBJ_ID => P_SRC_OBJ_ID,
      P_TRG_OBJ_PRNT => P_TRG_OBJ_PRNT,
      P_NEW_OBJ_ID => L_NEW_OBJ_ID) ;

    l_file_id := COREMOD_FILE_UTILS.copy_file(P_FILE_ID => l_result.attach_content);

    INSERT INTO opas_ot_attachments
     ( attach_id, modname, attach_content)
    VALUES
     ( L_NEW_OBJ_ID, l_result.modname, l_file_id);
  END copy;
*/

  function  get_size(p_obj_id opas_objects.obj_id%type) return number
  is
    l_file_id opas_files.file_id%type;
  begin
    select attach_content into l_file_id from opas_ot_attachments where attach_id = p_obj_id;
    return COREMOD_FILE_UTILS.get_file_size(l_file_id);
  end;

  procedure store_content(p_obj_id    opas_objects.obj_id%type,
                          p_content opas_files.file_contentb%type)
  is
    l_file_id opas_files.file_id%type;
  begin
    select attach_content into l_file_id from opas_ot_attachments where attach_id = p_obj_id;
    COREMOD_FILE_UTILS.store_content(l_file_id,p_content);
    COREOBJ_API.set_obj_size(p_obj_id,COREMOD_FILE_UTILS.get_file_size(l_file_id));
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
  begin
    return null;
  end;

END COREOBJ_ATTACHMENTS;
/


