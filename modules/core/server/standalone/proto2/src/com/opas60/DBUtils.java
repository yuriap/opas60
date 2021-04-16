package com.opas60;

import java.io.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
//import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class DBUtils {
    private static Connection localconn;
    private static Connection remoteconn;

    private static String local_username;
    private static String local_password_str;
    private static String local_server_connectstr;
    private static String remote_username;
    private static String remote_password_str;
    private static String remote_server_connectstr;

    private static String logging_mode = "INFO";
    private static DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss");
    private static String ProcName = "Default";
    private static int Worker_Id = 0;

    private static String Module = "";
    private static String Action = "";
    private static String Client_info = "";

    public static void setProcName(String pProcName) {ProcName = pProcName;}
    public static void setWorker_Id(int pWorker_Id) {Worker_Id = pWorker_Id;}

    public static void logm(String msg) {
        System.out.println(dtf.format(LocalDateTime.now()) + String.format(" RE (%s, %s): ", ProcName, Worker_Id) + msg);
    }

    public static void log_info(String msg) {
        //if (logging_mode.equals("INFO"))
        logm(msg);
    }

    public static void log_debug(String msg) {
        if (logging_mode.equals("DEBUG")) logm(msg);
    }

    public static void load_configuration(String FileName) {
        try (InputStream input = new FileInputStream(FileName)) {

            Properties prop = new Properties();

            prop.load(input);
            local_username = prop.getProperty("localdb.user");
            local_password_str = prop.getProperty("localdb.password");
            local_server_connectstr = prop.getProperty("localdb.url");
            log_info("Loaded configuration for: " + local_server_connectstr);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private static void execute_statement(Connection conn, String sql_text) throws Exception {
        PreparedStatement pstmt = conn.prepareStatement(sql_text);
        pstmt.executeUpdate();
        pstmt.close();
    }
    private static void setup_app_info_module_act(Connection conn, String Mod, String Act) throws Exception, SQLException {
        if (!Module.equals(Mod)) Module = Mod;
        if (!Action.equals(Mod)) Action = Act;
        execute_statement(conn, "begin dbms_application_info.set_module('" + Module + "','" + Action + "'); end;");
    }
    private static void setup_app_info_cli(Connection conn, String Cli) throws Exception, SQLException {
        if (!Client_info.equals(Cli)) Client_info = Cli;
        execute_statement(conn, "begin DBMS_APPLICATION_INFO.SET_CLIENT_INFO('" + Client_info + "'); end;");
    }
    private static void setup_session_nls(Connection conn) throws Exception, SQLException {
        execute_statement(conn, "alter session set nls_date_format='YYYYMMDDHH24MISS'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_FORMAT = 'YYYYMMDDHH24MISS.FF9'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYYMMDDHH24MISS.FF9 TZH:TZM'");
        execute_statement(conn, "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. '");
        execute_statement(conn, "alter session set time_zone=dbtimezone");
        setup_app_info_module_act(conn, "STNDLNREMEXEC", "");
        setup_app_info_cli(conn, "Performance data gatherer");
    }

    public static void connect_to_local() throws Exception, SQLException {
        localconn = DriverManager.getConnection("jdbc:oracle:thin:@" + local_server_connectstr, local_username, local_password_str);
        localconn.setAutoCommit(false);
        setup_session_nls(localconn);
        log_info("local connection established");
    }

    private static void finalize_conn() throws Exception, SQLException {
        localconn.close();
        log_info("Local connection closed.");
    }

    public static void test_remote_dbs() throws Exception, SQLException {
        String DBLinkName;
        connect_to_local();
        PreparedStatement localstmt = localconn.prepareStatement("select USERNAME, PASSWORD, CONNSTR, DB_LINK_NAME from OPAS_DB_LINKS where status='EXTENABLED' and dblink_mode='JAVASRV'");
        ResultSet localrset = localstmt.executeQuery();

        while (localrset.next()) {
            remote_username = localrset.getString(1);
            remote_password_str = localrset.getString(2);
            remote_server_connectstr = localrset.getString(3);
            DBLinkName = localrset.getString(4);
            remoteconn = DriverManager.getConnection("jdbc:oracle:thin:@//" + remote_server_connectstr, remote_username, remote_password_str);
            Statement remotestmt = remoteconn.createStatement();
            ResultSet remoterset = remotestmt.executeQuery("select * from dual");
            remoterset.next();
            log_info("Remote database <" + DBLinkName + "> is accessible.");
            remoterset.close();
            remotestmt.close();
            remoteconn.close();
        }

        localrset.close();
        localstmt.close();

        finalize_conn();
    }
    public static void init_server(String ConfigFileName, ExecutorService exec) throws Exception, SQLException
    {
        setProcName("Main thread");
        setWorker_Id(0);
        setup_app_info_module_act(localconn, Module, "Getting new server...");
        CallableStatement getserverid = localconn.prepareCall("{ call COREMOD_EXTPROC.get_next_server (  P_WORK_ID => ?) }");
        getserverid.registerOutParameter(1, java.sql.Types.DECIMAL);
        getserverid.executeUpdate();
        int work_id = getserverid.getInt(1);
        getserverid.close();

        log_info("init_server: Starting server for work_id: " + work_id);

        if (work_id>0) exec.execute(new ExternalWorker(ConfigFileName, work_id));

        log_info("init_server: Started server for work_id: " + work_id);
    }
}
