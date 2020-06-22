CREATE OR REPLACE
package COREOBJ_SQL_COMP_REPORT is

  flgTEXT      constant pls_integer := 1; -- comparing two texts
  flgSQLPLAN   constant pls_integer := 2; -- cpmparing execution plans adjusting sections

  --select rpad('  repco'||upper(x.val),30,' ')||'constant varchar2(30) := '''||rpad(upper(x.val||''';'),20,' ')||' -- '||x.display_val from opas_dictionary x where dic_name='SQLCOMPSECT' order by dic_ordr;
  repcoCSQLTEXT               constant varchar2(30) := 'CSQLTEXT';           -- SQL Texts
  repcoEXECPLAN               constant varchar2(30) := 'EXECPLAN';           -- Execution Plans
  repcoVSQLSTAT               constant varchar2(30) := 'VSQLSTAT';           -- V$SQL statistics
  repcoAWRSTAT                constant varchar2(30) := 'AWRSTAT';            -- AWR statistics
  repcoASHWAIT                constant varchar2(30) := 'ASHWAIT';            -- ASH Wait Profiles
  repcoASHPLANSTAT            constant varchar2(30) := 'ASHPLANSTAT';        -- ASH Plan Stats

  --params
  pSQLID#1                    constant varchar2(30) := 'SQLID1';
  pSQLID#2                    constant varchar2(30) := 'SQLID2';
  pMAX_WIDTH                  constant varchar2(30) := 'MAX_WIDTH';

  pPLANTP#1                   constant varchar2(30) := 'PLANTP1';
  pPLANTP#2                   constant varchar2(30) := 'PLANTP2';
  pPLANID#1                   constant varchar2(30) := 'PLANID1';
  pPLANID#2                   constant varchar2(30) := 'PLANID2';
  pMAINPLANSECTION            constant varchar2(30) := 'MAINPLANSECTION';

  pSTATTP                     constant varchar2(30) := 'STATTP';
  pSTATID#1                   constant varchar2(30) := 'STATID1';
  pSTATID#2                   constant varchar2(30) := 'STATID2';

  pDBID#1                     constant varchar2(30) := 'DBID#1';
  pDBID#2                     constant varchar2(30) := 'DBID#2';
  pSNAPS#1                    constant varchar2(30) := 'SNAPS#1';
  pSNAPS#2                    constant varchar2(30) := 'SNAPS#2';
  pSNAPE#1                    constant varchar2(30) := 'SNAPE#1';
  pSNAPE#2                    constant varchar2(30) := 'SNAPE#2';
  pINST#1                     constant varchar2(30) := 'INST#1';
  pINST#2                     constant varchar2(30) := 'INST#2';
  pPLNHASH#1                  constant varchar2(30) := 'PLNHASH#1';
  pPLNHASH#2                  constant varchar2(30) := 'PLNHASH#2';

  pDP_ID#1                   constant varchar2(30) := 'DP_ID#1';
  pDP_ID#2                   constant varchar2(30) := 'DP_ID#2';
  pCHLD#1                    constant varchar2(30) := 'CHLD#1';
  pCHLD#2                    constant varchar2(30) := 'CHLD#2';

  --plan types
  ptAWR                       constant varchar2(30) := 'AWR';
  ptEP                        constant varchar2(30) := 'EP';
  ptMAIN                      constant varchar2(30) := 'MAIN';

  --STAT types
  stAWR                       constant varchar2(30) := 'AWR';
  stV$SQL                     constant varchar2(30) := 'V$SQL';

  TYPE r_sqlstat_base_crsr IS RECORD (
    --sql_id               VARCHAR2(13),
    --plan_hash_value      NUMBER,
    --dbid                 NUMBER,
    executions_delta     NUMBER,
    ela_poe              NUMBER,
    lio_poe              NUMBER,
    cpu_poe              NUMBER,
    iowait_poe           NUMBER,
    ccwait_poe           NUMBER,
    apwait_poe           NUMBER,
    clwait_poe           NUMBER,
    reads_poe            NUMBER,
    dwrites_poe          NUMBER,
    rows_poe             NUMBER,
    ela_delta_sec        NUMBER,
    cpu_delta_sec        NUMBER,
    iowait_delta_sec     NUMBER,
    ccwait_delta_sec     NUMBER,
    apwait_delta_sec     NUMBER,
    clwait_delta_sec     NUMBER,
    disk_reads_delta     NUMBER,
    disk_writes_delta    NUMBER,
    buffer_gets_delta    NUMBER,
    rows_processed_delta NUMBER,
    phy_read_req_delta   NUMBER,
    phy_write_req_delta  NUMBER,
    lio_per_row          NUMBER,
    io_per_row           NUMBER,
    cpu_per_row          NUMBER,
    awg_io_tim           NUMBER
    --io_wait_5ms          NUMBER,
    --io_wait_pe_5ms       NUMBER
    );

  TYPE t_sqlstat_base_crsr IS REF CURSOR RETURN r_sqlstat_base_crsr;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null);

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null);

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N');

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

/*  procedure compare(p_txt1      COREMOD_REPORT_UTILS.t_output_lines,
                    p_txt2      COREMOD_REPORT_UTILS.t_output_lines,
                    p_flags     pls_integer,
                    p_output    out COREMOD_REPORT_UTILS.t_output_lines,
                    p_max_width out number);*/

/*  procedure compare_sql_stats(p_stats1    in out t_sqlstat_base_crsr,
                              p_stats2    in out t_sqlstat_base_crsr,
                              p_max_width number,
                              p_output    out COREMOD_REPORT_UTILS.t_output_lines);*/

  procedure create_comprep_section(p_obj_id           opas_objects.obj_id%type,
                                   p_section varchar2,
                                   p_output    out COREMOD_REPORT_UTILS.t_output_lines);

  procedure print_comprep_section_web(p_obj_id           opas_objects.obj_id%type,
                                      p_section varchar2);

end COREOBJ_SQL_COMP_REPORT;
/