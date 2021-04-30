package com.opas60;

public class ExternalWorker implements Runnable {
    private String ConfigFileName;
    private int work_id;
    public ExternalWorker(String ConfigFileName, int work_id) {
        this.ConfigFileName = ConfigFileName;
        this.work_id = work_id;
    }

    public void run() {
        ExternalWorkerImpl worker = new ExternalWorkerImpl();
        worker.load_configuration(ConfigFileName);
        worker.log_info("Server thread starting: work_id: <" + work_id + ">");
        try {
            worker.start_server(work_id);
            Thread.yield();
        } catch (Exception e) {
            worker.log_info("Server thread: work_id: <" + work_id + ">. Err: " + e.getMessage());
        } finally {
            worker.log_info("Server thread: work_id: <" + work_id + "> ended.");
        }

    }
}
