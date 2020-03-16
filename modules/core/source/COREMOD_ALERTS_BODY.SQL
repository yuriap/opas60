CREATE OR REPLACE
PACKAGE BODY COREMOD_ALERTS AS

  procedure add_alert(p_alert_id  out opas_alert_queue.alert_id%type,
                      p_alert_type    opas_alert_queue.alert_type%type,
                      p_alert_source  opas_alert_queue.alert_source%type,
                      p_created       opas_alert_queue.created%type,
                      p_owner         opas_alert_queue.owner%type,
                      p_message       opas_alert_queue.message%type,
                      p_link_page     opas_alert_queue.link_page%type,
                      p_link_param    opas_alert_queue.link_param%type)
  AS
  BEGIN

   INSERT INTO opas_alert_queue
            ( alert_type,   alert_source,    owner,   message,   link_page,   link_param, created,   viewed, status)
     VALUES ( p_alert_type, p_alert_source, p_owner, p_message, p_link_page, p_link_param, p_created /*to_timestamp_tz(p_created,gTSWTZFMT)*/, null,   'New') returning alert_id into p_alert_id;

  END add_alert;

  procedure viewed(p_alert_id  opas_alert_queue.alert_id%type)
  is
  begin
    update opas_alert_queue set viewed = systimestamp, status='Viewed' where alert_id = p_alert_id;
  end;

  procedure cleanup
  is
  begin
    delete from opas_alert_queue
     where (viewed is not null and viewed < sysdate - COREMOD_API.getconf('ALERTRETVED',COREMOD_API.gMODNAME))
        or (viewed is null and created < sysdate - COREMOD_API.getconf('ALERTRETNVED',COREMOD_API.gMODNAME));
    commit;
  end;

END COREMOD_ALERTS;
/
