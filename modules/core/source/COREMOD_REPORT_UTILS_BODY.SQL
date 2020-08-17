CREATE OR REPLACE


PACKAGE BODY COREMOD_REPORT_UTILS AS

  function to_hr_num (p_number number) return varchar2
  is
  begin
    return case when p_number>=0 then dbms_xplan.format_size(p_number) else '-'||dbms_xplan.format_size(abs(p_number)) end;
  end;

  function tptformat( p_num in number,
                      p_stype in varchar2 default 'STAT',
                      p_precision in number default 2,
                      p_base in number default 10,    -- for KiB/MiB formatting use
                      p_grouplen in number default 3  -- p_base=2 and p_grouplen=10
                     )
                     return varchar2
  is
  begin
      if p_num=0 then return '0'; end if;
      if p_num is null then return null; end if;
      if p_stype in ('WAIT','TIME') then
          return
              round(
                  p_num / power( p_base , trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen)) ), p_precision
              )
              || case trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen))
                     when 0            then 'us'
                     when 1            then 'us'
                     when p_grouplen*1 then 'ms'
                     when p_grouplen*2 then 's'
                     when p_grouplen*3 then 'ks'
                     when p_grouplen*4 then 'Ms'
                     else '*'||p_base||'e'||to_char( trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen)) )||' us'
                  end;
      else
          return
              round(
                  p_num / power( p_base , trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen)) ), p_precision
              )
              || case trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen))
                     when 0            then ''
                     when 1            then ''
                     when p_grouplen*1 then 'k'
                     when p_grouplen*2 then 'M'
                     when p_grouplen*3 then 'G'
                     when p_grouplen*4 then 'T'
                     when p_grouplen*5 then 'P'
                     when p_grouplen*6 then 'E'
                     else '*'||p_base||'e'||to_char( trunc(log(p_base,abs(p_num)))-trunc(mod(log(p_base,abs(p_num)),p_grouplen)) )
                  end;
      end if;
  end; -- tptformat

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
                                   p_output in out t_output_lines) is
    l_line varchar2(32765);  l_eof number;  l_iter number; l_length number;
    l_text clob;
    l_mode pls_integer := 0;

    l_pref varchar2(10) := 'z';

    l_indx       number := p_output.count + 1;
    l_char_width number := 0;

    l_tag1_indx  number;

    procedure p(p_line varchar2) is
    begin
      p_output(l_indx):=p_line;
      l_indx := l_indx + 1;
    end;
    procedure replace_tag(p_tag varchar2, p_val varchar2, p_line_num number)
    is
    begin
      p_output(p_line_num) := replace(p_output(p_line_num),p_tag,p_val);
    end;
  begin

    if p_text is not null then
      l_mode := 1;
    elsif p_input.count > 0 then
      l_mode := 2;
    end if;

    if l_mode not in (1,2) then
      raise_application_error(-20000,'Unable to execute COREMOD_REPORT_UTILS.convert_to_html_table. Mode: '||l_mode);
    end if;

    l_tag1_indx:=l_indx;
    p(HTF.TABLEOPEN(cborder=>0,cattributes=>'width="'||case when p_width = 0 then '<#WIDTH#>' else to_char(p_width) end||'" class="'||p_style_tab||'" summary="'||p_t_header||'"'));

    if p_t_header<>'#FIRST_LINE#' then
      p(HTF.TABLEROWOPEN);
      p(HTF.TABLEHEADER(cvalue=>replace(p_t_header,' ','&nbsp;'),calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"'));
      p(HTF.TABLEROWCLOSE);
    end if;

    if l_mode = 1 then
      if instr(p_text,chr(10))=0 then
        l_iter := 1;
        l_length:=dbms_lob.getlength(p_text);
        loop
          l_text := l_text||substr(p_text,l_iter,200)||chr(10);
          l_iter:=l_iter+200;
          exit when l_iter>=l_length;
        end loop;
      else
        l_text := p_text||chr(10);
      end if;
    end if;

    l_iter := 1;
    loop
      if l_mode = 1 then
        l_eof:=instr(l_text,chr(10));
        l_line:=substr(l_text,1,l_eof);
      elsif l_mode = 2 then
        l_line:=p_input(l_iter);
      end if;

      l_char_width := greatest(l_char_width, nvl(length(trim(l_line)),0));

      if p_t_header='#FIRST_LINE#' and l_iter = 1 then
        p(HTF.TABLEROWOPEN);
        p(HTF.TABLEHEADER(cvalue=>replace(l_line,' ','&nbsp;'),calign=>'left',cattributes=>'class="awrbg" scope="col"'));
        p(HTF.TABLEROWCLOSE);
      else
        p(HTF.TABLEROWOPEN);

        if p_comparison and substr(l_line,1,3)='~~*' then
          l_pref:=substr(l_line,1,7);
          l_line:=substr(l_line,8);
          l_pref:=substr(l_pref,4,1);
        end if;

        if p_search is not null and regexp_instr(l_line,p_search)>0 then
          l_line:=REGEXP_REPLACE(l_line,p_search,p_replacement);
        else
          l_line:=replace(l_line,' ','&nbsp;');
        end if;
        l_line:=replace(l_line,'`',' ');
        if p_comparison and l_pref in ('-') then
          p(HTF.TABLEDATA(cvalue=>l_line,calign=>'left',cattributes=>'class="'|| case when mod(l_iter,2)=0 then p_style_r1 else p_style_r2 end ||'"'));
        else
          p(HTF.TABLEDATA(cvalue=>l_line,calign=>'left',cattributes=>'class="'|| case when mod(l_iter,2)=0 then p_style_r1 else p_style_r2 end ||'"'));
        end if;

        p(HTF.TABLEROWCLOSE);
      end if;

      l_iter:=l_iter+1;

      if l_mode = 1 then
        l_text:=substr(l_text,l_eof+1);
        exit when /*l_iter>10000 or*/ dbms_lob.getlength(l_text)=0;
      elsif l_mode = 2 then
        exit when l_iter > p_input.count;
      end if;
    end loop;

    p(HTF.TABLECLOSE);

    if p_width = 0 then
      replace_tag('<#WIDTH#>', to_char(round(l_char_width * gPixelPerChar)), l_tag1_indx);
    end if;

    --p(l_char_width);
  end convert_to_html_table;

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
                             p_output in out t_output_lines) is
    l_theCursor   integer default dbms_sql.open_cursor;
    l_columnValue varchar2(32767);
    l_status      integer;
    l_descTbl     dbms_sql.desc_tab2;
    l_colCnt      number;
    l_rn          number := 0;
    l_style       varchar2(100);
    l_break_value varchar2(4000) := null;
    l_break_cnt   number := 1;
    l_indx   number := p_output.count + 1;

    l_final_row_col number;

    procedure p(p_line varchar2) is
    begin
      p_output(l_indx):=p_line;
      l_indx := l_indx + 1;
    end;
  begin
    p(HTF.TABLEOPEN(cborder=>0,cattributes=>'width="'||p_width||'" class="'||p_style_tab||'" summary="'||p_summary||'"'));

    dbms_sql.parse(l_theCursor, p_query, dbms_sql.native);
    dbms_sql.describe_columns2(l_theCursor, l_colCnt, l_descTbl);

    for i in 1 .. l_colCnt loop
      dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
    end loop;

    l_status := dbms_sql.execute(l_theCursor);

    --column names
    if p_style_head is not null then
      p(HTF.TABLEROWOPEN);
      for i in 1 .. l_colCnt loop
        if instr(upper(l_descTbl(i).col_name),'NOPRN')=0 then
          p(HTF.TABLEHEADER(cvalue=>l_descTbl(i).col_name,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"'));
        elsif instr(upper(l_descTbl(i).col_name),'LASTROW')>0 then
          l_final_row_col:=i;
        end if;
      end loop;
      p(HTF.TABLEROWCLOSE);
    end if;

    while dbms_sql.fetch_rows(l_theCursor) > 0 loop
      p(HTF.TABLEROWOPEN);
      l_rn := l_rn + 1;
      --coloring for rows for breaking column value
      if p_break_col is null then
        l_style := case when mod(l_rn,2)=0 then p_style_r1 else p_style_r2 end;
      else
        for i in 1 .. l_colCnt loop
          if instr(upper(l_descTbl(i).col_name),'NOPRN')=0 then
            dbms_sql.column_value(l_theCursor, i, l_columnValue);

            if p_break_col is not null and upper(p_break_col)=upper(l_descTbl(i).col_name) then
              if nvl(l_break_value,'$~') <> nvl(l_columnValue,'$~') then
                l_break_value:=l_columnValue;
                l_break_cnt:=l_break_cnt+1;
              end if;
            end if;

            if p_break_col is not null then
              l_style := case when mod(l_break_cnt,2)=0 then p_style_r1 else p_style_r2 end;
            end if;
          end if;
        end loop;
      end if;
      if p_style_finrow is not null then
        dbms_sql.column_value(l_theCursor, l_final_row_col, l_columnValue);
        if l_columnValue = 1 then l_style:=p_style_finrow; end if;
      end if;
      -----------------------------------------------------------------------------
      for i in 1 .. l_colCnt loop
        if instr(upper(l_descTbl(i).col_name),'NOPRN')=0 then
          dbms_sql.column_value(l_theCursor, i, l_columnValue);

          l_columnValue:=replace(replace(l_columnValue,chr(13)||chr(10),chr(10)||'<br/>'),chr(10),chr(10)||'<br/>');
          if p_search is not null then
            if instr(l_descTbl(i).col_name,p_search)>0 then
              l_columnValue:=REGEXP_REPLACE(l_columnValue,'(.*)',p_replacement);
              p(HTF.TABLEDATA(cvalue=>l_columnValue,calign=>'left',cattributes=>'class="'|| l_style ||'"'));
            elsif regexp_instr(l_columnValue,p_search)>0 then
              l_columnValue:=REGEXP_REPLACE(l_columnValue,p_search,p_replacement);
              p(HTF.TABLEDATA(cvalue=>l_columnValue,calign=>'left',cattributes=>'class="'|| l_style ||'"'));
            else
              p(HTF.TABLEDATA(cvalue=>replace(l_columnValue,'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"'));
            end if;
          else
            p(HTF.TABLEDATA(cvalue=>replace(l_columnValue,'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"'));
          end if;
        end if;
      end loop;
      p(HTF.TABLEROWCLOSE);
      if p_header > 0 and p_style_head is not null then
        if mod(l_rn,p_header)=0 then
          p(HTF.TABLEROWOPEN);
          for i in 1 .. l_colCnt loop
            if instr(upper(l_descTbl(i).col_name),'NOPRN')=0 then
              p(HTF.TABLEHEADER(cvalue=>l_descTbl(i).col_name,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"'));
            end if;
          end loop;
          p(HTF.TABLEROWCLOSE);
        end if;
      end if;
    end loop;
    dbms_sql.close_cursor(l_theCursor);
    p(HTF.TABLECLOSE);
  exception
    when others then
      if DBMS_SQL.IS_OPEN(l_theCursor) then dbms_sql.close_cursor(l_theCursor);end if;
      p(p_query);
      raise_application_error(-20000, 'print_query_result_html'||chr(10)||sqlerrm||chr(10)||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end print_query_result_html;

  procedure print_tables_of_arrays
                       (p_t_header      varchar2,
                        p_width         number,
                        p_style_r1      varchar2, --odd rows
                        p_style_r2      varchar2, --even rows
                        p_style_head    varchar2, --head
                        p_style_tab     varchar2,
                        p_output in out COREMOD_REPORT_UTILS.t_output_lines,
                        p_col1          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col2          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col3          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col4          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col5          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col6          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col7          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col8          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col9          COREMOD_REPORT_UTILS.t_output_lines,
                        p_col10         COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_indx        number := p_output.count + 1;
    l_style       varchar2(100);
    l_char_width  number := 0;
    l_tag1_indx   number;

    procedure p(p_line varchar2) is
    begin
      p_output(l_indx):=p_line;
      l_indx := l_indx + 1;
    end;
    procedure replace_tag(p_tag varchar2, p_val varchar2, p_line_num number)
    is
    begin
      p_output(p_line_num) := replace(p_output(p_line_num),p_tag,p_val);
    end;
  begin
    l_tag1_indx:=l_indx;
    p(HTF.TABLEOPEN(cborder=>0,cattributes=>'width="'||case when p_width = 0 then '<#WIDTH#>' else to_char(p_width) end||'" class="'||p_style_tab||'" summary="'||p_t_header||'"'));

    if p_t_header<>'#FIRST_LINE#' then
      p(HTF.TABLEROWOPEN);
      p(HTF.TABLEHEADER(cvalue=>replace(p_t_header,' ','&nbsp;'),calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"'));
      if p_col2.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col3.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col4.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col5.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col6.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col7.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col8.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col9.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      if p_col10.count > 0 then p(HTF.TABLEHEADER(cvalue=>null,calign=>'left',cattributes=>'class="'||p_style_head||'" scope="col"')); end if;
      p(HTF.TABLEROWCLOSE);
    end if;

    for i in 1..p_col1.count loop
      l_style := case when mod(i,2)=0 then p_style_r1 else p_style_r2 end;
      p(HTF.TABLEROWOPEN);
      p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col1(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"'));
      if p_col2.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col2(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col3.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col3(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col4.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col4(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col5.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col5(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col6.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col6(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col7.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col7(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col8.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col8(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col9.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col9(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      if p_col10.count > 0 then p(HTF.TABLEDATA(cvalue=>replace(rtrim(p_col10(i)),'  ','&nbsp;&nbsp;'),calign=>'left',cattributes=>'class="'|| l_style ||'"')); end if;
      p(HTF.TABLEROWCLOSE);
      l_char_width := greatest(l_char_width, length(rtrim(p_col1(i))) + length(rtrim(p_col2(i))) + length(rtrim(p_col3(i))));
    end loop;
    p(HTF.TABLECLOSE);

    if p_width = 0 then
      replace_tag('<#WIDTH#>', to_char(round(l_char_width * COREMOD_REPORT_UTILS.gPixelPerChar*0.8)), l_tag1_indx);
    end if;
  end;
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
                        p_col3          COREMOD_REPORT_UTILS.t_output_lines)
  is
                        p_col4          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col5          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col6          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col7          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col8          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col9          COREMOD_REPORT_UTILS.t_output_lines;
                        p_col10         COREMOD_REPORT_UTILS.t_output_lines;
  begin
    print_tables_of_arrays
                       (p_t_header      => print_3arrays.p_t_header,
                        p_width         => print_3arrays.p_width,
                        p_style_r1      => print_3arrays.p_style_r1,
                        p_style_r2      => print_3arrays.p_style_r2,
                        p_style_head    => print_3arrays.p_style_head,
                        p_style_tab     => print_3arrays.p_style_tab,
                        p_output        => print_3arrays.p_output,
                        p_col1          => print_3arrays.p_col1,
                        p_col2          => print_3arrays.p_col2,
                        p_col3          => print_3arrays.p_col3,
                        p_col4          => print_3arrays.p_col4,
                        p_col5          => print_3arrays.p_col5,
                        p_col6          => print_3arrays.p_col6,
                        p_col7          => print_3arrays.p_col7,
                        p_col8          => print_3arrays.p_col8,
                        p_col9          => print_3arrays.p_col9,
                        p_col10         => print_3arrays.p_col10);
  end;

END COREMOD_REPORT_UTILS;
/


