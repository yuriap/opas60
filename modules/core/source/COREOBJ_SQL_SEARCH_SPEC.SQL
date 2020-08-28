

CREATE OR REPLACE
PACKAGE COREOBJ_SQL_SEARCH AS

  --I - internal registry, E - through dblink, B - both
  stInternal  constant varchar2(1) := 'I';
  stExternal  constant varchar2(1) := 'E';
  stBoth      constant varchar2(1) := 'B';

  ssInQueue constant varchar2(20) := 'In Queue...';
  ssInProgress constant varchar2(20) := 'In Progress...';

  type t_params is table of varchar2(4000) index by varchar2(100);
  gParams t_params;

  function get_shorten_sql_text(p_sql_id varchar2, p_length number default 0) return varchar2 deterministic;
  function get_shorten_sql_text_for_html_expose(p_sql_text clob, p_length number default 0, p_replace_spec varchar2 default 'Y') return clob deterministic;

  procedure create_search_session(p_session_id out opas_ot_sql_searches.session_id%type,
                                  p_where varchar2);

  function is_session_current(p_session_id opas_ot_sql_searches.session_id%type) return boolean;

  procedure add_param(p_session_id opas_ot_sql_searches.session_id%type,
                      p_pname      varchar2,
                      p_value      varchar2);
  procedure extract_params(p_session_id opas_ot_sql_searches.session_id%type);
  procedure get_param(p_session_id opas_ot_sql_searches.session_id%type,
                      p_pname      varchar2,
                      p_value  out varchar2);

  procedure start_search(p_session_id opas_ot_sql_searches.session_id%type,
                         p_notifyme   boolean default false);
  --async
  procedure start_local_search(p_session_id opas_ot_sql_searches.session_id%type);
  procedure start_external_search(p_session_id opas_ot_sql_searches.session_id%type);

  procedure cleanup_sessions;
  procedure preserve_session(p_session_id opas_ot_sql_searches.session_id%type,
                             p_days       number);

END COREOBJ_SQL_SEARCH;
/


