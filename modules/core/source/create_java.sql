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
    private static String logging_mode = "INFO";
    
    private static DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss"); 
        
    private static void logm (String msg) throws Exception { 
      System.out.println(dtf.format(LocalDateTime.now()) + " remote_executor : " + msg);
    }
    
    private static void log_info (String msg) throws Exception { 
      if (logging_mode.equals("INFO")) logm(msg);
    }
    private static void log_debug (String msg) throws Exception { 
      if (logging_mode.equals("INFO")) logm(msg);
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
      execute_statement(conn, "begin dbms_application_info.set_module('REMOTEEXEC','Started'); end;");
      execute_statement(conn, "begin DBMS_APPLICATION_INFO.SET_CLIENT_INFO('Performance information gatherer'); end;");
    }    
    private static void connect_to_local() throws Exception, SQLException
    {
      localconn = DriverManager.getConnection("jdbc:default:connection:");
      setup_session_nls(localconn);
      log_info("local connection established");
    }
    
    private static void connect_to_remote() throws Exception, SQLException
    {
      CallableStatement setconnprob = localconn.prepareCall("{ call COREMOD_EXTPROC.report_connection_problem( p_work_id => ?, p_errors => ?) }");
      try
      {
        remoteconn = DriverManager.getConnection("jdbc:oracle:thin:@"+server_connectstr,username,password_str);
      } catch (Exception e) {
        setconnprob.setInt(1, cWORK_ID);
			  setconnprob.setString(2, e.getMessage());
        setconnprob.executeUpdate();				  
			  log_debug("executed Exception: " + e.getMessage()); 
        throw e;
      }
      setconnprob.close();
      
      setup_session_nls(remoteconn);
      log_info("remote connection established");  
    } 
    private static void finalize_conn() throws Exception, SQLException {
			remoteconn.close();
      log_info("Remote connection closed.");
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
    
    private static void init_server() throws Exception, SQLException
    {  
      
       CallableStatement callableStatement = localconn.prepareCall("{ call COREMOD_EXTPROC.init_server_parameters (  P_WORK_ID => ?, P_USERNAME => ?, P_PASSWORD => ?, P_CONNSTR => ?, P_QUERY_NUM => ?, p_logging_mode => ?) }");

       callableStatement.setInt(1, cWORK_ID);

       callableStatement.registerOutParameter(2, java.sql.Types.VARCHAR);
       callableStatement.registerOutParameter(3, java.sql.Types.VARCHAR);
       callableStatement.registerOutParameter(4, java.sql.Types.VARCHAR);
       callableStatement.registerOutParameter(5, java.sql.Types.DECIMAL);
       callableStatement.registerOutParameter(6, java.sql.Types.VARCHAR);

       callableStatement.executeUpdate();


       username = callableStatement.getString(2);
       password_str = callableStatement.getString(3);
       server_connectstr = callableStatement.getString(4);
       maxqrynum = callableStatement.getInt(5);  
       logging_mode = callableStatement.getString(6);
       callableStatement.close();
       
       log_info("logging_mode: " + logging_mode); 
    }
    
    public static void start_server(int work_id) throws Exception, SQLException
    {
      cWORK_ID = work_id;
      
      connect_to_local();
      init_server();
      
      connect_to_remote();
      
      int task_id = 0;
      int timedout = 0;
      int executed = 0;
      
      String qry_type = "";
      String select_sql = "";
      String load_sql = "";
      
      int num_cols = 0;
      int rows_processed = 0;
      
      PreparedStatement loadstmt;
      Statement selectdata = remoteconn.createStatement();

      ResultSet localrset;
      ResultSet rsetdata;

      CallableStatement gettask = localconn.prepareCall("{ call COREMOD_EXTPROC.get_next_task (  P_WORK_ID => ?, P_TASK_ID => ?, P_QRY_TYPE => ?, P_QRY1 => ?, P_QRY2 => ?, P_NUM_COLS => ?, P_TIMEOUTED => ?) }");
      CallableStatement settask = localconn.prepareCall("{ call COREMOD_EXTPROC.set_task_finshed (  P_TASK_ID => ?, p_status => ?, p_errormsg => ?) }");
      CallableStatement setwork = localconn.prepareCall("{ call COREMOD_EXTPROC.worker_finished( p_work_id => ?, p_stmt_done => ?, p_errors => ?) }");
      
      log_debug("cWORK_ID: " + cWORK_ID);        
      for(int i = 0; i < maxqrynum; i++) {  
        
        gettask.setInt(1, cWORK_ID);

        gettask.registerOutParameter(2, java.sql.Types.DECIMAL);
        gettask.registerOutParameter(3, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(4, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(5, java.sql.Types.VARCHAR);
        gettask.registerOutParameter(6, java.sql.Types.DECIMAL);
        gettask.registerOutParameter(7, java.sql.Types.DECIMAL);

        gettask.executeUpdate();
 
        task_id = gettask.getInt(2);
        qry_type = gettask.getString(3);
        select_sql = gettask.getString(4);
        load_sql = gettask.getString(5);
        num_cols = gettask.getInt(6);
        timedout = gettask.getInt(7);      

        log_debug("task_id: " + task_id);
        log_debug("qry_type: " + qry_type);
        log_debug("select_sql: " + select_sql);
        log_debug("load_sql: " + load_sql);
        log_debug("num_cols: " + num_cols);
        log_debug("timedout: " + timedout);

        if (timedout>0) break;
        
        if ((task_id > 0)&&(qry_type.equals("SQLSELINS"))) {
		    try {
          log_debug("Fetching");         
          rows_processed = 0;
          rsetdata = selectdata.executeQuery(select_sql);         
          loadstmt = localconn.prepareStatement(load_sql);
          
          while (rsetdata.next()) {
            loadstmt.setInt(1, task_id);
            for(int cols = 2; cols <= num_cols + 1; cols++) {               
              loadstmt.setString(cols, rsetdata.getString(cols-1));
            }
            loadstmt.executeUpdate();
            rows_processed++;
	        }
          loadstmt.close();
          localconn.commit();
          log_debug("rows_processed: " + rows_processed);          
          
          settask.setInt(1, task_id);
		      settask.setString(2, "FINISHED");
		      settask.setString(3, "");
          settask.executeUpdate();
         
          executed++;
          log_debug("executed: " + executed);   
          } catch (SQLException e) {
              settask.setInt(1, task_id);
		          settask.setString(2, "FAILED");
			        settask.setString(3, e.getMessage());
              settask.executeUpdate();			  
              //System.err.format("SQL State: %s\n%s", e.getSQLState(), e.getMessage());
              //e.printStackTrace();
			        log_debug("executed SQLException: " + e.getMessage()); 
          } catch (Exception e) {
              //e.printStackTrace();
              settask.setInt(1, task_id);
		          settask.setString(2, "FAILED");
			        settask.setString(3, e.getMessage());
              settask.executeUpdate();				  
			        log_debug("executed Exception: " + e.getMessage()); 
          }
        }
       
        try {
          TimeUnit.MILLISECONDS.sleep(100);
        } catch (InterruptedException ie) {
          Thread.currentThread().interrupt();
        }        
      }

      setwork.setInt(1, cWORK_ID);
      setwork.setInt(2, executed);
      setwork.setString(3, "No errors");
      setwork.executeUpdate();
          
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