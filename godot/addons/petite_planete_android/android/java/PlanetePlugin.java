package com.thomasgrsst.petiteplanete;

import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

public class PlanetePlugin extends GodotPlugin {
    private static final String NOTIFICATION_PERMISSION = "android.permission.POST_NOTIFICATIONS";

    public PlanetePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PetitePlanete";
    }

    private Context context() {
        Activity activity = getActivity();
        return activity == null ? null : activity.getApplicationContext();
    }

    @UsedByGodot
    public void publish(String widget, String notifications) {
        Context ctx = context();
        if (ctx == null) return;
        Store.save(ctx, widget, notifications);
        Alarms.scheduleNext(ctx);
        PlanetWidget.refreshAll(ctx);
    }

    @UsedByGodot
    public void clearNotifications() {
        Context ctx = context();
        if (ctx == null) return;
        Store.saveNotifications(ctx, "[]");
        Alarms.scheduleNext(ctx);
        NotificationManager manager = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager != null) manager.cancelAll();
    }

    @UsedByGodot
    public void requestNotificationPermission() {
        final Activity activity = getActivity();
        if (activity == null || Build.VERSION.SDK_INT < 33) return;
        if (activity.checkSelfPermission(NOTIFICATION_PERMISSION) == PackageManager.PERMISSION_GRANTED) return;
        activity.runOnUiThread(() -> activity.requestPermissions(new String[] { NOTIFICATION_PERMISSION }, 4242));
    }
}
