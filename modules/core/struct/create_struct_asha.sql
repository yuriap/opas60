create table opas_ot_ashacube_ranges (
asharange_id                 number                                           generated always as identity primary key,
dblink                       varchar2(128)                                    references opas_db_links (db_link_name),
SAMPLE_TP                    VARCHAR2(1 BYTE) check (SAMPLE_TP in ('V','A','S')), --V GV$ASH, A DBA_HIST_ASH, S - Samples of GV$SESS
START_TIME_UTC               TIMESTAMP(3),
END_TIME_UTC                 TIMESTAMP(3),
incarnation#                 number,
STATUS                       VARCHAR2(10),
created                      timestamp default systimestamp
);

create table opas_ot_ashacube_range_ref (
 obj_id                      number                                 not null  references opas_objects(obj_id) on delete cascade,
 asharange_id                number                                 not null  references opas_ot_ashacube_ranges(asharange_id),
 primary key (obj_id, asharange_id)
) organization index;

create table opas_ot_ashacube_ash (
asharange_id                 number                                           references opas_ot_ashacube_ranges (asharange_id) on delete cascade,
DBLINK                       varchar2(128)                                    references opas_db_links (db_link_name),
--SAMPLE_TP                    VARCHAR2(1 BYTE) check (SNAP_TP in ('V','A','S')), --V GV$ASH, A DBA_HIST_ASH, S - Samples of GV$SESS
SNAP_ID                      NUMBER,
DBID                         NUMBER, -- $LOCAL$ with some unlocal DBID comes from AWR dump
INSTANCE_NUMBER              NUMBER,
--SAMPLE_ID                    NUMBER
SAMPLE_TIME                  TIMESTAMP(3),
SAMPLE_TIME_UTC              TIMESTAMP(3),
--USECS_PER_ROW              NUMBER
SESSION_ID                   NUMBER,
SESSION_SERIAL#              NUMBER,
SESSION_TYPE                 VARCHAR2(10 BYTE),
--FLAGS                      NUMBER
USER_ID                      NUMBER,
USERNAME                     VARCHAR2(128 BYTE),
OSUSER                       VARCHAR2(128 BYTE),
SQL_ID                       VARCHAR2(13 BYTE),
--IS_SQLID_CURRENT           VARCHAR2(1 BYTE)
SQL_CHILD_NUMBER             NUMBER,
--SQL_OPCODE                     NUMBER
SQL_OPNAME                   VARCHAR2(64 BYTE),
FORCE_MATCHING_SIGNATURE     NUMBER,
TOP_LEVEL_SQL_ID             VARCHAR2(13 BYTE),
--TOP_LEVEL_SQL_OPCODE         NUMBER
--SQL_ADAPTIVE_PLAN_RESOLVED   NUMBER
SQL_PLAN_HASH_VALUE          NUMBER,
SQL_FULL_PLAN_HASH_VALUE     NUMBER,
SQL_PLAN_LINE_ID             NUMBER,
SQL_PLAN_OPERATION           VARCHAR2(64 BYTE),
SQL_PLAN_OPTIONS             VARCHAR2(64 BYTE),
SQL_EXEC_ID                  NUMBER,
SQL_EXEC_START               DATE,
PLSQL_ENTRY_OBJECT_ID        NUMBER,
PLSQL_ENTRY_SUBPROGRAM_ID    NUMBER,
PLSQL_OBJECT_ID              NUMBER,
PLSQL_SUBPROGRAM_ID          NUMBER,
QC_INSTANCE_ID               NUMBER,
QC_SESSION_ID                NUMBER,
QC_SESSION_SERIAL#           NUMBER,
PX_FLAGS                     NUMBER,
EVENT                        VARCHAR2(64 BYTE),
--EVENT_ID  NUMBER
--SEQ#  NUMBER
--P1TEXT    VARCHAR2(64 BYTE)
--P1    NUMBER
--P2TEXT    VARCHAR2(64 BYTE)
--P2    NUMBER
--P3TEXT    VARCHAR2(64 BYTE)
--P3    NUMBER
STATE                        VARCHAR2(19 BYTE),
WAIT_CLASS                   VARCHAR2(64 BYTE),
--WAIT_CLASS_ID NUMBER
--WAIT_TIME NUMBER
--SESSION_STATE VARCHAR2(7 BYTE)
--TIME_WAITED   NUMBER
BLOCKING_SESSION_STATUS      VARCHAR2(11 BYTE),
BLOCKING_SESSION             NUMBER,
BLOCKING_SESSION_SERIAL#     NUMBER,
BLOCKING_INST_ID             NUMBER,
--BLOCKING_HANGCHAIN_INFO      VARCHAR2(1 BYTE),
FINAL_BLOCKING_SESSION_STATUS VARCHAR2(11 BYTE),
FINAL_BLOCKING_INSTANCE      NUMBER,
FINAL_BLOCKING_SESSION       NUMBER,
CURRENT_OBJ#                 NUMBER,
CURRENT_FILE#                NUMBER,
CURRENT_BLOCK#               NUMBER,
CURRENT_ROW#                 NUMBER,
--TOP_LEVEL_CALL#   NUMBER
--TOP_LEVEL_CALL_NAME   VARCHAR2(64 BYTE)
CONSUMER_GROUP_ID            NUMBER,
XID                          RAW(32),
--REMOTE_INSTANCE#  NUMBER
--TIME_MODEL    NUMBER
--IN_CONNECTION_MGMT    VARCHAR2(1 BYTE)
--IN_PARSE  VARCHAR2(1 BYTE)
--IN_HARD_PARSE VARCHAR2(1 BYTE)
--IN_SQL_EXECUTION  VARCHAR2(1 BYTE)
--IN_PLSQL_EXECUTION    VARCHAR2(1 BYTE)
--IN_PLSQL_RPC  VARCHAR2(1 BYTE)
--IN_PLSQL_COMPILATION  VARCHAR2(1 BYTE)
--IN_JAVA_EXECUTION VARCHAR2(1 BYTE)
--IN_BIND   VARCHAR2(1 BYTE)
--IN_CURSOR_CLOSE   VARCHAR2(1 BYTE)
--IN_SEQUENCE_LOAD  VARCHAR2(1 BYTE)
--IN_INMEMORY_QUERY VARCHAR2(1 BYTE)
--IN_INMEMORY_POPULATE  VARCHAR2(1 BYTE)
--IN_INMEMORY_PREPOPULATE   VARCHAR2(1 BYTE)
--IN_INMEMORY_REPOPULATE    VARCHAR2(1 BYTE)
--IN_INMEMORY_TREPOPULATE   VARCHAR2(1 BYTE)
--IN_TABLESPACE_ENCRYPTION  VARCHAR2(1 BYTE)
--CAPTURE_OVERHEAD  VARCHAR2(1 BYTE)
--REPLAY_OVERHEAD   VARCHAR2(1 BYTE)
--IS_CAPTURED   VARCHAR2(1 BYTE)
--IS_REPLAYED   VARCHAR2(1 BYTE)
--IS_REPLAY_SYNC_TOKEN_HOLDER   VARCHAR2(1 BYTE)
--SERVICE_HASH  NUMBER
PROGRAM                      VARCHAR2(64 BYTE),
MODULE                       VARCHAR2(64 BYTE),
ACTION                       VARCHAR2(64 BYTE),
CLIENT_ID                    VARCHAR2(64 BYTE),
MACHINE                      VARCHAR2(64 BYTE),
PORT                         NUMBER,
ECID                         VARCHAR2(64 BYTE),
TERMINAL                     VARCHAR2(30 BYTE),
--DBREPLAY_FILE_ID  NUMBER
--DBREPLAY_CALL_COUNTER NUMBER
TM_DELTA_TIME                NUMBER,
TM_DELTA_CPU_TIME            NUMBER,
TM_DELTA_DB_TIME             NUMBER,
DELTA_TIME                   NUMBER,
DELTA_READ_IO_REQUESTS       NUMBER,
DELTA_WRITE_IO_REQUESTS      NUMBER,
DELTA_READ_IO_BYTES          NUMBER,
DELTA_WRITE_IO_BYTES         NUMBER,
DELTA_INTERCONNECT_IO_BYTES  NUMBER,
DELTA_READ_MEM_BYTES         NUMBER,
PGA_ALLOCATED                NUMBER,
TEMP_SPACE_ALLOCATED         NUMBER
) 
PARTITION BY LIST (DBLINK) AUTOMATIC
SUBPARTITION BY range (SAMPLE_TIME_UTC)
(
   PARTITION part_local values ('$LOCAL$')
      (
         SUBPARTITION spart_local_max values LESS THAN (maxvalue)
      )
)
ROW STORE COMPRESS ADVANCED
PCTFREE 0;


create index idx_opas_ot_ashac_dbl   on opas_ot_ashacube_ash(dblink);

drop table opas_ot_tmp_gv$ash;
create global temporary table opas_ot_tmp_gv$ash ON COMMIT DELETE ROWS as select * from opas_ot_ashacube_ash where 1=2;