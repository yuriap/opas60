CREATE OR REPLACE


package coreobj_db_mon_hist is

  stActive   constant varchar2(10) := 'ACTIVE';

  procedure init_histogram_job;
  procedure calc_histograms;
  procedure init_histograms(p_dbmh_id opas_ot_db_mon_hist.dbmh_id%type);

end coreobj_db_mon_hist;
/


