define namepref=opas45

@@version.sql

-- Oracle Performance Analytic Suite scheme for local database
define localscheme=&namepref.

-- Tablespace name for Oracle Performance Analytic Suite
define tblspc_name=&namepref.tbs

-- Local database connection string host:port/service_name
define localdb=wsuatelus:1521/db12cr21

-- Local SYS password (can be empty)
define localsys=qazwsx

-- module configs
rem @../modules/awr_warehouse/install/install_config