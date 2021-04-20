package com.opas60;
import java.util.concurrent.*;
import static com.opas60.DBUtils.*;


public class Main {

    public static void main(String[] args) throws Exception{
        //connect_to_local();
        DBUtils.setProcName("Main thread");
        if (args.length > 0 ) {
            if (args[0].equals("TESTDBLINKS")) {
                DBUtils.load_configuration(args[1]);
                test_remote_dbs();
            }else if (args[0].equals("STARTSERVER")){
                DBUtils.log_info("Starting server.");
                DBUtils.load_configuration(args[1]);
                connect_to_local();
                DBUtils.before_server_start();
                ExecutorService exec = Executors.newCachedThreadPool();
                do
                    DBUtils.init_server(args[1], exec);
                while (true);
                //exec.shutdown();
            }
        }else
        {
            DBUtils.log_info("Nothing to do.");
        }
        //ExecutorService exec = Executors.newCachedThreadPool();
        //for(int i = 0; i < 5; i++)
        //    exec.execute(new ExternalWorker());
        //exec.shutdown();
    }
}
