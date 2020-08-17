CREATE OR REPLACE


PACKAGE COREMOD_REPORT_UTILS AS

  gPixelPerChar  constant number := 6.1;

  type t_output_lines       is table of varchar2(32767) index by pls_integer;
  type t_params             is table of varchar2(32767) index by varchar2(100);
  type t_arrayofstrings     is table of varchar2(32767);
  type t_section            is table of t_arrayofstrings index by varchar2(100);
  type t_available_sections is table of number index by varchar2(100);

  function to_hr_num (p_number number) return varchar2;

  function tptformat( p_num in number,
                      p_stype in varchar2 default 'STAT',
                      p_precision in number default 2,
                      p_base in number default 10,    -- for KiB/MiB formatting use
                      p_grouplen in number default 3  -- p_base=2 and p_grouplen=10
                     ) return varchar2;

  procedure convert_to_html_table (p_text          clob default null,
                                   p_input      in t_output_lines,
                                   p_t_header      varchar2,
                                   p_width         number,
                                   p_search        varchar2 default null,
                                   p_replacement   varchar2 default null,
                                   p_comparison    boolean default false,
                                   p_style_tab     varchar2,
                                   p_style_head    varchar2, --head
                                   p_style_r1      varchar2,   --odd rows
                                   p_style_r2      varchar2, --even rows
                                   p_output in out t_output_lines);

  procedure print_query_result_html
                            (p_query in varchar2,
                             p_width number,
                             p_summary varchar2,
                             p_style_tab varchar2,
                             p_style_head varchar2, --head
                             p_style_r1 varchar2,   --odd rows
                             p_style_r2  varchar2, --even rows
                             p_style_finrow  varchar2, --final row
                             p_search varchar2 default null,
                             p_replacement varchar2 default null,
                             p_header number default 0,
                             p_break_col varchar2 default null,
                             p_output in out t_output_lines);

  procedure print_3arrays
                       (p_t_header      varchar2,
                        p_width         number,
                        p_style_r1      varchar2, --odd rows
                        p_style_r2      varchar2, --even rows
                        p_style_head    varchar2, --head
                        p_style_tab     varchar2,
                        p_output in out COREMOD_REPORT_UTILS.t_output_lines,
                        p_col1          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col2          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col3          COREMOD_REPORT_UTILS.t_output_lines);

END COREMOD_REPORT_UTILS;
/


