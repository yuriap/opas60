

CREATE OR REPLACE
PACKAGE COREMOD_ALERTS AS

  gTSWTZFMT varchar2(32) := 'YYYYMMDDHH24MISS.ff6 TZH:TZM';

  gmSHOWALERT constant varchar2(20) := 'SHOWALERT';
  gmPREVIEW   constant varchar2(20) := 'PREVIEW';
  gmREFRESH   constant varchar2(20) := 'REFRESH';

  ntNew       constant varchar2(20) := 'NEW';
  ntReady     constant varchar2(20) := 'READY';

  ntPlaceHolder constant varchar2(20) := '<RESULT>';

  nttMaintenance   constant number := 1;
  nttTaskfinished  constant number := 2;
  nttInformation   constant number := 3;
  nttException     constant number := 4;

  ntcGray          constant varchar2(20) := 'rgb(86,86,86)';
  ntcRed           constant varchar2(20) := 'rgb(192,0,15)';
  ntcGreen         constant varchar2(20) := 'rgb(00,255,00)';

  procedure add_alert(p_alert_id  out opas_alert_queue.alert_id%type,
                      p_alert_type    opas_alert_queue.alert_type%type,
                      p_alert_source  opas_alert_queue.alert_source%type,
                      p_created       opas_alert_queue.created%type,
                      p_owner         opas_alert_queue.owner%type,
                      p_message       opas_alert_queue.message%type,
                      p_link_page     opas_alert_queue.link_page%type,
                      p_link_param    opas_alert_queue.link_param%type) ;

  procedure viewed(p_alert_id  opas_alert_queue.alert_id%type);
  procedure viewed(p_alert_type    opas_alert_queue.alert_type%type,
                   p_alert_source  opas_alert_queue.alert_source%type,
                   p_CREATED_LHHTZ varchar2);
  procedure viewed(p_alert_type_n_source varchar2);
  procedure cleanup;

  procedure add_notification(
    nt_id         out opas_notification.ID%type,
    nt_text       opas_notification.text%type,
    nt_link       opas_notification.link%type default null,
    nt_type_id    opas_notification.type_id%type default nttTaskfinished, -- 1	Maintenance; 2	Task finished; 3	Information
    nt_color      opas_notification.color%type default ntcGray,
    nt_username   opas_notification.username%type default 'PUBLIC',
    nt_no_browser_notif_flag opas_notification.no_browser_notif_flag%type default 1,
    nt_activate   number default 1
  );

  procedure set_url(nt_id       opas_notification.id%type,
                    p_page_id   number,
                    p_obj_id    opas_objects.obj_id%type default null,
                    p_prev_page number default 10,
                    p_items     varchar2 default null,
                    p_values    varchar2 default null);

  procedure activate_notification(nt_id     opas_notification.id%type,
                                  nt_result varchar2,
                                  nt_color  opas_notification.color%type default null,
                                  nt_type   opas_notification.type_id%type default null);

  procedure viewed_notification(nt_id opas_notification.id%type);

END COREMOD_ALERTS;
/


