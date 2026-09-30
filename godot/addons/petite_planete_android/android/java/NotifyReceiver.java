package com.thomasgrsst.petiteplanete;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class NotifyReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context ctx, Intent intent) {
        Notifier.postDue(ctx);
        Alarms.scheduleNext(ctx);
        PlanetWidget.refreshAll(ctx);
    }
}
