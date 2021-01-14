

CREATE OR REPLACE
PACKAGE BODY COREMOD_FILE_UTILS AS

  function clob2tab(p_file_id    opas_files.file_id%type) return clob_page pipelined
  as
      m_c1            clob;
      --m_b1            blob;
      m_length        number(12);

      l_eof       number;
      l_iter      number;
      l_off       number;

      l_chunk_off number := 1;
      l_chunk     varchar2(32765);

      --l_lcntx     integer := DBMS_LOB.DEFAULT_LANG_CTX;
      --l_wrng      integer;
  begin
      select file_contentc, length(file_contentc)
      into   m_c1, m_length
      from   opas_files
      where  file_id = p_file_id;
/*
      DBMS_LOB.CONVERTTOCLOB(
        dest_lob       => m_c1,
        src_blob       => m_b1,
        amount         => DBMS_LOB.LOBMAXSIZE,
        dest_offset    => l_off,
        src_offset     => l_off,
        blob_csid      => DBMS_LOB.DEFAULT_CSID,
        lang_context   => l_lcntx,
        warning        => l_wrng);
*/
      if (m_c1 is null or m_length = 0) then
          pipe row(clob_line(1,to_char(null)));
      else
        l_iter:=1;
        m_c1:=m_c1||chr(10);
        loop
          l_chunk:=substr(m_c1,l_chunk_off,32765);
          l_chunk:=substr(l_chunk,1,instr(l_chunk,chr(10),-1));
          exit when nvl(length(l_chunk),0)=0;
          l_chunk_off:=l_chunk_off+length(l_chunk);
          l_off:=1;
          loop
            l_eof:=instr(l_chunk,chr(10),l_off);
            if l_eof=0 then
              --pipe row (clob_line( l_iter, '<EOF>' /*substr(rtrim(rtrim(substr(l_chunk,l_off),chr(13)),chr(10)),1,4000)*/));
              null;
            else
              pipe row (clob_line( l_iter, substr(rtrim(rtrim(substr(l_chunk,l_off,l_eof-l_off+1),chr(13)),chr(10)),1,4000)));
            end if;
            l_off:=1+l_eof;
            l_iter:=l_iter+1;
            exit when l_eof=0;
          end loop;
        end loop;
      end if;
      return;
  end;

  --download preparation/depreparation
  procedure clob2blob_prep   (p_file_id    opas_files.file_id%type)
  is
    m_c1            clob;
    m_b1            blob;
    l_last_prep     timestamp;
    l_lcntx     integer := DBMS_LOB.DEFAULT_LANG_CTX;
    l_wrng      integer;
    l_off       number := 1;
  begin
    select file_contentc, nvl(file_contentb,empty_blob()), blob_prepared
      into   m_c1, m_b1, l_last_prep
      from   opas_files
     where  file_id = p_file_id and file_mimetype in (mtTEXT, mtHTML, mtPLAINTEXT) for update wait 60;

    if l_last_prep is null then
      DBMS_LOB.CONVERTTOBLOB(
        dest_lob       => m_b1,
        src_clob       => m_c1,
        amount         => DBMS_LOB.LOBMAXSIZE,
        dest_offset    => l_off,
        src_offset     => l_off,
        blob_csid      => DBMS_LOB.DEFAULT_CSID,
        lang_context   => l_lcntx,
        warning        => l_wrng);

      update opas_files set file_contentb = m_b1, blob_prepared = systimestamp where file_id = p_file_id;
    else
      update opas_files set blob_prepared = systimestamp where file_id = p_file_id;
    end if;
  end;

  procedure clob2blob_cleanup
  is
    l_cnt number;
  begin
    delete from opas_files where blob_prepared + 1/24 < systimestamp and file_mimetype in (mtTEXT, mtHTML) and file_type = ftTMP2DOWNLOAD;
    update opas_files set file_contentb = empty_blob(), blob_prepared = null where blob_prepared + 1/24 < systimestamp and file_mimetype in (mtTEXT, mtHTML);
    l_cnt := sql%rowcount;
    if l_cnt > 0 then
      coremod_log.log('COREMOD_FILE_UTILS.clob2blob_cleanup: cleaned '||l_cnt||' files.');
    end if;
  end;

  -----------------------------------------------------------
  procedure move_blob2clob (p_file_id    opas_files.file_id%type)
  is
    m_c1            clob;
    m_b1            blob;
    l_lcntx     integer := DBMS_LOB.DEFAULT_LANG_CTX;
    l_wrng      integer;
    l_off       number := 1;
  begin
    select file_contentc,
           file_contentb
      into   m_c1, m_b1
      from   opas_files
     where  file_id = p_file_id for update wait 60;

     DBMS_LOB.CONVERTTOCLOB(
        dest_lob       => m_c1,
        src_blob       => m_b1,
        amount         => DBMS_LOB.LOBMAXSIZE,
        dest_offset    => l_off,
        src_offset     => l_off,
        blob_csid      => DBMS_LOB.DEFAULT_CSID,
        lang_context   => l_lcntx,
        warning        => l_wrng);

      update opas_files set file_contentc = m_c1, file_contentb = null where file_id = p_file_id;
  end;

  function create_tmp_4downl
                      (p_file_name opas_files.file_name%type,
                       p_mimetype  opas_files.file_mimetype%type
                      ) return     opas_files.file_id%type
  is
    l_file opas_files.file_id%type;
  begin
    l_file := coremod_file_utils.create_file(p_modname => coremod_api.gmodname,
                                             p_file_type => ftTMP2DOWNLOAD,
                                             p_file_name => create_tmp_4downl.p_file_name,
                                             p_mimetype => create_tmp_4downl.p_mimetype,
                                             p_owner => 'PUBLIC');
    return l_file;
  end;

  function prepare_file_4download(p_file_name varchar2,
                                  p_file_mime_type varchar2,
                                  p_file_content clob) return opas_files.file_id%type
  is
    l_file_id    opas_files.file_id%type;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREMOD_FILE_UTILS.PREPARE_FILE_4DOWNLOAD.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREMOD_FILE_UTILS.PREPARE_FILE_4DOWNLOAD.SQL_TRACE');

    l_file_id := COREMOD_FILE_UTILS.create_tmp_4downl(
      P_FILE_NAME => p_file_name,
      P_MIMETYPE =>  p_file_mime_type);

    COREMOD_FILE_UTILS.store_content (
       P_FILE_ID => l_file_id,
       P_CONTENT => p_file_content) ;

    coremod_file_utils.clob2blob_prep(p_file_id => l_file_id);

    COREMOD_LOG.Stop_SQL_TRACE('COREMOD_FILE_UTILS.PREPARE_FILE_4DOWNLOAD.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREMOD_FILE_UTILS.PREPARE_FILE_4DOWNLOAD.GATHER_SQL_STAT');

    return l_file_id;
  end;

  -------------------------------------------------------------------
  function create_file(p_modname   opas_files.modname%type,
                       p_file_type opas_files.file_type%type,
                       p_file_name opas_files.file_name%type,
                       p_mimetype  opas_files.file_mimetype%type,
                       p_owner     opas_files.owner%type default 'PUBLIC'
                      ) return     opas_files.file_id%type AS
    l_file_id opas_files.file_id%type;
  BEGIN
    INSERT INTO opas_files (  modname,  file_type,  file_name,  file_mimetype,file_contentb,file_contentc,
                              created,  owner)
                    VALUES (p_modname,p_file_type,p_file_name,p_mimetype,     empty_blob(), case when p_mimetype in (mtTEXT, mtHTML) then empty_clob() else null end,
                              default,p_owner) returning file_id into l_file_id;
    return l_file_id;
  END create_file;

  function  copy_file(p_file_id opas_files.file_id%type) return opas_files.file_id%type
  is
    l_file_id opas_files.file_id%type;
  begin
    for i in (select * from opas_files where file_id = p_file_id) loop
      INSERT INTO opas_files (  modname,   file_type,   file_name,   file_mimetype,   file_contentb,   file_contentc,   created,   owner)
                      VALUES (i.modname, i.file_type, i.file_name, i.file_mimetype, i.file_contentb, i.file_contentc, i.created, i.owner) returning file_id into l_file_id;
    end loop;
    return l_file_id;
  end;

  procedure  get_locator(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentb%type) is
  begin
    select file_contentb into p_locator from opas_files where file_id=p_file_id;
  end;

  procedure  get_locator(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentc%type) is
  begin
    select file_contentc into p_locator from opas_files where file_id=p_file_id;
  end;

  procedure  get_locator_for_storage(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentb%type) is
  begin
    update opas_files set file_contentb=empty_blob() where file_id=p_file_id /*and file_mimetype in (mtAPPBIN)*/ returning file_contentb into p_locator;
--    if sql%rowcount<1 then
--      raise_application_error(-20000,'Storing binaries not allowed for FILE_ID: '||p_file_id);
--    end if;
  end;
  procedure  get_locator_for_storage(p_file_id opas_files.file_id%type, p_locator out opas_files.file_contentc%type) is
  begin
    update opas_files set file_contentc=empty_clob() where file_id=p_file_id /*and file_mimetype in (mtTEXT, mtHTML)*/ returning file_contentc into p_locator;
--    if sql%rowcount<1 then
--      raise_application_error(-20000,'Storing texts not allowed for FILE_ID: '||p_file_id);
--    end if;
  end;

  procedure store_content(p_file_id opas_files.file_id%type,
                          p_content opas_files.file_contentb%type) AS
    l_file_mimetype opas_files.file_mimetype%type;
  BEGIN
    update opas_files set file_contentb=p_content where file_id=p_file_id returning file_mimetype into l_file_mimetype;
    if l_file_mimetype in (mtTEXT, mtHTML) then
      move_blob2clob(p_file_id);
    end if;
  END store_content;

  procedure store_content(p_file_id opas_files.file_id%type,
                          p_content opas_files.file_contentc%type) AS
  BEGIN
    update opas_files set file_contentc=p_content where file_id=p_file_id; -- and file_mimetype in (mtTEXT, mtHTML);
  END store_content;

  procedure delete_file(p_file_id opas_files.file_id%type)
  is
  begin
    delete from opas_files where file_id = p_file_id;
  end;
/*
  function get_filec_size(p_file_id opas_files.file_id%type) return number
  is
    l_size number;
  begin
    select nvl(dbms_lob.getlength(file_contentc),0) into l_size from opas_files where file_id=p_file_id;
    return l_size;
  end;

  function get_fileb_size(p_file_id opas_files.file_id%type) return number
  is
    l_size number;
  begin
    select nvl(dbms_lob.getlength(file_contentb),0) into l_size from opas_files where file_id=p_file_id;
    return l_size;
  end;
*/
  function get_file_size(p_file_id opas_files.file_id%type) return number
  is
    l_size number;
  begin
    select case
             when file_mimetype in (mtTEXT, mtHTML)  then nvl(dbms_lob.getlength(file_contentc),0)
             when file_mimetype in (/*mtBIN,*/ mtAPPBIN) then nvl(dbms_lob.getlength(file_contentb),0)
           else
             null
           end
      into l_size
      from opas_files
     where file_id=p_file_id;
    return l_size;
  end;

  procedure put_file_to_fs(p_blob blob, p_filename varchar2, p_dir varchar2, p_uncompress boolean default false)
  is
    l_file      UTL_FILE.FILE_TYPE;
    l_buffer    RAW(32767);
    l_amount    BINARY_INTEGER := 32767;
    l_pos       INTEGER := 1;
    l_blob_len  INTEGER;
    l_blob      blob;
  BEGIN
    coremod_log.log('COREMOD_FILE_UTILS.put_file_to_fs: '||p_filename||';'||p_dir,'DEBUG');

    if p_uncompress then
      l_blob := UTL_COMPRESS.LZ_UNCOMPRESS(src => p_blob);
    else
      l_blob := p_blob;
    end if;

    l_blob_len := DBMS_LOB.getlength(l_blob);

    -- Open the destination file.
    l_file := UTL_FILE.fopen(p_dir,p_filename,'wb', 32767);

    -- Read chunks of the BLOB and write them to the file
    -- until complete.
    WHILE l_pos < l_blob_len LOOP
      DBMS_LOB.read(l_blob, l_amount, l_pos, l_buffer);
      UTL_FILE.put_raw(l_file, l_buffer, TRUE);
      l_pos := l_pos + l_amount;
    END LOOP;

    -- Close the file.
    UTL_FILE.fclose(l_file);

  EXCEPTION
    WHEN OTHERS THEN
      -- Close the file if something goes wrong.
      IF UTL_FILE.is_open(l_file) THEN
        UTL_FILE.fclose(l_file);
      END IF;
      RAISE;
  END;

  procedure get_file_from_fs(p_file_id opas_files.file_id%type, p_filename varchar2, p_dir varchar2, p_compress boolean default false)
  is
    l_bfile             bfile := bfilename(p_dir, p_filename);
    l_blob              blob;
    l_tmp               blob;
  begin
    get_locator_for_storage(p_file_id,l_blob);

    dbms_lob.open(l_bfile, dbms_lob.lob_readonly);

    if p_compress then
      DBMS_LOB.CREATETEMPORARY (lob_loc => l_tmp, cache => true, dur => DBMS_LOB.SESSION);
      l_tmp:=UTL_COMPRESS.LZ_COMPRESS (src => l_bfile);
      DBMS_LOB.COPY (dest_lob    => l_blob, src_lob     => l_tmp, amount => DBMS_LOB.LOBMAXSIZE);
    else
      dbms_lob.open(l_blob, dbms_lob.lob_readwrite);
      dbms_lob.loadfromfile(dest_lob      => l_blob,
                            src_lob       => l_bfile,
                            amount        => dbms_lob.getlength(l_bfile));
      dbms_lob.close(l_blob);
    end if;
    dbms_lob.close(l_bfile);
  end;

  procedure remove_file_from_fs(p_filename varchar2,
                                p_dir varchar2)
  is
    l_exists       BOOLEAN;
    l_file_length  NUMBER;
    l_blocksize    NUMBER;
  begin
    coremod_log.log('COREMOD_FILE_UTILS.remove_file_from_fs: '||p_filename||';'||p_dir,'DEBUG');
    UTL_FILE.fgetattr(p_dir, p_filename, l_exists, l_file_length, l_blocksize);
    if l_exists then
      UTL_FILE.FREMOVE ( location => p_dir, filename => p_filename);
    end if;
  end;

END COREMOD_FILE_UTILS;
/


