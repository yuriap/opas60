CREATE OR REPLACE
PACKAGE BODY COREMOD_CONTEXT IS

PROCEDURE set_parameter (p_name   IN  VARCHAR2,
                         p_value  IN  VARCHAR2) IS
BEGIN
  DBMS_SESSION.set_context('OPAS_CONTEXT', p_name, p_value);
END set_parameter;

END COREMOD_CONTEXT;
/
