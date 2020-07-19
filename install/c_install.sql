-- Oracle Performance Analytic Suite install script
-- Cloud Edition
-- Installation from scratch

spool ./logs/c_install.log
set echo on

--Global Config
@c_install_global_config

--Module installation
@c_install_modules

spool off
set echo off