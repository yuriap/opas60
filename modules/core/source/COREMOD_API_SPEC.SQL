

CREATE OR REPLACE
package COREMOD_API as

   gDefaultSource constant varchar2(32) := 'LOCAL';
   gDefaultOwner  constant varchar2(32) := 'PUBLIC';

   gLocalDBLink   constant varchar2(32) := '$LOCAL$';

   gMODNAME       constant varchar2(32) := 'OPASCORE';

   exDBLinkSuspended exception;
   pragma exception_init(exDBLinkSuspended, -20999);

   dblNEW        constant varchar2(32) := 'NEW';
   dblMODIFIED   constant varchar2(32) := 'MODIFIED';
   dblCREATED    constant varchar2(32) := 'CREATED';
   dblSUSPENDED  constant varchar2(32) := 'SUSPENDED';
   dblTODELETE   constant varchar2(32) := 'TODELETE';

   procedure register(p_modname opas_modules.MODNAME%type,
                      p_moddescr opas_modules.MODDESCR%type default null,
                      p_modver opas_modules.MODVER%type,
                      p_installed opas_modules.INSTALLED%type default sysdate);

   function getconf(p_key varchar2, p_module opas_modules.modname%type default gMODNAME) return varchar2 RESULT_CACHE;
   --function getscript(p_script_id varchar2) return clob;
   function getmodver(p_module opas_modules.modname%type) return varchar2 RESULT_CACHE;
   function getMODNAME return varchar2;

   procedure register_dblink(p_db_link_name varchar2,
                             p_owner varchar2,
                             p_is_public varchar2,
                             p_username varchar2,
                             p_password varchar2,
                             p_connectstring varchar2);
   procedure edit_dblink    (p_db_link_name varchar2,
                             p_is_public varchar2,
                             p_username varchar2,
                             p_password varchar2,
                             p_connectstring varchar2);
   procedure create_dblink(p_db_link_name varchar2, p_recreate boolean default false);
   procedure drop_dblink(p_db_link_name varchar2, p_suspend boolean default false);
   procedure test_dblink(p_db_link_name varchar2);
   function get_ora_dblink(p_db_link_name varchar2) return varchar2;
   function get_dblink_for_query(p_dblink varchar2) return varchar2;
   function get_ora_dblink_cache(p_db_link_name varchar2, p_key varchar2, p_local_tab varchar2 default null) return varchar2;

   procedure load_tmp_data(p_db_link_name varchar2,
                          p_src_table_name_r varchar2,
                          p_src_table_name varchar2,
                          p_trg_table_name varchar2,
                          p_suff varchar2,
                          p_dbid number default null,
                          p_key_pref varchar2 default 'TABCOLLIST',
                          p_filter varchar2 default null);
   function get_dblink_user(p_dblink varchar2) return varchar2;

   function get_dblink_dbid(p_dblink varchar2) return number;

   procedure update_dblink_db_info(p_db_link_name varchar2);

   function get_def_source return varchar2;
   function get_def_owner return varchar2;

   procedure init_longops(p_op_name varchar2, p_target_desc varchar2, p_units varchar2, p_totalwork number, p_lops_ind out pls_integer);
   procedure start_longops_section(p_module_name varchar2, p_action_name varchar2);
   procedure end_longops_section(p_sofar number default 1, p_lops_ind pls_integer);

   procedure lock_resource(p_resource_name varchar2, p_mode number default DBMS_LOCK.X_MODE, p_timeout number default 0, p_release_on_commit boolean default true);
   function lock_resource(p_resource_name varchar2, p_mode number default DBMS_LOCK.X_MODE, p_timeout number default 0, p_release_on_commit boolean default true) return varchar2;
   procedure release_resource(p_handle varchar2);
   procedure release_resource;

   function get_dic_displ_val(p_dic_name varchar2, p_dic_val varchar2) return varchar2;

end COREMOD_API;
/


