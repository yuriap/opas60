package com.opas60;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Properties;
import java.util.concurrent.ExecutorService;

public class ExternalExecutor {
    protected Connection localconn;
    protected Connection remoteconn;

    protected String local_username;
    protected String local_password_str;
    protected String local_server_connectstr;
    protected String remote_username;
    protected String remote_password_str;
    protected String remote_server_connectstr;

    protected String logging_mode = "INFO";
    protected DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss");
    protected String ProcName = "Default";
    protected int Worker_Id = 0;

    protected String Module = "";
    protected String Action = "";
    protected String Client_info = "";

    protected String remote_conn_error;

    public int maxRestarts = 1;

    public void setProcName(String pProcName) {ProcName = pProcName;}
    public void setWorker_Id(int pWorker_Id) {Worker_Id = pWorker_Id;}

    public void logm(String msg) {
        System.out.println(dtf.format(LocalDateTime.now()) + String.format(" RE (%s, %s): ", ProcName, Worker_Id) + msg);
    }

    public void log_info(String msg) { logm(msg); }

    public void log_debug(String msg) {
        if (logging_mode.equals("DEBUG")) logm(msg);
    }

    public void load_configuration(String FileName) {
        try (InputStream input = new FileInputStream(FileName)) {

            Properties prop = new Properties();

            prop.load(input);
            local_username = prop.getProperty("localdb.user");
            local_password_str = prop.getProperty("localdb.password");
            local_server_connectstr = prop.getProperty("localdb.url");
            maxRestarts = prop.getProperty("server.max_restart_attempts");
            log_info("Loaded configuration for: " + local_server_connectstr);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    protected void execute_statement(Connection conn, String sql_text) throws Exception {
        PreparedStatement pstmt = conn.prepareStatement(sql_text);
        pstmt.executeUpdate();
        pstmt.close();
    }

    protected void setup_app_info_module_act(Connection conn, String Mod, String Act) throws Exception, SQLException {
        if (((logging_mode.equals("DEBUG"))&&(conn == remoteconn))||(conn == localconn)) {
            if (!Module.equals(Mod)) Module = Mod;
            if (!Action.equals(Mod)) Action = Act;
            execute_statement(conn, "begin dbms_application_info.set_module('" + Module + "','" + Action + "'); end;");
        }
    }
    protected void setup_app_info_cli(Connection conn, String Cli) throws Exception, SQLException {
        if (!Client_info.equals(Cli)) Client_info = Cli;
        execute_statement(conn, "begin DBMS_APPLICATION_INFO.SET_CLIENT_INFO('" + Client_info + "'); end;");
    }
    protected void setup_session_nls(Connection conn) throws Exception, SQLException {
        execute_statement(conn, "alter session set nls_date_format='YYYYMMDDHH24MISS'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_FORMAT = 'YYYYMMDDHH24MISS.FF9'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYYMMDDHH24MISS.FF9 TZH:TZM'");
        execute_statement(conn, "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. '");
        execute_statement(conn, "alter session set time_zone=dbtimezone");
        setup_app_info_module_act(conn, "STNDLNREMEXEC", "");
        setup_app_info_cli(conn, "Performance data gatherer");
    }

    protected void connect_to_local() throws Exception, SQLException {
        localconn = DriverManager.getConnection("jdbc:oracle:thin:@" + local_server_connectstr, local_username, local_password_str);
        localconn.setAutoCommit(false);
        setup_session_nls(localconn);
        log_info("local connection established");
    }

    protected void connect_to_remote() throws Exception, SQLException
    {
        CallableStatement setconnprob = localconn.prepareCall("{ call COREMOD_EXTPROC_SRV.report_connection_problem( p_work_id => ?, p_errormsg => ? ) }");
        try
        {
            log_info("remote connection establishing...");

            remoteconn = DriverManager.getConnection("jdbc:oracle:thin:@"+remote_server_connectstr,remote_username,remote_password_str);
            log_info("remote connection established");
            remoteconn.setAutoCommit(false);
            setup_session_nls(remoteconn);
            log_info("remote connection NLS set");
        } catch (Exception e) {
            remote_conn_error = e.getMessage();
            setconnprob.setInt(1, Worker_Id);
            setconnprob.setString(2, remote_conn_error);
            setconnprob.executeUpdate();
            setconnprob.close();
            log_info("connect_to_remote Exception: " + e.getMessage());
        }
    }

    protected void finalize_conn() throws Exception, SQLException {
        log_info("Remote connection closing...");
        if ((remoteconn != null)&&(!remoteconn.isClosed())) {
            log_info("Remote connection is not closed.");
            remoteconn.close();
            log_info("Remote connection closed.");
        } else {
            log_info("Remote connection was not established. Nothing to close");
        }
        log_info("Local connection closing...");
        if ((localconn != null)&&(!localconn.isClosed())) {
            log_info("Local connection is not closed.");
            localconn.close();
            log_info("Local connection closed.");
        }
        else {
            log_info("Local connection was not established. Nothing to close");
        }
    }

}
