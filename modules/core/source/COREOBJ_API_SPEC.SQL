

CREATE OR REPLACE
PACKAGE COREOBJ_API AS

  --select rpad('  ot'||upper(replace(ot_name,' ','_')),30,' ')||'constant number := '||ot_id||';', x.* from opas_object_types x order by 2;

  otFOLDER                    constant number := 100;
  otATTACHMENT                constant number := 110;
  otREPORT                    constant number := 120;
  otDB_LINK_ASSIGNMENT        constant number := 130;
  otSQL_PERFORMANCE_DATA      constant number := 140;
  otSQL_LIST                  constant number := 150;
  otSQL_TRACE                 constant number := 200;
  otASHA_CUBE                 constant number := 300;
  otAWR_DUMP                  constant number := 400;
  otDB_GROWTH_TRACKER         constant number := 500;
  otSIMPLE_DB_MONITOR         constant number := 600;
  otSQL_Catcher               constant number := 700;
  otSQL_COMPARISON            constant number := 800;
  otSQL_FORECAST_REPORT       constant number := 900;	


  type t_string_indexed_tbl is table of varchar2(4000) index by pls_integer;

  g_ot_icons         t_string_indexed_tbl;
  g_ot_api           t_string_indexed_tbl;
  g_ot_create_page   t_string_indexed_tbl;

  type t_params is table of varchar2(4000) index by varchar2(256);
  gParams t_params;

  --type tParamsSet is table of COREOBJ_API.t_params index by varchar2(256);

  jsParamName            constant opas_object_pars.par_name%type := 'OPASSYSJSPAR';

  procedure lock_object(p_obj_id opas_objects.obj_id%type, p_mode varchar2 default 'NOWAIT', p_wait number default 60);

  procedure add   (p_obj_id      out opas_objects.obj_id%type,
                   p_obj_prnt        opas_objects.obj_prnt%type,
                   p_obj_ot          opas_objects.obj_ot%type,
                   p_obj_name        opas_objects.obj_name%type,
                   p_obj_descr       opas_objects.obj_descr%type,
                   p_obj_created     opas_objects.obj_created%type default sysdate,
                   p_obj_expired     opas_objects.obj_expired%type default null,
                   p_obj_sortordr    opas_objects.obj_sortordr%type default 0,
                   p_obj_owner       opas_objects.obj_owner%type default 'PUBLIC',
                   p_is_public       opas_objects.is_public%type default 'Y');

  procedure edit  (p_obj_id          opas_objects.obj_id%type,
                   p_obj_name        opas_objects.obj_name%type,
                   p_obj_descr       opas_objects.obj_descr%type,
                   p_obj_expired     opas_objects.obj_expired%type,
                   p_obj_sortordr    opas_objects.obj_sortordr%type,
                   p_obj_owner       opas_objects.obj_owner%type,
                   p_is_public       opas_objects.is_public%type,
                   p_is_readonly     opas_objects.is_readonly%type default 'N',
                   p_retention       number default -1);

  procedure edit_descr  (p_obj_id          opas_objects.obj_id%type,
                         p_obj_name        opas_objects.obj_name%type,
                         p_obj_descr       opas_objects.obj_descr%type,
                         p_obj_owner       opas_objects.obj_owner%type default null);

  procedure remove(p_obj_id opas_objects.obj_id%type);

  procedure copy  (p_src_obj_id       opas_objects.obj_id%type,
                   p_trg_obj_prnt     opas_objects.obj_prnt%type,
                   p_new_obj_id   out opas_objects.obj_id%type);

  procedure move  (p_src_obj_id       opas_objects.obj_id%type,
                   p_trg_obj_prnt     opas_objects.obj_prnt%type);

  function get_obj(p_obj_id           opas_objects.obj_id%type) return opas_objects%rowtype;
  procedure set_obj_size(p_obj_id     opas_objects.obj_id%type,
                         p_size       number);

  procedure check_remove_ability(p_obj_id opas_objects.obj_id%type);

  procedure set_param (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                       p_par_name        OPAS_OBJECT_PARS.par_name%type,
                       p_NUM_PAR         OPAS_OBJECT_PARS.NUM_PAR%type default null,
                       p_VARCHAR_PAR     OPAS_OBJECT_PARS.VARCHAR_PAR%type default null,
                       p_DATE_PAR        OPAS_OBJECT_PARS.DATE_PAR%type default null,
                       p_DTTZ_PAR        OPAS_OBJECT_PARS.DTTZ_PAR%type default null);

  procedure clean_param (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type);

  function  get_param_n (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return number;
  function  get_param_d (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return date;
  function  get_param_c (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return varchar2;
  function  get_param_z (p_obj_id          OPAS_OBJECT_PARS.obj_id%type,
                         p_par_name        OPAS_OBJECT_PARS.par_name%type,
                         p_search_top      boolean default false) return timestamp with time zone;
  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type,
                                         p_obj_ot          opas_objects.obj_ot%type) return varchar2;

  function get_object_path(p_obj_id           opas_objects.obj_id%type,
                           p_including_object varchar2 default 'Y') return varchar2;

  --JSON params
  procedure set_json_par_name(p_ParamName opas_object_pars.par_name%type default jsParamName);

  procedure add_jparam(p_obj_id           opas_objects.obj_id%type,
                      p_pname      varchar2,
                      p_value      varchar2);
  procedure extract_jparams(p_obj_id           opas_objects.obj_id%type);
  procedure get_jparam(p_obj_id           opas_objects.obj_id%type,
                       p_pname      varchar2,
                       p_value  out varchar2,
                       p_default    varchar2 default null);
  function get_all_jparam(p_obj_id           opas_objects.obj_id%type) return t_params;
  procedure store_jparams(p_obj_id           opas_objects.obj_id%type);

  --set json whole param
  procedure set_jparam(p_obj_id           opas_objects.obj_id%type,
                       p_pname            varchar2,
                       p_json             clob);

  procedure remove_param(p_obj_id           opas_objects.obj_id%type,
                         p_pname            varchar2);
END COREOBJ_API;
/


