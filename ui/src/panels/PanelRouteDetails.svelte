<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import * as Accordion from "$lib/components/ui/accordion/index.js";
    import { untrack } from "svelte";
    import {
        toCapitalCase,
        getDisturbanceIndexCategory,
        getDisturbanceIndexCategories,
    } from "$lib/utils.js";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";

    let {
        selected_shape_id = $bindable(),
        geoData,
        selectedWayId,
        di_threshold_low = 0.05,
        di_threshold_high = 0.2,
    }: {
        selected_shape_id: string;
        geoData: GeoPrioritisation | null;
        selectedWayId: string | undefined;
        di_threshold_low?: number;
        di_threshold_high?: number;
    } = $props();
</script>

{#if selected_shape_id && selected_shape_id !== "all" && geoData && !selectedWayId}
    {@const shape = geoData.shapes[selected_shape_id]}
    {@const shapeColor = shape?.route_color ?? "var(--primary)"}
    {@const routeDemand = shape?.route_id
        ? Number(geoData.routes?.[shape.route_id]?.demand)
        : NaN}
    {@const shapeWayIds = Object.entries(geoData.wayData)
        .filter(([, wd]: [string, any]) =>
            wd?.shapes?.includes(selected_shape_id),
        )
        .map(([id]) => id)}
    {@const shapeWays = shapeWayIds
        .map((id) => geoData!.wayData[id])
        .filter(Boolean)}
    {@const scheduleEntries = shape?.schedule
        ? Object.entries(shape.schedule).map(([h, v]) => ({
              hour: parseInt(h),
              count: v as number,
          }))
        : []}
    {@const maxSchedule =
        scheduleEntries.length > 0
            ? Math.max(...scheduleEntries.map((e) => e.count))
            : 1}
    {@const speedProfile = shape?.speed_profile}
    {@const speedProfileStats = speedProfile?.stats}
    {@const speedProfileHours = speedProfile?.hours ?? []}
    {@const maxHourlyCommercialSpeed =
        speedProfileHours.length > 0
            ? Math.max(
                  ...speedProfileHours.map(
                      (h) => h.commercial_speed_avg ?? 0,
                  ),
                  1,
              )
            : 1}
    {@const maxAbsDi =
        speedProfileHours.length > 0
            ? Math.max(
                  ...speedProfileHours.map((h) =>
                      Math.abs(h.disturbance_index ?? 0),
                  ),
                  0.1,
              )
            : 0.1}
    <div
        id="route-details-panel"
        class="absolute top-4 left-4 right-4 sm:left-auto sm:right-4 z-[1010] flex flex-col w-[calc(100vw-2rem)] sm:w-[380px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-5 overflow-y-auto gap-4"
    >
        <!-- Header -->
        <div class="flex items-start justify-between gap-2">
            <div>
                <div class="flex items-center gap-2 mb-0.5">
                    <div
                        class="w-3 h-3 rounded-full shrink-0"
                        style="background-color: {shapeColor}"
                    ></div>
                    <span
                        class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                        >Route {shape?.route_short_name}</span
                    >
                </div>
                <h3 class="text-base font-bold text-foreground leading-snug">
                    {shape?.route_long_name}
                </h3>
                <p class="text-[10px] text-muted-foreground font-mono mt-1">
                    route_id: {shape?.route_id || "N/A"} • shape_id: {selected_shape_id}
                </p>
                <p class="text-xs text-muted-foreground mt-0.5">
                    {shape?.direction_id ? "↙ Descending" : "↗ Ascending"} · {shapeWayIds.length}
                    road segments
                </p>
            </div>
            <Button
                variant="ghost"
                size="icon"
                onclick={() => (selected_shape_id = "all")}
                class="rounded-full shrink-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Terminal Stops (Departure & Arrival) -->
        {#if shape?.departure_stop || shape?.arrival_stop}
            <div class="px-1 py-0.5 space-y-1 text-xs">
                {#if shape.departure_stop}
                    {@const depName =
                        toCapitalCase(shape.departure_stop.stop_name) ||
                        shape.departure_stop.stop_id}
                    <div class="flex items-center gap-2">
                        <span
                            class="w-2.5 h-2.5 rounded-full border-2 border-emerald-600 bg-background shrink-0"
                        ></span>
                        <div class="min-w-0 flex-1 truncate">
                            <span
                                class="text-xs text-foreground font-medium"
                                title={depName}
                            >
                                <span class="text-muted-foreground">From:</span>
                                {depName}
                            </span>
                        </div>
                    </div>
                {/if}
                {#if shape.departure_stop && shape.arrival_stop}
                    <div
                        class="ml-[4px] h-2.5 border-l border-dashed border-border/80"
                    ></div>
                {/if}
                {#if shape.arrival_stop}
                    {@const arrName =
                        toCapitalCase(shape.arrival_stop.stop_name) ||
                        shape.arrival_stop.stop_id}
                    <div class="flex items-center gap-2">
                        <span
                            class="w-2.5 h-2.5 rounded-full border-2 border-red-600 bg-background shrink-0"
                        ></span>
                        <div class="min-w-0 flex-1 truncate">
                            <span
                                class="text-xs text-foreground font-medium"
                                title={arrName}
                            >
                                <span class="text-muted-foreground">To:</span>
                                {arrName}
                            </span>
                        </div>
                    </div>
                {/if}
            </div>
        {/if}

        <!-- Sections Accordion -->
        <Accordion.Root
            type="multiple"
            value={["demand-departures"]}
            class="w-full space-y-2"
        >
            <!-- Group: Demand & Departures -->
            {#if !Number.isNaN(routeDemand) || scheduleEntries.length > 0}
                <Accordion.Item
                    value="demand-departures"
                    class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                >
                    <Accordion.Trigger class="py-3 hover:no-underline">
                        <div class="flex items-center gap-2 text-start">
                            <i class="fas fa-users text-xs text-muted-foreground"></i>
                            <span class="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                                Demand & Departures
                            </span>
                        </div>
                    </Accordion.Trigger>
                    <Accordion.Content class="pt-1 pb-3 space-y-3">
                        <!-- Route demand -->
                        {#if !Number.isNaN(routeDemand)}
                            <div class="p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs">
                                <div class="flex items-start justify-between gap-3">
                                    <div>
                                        <p class="text-[10px] font-bold uppercase tracking-wider text-muted-foreground mb-1">
                                            Route Demand
                                        </p>
                                        <p class="text-2xl font-bold leading-none">
                                            {Math.round(routeDemand).toLocaleString()}
                                        </p>
                                        <p class="text-xs text-muted-foreground mt-1">
                                            passengers/day
                                        </p>
                                    </div>
                                    <div
                                        class="w-10 h-10 rounded-full flex items-center justify-center text-white/90 shadow-sm shrink-0"
                                        style="background-color: {shapeColor}"
                                    >
                                        <i class="fas fa-users text-sm"></i>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        <!-- 24h Frequency Chart -->
                        {#if scheduleEntries.length > 0}
                            <div class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs">
                                <h5 class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground">
                                    <i class="fas fa-chart-bar" style="color: {shapeColor}"></i>
                                    Scheduled Departures / Hour
                                </h5>
                                <div
                                    class="flex items-end gap-[2px] h-20 border-l border-b border-muted-foreground/30 px-1 pt-2"
                                >
                                    {#each Array(24) as _, i}
                                        {@const entry = scheduleEntries.find(
                                            (e) => e.hour === i,
                                        )}
                                        {@const count = entry?.count ?? 0}
                                        {@const height =
                                            count > 0
                                                ? Math.max((count / maxSchedule) * 100, 8)
                                                : 0}
                                        <div
                                            class="flex-1 rounded-t-[1px] relative group transition-colors"
                                            style="height: {height}%; background-color: {count > 0
                                                ? shapeColor + 'bb'
                                                : 'transparent'};"
                                            title="{i}:00 – {count} dep."
                                        >
                                            {#if count > 0}
                                                <div
                                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                                >
                                                    {i}:00: {count}
                                                </div>
                                            {/if}
                                        </div>
                                    {/each}
                                </div>
                                <div
                                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                                >
                                    <span>0h</span><span>6h</span><span>12h</span><span
                                        >18h</span
                                    ><span>23h</span>
                                </div>
                            </div>
                        {/if}
                    </Accordion.Content>
                </Accordion.Item>
            {/if}

            <!-- Road Segment Indicators -->
            {#if shapeWays.length > 0}
                <Accordion.Item
                    value="road-segment"
                    class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                >
                    <Accordion.Trigger class="py-3 hover:no-underline">
                        <div class="flex items-center gap-2 text-start">
                            <i class="fas fa-road text-xs text-muted-foreground"></i>
                            <span class="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                                Road Segment Indicators
                            </span>
                        </div>
                    </Accordion.Trigger>
                    <Accordion.Content class="pt-1 pb-3 space-y-3">
                        <p class="text-[10px] text-muted-foreground">
                            Average values weighted by segment length.
                        </p>
                        <div class="grid grid-cols-3 gap-2">
                            <!-- Speed indicators -->
                            {#if shape.stats?.speed_min && shape.stats?.speed_max && shape.stats?.speed_avg}
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                >
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Min Speed
                                    </p>
                                    <p class="text-sm font-bold">
                                        {shape.stats.speed_min}<span
                                            class="text-[9px] font-normal"
                                        >
                                            km/h</span
                                        >
                                    </p>
                                </div>
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                >
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Avg Speed
                                    </p>
                                    <p class="text-sm font-bold">
                                        {shape.stats.speed_avg}<span
                                            class="text-[9px] font-normal"
                                        >
                                            km/h</span
                                        >
                                    </p>
                                </div>
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                >
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Max Speed
                                    </p>
                                    <p class="text-sm font-bold">
                                        {shape.stats.speed_max}<span
                                            class="text-[9px] font-normal"
                                        >
                                            km/h</span
                                        >
                                    </p>
                                </div>
                                <p class="col-span-3 text-[10px] text-muted-foreground">
                                    Speed metrics considering speed at segment level
                                    (which considers all routes that go through it).
                                </p>
                            {/if}

                            <!-- Lanes indicators -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Min Lanes/Dir
                                </p>
                                <p class="text-sm font-bold">
                                    {shape.stats.n_lanes_circulation_min}
                                </p>
                            </div>
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Avg Lanes/Dir
                                </p>
                                <p class="text-sm font-bold">
                                    {shape.stats.n_lanes_circulation_avg}
                                </p>
                            </div>
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Max Lanes/Dir
                                </p>
                                <p class="text-sm font-bold">
                                    {shape.stats.n_lanes_circulation_max}
                                </p>
                            </div>
                        </div>

                        <!-- Extension bars -->
                        <div class="space-y-2 mt-1">
                            <div
                                class="p-3 bg-background/80 rounded-xl border border-border/40 space-y-2 shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground"
                                >
                                    Route Extension
                                </p>
                                <div class="space-y-1.5">
                                    <div>
                                        <div
                                            class="flex justify-between text-[10px] mb-0.5"
                                        >
                                            <span class="text-muted-foreground"
                                                >With bus lane</span
                                            >
                                            <span class="font-semibold"
                                                >{(
                                                    shape.stats.extension_bus_lane /
                                                    1000
                                                ).toFixed(2)} km ({shape.stats
                                                    .extension > 0
                                                    ? (
                                                          (shape.stats
                                                              .extension_bus_lane /
                                                              shape.stats.extension) *
                                                          100
                                                      ).toFixed(0)
                                                    : 0}%)</span
                                            >
                                        </div>
                                        <div
                                            class="h-2 rounded-full bg-muted overflow-hidden"
                                        >
                                            <div
                                                class="h-full rounded-full bg-teal-500"
                                                style="width: {shape.stats.extension > 0
                                                    ? (shape.stats.extension_bus_lane /
                                                          shape.stats.extension) *
                                                      100
                                                    : 0}%"
                                            ></div>
                                        </div>
                                    </div>
                                    <div>
                                        <div
                                            class="flex justify-between text-[10px] mb-0.5"
                                        >
                                            <span class="text-muted-foreground"
                                                >Without bus lane</span
                                            >
                                            <span class="font-semibold"
                                                >{(
                                                    (shape.stats.extension -
                                                        shape.stats
                                                            .extension_bus_lane) /
                                                    1000
                                                ).toFixed(2)} km ({shape.stats
                                                    .extension > 0
                                                    ? (
                                                          ((shape.stats.extension -
                                                              shape.stats
                                                                  .extension_bus_lane) /
                                                              shape.stats.extension) *
                                                          100
                                                      ).toFixed(0)
                                                    : 0}%)</span
                                            >
                                        </div>
                                        <div
                                            class="h-2 rounded-full bg-muted overflow-hidden"
                                        >
                                            <div
                                                class="h-full rounded-full bg-orange-400"
                                                style="width: {shape.stats.extension > 0
                                                    ? ((shape.stats.extension -
                                                          shape.stats
                                                              .extension_bus_lane) /
                                                          shape.stats.extension) *
                                                      100
                                                    : 0}%"
                                            ></div>
                                        </div>
                                    </div>
                                    <div
                                        class="flex justify-between text-[10px] pt-1 border-t border-border/50"
                                    >
                                        <span
                                            class="text-muted-foreground font-semibold"
                                            >Total</span
                                        >
                                        <span class="font-bold"
                                            >{(shape.stats.extension / 1000).toFixed(2)}
                                            km</span
                                        >
                                    </div>
                                </div>
                            </div>
                        </div>
                    </Accordion.Content>
                </Accordion.Item>
            {/if}

            <!-- Commercial Speed Indicators -->
            {#if speedProfileStats || speedProfileHours.length > 0}
                <Accordion.Item
                    value="commercial-speed"
                    class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                >
                    <Accordion.Trigger class="py-3 hover:no-underline">
                        <div class="flex items-center gap-2 text-start">
                            <i class="fas fa-gauge-high text-xs text-muted-foreground"></i>
                            <span class="text-xs font-bold uppercase tracking-wider text-muted-foreground">
                                Commercial Speed Indicators
                            </span>
                        </div>
                    </Accordion.Trigger>
                    <Accordion.Content class="pt-1 pb-3 space-y-3">
                        <p class="text-[10px] text-muted-foreground">
                            Real-time commercial speed metrics aggregated for this route shape.
                        </p>

                        <!-- Stats Cards -->
                        {#if speedProfileStats}
                            <div class="grid grid-cols-3 gap-2">
                                {#if speedProfileStats.commercial_speed_min != null}
                                    <div
                                        class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                    >
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Min Speed
                                        </p>
                                        <p class="text-sm font-bold">
                                            {Number(speedProfileStats.commercial_speed_min).toFixed(1)}<span
                                                class="text-[9px] font-normal"
                                            >
                                                km/h</span
                                            >
                                        </p>
                                    </div>
                                {/if}

                                {#if speedProfileStats.commercial_speed_avg != null}
                                    <div
                                        class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                    >
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Avg Speed
                                        </p>
                                        <p class="text-sm font-bold">
                                            {Number(speedProfileStats.commercial_speed_avg).toFixed(1)}<span
                                                class="text-[9px] font-normal"
                                            >
                                                km/h</span
                                            >
                                        </p>
                                    </div>
                                {/if}

                                {#if speedProfileStats.commercial_speed_max != null}
                                    <div
                                        class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                    >
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Max Speed
                                        </p>
                                        <p class="text-sm font-bold">
                                            {Number(speedProfileStats.commercial_speed_max).toFixed(1)}<span
                                                class="text-[9px] font-normal"
                                            >
                                                km/h</span
                                            >
                                        </p>
                                    </div>
                                {/if}

                                {#if speedProfileStats.commercial_speed_median != null}
                                    <div
                                        class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                    >
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Median Speed
                                        </p>
                                        <p class="text-sm font-bold">
                                            {Number(speedProfileStats.commercial_speed_median).toFixed(1)}<span
                                                class="text-[9px] font-normal"
                                            >
                                                km/h</span
                                            >
                                        </p>
                                    </div>
                                {/if}

                                {#if speedProfileStats.commercial_speed_p85 != null}
                                    <div
                                        class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                                    >
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            P85 Speed
                                        </p>
                                        <p class="text-sm font-bold">
                                            {Number(speedProfileStats.commercial_speed_p85).toFixed(1)}<span
                                                class="text-[9px] font-normal"
                                            >
                                                km/h</span
                                            >
                                        </p>
                                    </div>
                                {/if}
                            </div>

                            {#if speedProfileStats.n_trips != null || speedProfileStats.n_days != null}
                                <div
                                    class="flex justify-between items-center text-[10px] text-muted-foreground px-1"
                                >
                                    {#if speedProfileStats.n_trips != null}
                                        <span>Trips sampled: <strong class="text-foreground">{speedProfileStats.n_trips}</strong></span>
                                    {/if}
                                    {#if speedProfileStats.n_days != null}
                                        <span>Days observed: <strong class="text-foreground">{speedProfileStats.n_days}</strong></span>
                                    {/if}
                                </div>
                            {/if}
                        {/if}

                        <!-- Hourly Variation Chart -->
                        {#if speedProfileHours.length > 0}
                            <div
                                class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                            >
                                <h6
                                    class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                >
                                    <i class="fas fa-gauge-high" style="color: {shapeColor}"></i>
                                    Hourly Commercial Speed (Avg)
                                </h6>
                                <div
                                    class="flex items-end gap-[2px] h-24 border-l border-b border-muted-foreground/30 px-1 pt-2 bg-muted/10 rounded-sm"
                                >
                                    {#each Array(24) as _, i}
                                        {@const hourData = speedProfileHours.find(
                                            (h) => h.hour === i,
                                        )}
                                        {@const speedAvg = hourData?.commercial_speed_avg}
                                        {@const height =
                                            speedAvg != null && speedAvg > 0
                                                ? Math.max(
                                                      (speedAvg / maxHourlyCommercialSpeed) * 100,
                                                      8,
                                                  )
                                                : 0}
                                        <div
                                            class="flex-1 rounded-t-[1px] relative group transition-colors"
                                            style="height: {height}%; background-color: {speedAvg != null && speedAvg > 0
                                                ? shapeColor + 'cc'
                                                : 'transparent'};"
                                        >
                                            {#if hourData && speedAvg != null}
                                                <div
                                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                                >
                                                    {i}:00: {Number(speedAvg).toFixed(1)} km/h
                                                </div>
                                            {/if}
                                        </div>
                                    {/each}
                                </div>
                                <div
                                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                                >
                                    <span>0h</span><span>6h</span><span>12h</span><span
                                        >18h</span
                                    ><span>23h</span>
                                </div>

                                <!-- Hourly Metrics Table -->
                                <div class="overflow-x-auto pt-2">
                                    <table
                                        class="w-full min-w-[760px] border-separate border-spacing-x-[2px] border-spacing-y-1"
                                    >
                                        <tbody>
                                            <tr>
                                                <th
                                                    class="text-[9px] font-mono font-semibold text-muted-foreground text-left px-2 py-1"
                                                >
                                                    Metric\Hour
                                                </th>
                                                {#each Array(24) as _, i}
                                                    <th
                                                        class="text-[9px] font-mono font-semibold text-muted-foreground text-center px-1 py-1"
                                                    >
                                                        {i}h
                                                    </th>
                                                {/each}
                                            </tr>

                                            <!-- Average Speed -->
                                            <tr>
                                                <th
                                                    class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                                >
                                                    Average speed (km/h)
                                                </th>
                                                {#each Array(24) as _, i}
                                                    {@const hourData = speedProfileHours.find((h) => h.hour === i)}
                                                    {@const val = hourData?.commercial_speed_avg}
                                                    <td
                                                        class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                                        title="{i}:00 avg speed"
                                                    >
                                                        {val != null && !isNaN(Number(val))
                                                            ? Number(val).toFixed(1)
                                                            : "-"}
                                                    </td>
                                                {/each}
                                            </tr>

                                            <!-- Median Speed -->
                                            <tr>
                                                <th
                                                    class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                                >
                                                    Median speed (km/h)
                                                </th>
                                                {#each Array(24) as _, i}
                                                    {@const hourData = speedProfileHours.find((h) => h.hour === i)}
                                                    {@const val = hourData?.commercial_speed_median}
                                                    <td
                                                        class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                                        title="{i}:00 median speed"
                                                    >
                                                        {val != null && !isNaN(Number(val))
                                                            ? Number(val).toFixed(1)
                                                            : "-"}
                                                    </td>
                                                {/each}
                                            </tr>

                                            <!-- P85 Speed -->
                                            <tr>
                                                <th
                                                    class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                                >
                                                    P85 speed (km/h)
                                                </th>
                                                {#each Array(24) as _, i}
                                                    {@const hourData = speedProfileHours.find((h) => h.hour === i)}
                                                    {@const val = hourData?.commercial_speed_p85}
                                                    <td
                                                        class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                                        title="{i}:00 p85 speed"
                                                    >
                                                        {val != null && !isNaN(Number(val))
                                                            ? Number(val).toFixed(1)
                                                            : "-"}
                                                    </td>
                                                {/each}
                                            </tr>

                                            <!-- Trips count -->
                                            <tr>
                                                <th
                                                    class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                                >
                                                    Trips sampled (nr.)
                                                </th>
                                                {#each Array(24) as _, i}
                                                    {@const hourData = speedProfileHours.find((h) => h.hour === i)}
                                                    {@const trips = hourData?.n_trips}
                                                    <td
                                                        class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                                        title="{i}:00 trips"
                                                    >
                                                        {trips != null ? trips : "-"}
                                                    </td>
                                                {/each}
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        {/if}

                        <!-- Hourly Disturbance Index Chart -->
                        {#if speedProfileHours.some((h) => h.disturbance_index != null)}
                            <div
                                class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                            >
                                <h6
                                    class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                >
                                    <i class="fas fa-wave-square" style="color: {shapeColor}"></i>
                                    Disturbance Index per Hour
                                </h6>
                                <p class="text-[10px] text-muted-foreground">
                                    Relative difference from baseline (positive: faster, negative: slower).
                                </p>

                                <!-- Diverging bar chart (positive values go up, negative values go down) -->
                                <div
                                    class="flex items-center gap-[2px] h-28 border-l border-b border-muted-foreground/30 px-1 relative bg-muted/10 rounded-sm"
                                >
                                    <!-- Center dashed zero baseline -->
                                    <div
                                        class="absolute left-0 right-0 top-1/2 -translate-y-1/2 border-t border-dashed border-muted-foreground/40 pointer-events-none z-0"
                                    ></div>
                                    <span
                                        class="absolute right-1 top-1/2 -translate-y-1/2 text-[8px] font-mono text-muted-foreground/50 pointer-events-none select-none z-0"
                                    >
                                        0%
                                    </span>

                                    {#each Array(24) as _, i}
                                        {@const hourData = speedProfileHours.find(
                                            (h) => h.hour === i,
                                        )}
                                        {@const di = hourData?.disturbance_index}
                                        <div
                                            class="flex-1 h-full flex flex-col relative group z-10"
                                        >
                                            <!-- Top half: positive values (faster than baseline) -->
                                            <div
                                                class="flex-1 flex items-end justify-center"
                                            >
                                                {#if di != null && di > 0}
                                                    {@const cat =
                                                        getDisturbanceIndexCategory(
                                                            di,
                                                            di_threshold_low,
                                                            di_threshold_high,
                                                        )}
                                                    {@const barHeight = Math.min(
                                                        Math.max(
                                                            (di / maxAbsDi) * 100,
                                                            5,
                                                        ),
                                                        100,
                                                    )}
                                                    <div
                                                        class="w-full rounded-t-[1px] transition-all group-hover:brightness-110"
                                                        style="height: {barHeight}%; background-color: {cat.color};"
                                                    ></div>
                                                {/if}
                                            </div>

                                            <!-- Bottom half: negative values (slower than baseline) -->
                                            <div
                                                class="flex-1 flex items-start justify-center"
                                            >
                                                {#if di != null && di < 0}
                                                    {@const cat =
                                                        getDisturbanceIndexCategory(
                                                            di,
                                                            di_threshold_low,
                                                            di_threshold_high,
                                                        )}
                                                    {@const barHeight = Math.min(
                                                        Math.max(
                                                            (Math.abs(di) / maxAbsDi) * 100,
                                                            5,
                                                        ),
                                                        100,
                                                    )}
                                                    <div
                                                        class="w-full rounded-b-[1px] transition-all group-hover:brightness-110"
                                                        style="height: {barHeight}%; background-color: {cat.color};"
                                                    ></div>
                                                {/if}
                                            </div>

                                            <!-- Tooltip on hover -->
                                            {#if di != null}
                                                {@const cat =
                                                    getDisturbanceIndexCategory(
                                                        di,
                                                        di_threshold_low,
                                                        di_threshold_high,
                                                    )}
                                                <div
                                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-30 shadow-md"
                                                >
                                                    {i}:00: {di > 0 ? "+" : ""}{(
                                                        di * 100
                                                    ).toFixed(1)}% ({cat.label})
                                                </div>
                                            {/if}
                                        </div>
                                    {/each}
                                </div>

                                <div
                                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter mt-1"
                                >
                                    <span>0h</span>
                                    <span>6h</span>
                                    <span>12h</span>
                                    <span>18h</span>
                                    <span>23h</span>
                                </div>

                                <!-- Category legend chips -->
                                <div
                                    class="flex flex-wrap items-center justify-between gap-1 pt-1 border-t border-border/40 text-[9px]"
                                >
                                    {#each getDisturbanceIndexCategories(di_threshold_low, di_threshold_high) as cat}
                                        <div class="flex items-center gap-1">
                                            <span
                                                class="w-2 h-2 rounded-xs inline-block"
                                                style="background-color: {cat.color}"
                                            ></span>
                                            <span class="text-muted-foreground"
                                                >{cat.label}</span
                                            >
                                        </div>
                                    {/each}
                                </div>
                            </div>
                        {/if}
                    </Accordion.Content>
                </Accordion.Item>
            {/if}
        </Accordion.Root>
    </div>
{/if}
