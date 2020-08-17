

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_CALCS AS

  procedure load_v$ash
  AS
  begin
    --COREMOD_API.load_tmp_data('$LOCAL$', 'GV_$ACTIVE_SESSION_HISTORY', 'GV$ACTIVE_SESSION_HISTORY', 'OPAS_OT_TMP_GV$ASH', 'GV$ASH', 'rownum < 1e6');

    COREMOD_API.load_tmp_data (
      P_DB_LINK_NAME => '$LOCAL$',
      P_SRC_TABLE_NAME_R => 'GV_$ACTIVE_SESSION_HISTORY',
      P_SRC_TABLE_NAME => 'GV$ACTIVE_SESSION_HISTORY',
      P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
      P_SUFF => 'GV$ASH',
      p_key_pref => 'LOCTABCOLS',
      --P_DBID => null,
      P_FILTER => 'rownum < 1e6'
      );

  END load_v$ash;

END COREOBJ_ASHA_CUBE_CALCS;
/


