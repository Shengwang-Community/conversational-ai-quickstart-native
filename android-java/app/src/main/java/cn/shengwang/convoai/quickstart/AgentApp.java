package cn.shengwang.convoai.quickstart;

import android.app.Application;

public class AgentApp extends Application {
    private static final String TAG = "AgentApp";
    private static Application app;

    public static Application instance() {
        return app;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        app = this;
    }
}

