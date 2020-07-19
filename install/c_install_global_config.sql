define namepref=OPAS60CLOUD

@@version.sql

-- Oracle Performance Analytic Suite scheme for local database
define localscheme=&namepref.

-- Tablespace name for Oracle Performance Analytic Suite
define tblspc_name=DATA

-- Job Class name for Oracle Performance Analytic Suite
define job_class_name=JC_&namepref.

-- Cloud OPAS schema connection script
define cloud_opas=cloud_opas

-- Cloud ADMIN connection script
define cloud_adm=cloud_adm

-- module configs
rem @../modules/awr_warehouse/install/install_config