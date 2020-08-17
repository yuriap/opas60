

CREATE OR REPLACE
PACKAGE BODY COREMOD_DICT AS

begin
  for i in (select display_val, val from opas_dictionary x where dic_name='SQLREPSECT') loop
    gdicSQLREPSECT(i.val) := i.display_val;
  end loop;
END COREMOD_DICT;
/


