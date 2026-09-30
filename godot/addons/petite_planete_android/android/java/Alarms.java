package com.thomasgrsst.petiteplanete;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

final class Alarms {
    private Alarms() {}

    private static PendingIntent intent(Context ctx) {
        Intent intent = new Intent(ctx, NotifyReceiver.class);
        return PendingIntent.getBroadcast(ctx, 7, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static void scheduleNext(Context ctx) {
        AlarmManager alarms = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (alarms == null) return;
        long next = Store.nextTime(ctx);
        if (next <= 0) {
            alarms.cancel(intent(ctx));
            return;
        }
        long at = Math.max(next, System.currentTimeMillis() + 1000L);
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(ctx));
    }
}
