CREATE OR REPLACE AND RESOLVE JAVA SOURCE NAMED remote_executor
AS 
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import oracle.jdbc.driver.OracleDriver;
import oracle.jdbc.pool.OracleDataSource;
import java.sql.ResultSet;
//import oracle.sql.NUMBER;
//import oracle.sql.CLOB;
//import java.io.Writer;
import java.io.IOException;
import java.io.BufferedReader;
import java.io.Reader;
import java.sql.Clob;
import java.sql.Date;
import java.sql.Timestamp;
import java.util.concurrent.TimeUnit ;
import java.math.BigDecimal;
import java.time.format.DateTimeFormatter;  
import java.time.LocalDateTime;  

public class remote_executor {
    private static Connection localconn;
    private static Connection remoteconn;
    
    private static String username;
    private static String password_str;
    private static String server_connectstr;
    
    private static int maxqrynum;
    
    private static int cWORK_ID;
    private static int BatchSize;
    private static String logging_mode = "INFO";
    private static String remote_conn_error;
    private static boolean remote_conn_established;
    
    private static int task_id = 0;
    private static String qry_type = "";
    private static String select_sql = "";
    private static String load_sql = "";
    private static String pl_sql = "";
    private static int num_cols = 0;
    private static int timedout = 0;
    
    private static int executed = 0;
    
    private static DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss"); 
    
    private static void logm (String msg) throws Exception { 
      System.out.println(dtf.format(LocalDateTime.now()) + " remote_executor : " + msg);
    }
    
    private static void log_info (String msg) throws Exception { 
      //if (logging_mode.equals("INFO")) 
      logm(msg);
    }
    private static void log_debug (String msg) throws Exception { 
      if (logging_mode.equals("DEBUG")) logm(msg);
    }    
    private static void execute_statement(Connection conn, String sql_text) throws Exception, SQLException
    {
      PreparedStatement pstmt = conn.prepareStatement(sql_text);
      pstmt.executeUpdate();
      pstmt.close();    
    }
    private static void setup_session_nls(Connection conn) throws Exception, SQLException {
      execute_statement(conn, "alter session set nls_date_format='YYYYMMDDHH24MISS'");
      execute_statement(conn, "alter session set NLS_TIMESTAMP_FORMAT = 'YYYYMMDDHH24MISS.FF9'");
      execute_statement(conn, "alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYYMMDDHH24MISS.FF9 TZH:TZM'");
      execute_statement(conn, "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. '");
      execute_statement(conn, "alter session set time_zone=dbtimezone");
      execute_statement(conn, "begin dbms_application_info.set_module('REMOTEEXEC','Started'); end;");
      execute_statement(conn, "begin DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Performance information gatherer'); end;");
    }    
    private static void connect_to_local() throws Exception, SQLException
    {
      localconn = DriverManager.getConnection("jdbc:default:connection:");
      localconn.setAutoCommit(false);
      setup_session_nls(localconn);
      log_info("local connection established");
    }
    
    private static void connect_to_remote() throws Exception, SQLException
    {
      CallableStatement setconnprob = localconn.prepareCall("{ call COREMOD_EXTPROC.report_connection_problem( p_work_id => ?, p_errormsg => ? ) }");
      try
      {
        log_info("remote connection establishing...");

        remoteconn = DriverManager.getConnection("jdbc:oracle:thin:@"+server_connectstr,username,password_str);
        remoteconn.setAutoCommit(false);
        setup_session_nls(remoteconn);
        log_info("remote connection established"); 
        remote_conn_established = true;
        
      } catch (Exception e) {
        remote_conn_error = e.getMessage();
        setconnprob.setInt(1, cWORK_ID);
        setconnprob.setString(2, remote_conn_error);
        setconnprob.executeUpdate();    
        setconnprob.close();
        log_debug("executed Exception: " + e.getMessage()); 
        remote_conn_established = false;
      }
    } 
    private static void finalize_conn() throws Exception, SQLException {
       if (remote_conn_established) {
        remoteconn.close();
        log_info("Remote connection closed.");
      } else {
        log_info("Remote connection was not established.");
      }
      localconn.close();    
      log_info("Local connection closed.");
    }
    public static void test_remote_db(String dblink) throws Exception, SQLException
    {  
      
      connect_to_local();
      PreparedStatement localstmt = localconn.prepareStatement("select USERNAME, PASSWORD, CONNSTR from OPAS_DB_LINKS where DB_LINK_NAME = ?");
      localstmt.setString(1, dblink);
      ResultSet localrset = localstmt.executeQuery();

      while (localrset.next()) {
        username = localrset.getString(1);
        password_str = localrset.getString(2);
        server_connectstr = localrset.getString(3);
      }
      
      localrset.close();   
      localstmt.close();
      
      connect_to_remote();
      Statement remotestmt = remoteconn.createStatement();
      ResultSet remoterset = remotestmt.executeQuery("select * from dual");

      remoterset.next();
      log_info("Remote database <"+dblink+"> is accessible.");   
      remoterset.close();    
      remotestmt.close();
      
      finalize_conn();
    }
    
    private static void init_server(int p_work_id) throws Exception, SQLException
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


       username = callableStatement.getString(2);
       password_str = callableStatement.getString(3);
       server_connectstr = callableStatement.getString(4);
       maxqrynum = callableStatement.getInt(5);  
       logging_mode = callableStatement.getString(6);
       BatchSize = callableStatement.getInt(7);  
       callableStatement.close();
       
       log_info("logging_mode: " + logging_mode); 
    }
    
    private static void set_work(int p_work_id, int p_stmt_processed, String p_errm) throws Exception, SQLException
    {  
      CallableStatement setwork = localconn.prepareCall("{ call COREMOD_EXTPROC.worker_finished( p_work_id => ?, p_stmt_done => ?, p_errors => ?) }");
      setwork.setInt(1, p_work_id);
      setwork.setInt(2, p_stmt_processed);
      setwork.setString(3, p_errm);
      setwork.executeUpdate();
      setwork.close();    
    }    
    
    private static void set_task(int p_task_id, String p_status, String p_errm, int p_rows_processed) throws Exception, SQLException
    {  
      CallableStatement settask = localconn.prepareCall("{ call COREMOD_EXTPROC.set_task_finshed (  P_TASK_ID => ?, p_status => ?, p_errormsg => ?, p_rows_processed => ?) }");    
      settask.setInt(1, p_task_id);
      settask.setString(2, p_status);
      settask.setString(3, p_errm);
      settask.setInt(4, p_rows_processed);
      settask.executeUpdate();  
      settask.close();      
    }
  
    private static void get_task(int p_work_id) throws Exception, SQLException
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
    
    private static void execute_select_insert_task(int p_task_id)  throws Exception, SQLException {
		
      log_debug("start execute_select_insert_task: p_task_id=" + p_task_id);
      
      String which_sql = "";
      int rows_processed = 0;
      int batch_processed = 0;
      int[] cnt;    
      
      Statement selectdata;      
      PreparedStatement loadstmt;
      ResultSet localrset;
      ResultSet rsetdata;    
      
      if (remote_conn_established) {
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
    
    private static void set_result_varchar(int p_task_id, int p_ordr_num, String p_result) throws Exception, SQLException
    {  
      CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_varchar2 => ?) }");    
      setres.setInt(1, p_task_id);
      setres.setInt(2, p_ordr_num);
      setres.setString(3, p_result);
      setres.executeUpdate();  
      setres.close();      
    }

    private static void set_result_number(int p_task_id, int p_ordr_num, Long p_result) throws Exception, SQLException
    {  
      CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_number => ?) }");    
      setres.setInt(1, p_task_id);
      setres.setInt(2, p_ordr_num);
      setres.setLong(3, p_result);
      setres.executeUpdate();  
      setres.close();      
    }    
    //private static void set_result_clob(int p_task_id, int p_ordr_num, CLOB p_result) throws Exception, SQLException
    //{  
    //  CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_clob => ?) }");    
    //  setres.setInt(1, p_task_id);
    //  setres.setInt(2, p_ordr_num);
    //  setres.setClob(3, p_result);
    //  setres.executeUpdate();  
    //  setres.close();      
    //}     
    private static void set_result_date(int p_task_id, int p_ordr_num, Date p_result) throws Exception, SQLException
    {  
      CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_date => ?) }");    
      setres.setInt(1, p_task_id);
      setres.setInt(2, p_ordr_num);
      setres.setDate(3, p_result);
      setres.executeUpdate();  
      setres.close();      
    }    
    private static void set_result_timestamp(int p_task_id, int p_ordr_num, Timestamp p_result) throws Exception, SQLException
    {  
      CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_timestamp => ?) }");    
      setres.setInt(1, p_task_id);
      setres.setInt(2, p_ordr_num);
      setres.setTimestamp(3, p_result);
      setres.executeUpdate();  
      setres.close();      
    }  
    private static void set_result_timestamp_tz(int p_task_id, int p_ordr_num, Timestamp p_result) throws Exception, SQLException
    {  
      CallableStatement setres = localconn.prepareCall("{ call COREMOD_EXTPROC.set_param (  P_TASK_ID => ?, p_ordr_num => ?, p_timestamp_tz => ?) }");    
      setres.setInt(1, p_task_id);
      setres.setInt(2, p_ordr_num);
      setres.setTimestamp(3, p_result);
      setres.executeUpdate();  
      setres.close();      
    }     
    private static String clobToString(java.sql.Clob data) throws Exception, SQLException
    {
        final StringBuilder sb = new StringBuilder();

        try
        {
            final Reader         reader = data.getCharacterStream();
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
    private static void execute_plsql_task(int p_task_id)  throws Exception, SQLException {
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
          set_task(p_task_id, "FAILED", "SQL Exception: " + e.getMessage(), 0);
          log_info("execute_plsql_task SQLException: " + e.getMessage()); 
      } catch (Exception e) {       
          set_task(p_task_id, "FAILED", "Exception: " + e.getMessage(), 0);
          log_info("execute_plsql_task Exception: " + e.getMessage()); 
      }            
    }
    public static void start_server(int work_id) throws Exception, SQLException
    {
      cWORK_ID = work_id; 
      log_debug("cWORK_ID: " + cWORK_ID);
      
      connect_to_local();
      init_server(cWORK_ID);
      connect_to_remote();

      for(int i = 0; i < maxqrynum; i++) {  
        get_task(cWORK_ID);

        if (timedout>0) break;
        
        if (!remote_conn_established&&(task_id > 0)) {
          set_task(task_id, "FAILED", remote_conn_error, 0);
          break;
        }
        
        if (!remote_conn_established) break;
        
        if (remote_conn_established&&(task_id > 0)&&(qry_type.equals("SQLSELINS"))) execute_select_insert_task(task_id);
        if (remote_conn_established&&(task_id > 0)&&(qry_type.equals("PLSQL")))     execute_plsql_task(task_id);
        if (remote_conn_established&&(task_id > 0)&&(qry_type.equals("PLSQLSELINS"))) {
          execute_plsql_task(task_id);
          execute_select_insert_task(task_id);
        }
      
        try {
          TimeUnit.MILLISECONDS.sleep(100);
        } catch (InterruptedException ie) {
          Thread.currentThread().interrupt();
        }        
      }

      if (remote_conn_established) set_work(cWORK_ID, executed, "No errors");
      finalize_conn();
      log_info("finished");        
    }
}
/


CREATE OR REPLACE procedure start_server_prc(p_work_id number)
 IS
     LANGUAGE JAVA
     NAME 'remote_executor.start_server(int)' ;
 /

CREATE OR REPLACE procedure test_remote_db(p_dblink varchar2)
 IS
     LANGUAGE JAVA
     NAME 'remote_executor.test_remote_db(java.lang.String)' ;
 /