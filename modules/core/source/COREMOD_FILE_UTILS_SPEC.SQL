CREATE OR REPLACE
PACKAGE COREMOD_FILE_UTILS AS

  --Mime Types
  mtTEXT      constant varchar2(100) := 'TXT';
  mtHTML      constant varchar2(100) := 'TEXT/HTML';
  --mtBIN       constant varchar2(100) := 'BIN';
  mtAPPBIN    constant varchar2(100) := 'APPLICATION/OCTET-STREAM';
  mtRTF       constant varchar2(100) := 'APPLICATION/RTF';

  function clob2tab(p_file_id    opas_files.file_id%type) return clob_page pipelined;

  --download preparation/depreparation
  procedure clob2blob_prep   (p_file_id    opas_files.file_id%type);
  procedure clob2blob_cleanup;

  --File Operatios
  function create_file(p_modname   opas_files.modname%type,
                       p_file_type opas_files.file_type%type,
                       p_file_name opas_files.file_name%type,
                       p_mimetype  opas_files.file_mimetype%type,
                       p_owner     opas_files.owner%type default 'PUBLIC'
                      ) return     opas_files.file_id%type;

  procedure  get_locator(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentb%type);
  procedure  get_locator(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentc%type);

  procedure  get_locator_for_storage(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentb%type);
  procedure  get_locator_for_storage(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentc%type);

  procedure store_content(p_file_id opas_files.file_id%type,
                          p_content opas_files.file_contentb%type);

  procedure store_content(p_file_id opas_files.file_id%type,
                          p_content opas_files.file_contentc%type);

  procedure move_blob2clob (p_file_id    opas_files.file_id%type);

  procedure delete_file(p_file_id opas_files.file_id%type);

  function  copy_file(p_file_id opas_files.file_id%type) return opas_files.file_id%type;

  --function get_filec_size(p_file_id opas_files.file_id%type) return number;
  --function get_fileb_size(p_file_id opas_files.file_id%type) return number;
  function get_file_size(p_file_id opas_files.file_id%type) return number;

  --FS
  procedure put_file_to_fs(p_blob blob, p_filename varchar2, p_dir varchar2, p_uncompress boolean default false);
  procedure get_file_from_fs(p_file_id opas_files.file_id%type, p_filename varchar2, p_dir varchar2, p_compress boolean default false);
  procedure remove_file_from_fs(p_filename varchar2, p_dir varchar2);

END COREMOD_FILE_UTILS;
/
