CREATE OR REPLACE
package coreobj_sql_tags is

  procedure add(p_tag_name opas_ot_sql_tags.tag_name%type,
                p_tag_prnt opas_ot_sql_tags.tag_prnt%type,
                p_tag_description opas_ot_sql_tags.tag_description%type,
                p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type);
/*
  procedure edit(p_tag_name opas_ot_sql_tags.tag_name%type,
                 p_tag_description opas_ot_sql_tags.tag_description%type,
                 p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type);
*/
  procedure tag_sql(p_tag_names varchar2,
                    p_sql_id    opas_ot_sql_descriptions.sql_id%type);

  procedure test_tag_expr(p_tag_name opas_ot_sql_tags.tag_name%type);

  function  tags(p_sql_id opas_ot_sql_descriptions.sql_id%type,
                 p_for_apex_ctrl varchar2 default 'N') return varchar2;
  procedure auto_tag_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type);

  function parse_tag_ist(p_tag_names varchar2,
                         p_delim     varchar2 default ',',
                         p_enclosed  varchar2 default 'Y') return varchar2;

end coreobj_sql_tags;
/
