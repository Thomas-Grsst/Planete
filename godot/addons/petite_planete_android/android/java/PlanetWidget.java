package com.thomasgrsst.petiteplanete;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Locale;

public class PlanetWidget extends AppWidgetProvider {
    private static final long MS_PER_DAY = 600000L;
    private static final int DAYS_PER_YEAR = 360;

    @Override
    public void onUpdate(Context ctx, AppWidgetManager manager, int[] ids) {
        manager.updateAppWidget(ids, build(ctx));
    }

    static void refreshAll(Context ctx) {
        AppWidgetManager manager = AppWidgetManager.getInstance(ctx);
        int[] ids = manager.getAppWidgetIds(new ComponentName(ctx, PlanetWidget.class));
        if (ids != null && ids.length > 0) manager.updateAppWidget(ids, build(ctx));
    }

    private static int res(Context ctx, String name, String type) {
        return Res.id(ctx, name, type);
    }

    private static RemoteViews build(Context ctx) {
        RemoteViews views = new RemoteViews(ctx.getPackageName(), res(ctx, "planete_widget", "layout"));
        views.setOnClickPendingIntent(res(ctx, "planete_root", "id"), Notifier.openGame(ctx));
        JSONObject w = Store.widget(ctx);
        if (!w.has("name")) {
            views.setTextViewText(res(ctx, "planete_title", "id"), "🌍 Petite Planète");
            views.setTextViewText(res(ctx, "planete_day", "id"), "");
            views.setTextViewText(res(ctx, "planete_pop", "id"), "");
            views.setTextViewText(res(ctx, "planete_event", "id"), "Ouvre le jeu une fois pour réveiller ton monde.");
            return views;
        }
        long elapsed = Math.max(0L, System.currentTimeMillis() - w.optLong("t0"));
        int passed = (int) Math.min(w.optLong("max", 4320L), elapsed / MS_PER_DAY);
        int day = w.optInt("day0") + passed;
        double hour = (6.0 + (elapsed % MS_PER_DAY) * 24.0 / MS_PER_DAY) % 24.0;
        String sky = hour >= 6.0 && hour < 20.0 ? "☀️" : "🌙";
        views.setTextViewText(res(ctx, "planete_title", "id"), "🌍 " + w.optString("name"));
        views.setTextViewText(res(ctx, "planete_day", "id"), String.format(Locale.FRANCE, "%s An %d, jour %d", sky, day / DAYS_PER_YEAR + 1, day % DAYS_PER_YEAR + 1));
        views.setTextViewText(res(ctx, "planete_pop", "id"), population(w.optJSONArray("pops"), passed));
        views.setTextViewText(res(ctx, "planete_event", "id"), lastEvent(w.optJSONArray("events"), day));
        return views;
    }

    private static String population(JSONArray pops, int passed) {
        if (pops == null || pops.length() == 0) return "";
        boolean known = passed < pops.length();
        int pop = pops.optInt(Math.min(passed, pops.length() - 1));
        if (pop <= 0) return "🪦 Plus personne ne vit ici";
        String count = String.format(Locale.FRANCE, "%,d", pop);
        return "👥 " + (known ? "" : "≈ ") + count + (pop > 1 ? " habitants" : " habitant");
    }

    private static String lastEvent(JSONArray events, int day) {
        String text = "";
        if (events == null) return text;
        for (int i = 0; i < events.length(); i++) {
            JSONObject e = events.optJSONObject(i);
            if (e != null && e.optInt("d") <= day) text = e.optString("x");
        }
        return text;
    }
}
