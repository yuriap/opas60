CREATE OR REPLACE
PACKAGE COREOBJ_MEMO AS

  procedure add   (p_obj_id           opas_objects.obj_id%type);
  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_memo             opas_files.file_contentc%type);
  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N');

END COREOBJ_MEMO;
/
