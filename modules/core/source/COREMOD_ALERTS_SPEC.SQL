CREATE OR REPLACE
PACKAGE COREMOD_ALERTS AS

  procedure add_alert(p_alert_id  out opas_alert_queue.alert_id%type,
                      p_alert_type    opas_alert_queue.alert_type%type,
                      p_owner         opas_alert_queue.owner%type,
                      p_message       opas_alert_queue.message%type,
                      p_link_page     opas_alert_queue.link_page%type,
                      p_link_param    opas_alert_queue.link_param%type) ;

  procedure viewed(p_alert_id  opas_alert_queue.alert_id%type);

  procedure cleanup;

END COREMOD_ALERTS;
/
