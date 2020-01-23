CREATE OR REPLACE
PACKAGE BODY COREOBJ_MEMO AS

  procedure add   (p_obj_id           opas_objects.obj_id%type)
  AS
    l_file_id    opas_files.file_id%type;
  BEGIN
    l_file_id := COREMOD_FILE_UTILS.create_file(
      P_MODNAME => COREMOD_API.gMODNAME,
      P_FILE_TYPE => 'MEMO',
      P_FILE_NAME => 'memo.rtf',
      P_MIMETYPE => COREMOD_FILE_UTILS.mtRTF,
      P_OWNER => 'PUBLIC');
    COREMOD_FILE_UTILS.store_content (
       P_FILE_ID => l_file_id,
       P_CONTENT => '--Enter memo here--') ;
    insert into OPAS_OT_MEMO (MEMO_ID, MEMO_CONTENT) values (p_obj_id,l_file_id);
  END add;

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_memo             opas_files.file_contentc%type)
  AS
    l_file_id    opas_files.file_id%type;
  BEGIN
    select MEMO_CONTENT into l_file_id from OPAS_OT_MEMO where MEMO_ID = p_obj_id;
    COREMOD_FILE_UTILS.store_content (
       P_FILE_ID => l_file_id,
       P_CONTENT => p_memo) ;
  END edit;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N')
  AS
    l_file_id    opas_files.file_id%type;
  BEGIN
    delete from OPAS_OT_MEMO where MEMO_ID = p_obj_id returning MEMO_CONTENT into l_file_id;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_file_id) ;
  END remove;

  function get_object_status_do_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
  begin
    return null;
  end;

END COREOBJ_MEMO;
/
