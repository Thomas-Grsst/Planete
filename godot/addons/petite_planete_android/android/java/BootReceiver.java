package com.thomasgrsst.petiteplanete;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;
        Alarms.scheduleNext(ctx);
        PlanetWidget.refreshAll(ctx);
    }
}
