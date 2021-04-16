package com.opas60;

import java.io.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
//import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class ExternalWorkerImpl {
    private Connection localconn;
    private Connection remoteconn;

    private String local_username;
    private String local_password_str;
    private String local_server_connectstr;
    private String remote_username;
    private String remote_password_str;
    private String remote_server_connectstr;

    private String logging_mode = "INFO";
    private DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss");
    private String ProcName = "Default";
    private int Worker_Id = 0;
    private int maxqrynum;
    private int BatchSize;
    private int executed = 0;
    private int task_id;
    private String qry_type;
    private String select_sql = "";
    private String load_sql = "";
    private String pl_sql = "";
    private int num_cols = 0;
    private int timedout = 0;
    private String remote_conn_error;

    private String Module = "";
    private String Action = "";
    private String Client_info = "";

    public void setProcName(String pProcName) {ProcName = pProcName;}
    public void setWorker_Id(int pWorker_Id) {Worker_Id = pWorker_Id;}

    public void logm(String msg) {
        System.out.println(dtf.format(LocalDateTime.now()) + String.format(" RE (%s, %s): ", ProcName, Worker_Id) + msg);
    }

    public void log_info(String msg) {
        //if (logging_mode.equals("INFO"))
        logm(msg);
    }

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
            log_info("Loaded configuration for: " + local_server_connectstr);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private void execute_statement(Connection conn, String sql_text) throws Exception {
        PreparedStatement pstmt = conn.prepareStatement(sql_text);
        pstmt.executeUpdate();
        pstmt.close();
    }
    private void setup_app_info_module_act(Connection conn, String Mod, String Act) throws Exception, SQLException {
        if (((logging_mode.equals("DEBUG"))&&(conn == remoteconn))||(conn == localconn)) {
            if (!Module.equals(Mod)) Module = Mod;
            if (!Action.equals(Mod)) Action = Act;
            execute_statement(conn, "begin dbms_application_info.set_module('" + Module + "','" + Action + "'); end;");
        }
    }
    private void setup_app_info_cli(Connection conn, String Cli) throws Exception, SQLException {
        if (!Client_info.equals(Cli)) Client_info = Cli;
        execute_statement(conn, "begin DBMS_APPLICATION_INFO.SET_CLIENT_INFO('" + Client_info + "'); end;");
    }
    private void setup_session_nls(Connection conn) throws Exception, SQLException {
        execute_statement(conn, "alter session set nls_date_format='YYYYMMDDHH24MISS'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_FORMAT = 'YYYYMMDDHH24MISS.FF9'");
        execute_statement(conn, "alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYYMMDDHH24MISS.FF9 TZH:TZM'");
        execute_statement(conn, "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. '");
        execute_statement(conn, "alter session set time_zone=dbtimezone");
        setup_app_info_module_act(conn, "STNDLNREMEXEC", "");
        setup_app_info_cli(conn, "Performance data gatherer");
    }

    public void connect_to_local() throws Exception, SQLException {
        localconn = DriverManager.getConnection("jdbc:oracle:thin:@" + local_server_connectstr, local_username, local_password_str);
        localconn.setAutoCommit(false);
        setup_session_nls(localconn);
        log_info("local connection established");
    }

    private void connect_to_remote() throws Exception, SQLException
    {
        CallableStatement setconnprob = localconn.prepareCall("{ call COREMOD_EXTPROC.report_connection_problem( p_work_id => ?, p_errormsg => ? ) }");
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
            log_debug("connect_to_remote Exception: " + e.getMessage());
        }
    }
    private void finalize_conn() throws Exception, SQLException {
        if (!remoteconn.isClosed()) {
            remoteconn.close();
            log_info("Remote connection closed.");
        } else {
            log_info("Remote connection was not established. Nothing to close");
        }
        localconn.close();
        log_info("Local connection closed.");
    }

    public void test_remote_dbs() throws Exception, SQLException {
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
    public void init_server(String ConfigFileName, ExecutorService exec) throws Exception, SQLException
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
    //=========================================================================
    public void start_server(int work_id) throws Exception, SQLException
    {
        setProcName("Worker");
        setWorker_Id(work_id);

        log_info("start_server work_id: " + work_id);

        try {
            connect_to_local();
            init_worker(Worker_Id);
            setup_app_info_module_act(localconn, "Worker ("+Worker_Id+")", "Connecting remote server...");

            connect_to_remote();
            if ((!remoteconn.isClosed())) setup_app_info_module_act(remoteconn, "Worker ("+Worker_Id+")", "Initializing...");

            for(int i = 0; i < maxqrynum; i++) {
                setup_app_info_module_act(remoteconn, "Worker ("+Worker_Id+")", "Getting task...");
                setup_app_info_module_act(localconn, "Worker ("+Worker_Id+")", "Getting task...");
                get_task(Worker_Id);

                if (timedout>0) break;

                if (remoteconn.isClosed()&&(task_id > 0)) {
                    set_task(task_id, "FAILED", remote_conn_error, 0);
                    break;
                }

                if (remoteconn.isClosed()) break;

                if ((!remoteconn.isClosed())&&(task_id > 0)) setup_app_info_module_act(remoteconn, "Worker ("+Worker_Id+")", "Task/qry_type "+task_id+"/"+qry_type);
                if ((!remoteconn.isClosed())&&(task_id > 0)&&(qry_type.equals("SQLSELINS"))) execute_select_insert_task(task_id);
                if ((!remoteconn.isClosed())&&(task_id > 0)&&(qry_type.equals("PLSQL")))     execute_plsql_task(task_id);
                if ((!remoteconn.isClosed())&&(task_id > 0)&&(qry_type.equals("PLSQLSELINS"))) {
                    execute_plsql_task(task_id);
                    execute_select_insert_task(task_id);
                }

                try {
                    TimeUnit.MILLISECONDS.sleep(100);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }
            if (!localconn.isClosed()) {
                log_info("start_server Finish work");
                set_work(Worker_Id, executed, "No errors");
            } else {
                log_info("start_server Unable to Finish work, local connection is closed");
            }

        } catch (SQLException e) {
            //set_task(p_task_id, "FAILED", which_sql + e.getMessage(), 0);
            if (!localconn.isClosed()) {
              set_work(Worker_Id, executed, e.getMessage());
            }else {
                log_info("start_server Unable to Finish work with SQL Exception, local connection is closed");
            }
            log_info("start_server SQLException: " + e.getMessage());
        } catch (Exception e) {
            //set_task(p_task_id, "FAILED", e.getMessage(), 0);
            if (!localconn.isClosed()) {
                set_work(Worker_Id, executed, e.getMessage());
            }else {
                log_info("start_server Unable to Finish work with Exception, local connection is closed");
            }
            log_info("start_server Exception: " + e.getMessage());
        }
        //if (!remoteconn.isClosed())

        finalize_conn();
        log_info("finished. executed tasks: " + executed);
    }
    private void init_worker(int p_work_id) throws Exception, SQLException
    {

        CallableStatement callableStatement = localconn.prepareCall("{ call COREMOD_EXTPROC.init_server_parameters (  P_WORK_ID => ?, P_USERNAME => ?, P_PASSWORD => ?, P_CONNSTR => ?, P_QUERY_NUM => ?, p_logging_mode => ?, p_batch_size => ?) }");

        callableStatement.setInt(1, p_work_id);

        callableStatement.registerOutParameter(2, java.sql.Types.VARCHAR);
        callableStatement.registerOutParameter(3, java.sql.Types.VARCHAR);
        callableStatement.registerOutParameter(4, java.sql.Types.VARCHAR);
        callableStatement.registerOutParameter(5, java.sql.Types.DECIMAL);
        callableStatement.registerOutParameter(6, java.sql.Types.VARCHAR);
        callableStatement.registerOutParameter(7, java.sql.Types.DECIMAL);

        callableStatement.executeUpdate();


        remote_username = callableStatement.getString(2);
        remote_password_str = callableStatement.getString(3);
        remote_server_connectstr = callableStatement.getString(4);
        maxqrynum = callableStatement.getInt(5);
        logging_mode = callableStatement.getString(6);
        BatchSize = callableStatement.getInt(7);
        callableStatement.close();

        log_info("init_worker: logging_mode: " + logging_mode);
    }
    private void set_work(int p_work_id, int p_stmt_processed, String p_errm) throws Exception, SQLException
    {
        log_info("set_work: p_work_id: " + p_work_id);
        CallableStatement setwork = localconn.prepareCall("{ call COREMOD_EXTPROC.worker_finished( p_work_id => ?, p_stmt_done => ?, p_errors => ?) }");
        setwork.setInt(1, p_work_id);
        setwork.setInt(2, p_stmt_processed);
        setwork.setString(3, p_errm);
        setwork.executeUpdate();
        setwork.close();
        log_info("set_work: p_work_id: " + p_work_id + " done");
    }
    private void set_task(int p_task_id, String p_status, String p_errm, int p_rows_processed) throws Exception, SQLException
    {
        CallableStatement settask = localconn.prepareCall("{ call COREMOD_EXTPROC.set_task_finshed (  P_TASK_ID => ?, p_status => ?, p_errormsg => ?, p_rows_processed => ?) }");
        settask.setInt(1, p_task_id);
        settask.setString(2, p_status);
        settask.setString(3, p_errm);
        settask.setInt(4, p_rows_processed);
        settask.executeUpdate();
        settask.close();
    }

    private void get_task(int p_work_id) throws Exception, SQLException
    {
        CallableStatement gettask = localconn.prepareCall("{ call COREMOD_EXTPROC.get_next_task (  P_WORK_ID => ?, P_TASK_ID => ?, P_QRY_TYPE => ?, P_QRY1 => ?, P_QRY2 => ?, P_QRY3 => ?, P_NUM_COLS => ?, P_TIMEOUTED => ?) }");
        gettask.setInt(1, p_work_id);

        gettask.registerOutParameter(2, java.sql.Types.DECIMAL);
        gettask.registerOutParameter(3, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(4, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(5, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(6, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(7, java.sql.Types.DECIMAL);
        gettask.registerOutParameter(8, java.sql.Types.DECIMAL);

        gettask.executeUpdate();

        task_id = gettask.getInt(2);
        qry_type = gettask.getString(3);
        select_sql = gettask.getString(4);
        load_sql = gettask.getString(5);
        pl_sql = gettask.getString(6);
        num_cols = gettask.getInt(7);
        timedout = gettask.getInt(8);

        gettask.close();

        log_debug("task_id: " + task_id);
        log_debug("qry_type: " + qry_type);
        //log_debug("select_sql: " + select_sql);
        //log_debug("load_sql: " + load_sql);
        //log_debug("pl_sql: " + pl_sql);
        log_debug("num_cols: " + num_cols);
        log_debug("timedout: " + timedout);
    }
    private void execute_select_insert_task(int p_task_id)  throws Exception, SQLException {

        log_debug("start execute_select_insert_task: p_task_id=" + p_task_id);

        String which_sql = "";
        int rows_processed = 0;
        int batch_processed = 0;
        int[] cnt;

        Statement selectdata;
        PreparedStatement loadstmt;
        ResultSet localrset;
        ResultSet rsetdata;

        if (!remoteconn.isClosed()) {
            selectdata = remoteconn.createStatement();
        } else {
            selectdata = localconn.createStatement();
        }
        selectdata.setFetchSize(BatchSize);
        try {
            log_debug("Fetching");
            rows_processed = 0;
            which_sql = "SEL: ";
            rsetdata = selectdata.executeQuery(select_sql);
            loadstmt = localconn.prepareStatement(load_sql);
            which_sql = "INS: ";

            batch_processed = 0;

            while (rsetdata.next()) {
                loadstmt.setInt(1, p_task_id);
                for(int cols = 2; cols <= num_cols + 1; cols++) {
                    loadstmt.setString(cols, rsetdata.getString(cols-1));
                }
                loadstmt.addBatch();
                rows_processed++;
                batch_processed++;
                if (batch_processed == BatchSize) {
                    cnt = loadstmt.executeBatch();
                    batch_processed = 0;
                }
            }
            if (batch_processed > 0) {
                cnt = loadstmt.executeBatch();
            }

            loadstmt.close();
            localconn.commit();
            log_debug("rows_processed: " + rows_processed);
            set_task(p_task_id, "FINISHED", "", rows_processed);

            executed++;
            log_debug("execute_select_insert_task: " + executed);
        } catch (SQLException e) {
            set_task(p_task_id, "FAILED", which_sql + e.getMessage(), 0);
            log_info("execute_select_insert_task SQLException: " + which_sql + e.getMessage());
        } catch (Exception e) {
            set_task(p_task_id, "FAILED", e.getMessage(), 0);
            log_info("execute_select_insert_task Exception: " + e.getMessage());
        }
    }

    private void set_result_varchar(int p_task_id, int p_ordr_num, String p_result) throws Exception, SQLException
    {
        CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_varchar2 => ?) }");
        setres.setInt(1, p_task_id);
        setres.setInt(2, p_ordr_num);
        setres.setString(3, p_result);
        setres.executeUpdate();
        setres.close();
    }

    private void set_result_number(int p_task_id, int p_ordr_num, Long p_result) throws Exception, SQLException
    {
        CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_number => ?) }");
        setres.setInt(1, p_task_id);
        setres.setInt(2, p_ordr_num);
        setres.setLong(3, p_result);
        setres.executeUpdate();
        setres.close();
    }

    private void set_result_date(int p_task_id, int p_ordr_num, Date p_result) throws Exception, SQLException
    {
        CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_date => ?) }");
        setres.setInt(1, p_task_id);
        setres.setInt(2, p_ordr_num);
        setres.setDate(3, p_result);
        setres.executeUpdate();
        setres.close();
    }
    private void set_result_timestamp(int p_task_id, int p_ordr_num, Timestamp p_result) throws Exception, SQLException
    {
        CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_timestamp => ?) }");
        setres.setInt(1, p_task_id);
        setres.setInt(2, p_ordr_num);
        setres.setTimestamp(3, p_result);
        setres.executeUpdate();
        setres.close();
    }
    private void set_result_timestamp_tz(int p_task_id, int p_ordr_num, Timestamp p_result) throws Exception, SQLException
    {
        CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_timestamp_tz => ?) }");
        setres.setInt(1, p_task_id);
        setres.setInt(2, p_ordr_num);
        setres.setTimestamp(3, p_result);
        setres.executeUpdate();
        setres.close();
    }
    private String clobToString(java.sql.Clob data) throws Exception, SQLException
    {
        final StringBuilder sb = new StringBuilder();

        try
        {
            final Reader reader = data.getCharacterStream();
            final BufferedReader br     = new BufferedReader(reader);

            int b;
            while(-1 != (b = br.read()))
            {
                sb.append((char)b);
            }

            br.close();
        }
        catch (SQLException e)
        {
            log_info("SQL. Could not convert CLOB to string" + e.getMessage());
            return e.toString();
        }
        catch (IOException e)
        {
            log_info("IO. Could not convert CLOB to string" + e.getMessage());
            return e.toString();
        }

        return sb.toString();
    }
    private void execute_plsql_task(int p_task_id)  throws Exception, SQLException {
        int r_ordr_num;
        String r_io_type;
        String r_data_type;

        PreparedStatement paramsstmt = localconn.prepareStatement("SELECT r_ordr_num, r_io_type, r_data_type, r_clob, r_number, r_date, r_timestamp, r_timestamp_tz, r_varchar FROM opas_extproc_results where task_id = ? order by r_ordr_num, r_io_type");
        try {
            log_debug("start execute_plsql_task exec: p_task_id=" + p_task_id);
            paramsstmt.setInt(1, p_task_id);
            ResultSet paramsset = paramsstmt.executeQuery();
            CallableStatement plsql_block = remoteconn.prepareCall(pl_sql);
            while (paramsset.next()) {
                r_ordr_num = paramsset.getInt(1);
                r_io_type = paramsset.getString(2);
                r_data_type = paramsset.getString(3);
                if (r_io_type.equals("IN")) {
                    if (r_data_type.equals("NUMBER"))        plsql_block.setLong(r_ordr_num, paramsset.getLong(5));
                    if (r_data_type.equals("VARCHAR2"))      plsql_block.setString(r_ordr_num, paramsset.getString(9));
                    //if (r_data_type.equals("CLOB"))          plsql_block.setClob(r_ordr_num, paramsset.getClob(4)); // does not work so far
                    if (r_data_type.equals("DATE"))          plsql_block.setDate(r_ordr_num, paramsset.getDate(6));
                    if (r_data_type.equals("TIMESTAMP"))     plsql_block.setTimestamp(r_ordr_num, paramsset.getTimestamp(7));
                    if (r_data_type.equals("TIMESTAMP_TZ"))     plsql_block.setTimestamp(r_ordr_num, paramsset.getTimestamp(8));
                }
                if (r_io_type.equals("OUT")) {
                    if (r_data_type.equals("NUMBER"))        plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.NUMERIC);
                    if (r_data_type.equals("VARCHAR2"))      plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.VARCHAR);
                    if (r_data_type.equals("CLOB"))          plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.CLOB);
                    if (r_data_type.equals("DATE"))          plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.DATE);
                    if (r_data_type.equals("TIMESTAMP"))     plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.TIMESTAMP);
                    if (r_data_type.equals("TIMESTAMP_TZ"))  plsql_block.registerOutParameter(r_ordr_num, java.sql.Types.TIMESTAMP);
                }
            }
            log_debug("start plsql before");
            plsql_block.executeUpdate();
            log_debug("start plsql after");
            paramsset = paramsstmt.executeQuery();
            while (paramsset.next()) {
                r_ordr_num = paramsset.getInt(1);
                r_io_type = paramsset.getString(2);
                r_data_type = paramsset.getString(3);
                if (r_io_type.equals("OUT")) {
                    if (r_data_type.equals("NUMBER"))       set_result_number(p_task_id, r_ordr_num, plsql_block.getLong(r_ordr_num));
                    if (r_data_type.equals("VARCHAR2"))     set_result_varchar(p_task_id, r_ordr_num, plsql_block.getString(r_ordr_num));
                    if (r_data_type.equals("CLOB"))         {
                        //set_result_clob(p_task_id, r_ordr_num, plsql_block.getClob(r_ordr_num));
                        Clob myClob1 = plsql_block.getClob(r_ordr_num);
                        if ((myClob1 != null)&&(myClob1.length()>0)) {
                            Clob myClob2 = localconn.createClob();
                            String res = clobToString(myClob1);
                            myClob2.setString(1, res); //;
                            CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_clob => ?) }");
                            setres.setInt(1, p_task_id);
                            setres.setInt(2, r_ordr_num);
                            setres.setClob(3, myClob2);
                            setres.executeUpdate();
                            setres.close();
                        }
                    }
                    if (r_data_type.equals("DATE"))         set_result_date(p_task_id, r_ordr_num, plsql_block.getDate(r_ordr_num));
                    if (r_data_type.equals("TIMESTAMP"))    set_result_timestamp(p_task_id, r_ordr_num, plsql_block.getTimestamp(r_ordr_num));
                    if (r_data_type.equals("TIMESTAMP_TZ")) set_result_timestamp_tz(p_task_id, r_ordr_num, plsql_block.getTimestamp(r_ordr_num));
                }
            }

            plsql_block.close();
            paramsset.close();
            paramsstmt.close();
            if (qry_type.equals("PLSQL")) remoteconn.rollback();
            //localconn.commit();

            if (qry_type.equals("PLSQL")) set_task(p_task_id, "FINISHED", "", 1);

            executed++;
            log_debug("execute_plsql_task: " + executed);
        } catch (SQLException e) {
            set_task(p_task_id, "FAILED", " PLSQL: SQL Exception: " + e.getMessage(), 0);
            log_info("execute_plsql_task SQLException: " + e.getMessage());
        } catch (Exception e) {
            set_task(p_task_id, "FAILED", " PLSQL: Exception: " + e.getMessage(), 0);
            log_info("execute_plsql_task Exception: " + e.getMessage());
        }
    }

}

