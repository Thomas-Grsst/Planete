package com.thomasgrsst.petiteplanete;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

final class WidgetClock {
    static final String TICK = "com.thomasgrsst.petiteplanete.WIDGET_TICK";
    private static final double[] CHANGES = { 5.0, 7.0, 17.5, 20.0 };

    private WidgetClock() {}

    static double hour(long elapsed, long msPerDay) {
        return (6.0 + (elapsed % msPerDay) * 24.0 / msPerDay) % 24.0;
    }

    static String scene(double hour) {
        if (hour >= 7.0 && hour < 17.5) return "day";
        if (hour >= 5.0 && hour < 20.0) return "dusk";
        return "night";
    }

    static String sky(double hour) {
        String scene = scene(hour);
        if (scene.equals("day")) return "☀️";
        if (scene.equals("dusk")) return hour < 12.0 ? "🌄" : "🌅";
        return "🌙";
    }

    private static PendingIntent intent(Context ctx) {
        Intent intent = new Intent(ctx, PlanetWidget.class).setAction(TICK);
        return PendingIntent.getBroadcast(ctx, 9, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static void scheduleNext(Context ctx, long elapsed, long msPerDay) {
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (alarms == null) return;
        long at = System.currentTimeMillis() + 500L + (elapsed < 0 ? -elapsed : waitMs(elapsed, msPerDay));
        if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
            alarms.setExact(AlarmManager.RTC, at, intent(ctx));
        } else {
            alarms.set(AlarmManager.RTC, at, intent(ctx));
        }
    }

    private static long waitMs(long elapsed, long msPerDay) {
        double now = hour(elapsed, msPerDay);
        double wait = 24.0;
        for (double change : CHANGES) {
            double d = (change - now + 24.0) % 24.0;
            if (d > 0.001 && d < wait) wait = d;
        }
        return (long) (wait / 24.0 * msPerDay);
    }

    static void cancel(Context ctx) {
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (alarms != null) alarms.cancel(intent(ctx));
    }
}
