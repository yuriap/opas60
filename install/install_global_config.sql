define namepref=opas60dev

@@version.sql

-- Oracle Performance Analytic Suite scheme for local database
define localscheme=&namepref.

-- Tablespace name for Oracle Performance Analytic Suite
define tblspc_name=&namepref.tbs

-- Job Class name for Oracle Performance Analytic Suite
define job_class_name=JC_&namepref.

-- Local database connection string host:port/service_name
define localdb=localhost:1521/pdb1.localdomain

-- Local SYS password (can be empty)
define localsys=qazwsx

-- module configs
rem @../modules/awr_warehouse/install/install_config