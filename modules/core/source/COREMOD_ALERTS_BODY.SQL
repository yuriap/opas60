

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

  procedure viewed(p_alert_type    opas_alert_queue.alert_type%type,
                   p_alert_source  opas_alert_queue.alert_source%type,
                   p_CREATED_LHHTZ varchar2)
  is
  begin
    for i in (select alert_id from v$opas_alert_queue
               where alert_type = replace(replace(p_alert_type,'&',':'),'~','#')
                 and alert_source = p_alert_source
                 and created_lhhtz = p_CREATED_LHHTZ) loop
      viewed(i.alert_id);
    end loop;
  end;

  procedure viewed(p_alert_type_n_source varchar2)
  is
  begin
    --coremod_log.log('COREMOD_ALERTS.viewed: <'||substr(p_alert_type_n_source,1,instr(p_alert_type_n_source,';')-1)||'>:<'||substr(p_alert_type_n_source,instr(p_alert_type_n_source,';')+1)||'>');

    for i in (select alert_id from v$opas_alert_queue
               where alert_type = substr(p_alert_type_n_source,1,instr(p_alert_type_n_source,';')-1)
                 and alert_source = substr(p_alert_type_n_source,instr(p_alert_type_n_source,';')+1)) loop
      viewed(i.alert_id);
    end loop;
  end;

  procedure cleanup
  is
  begin
    begin
      delete from opas_alert_queue
       where (viewed is not null and viewed < sysdate - COREMOD_API.getconf('ALERTRETVED',COREMOD_API.gMODNAME))
          or (viewed is null and created < sysdate - COREMOD_API.getconf('ALERTRETNVED',COREMOD_API.gMODNAME));
      commit;
    exception
      when others then
        rollback;
        coremod_log.log('Cleanup job COREMOD_ALERTS.cleanup opas_alert_queue error: '||sqlerrm);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    end;

    begin
      delete from OPAS_NOTIFICATION
       where CREATED < sysdate - COREMOD_API.getconf('NOTIFICATIONS',COREMOD_API.gMODNAME)/24;
      commit;
    exception
      when others then
        rollback;
        coremod_log.log('Cleanup job COREMOD_ALERTS.cleanup OPAS_NOTIFICATION error: '||sqlerrm);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    end;
  end;

  procedure add_notification(
    nt_id         out opas_notification.ID%type,
    nt_text       opas_notification.text%type,
    nt_link       opas_notification.link%type default null,
    nt_type_id    opas_notification.type_id%type default nttTaskfinished, -- 1	Maintenance; 2	Task finished; 3	Information
    nt_color      opas_notification.color%type default ntcGray,
    nt_username   opas_notification.username%type default 'PUBLIC',
    nt_no_browser_notif_flag opas_notification.no_browser_notif_flag%type default 1,
    nt_activate    number default 1,
    nt_alter_key  varchar2 default null
  ) is
    l_cnt number;
  begin
    if nt_alter_key is not null then
      select count(1) into l_cnt from OPAS_NOTIFICATION where alter_key = upper(nt_alter_key) and username = upper(nt_username);
    end if;
    if nt_alter_key is null or
       nt_alter_key is not null and l_cnt = 0
    then
      insert into OPAS_NOTIFICATION (type_id, text, link, color, username, no_browser_notif_flag, STATUS, ALTER_KEY)
      values (nt_type_id, nt_text, nt_link, nt_color, nt_username, nt_no_browser_notif_flag, case when nt_activate = 1 then ntReady else ntNew end, nt_alter_key)
      returning ID into nt_id;
    elsif nt_alter_key is not null and l_cnt > 0 then
      UPDATE opas_notification SET
        type_id = nt_type_id,
        TEXT = nt_text,
        LINK = nt_link,
        COLOR = nt_color,
        NO_BROWSER_NOTIF_FLAG = nt_no_browser_notif_flag,
        STATUS = case when nt_activate = 1 then ntReady else ntNew end
      where alter_key = upper(nt_alter_key) and username = upper(nt_username)
      returning id into nt_id;
    end if;
    --commit;
  end add_notification;

  procedure set_url(nt_id       opas_notification.id%type,
                    p_page_id   number,
                    p_obj_id    opas_objects.obj_id%type default null,
                    p_prev_page number default 10,
                    p_items     varchar2 default null,
                    p_values    varchar2 default null)
  is
  begin
    update OPAS_NOTIFICATION
    set link = 'f?p='||nvl(v('APP_ID'),COREMOD_API.gAPEX_APP_ID)||':'||p_page_id||':<APP_SESSION>::::'||
      case
        when p_items is null or p_values  is null
          then 'APP_OBJ_ID,APP_PREV_PAGE,APP_NOTIF:'||p_obj_id||','||p_prev_page||','||nt_id
        when p_items is not null and p_values is not null
          then p_items||',APP_NOTIF:'||p_values||','||nt_id
      else
        null
      end
    where ID = nt_id;
  end;

  procedure activate_notification(nt_id     opas_notification.id%type,
                                  nt_result varchar2,
                                  nt_color  opas_notification.color%type default null,
                                  nt_type   opas_notification.type_id%type default null) is
    pragma autonomous_transaction;
  begin
    update OPAS_NOTIFICATION
    set text = substr(replace(text,ntPlaceHolder,nt_result),1,1000),
        status = ntReady,
        color  = nvl(nt_color, color),
        type_id = nvl(nt_type,type_id)
    where ID = nt_id;
    commit;
  end activate_notification;

  procedure viewed_notification(nt_id opas_notification.id%type) is
  begin
    delete from OPAS_NOTIFICATION where ID = nt_id;
    --commit;
  end viewed_notification;

END COREMOD_ALERTS;
/


