package com.thomasgrsst.petiteplanete;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

final class Notifier {
    private static final String CHANNEL = "planete_events";
    private static final long EARLY_MS = 30000L;

    private Notifier() {}

    static void postDue(Context ctx) {
        JSONArray list = Store.notifications(ctx);
        JSONArray rest = new JSONArray();
        JSONObject due = null;
        long now = System.currentTimeMillis();
        for (int i = 0; i < list.length(); i++) {
            JSONObject n = list.optJSONObject(i);
            if (n == null) continue;
            if (n.optLong("at") <= now + EARLY_MS) due = n;
            else rest.put(n);
        }
        Store.saveNotifications(ctx, rest.toString());
        if (due != null) show(ctx, due);
    }

    private static void show(Context ctx, JSONObject n) {
        NotificationManager manager = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Événements du monde", NotificationManager.IMPORTANCE_DEFAULT));
            builder = new Notification.Builder(ctx, CHANNEL);
        } else {
            builder = new Notification.Builder(ctx);
        }
        String text = n.optString("text");
        builder.setSmallIcon(icon(ctx))
            .setContentTitle(n.optString("title"))
            .setContentText(text)
            .setStyle(new Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(openGame(ctx));
        manager.notify((int) (n.optLong("at") / 1000L), builder.build());
    }

    private static int icon(Context ctx) {
        int id = Res.id(ctx, "planete_notif", "drawable");
        return id != 0 ? id : android.R.drawable.star_on;
    }

    static PendingIntent openGame(Context ctx) {
        Intent intent = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
        if (intent == null) intent = new Intent();
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        return PendingIntent.getActivity(ctx, 3, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
}
