package com.opas60;

import java.sql.*;
import java.util.concurrent.ExecutorService;

public class ExternalServerImpl extends ExternalExecutor{
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
    public void before_server_start() throws Exception, SQLException
    {

        CallableStatement beforestart = localconn.prepareCall("{ call COREMOD_EXTPROC.server_before_start }");
        beforestart.executeUpdate();
        beforestart.close();
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

        if (work_id>0) {
            log_info("init_server: Starting server for work_id: " + work_id);
            exec.execute(new ExternalWorker(ConfigFileName, work_id));
            log_info("init_server: Started server for work_id: " + work_id);
        } else {
            log_info("init_server: No task in queue");
        }
    }
}
