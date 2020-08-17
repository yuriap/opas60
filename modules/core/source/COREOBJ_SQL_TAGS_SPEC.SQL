

CREATE OR REPLACE
package coreobj_sql_tags is

  procedure add(p_tag_name opas_ot_sql_tags.tag_name%type,
                p_tag_prnt opas_ot_sql_tags.tag_prnt%type,
                p_tag_description opas_ot_sql_tags.tag_description%type,
                p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type);

  procedure remove(p_tag_name opas_ot_sql_tags.tag_name%type,
                   p_tag_type opas_ot_sql_sql2tags.tag_type%type default '%');

  procedure tag_sql(p_tag_names varchar2,
                    p_sql_id    opas_ot_sql_descriptions.sql_id%type);

  function  tags(p_sql_id opas_ot_sql_descriptions.sql_id%type,
                 p_for_apex_ctrl varchar2 default 'N') return varchar2;
  procedure auto_tag_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type);

  procedure remove_tag_from_sqls(p_tag_name opas_ot_sql_tags.tag_name%type,
                                 p_tag_type opas_ot_sql_sql2tags.tag_type%type default 'A');
  procedure auto_tag_sql_task(p_tag_name opas_ot_sql_tags.tag_name%type);
  procedure start_auto_tag_sql_task(p_tag_name opas_ot_sql_tags.tag_name%type);

  function parse_tag_ist(p_tag_names varchar2,
                         p_delim     varchar2 default ',',
                         p_enclosed  varchar2 default 'Y') return varchar2;

  function parse_tag_list(p_tag_names varchar2) return tableofstrings;

  procedure tag_sql_by_expr(p_tag_name opas_ot_sql_tags.tag_name%type,
                            p_expr     varchar2);
  procedure tag_all_sqls;
end coreobj_sql_tags;
/


