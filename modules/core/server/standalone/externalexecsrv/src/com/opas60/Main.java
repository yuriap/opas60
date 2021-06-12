package com.opas60;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {

    public static void main(String[] args) throws Exception{
        //connect_to_local();
        ExternalServerImpl server = new ExternalServerImpl();
        server.setProcName("Main thread");
        int cntRestart = 0;
        if (args.length > 0 ) {
            if (args[0].equals("TESTDBLINKS")) {
                server.load_configuration(args[1]);
                server.test_remote_dbs();
            }else if (args[0].equals("STARTSERVER")){
                server.log_info("Starting server.");
                server.load_configuration(args[1]);
                do
                    try {
                        cntRestart++;
                        server.connect_to_local();
                        server.before_server_start();
                        ExecutorService exec = Executors.newCachedThreadPool();
                        do
                            server.init_server(args[1], exec);
                        while (true);
                        //exec.shutdown();
                    } catch (Exception e) {
                        server.log_info("Server exception: " + e.getMessage());
                        server.log_info("Trying to restart: attempt " + server.maxRestarts);
                        server.prepare2restart();
                    }
                while (cntRestart<=server.maxRestarts);
            }
        }else
        {
            server.log_info("Nothing to do.");
        }
    }
}
