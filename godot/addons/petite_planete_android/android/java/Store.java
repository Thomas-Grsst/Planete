package com.thomasgrsst.petiteplanete;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

final class Store {
    private static final String PREFS = "petite_planete";
    private static final String WIDGET = "widget";
    private static final String NOTIFICATIONS = "notifications";

    private Store() {}

    private static SharedPreferences prefs(Context ctx) {
        return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static void save(Context ctx, String widget, String notifications) {
        prefs(ctx).edit().putString(WIDGET, widget).putString(NOTIFICATIONS, notifications).commit();
    }

    static void saveNotifications(Context ctx, String notifications) {
        prefs(ctx).edit().putString(NOTIFICATIONS, notifications).commit();
    }

    static JSONObject widget(Context ctx) {
        try {
            return new JSONObject(prefs(ctx).getString(WIDGET, "{}"));
        } catch (JSONException e) {
            return new JSONObject();
        }
    }

    static JSONArray notifications(Context ctx) {
        try {
            return new JSONArray(prefs(ctx).getString(NOTIFICATIONS, "[]"));
        } catch (JSONException e) {
            return new JSONArray();
        }
    }

    static long nextTime(Context ctx) {
        JSONArray list = notifications(ctx);
        long next = 0;
        for (int i = 0; i < list.length(); i++) {
            JSONObject n = list.optJSONObject(i);
            long at = n == null ? 0 : n.optLong("at");
            if (at > 0 && (next == 0 || at < next)) next = at;
        }
        return next;
    }
}
