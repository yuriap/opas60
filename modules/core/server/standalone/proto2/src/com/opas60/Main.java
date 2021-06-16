package com.opas60;
import java.util.concurrent.*;
import static com.opas60.DBUtils.*;


public class Main {

    public static void main(String[] args) throws Exception{
        //connect_to_local();
        DBUtils.setProcName("Main thread");
        int cntRestart = 0;
        if (args.length > 0 ) {
            if (args[0].equals("TESTDBLINKS")) {
                DBUtils.load_configuration(args[1]);
                test_remote_dbs();
            }else if (args[0].equals("STARTSERVER")){
                DBUtils.log_info("Starting server.");
                DBUtils.load_configuration(args[1]);
                //connect_to_local();
                //DBUtils.before_server_start();
                //ExecutorService exec = Executors.newCachedThreadPool();
                //do
                //    DBUtils.init_server(args[1], exec);
                //while (true);

                do
                    try {
                        cntRestart++;
                        DBUtils.log_info("Session #" + cntRestart);
                        connect_to_local();
                        before_server_start();
                        ExecutorService exec = Executors.newCachedThreadPool();
                        do
                            DBUtils.init_server(args[1], exec);
                        while (true);
                        //exec.shutdown();
                    } catch (Exception e) {
                        DBUtils.log_info("Server exception: " + e.getMessage());
                        DBUtils.prepare2restart();

                        try {
                            DBUtils.log_info("Trying to restart, delay 10 seconds: attempt " + cntRestart + " of " + 100);
                            TimeUnit.MILLISECONDS.sleep(10000);
                        } catch (InterruptedException ie) {
                            Thread.currentThread().interrupt();
                        }
                    }

                while (cntRestart<=100);
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
