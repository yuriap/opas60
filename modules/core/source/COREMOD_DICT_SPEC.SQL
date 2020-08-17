CREATE OR REPLACE


PACKAGE COREMOD_DICT AS

  type t_dict_table is table of opas_dictionary.display_val%type index by opas_dictionary.val%type;
  gdicSQLREPSECT t_dict_table;

END COREMOD_DICT;
/


