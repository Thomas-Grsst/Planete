package com.thomasgrsst.petiteplanete;

import android.content.Context;
import android.content.res.Resources;

final class Res {
    private Res() {}

    static int id(Context ctx, String name, String type) {
        Resources res = ctx.getResources();
        int id = res.getIdentifier(name, type, tablePackage(ctx));
        return id != 0 ? id : res.getIdentifier(name, type, ctx.getPackageName());
    }

    private static String tablePackage(Context ctx) {
        int icon = ctx.getApplicationInfo().icon;
        if (icon == 0) return ctx.getPackageName();
        try {
            return ctx.getResources().getResourcePackageName(icon);
        } catch (Resources.NotFoundException e) {
            return ctx.getPackageName();
        }
    }
}
