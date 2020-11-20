

CREATE OR REPLACE
PACKAGE COREMOD_APPSTATE AS

  procedure set_jparam(p_pname      varchar2,
                       p_value      varchar2);

  procedure set_jparam_m(p_pname      varchar2,
                         p_value      varchar2);

  procedure get_jparam(p_pname      varchar2,
                       p_value  out varchar2,
                       p_default    varchar2 default null);

  procedure get_jparam_m(p_pname      varchar2,
                         p_value  out varchar2,
                         p_default    varchar2 default null);

  procedure store_jparams;
  procedure extract_jparams;

END COREMOD_APPSTATE;
/


