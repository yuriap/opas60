CREATE OR REPLACE
PACKAGE BODY COREOBJ_DBLINKS2OBJ AS

  procedure add_obj   (p_obj_id       out opas_objects.obj_id%type,
                       p_obj_prnt        opas_objects.obj_prnt%type) AS
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otDB_LINK_ASSIGNMENT,
      P_OBJ_NAME  => 'DB Links '||to_char(sysdate,'YYYYMMDD'),
      P_OBJ_DESCR => null) ;
  END add_obj;

  procedure add(p_obj_id opas_objects.obj_id%type, p_db_link opas_db_links.db_link_name%type) AS
  BEGIN
    INSERT INTO opas_ot_dblinks2obj ( trg_obj_id, dblink,    default_dblink, sortordr)
                          VALUES ( p_obj_id,   p_db_link, default,        default);
  END add;

  procedure lock_object(p_obj_id opas_objects.obj_id%type,
                     p_db_link opas_db_links.db_link_name%type)
  is
  begin
    --COREOBJ_API.lock_object(p_obj_id);
    for i in (select * from opas_ot_dblinks2obj where trg_obj_id = p_obj_id and dblink = p_db_link for update nowait)
    loop
      null;
    end loop;
  end;

  procedure remove(p_obj_id    opas_objects.obj_id%type,
                   p_db_link   opas_db_links.db_link_name%type default 'N/A',
                   p_cascade   varchar2 default 'N')
  is
  begin
    delete from opas_ot_dblinks2obj where trg_obj_id = p_obj_id and dblink = decode(p_db_link,'N/A',dblink,p_db_link);
    if p_db_link = 'N/A' then
      COREOBJ_API.remove (  P_OBJ_ID => P_OBJ_ID) ;
    end if;
  end;

  procedure edit  (p_obj_id opas_objects.obj_id%type,
                   p_db_link opas_db_links.db_link_name%type,
                   p_default opas_ot_dblinks2obj.default_dblink%type,
                   p_sortordr opas_ot_dblinks2obj.sortordr%type)
  is
  begin
    if p_default = 'Y' then
      update opas_ot_dblinks2obj
         set DEFAULT_DBLINK = case when dblink = p_db_link then p_default else 'N' end,
             SORTORDR       = case when dblink = p_db_link then p_sortordr else SORTORDR end
       where trg_obj_id = p_obj_id;
    else
      update opas_ot_dblinks2obj
         set DEFAULT_DBLINK = p_default,
             SORTORDR       = p_sortordr
       where trg_obj_id = p_obj_id and dblink = p_db_link;
    end if;
  end;

  procedure copy    (p_src_obj_id       opas_objects.obj_id%type,
                     p_trg_obj_prnt     opas_objects.obj_prnt%type)
  is
    L_NEW_OBJ_ID opas_objects.obj_id%type;
  begin

    COREOBJ_API.copy (
      P_SRC_OBJ_ID => P_SRC_OBJ_ID,
      P_TRG_OBJ_PRNT => P_TRG_OBJ_PRNT,
      P_NEW_OBJ_ID => L_NEW_OBJ_ID) ;

    INSERT INTO opas_ot_dblinks2obj
         ( trg_obj_id,   dblink, default_dblink, sortordr)
    select L_NEW_OBJ_ID, dblink, default_dblink, sortordr
      from opas_ot_dblinks2obj where trg_obj_id = p_src_obj_id;
  end;
/*
  procedure move    (p_src_obj_id opas_objects.obj_id%type,
                     p_trg_obj_id opas_objects.obj_id%type)
  is
  begin
    copy(p_src_obj_id, p_trg_obj_id);
    delete from opas_ot_dblinks2obj where trg_obj_id = p_src_obj_id;
  end;
*/
  function get_dbl_list(p_obj_id opas_objects.obj_id%type) return t_opasobj_dbltab
  is
    l_tab t_opasobj_dbltab;
  begin
    select t_opasobj_dblrec(odbl.display_name, odbl.db_link_name)
      bulk collect into l_tab
      from opas_ot_dblinks2obj dbl,
           opas_objects dbl_objs,
          (select obj_id
             from opas_objects
            start with obj_id=p_obj_id
          connect by prior obj_prnt = obj_id) objs,
           v$opas_db_links odbl
     where dbl.trg_obj_id = dbl_objs.obj_id
       and dbl.dblink = odbl.db_link_name
       and objs.obj_id = dbl_objs.obj_prnt and dbl_objs.obj_ot=130;
    return l_tab;
  end;

  function get_object_status_do_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status varchar2(100);
  begin
    select status into l_status
    from opas_db_links li, OPAS_OT_DBLINKS2OBJ o2l
    where TRG_OBJ_ID = p_obj_id and DBLINK = DB_LINK_NAME;
    return l_status;
  end;

END COREOBJ_DBLINKS2OBJ;
/
