package com.thomasgrsst.petiteplanete;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Locale;

public class PlanetWidget extends AppWidgetProvider {
    private static final int DAYS_PER_YEAR = 360;

    @Override
    public void onReceive(Context ctx, Intent intent) {
        if (WidgetClock.TICK.equals(intent.getAction())) refreshAll(ctx);
        else super.onReceive(ctx, intent);
    }

    @Override
    public void onUpdate(Context ctx, AppWidgetManager manager, int[] ids) {
        refreshAll(ctx);
    }

    @Override
    public void onDisabled(Context ctx) {
        WidgetClock.cancel(ctx);
    }

    static void refreshAll(Context ctx) {
        AppWidgetManager manager = AppWidgetManager.getInstance(ctx);
        int[] ids = manager.getAppWidgetIds(new ComponentName(ctx, PlanetWidget.class));
        if (ids == null || ids.length == 0) {
            WidgetClock.cancel(ctx);
            return;
        }
        manager.updateAppWidget(ids, build(ctx));
    }

    private static int res(Context ctx, String name, String type) {
        return Res.id(ctx, name, type);
    }

    private static void text(Context ctx, RemoteViews views, String id, String value) {
        views.setTextViewText(res(ctx, id, "id"), value);
    }

    private static RemoteViews build(Context ctx) {
        RemoteViews views = new RemoteViews(ctx.getPackageName(), res(ctx, "planete_widget", "layout"));
        views.setOnClickPendingIntent(res(ctx, "planete_root", "id"), Notifier.openGame(ctx));
        JSONObject w = Store.widget(ctx);
        if (!w.has("name")) {
            views.setImageViewResource(res(ctx, "planete_scene", "id"), res(ctx, "planete_scene_day", "drawable"));
            text(ctx, views, "planete_title", "🌍 Petite Planète");
            text(ctx, views, "planete_day", "");
            text(ctx, views, "planete_pop", "");
            text(ctx, views, "planete_event", "Ouvre le jeu une fois pour réveiller ton monde.");
            return views;
        }
        long msPerDay = Math.max(1L, w.optLong("ms", 300000L));
        long raw = System.currentTimeMillis() - w.optLong("t0");
        long elapsed = Math.max(0L, raw);
        int passed = (int) Math.min(w.optLong("max", 8640L), elapsed / msPerDay);
        int day = w.optInt("day0") + passed;
        double hour = WidgetClock.hour(elapsed, msPerDay);
        views.setImageViewResource(res(ctx, "planete_scene", "id"), res(ctx, "planete_scene_" + WidgetClock.scene(hour), "drawable"));
        text(ctx, views, "planete_title", "🌍 " + w.optString("name"));
        text(ctx, views, "planete_day", String.format(Locale.FRANCE, "%s An %d, jour %d", WidgetClock.sky(hour), day / DAYS_PER_YEAR + 1, day % DAYS_PER_YEAR + 1));
        text(ctx, views, "planete_pop", population(w.optJSONArray("pops"), passed));
        text(ctx, views, "planete_event", lastEvent(w.optJSONArray("events"), day));
        WidgetClock.scheduleNext(ctx, raw, msPerDay);
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
