

CREATE OR REPLACE
PACKAGE COREMOD_HOME_PAGE AS

  procedure modify_brief(p_name      OPAS_HOMEPAGE_BRIEFS.NAME%type,
                         p_qry_text  OPAS_HOMEPAGE_BRIEFS.QRY_TEXT%type,
                         p_ordr      OPAS_HOMEPAGE_BRIEFS.ORDR%type,
                         p_br_id in out OPAS_HOMEPAGE_BRIEFS.BR_ID%type);

  procedure drop_brief(p_br_id OPAS_HOMEPAGE_BRIEFS.BR_ID%type);

  function sql_qry_brief return varchar2;

END COREMOD_HOME_PAGE;
/


