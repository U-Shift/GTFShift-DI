<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import {
        getColorFromGradient,
        getDisturbanceIndex,
        getDisturbanceIndexCategory,
        DISTURBANCE_INDEX_CATEGORIES,
    } from "$lib/utils.js";
    import { COLOR_GRADIENT, COLOR_GRADIENT_RED, COLOR_TEAL } from "../data.js";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";

    let {
        selectedWayId = $bindable(),
        selected_shape_id = $bindable(),
        geoData,
        criteria_hour,
        display_rt,
    }: {
        selectedWayId: string | undefined;
        selected_shape_id: string | undefined;
        geoData: GeoPrioritisation | null;
        criteria_hour: number;
        display_rt: boolean;
    } = $props();
</script>

<!-- Right Details Panel -->
{#if selectedWayId && geoData && geoData.wayData[selectedWayId]}
    {@const way = geoData.wayData[selectedWayId]}
    <div
        id="details-panel"
        class="absolute top-4 left-4 right-4 sm:left-auto sm:right-4 z-[1010] flex flex-col w-[calc(100vw-2rem)] sm:w-[400px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-6 overflow-y-auto"
    >
        <div class="flex items-center justify-between mb-6">
            <h3 class="text-xl font-bold text-primary m-0">Way Details</h3>
            <Button
                variant="ghost"
                size="icon"
                onclick={() => (selectedWayId = undefined)}
                class="rounded-full"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <div class="space-y-6 flex-1">
            <section>
                <div class="flex items-center gap-2 mb-2">
                    <span
                        class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                        >OSM ID</span
                    >
                    <a
                        href="https://www.openstreetmap.org/way/{selectedWayId}"
                        target="_blank"
                        class="text-xs font-mono text-blue-500 hover:underline"
                    >
                        {selectedWayId}
                        <i class="fas fa-external-link-alt ml-1"></i>
                    </a>
                </div>
                <h4 class="text-lg font-semibold">
                    {way.name && typeof way.name === "string"
                        ? way.name
                        : "Unnamed Way"}
                </h4>
            </section>

            <div class="grid grid-cols-2 gap-3">
                <!-- Disturbance Index Card -->
                {#if display_rt}
                    <div
                        class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                    >
                        {#if true}
                            {@const di = getDisturbanceIndex(way, criteria_hour)}
                            {@const cat = di != null ? getDisturbanceIndexCategory(di) : null}
                            <p
                                class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Disturbance Index ({criteria_hour}:00)
                            </p>
                            <p class="text-lg font-bold">
                                {#if di != null}
                                    {di > 0 ? "+" : ""}{(di * 100).toFixed(1)}<span class="text-[10px] font-normal">%</span>
                                {:else}
                                    N/A
                                {/if}
                            </p>
                            <p class="text-[10px] text-muted-foreground truncate">
                                {cat ? cat.label : "Relative to P75 speed"}
                            </p>
                            {#if cat}
                                <div
                                    class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                    style="background-color: {cat.color}"
                                ></div>
                            {/if}
                        {/if}
                    </div>
                {/if}

                <!-- Bus Frequency Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    {#if true}
                        {@const freq = way.hour_frequency?.[criteria_hour] ?? 0}
                        {@const freqCensus =
                            geoData.metadata.data_census.frequency_hour[
                                criteria_hour
                            ]}
                        {@const freqColor = freqCensus
                            ? getColorFromGradient(
                                  freq,
                                  freqCensus.p5,
                                  freqCensus.p95,
                                  COLOR_GRADIENT,
                              )
                            : null}
                        <p
                            class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Buses/h ({criteria_hour}:00)
                        </p>
                        <p class="text-lg font-bold">
                            {freq}
                        </p>
                        {#if freqColor}
                            <div
                                class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                style="background-color: {freqColor}"
                            ></div>
                        {/if}
                    {/if}
                </div>

                <!-- Bus Lane Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    <p
                        class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                    >
                        Bus Lane
                    </p>
                    <p class="text-sm font-bold">
                        {way.is_bus_lane ? "Yes" : "No"}
                    </p>
                    {#if way.is_bus_lane}
                        <div
                            class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                            style="background-color: {COLOR_TEAL}"
                        ></div>
                    {/if}
                </div>

                <!-- Lanes/Direction Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    {#if true}
                        {@const lanesDir =
                            way.n_lanes_circulation_direction ?? 0}
                        {@const lanesCensus =
                            geoData.metadata.data_census.lanes_length}
                        {@const lanesColor = lanesCensus
                            ? getColorFromGradient(
                                  lanesDir,
                                  lanesCensus.p5,
                                  lanesCensus.p95,
                                  COLOR_GRADIENT,
                              )
                            : null}
                        <p
                            class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Lanes/Dir
                        </p>
                        <p class="text-lg font-bold">
                            {lanesDir || "N/A"}
                        </p>
                        {#if lanesColor}
                            <div
                                class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                style="background-color: {lanesColor}"
                            ></div>
                        {/if}
                    {/if}
                </div>

                <!-- Demand Card -->
                {#if way.demand != null}
                    <div
                        class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                    >
                        {#if true}
                            {@const demand = Number(way.demand)}
                            {@const demandCensus =
                                geoData.metadata.data_census.demand_length}
                            {@const demandColor = demandCensus
                                ? getColorFromGradient(
                                      demand,
                                      demandCensus.p5,
                                      demandCensus.p95,
                                      COLOR_GRADIENT,
                                  )
                                : null}
                            <p
                                class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Demand
                            </p>
                            <p class="text-lg font-bold leading-tight">
                                {Math.round(demand).toLocaleString()}
                            </p>
                            <p class="text-[10px] text-muted-foreground">
                                passengers/day
                            </p>
                            {#if demandColor}
                                <div
                                    class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                    style="background-color: {demandColor}"
                                ></div>
                            {/if}
                        {/if}
                    </div>
                {/if}

                <!-- Speed Card (100% width with 3 metrics) -->
                {#if way.speed_avg != null || way.speed_median != null || way.speed_p75 != null}
                    <div
                        class="col-span-2 p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                    >
                        {#if true}
                            {@const speedCensus =
                                geoData.metadata.data_census.speed_avg_length}
                            {@const avgColor =
                                speedCensus && way.speed_avg != null
                                    ? getColorFromGradient(
                                          way.speed_avg,
                                          speedCensus.p5,
                                          speedCensus.p95,
                                          COLOR_GRADIENT_RED.slice().reverse(),
                                      )
                                    : null}
                            {@const medianColor =
                                speedCensus && way.speed_median != null
                                    ? getColorFromGradient(
                                          way.speed_median,
                                          speedCensus.p5,
                                          speedCensus.p95,
                                          COLOR_GRADIENT_RED.slice().reverse(),
                                      )
                                    : null}
                            {@const p75Color =
                                speedCensus && way.speed_p75 != null
                                    ? getColorFromGradient(
                                          way.speed_p75,
                                          speedCensus.p5,
                                          speedCensus.p95,
                                          COLOR_GRADIENT_RED.slice().reverse(),
                                      )
                                    : null}
                            <div class="flex items-center justify-between mb-2">
                                <p
                                    class="text-[10px] font-bold uppercase text-muted-foreground"
                                >
                                    Speed <span
                                        class="text-[9px] font-normal normal-case"
                                        >(km/h)</span
                                    >
                                </p>
                                <p class="text-[10px] text-muted-foreground">
                                    Whole RT collection interval
                                </p>
                            </div>

                            <div class="grid grid-cols-3 gap-2">
                                <div
                                    class="bg-background/50 rounded-lg p-2 border border-border/30 relative overflow-hidden"
                                >
                                    <p
                                        class="text-[10px] font-medium text-muted-foreground mb-0.5"
                                    >
                                        Average
                                    </p>
                                    <p class="text-base font-bold">
                                        {way.speed_avg != null
                                            ? typeof way.speed_avg === "number"
                                                ? way.speed_avg.toFixed(1)
                                                : Number(way.speed_avg).toFixed(
                                                      1,
                                                  )
                                            : "-"}
                                        <span
                                            class="text-[9px] font-normal text-muted-foreground"
                                            >km/h</span
                                        >
                                    </p>
                                    {#if avgColor}
                                        <div
                                            class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                            style="background-color: {avgColor}"
                                        ></div>
                                    {/if}
                                </div>

                                <div
                                    class="bg-background/50 rounded-lg p-2 border border-border/30 relative overflow-hidden"
                                >
                                    <p
                                        class="text-[10px] font-medium text-muted-foreground mb-0.5"
                                    >
                                        Median
                                    </p>
                                    <p class="text-base font-bold">
                                        {way.speed_median != null
                                            ? typeof way.speed_median ===
                                              "number"
                                                ? way.speed_median.toFixed(1)
                                                : Number(
                                                      way.speed_median,
                                                  ).toFixed(1)
                                            : "-"}
                                        <span
                                            class="text-[9px] font-normal text-muted-foreground"
                                            >km/h</span
                                        >
                                    </p>
                                    {#if medianColor}
                                        <div
                                            class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                            style="background-color: {medianColor}"
                                        ></div>
                                    {/if}
                                </div>

                                <div
                                    class="bg-background/50 rounded-lg p-2 border border-border/30 relative overflow-hidden"
                                >
                                    <p
                                        class="text-[10px] font-medium text-muted-foreground mb-0.5"
                                    >
                                        P75
                                    </p>
                                    <p class="text-base font-bold">
                                        {way.speed_p75 != null
                                            ? typeof way.speed_p75 === "number"
                                                ? way.speed_p75.toFixed(1)
                                                : Number(way.speed_p75).toFixed(
                                                      1,
                                                  )
                                            : "-"}
                                        <span
                                            class="text-[9px] font-normal text-muted-foreground"
                                            >km/h</span
                                        >
                                    </p>
                                    {#if p75Color}
                                        <div
                                            class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                            style="background-color: {p75Color}"
                                        ></div>
                                    {/if}
                                </div>
                            </div>
                        {/if}
                    </div>
                {/if}

                <!-- Total Lanes Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Total Lanes
                    </p>
                    <p class="text-xs font-medium text-muted-foreground">
                        <span class="text-foreground">
                            {way.n_lanes_circulation ?? 0}
                            <span class="text-[9px] text-muted-foreground"
                                >circulation</span
                            >
                            + {way.n_lanes_parking ?? 0}
                            <span class="text-[9px] text-muted-foreground"
                                >parking</span
                            >
                        </span>
                    </p>
                </div>

                <!-- Directions Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Nr Directions
                    </p>
                    <p class="text-xs font-medium text-foreground">
                        {way.n_directions ?? "N/A"}
                    </p>
                </div>

                <!-- Extension Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Extension
                    </p>
                    <p class="text-xs font-medium text-foreground">
                        {typeof way.length_m === "number"
                            ? way.length_m.toFixed(1)
                            : way.length_m != null
                              ? Number(way.length_m).toFixed(1)
                              : "-"}
                        <span class="text-[9px] text-muted-foreground"
                            >meters</span
                        >
                    </p>
                </div>

                <!-- Speed count -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Speed count
                    </p>
                    <p class="text-xs font-medium text-foreground">
                        {way.speed_count ?? 0}
                        <span class="text-[9px] text-muted-foreground"
                            >measurements</span
                        >
                    </p>
                </div>
            </div>

            {#if way.shapes && way.shapes.length > 0}
                <section class="space-y-3">
                    <h5 class="text-sm font-bold border-b pb-1">
                        Associated Routes
                    </h5>
                    <div class="flex flex-wrap gap-2">
                        {#each way.shapes as shape_id}
                            {@const route = geoData.shapes[shape_id]}
                            {@const routeColor = route?.route_color
                                ? `${route.route_color}`
                                : null}
                            <Tooltip.Provider delayDuration={0}>
                                <Tooltip.Root>
                                    <Tooltip.Trigger>
                                        {#snippet child({ props })}
                                            <button
                                                {...props}
                                                onclick={() => {
                                                    selected_shape_id =
                                                        shape_id;
                                                    selectedWayId = undefined;
                                                }}
                                                class="px-2 py-1 text-[10px] font-bold rounded border cursor-pointer hover:brightness-90 transition-all text-left"
                                                style={routeColor
                                                    ? `background-color: ${routeColor}22; border-color: ${routeColor}44; color: ${routeColor};`
                                                    : ""}
                                            >
                                                {route?.route_short_name ||
                                                    shape_id}
                                            </button>
                                        {/snippet}
                                    </Tooltip.Trigger>
                                    <Tooltip.Content class="z-[1100]">
                                        <p>
                                            {route?.route_short_name}: {route?.route_long_name}
                                            ({route?.direction_id
                                                ? "DESC"
                                                : "ASC"})
                                        </p>
                                    </Tooltip.Content>
                                </Tooltip.Root>
                            </Tooltip.Provider>
                        {/each}
                    </div>
                </section>
            {/if}

            <!-- 24h Disturbance Index Section -->
            {#if display_rt && way.speed_p75 != null && way.hour_speed_median && Object.values(way.hour_speed_median)?.some((v) => v != null)}
                {@const hourDis = Array.from({ length: 24 }, (_, i) => getDisturbanceIndex(way, i))}
                {@const validDis = hourDis.filter((v) => v != null) as number[]}
                {@const maxAbsDi = Math.max(0.25, ...validDis.map((v) => Math.abs(v)))}
                {@const currentHourDi = getDisturbanceIndex(way, criteria_hour)}
                <section
                    class="space-y-3 p-4 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
                >
                    <div class="flex items-center justify-between">
                        <h5 class="text-sm font-bold flex items-center gap-2">
                            <i class="fas fa-gauge-high text-primary/70"></i>
                            24h Disturbance Index
                        </h5>
                        {#if currentHourDi != null}
                            {@const cat = getDisturbanceIndexCategory(currentHourDi)}
                            <span
                                class="text-[10px] font-mono font-bold px-2 py-0.5 rounded text-white shadow-xs"
                                style="background-color: {cat.color};"
                                title="DI at {criteria_hour}:00 ({cat.label})"
                            >
                                {criteria_hour}:00 {currentHourDi > 0 ? "+" : ""}{(currentHourDi * 100).toFixed(1)}%
                            </span>
                        {/if}
                    </div>

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
                            {@const di = hourDis[i]}
                            {@const isSelectedHour = i === criteria_hour}
                            <div
                                class="flex-1 h-full flex flex-col relative group z-10 {isSelectedHour ? 'bg-primary/5 rounded-sm' : ''}"
                            >
                                <!-- Top half: positive values (faster than baseline) -->
                                <div class="flex-1 flex items-end justify-center">
                                    {#if di != null && di > 0}
                                        {@const cat = getDisturbanceIndexCategory(di)}
                                        {@const barHeight = Math.min(Math.max((di / maxAbsDi) * 100, 5), 100)}
                                        <div
                                            class="w-full rounded-t-[1px] transition-all group-hover:brightness-110"
                                            style="height: {barHeight}%; background-color: {cat.color};"
                                        ></div>
                                    {/if}
                                </div>

                                <!-- Bottom half: negative values (slower than baseline) -->
                                <div class="flex-1 flex items-start justify-center">
                                    {#if di != null && di < 0}
                                        {@const cat = getDisturbanceIndexCategory(di)}
                                        {@const barHeight = Math.min(Math.max((Math.abs(di) / maxAbsDi) * 100, 5), 100)}
                                        <div
                                            class="w-full rounded-b-[1px] transition-all group-hover:brightness-110"
                                            style="height: {barHeight}%; background-color: {cat.color};"
                                        ></div>
                                    {/if}
                                </div>

                                <!-- Tooltip on hover -->
                                <div
                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-30 shadow-md"
                                >
                                    {#if di != null}
                                        {@const cat = getDisturbanceIndexCategory(di)}
                                        {i}:00: {di > 0 ? "+" : ""}{(di * 100).toFixed(1)}% ({cat.label})
                                    {:else}
                                        {i}:00: no data
                                    {/if}
                                </div>
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
                    <div class="flex flex-wrap items-center justify-between gap-1 pt-1 border-t border-border/40 text-[9px]">
                        {#each DISTURBANCE_INDEX_CATEGORIES as cat}
                            <div class="flex items-center gap-1">
                                <span class="w-2 h-2 rounded-xs inline-block" style="background-color: {cat.color}"></span>
                                <span class="text-muted-foreground">{cat.label}</span>
                            </div>
                        {/each}
                    </div>

                    <!-- Hourly table -->
                    <div class="overflow-x-auto pt-1">
                        <table
                            class="w-full min-w-[860px] border-separate border-spacing-x-[2px] border-spacing-y-1"
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
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                    >
                                        Disturbance Index
                                    </th>
                                    {#each Array(24) as _, i}
                                        {@const di = hourDis[i]}
                                        <td
                                            class="text-[10px] font-mono font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30 {i === criteria_hour ? 'ring-1 ring-primary font-bold' : ''}"
                                            title="{i}:00 DI"
                                        >
                                            {#if di != null}
                                                {@const cat = getDisturbanceIndexCategory(di)}
                                                <span style="color: {cat.color};">
                                                    {di > 0 ? "+" : ""}{(di * 100).toFixed(0)}%
                                                </span>
                                            {:else}
                                                <span class="text-muted-foreground/60">-</span>
                                            {/if}
                                        </td>
                                    {/each}
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </section>
            {/if}

            <section
                class="space-y-3 p-4 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
            >
                <h5 class="text-sm font-bold flex items-center gap-2">
                    <i class="fas fa-chart-bar text-primary/70"></i>
                    24h Transit Frequency
                </h5>
                <div
                    class="flex items-end gap-[2px] h-24 pt-2 border-l border-b border-muted-foreground/30 px-1"
                >
                    {#each Array(24) as _, i}
                        {@const freq = way.hour_frequency?.[i] || 0}
                        {@const maxFreq =
                            Math.max(
                                ...(Object.values(
                                    way.hour_frequency || { 0: 1 },
                                ) as number[]),
                            ) || 1}
                        {@const height = Math.max((freq / maxFreq) * 100, 2)}
                        {@const hourFreqCensus =
                            geoData.metadata.data_census.frequency_hour[i]}
                        {@const barColor = hourFreqCensus
                            ? getColorFromGradient(
                                  freq,
                                  hourFreqCensus.p5,
                                  hourFreqCensus.p95,
                                  COLOR_GRADIENT,
                              )
                            : "var(--primary)"}
                        <div
                            class="flex-1 transition-colors rounded-t-[1px] relative group"
                            style="height: {height}%; background-color: {barColor}88;"
                            title="{i}:00 - {freq} buses"
                        >
                            <div
                                class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                            >
                                {i}:00: {freq} buses
                            </div>
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
            </section>

            {#if display_rt && ((way.hour_speed_avg && Object.values(way.hour_speed_avg)?.some((v) => v != null)) || (way.hour_speed_median && Object.values(way.hour_speed_median)?.some((v) => v != null)) || (way.hour_speed_p75 && Object.values(way.hour_speed_p75)?.some((v) => v != null)))}
                <section
                    class="space-y-3 p-4 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
                >
                    <h5 class="text-sm font-bold flex items-center gap-2">
                        <i class="fas fa-chart-bar text-primary/70"></i>
                        24h Speed
                    </h5>
                    <div
                        class="flex items-end gap-[2px] h-24 pt-2 border-l border-b border-muted-foreground/30 px-1"
                    >
                        {#each Array(24) as _, i}
                            {@const avg_speed = way.hour_speed_avg?.[i] || 0}
                            {@const maxSpeed =
                                Math.max(
                                    ...(Object.values(
                                        way.hour_speed_avg || { 0: 1 },
                                    ) as number[]),
                                ) || 1}
                            {@const height = Math.max(
                                (avg_speed / maxSpeed) * 100,
                                2,
                            )}
                            {@const hourFreqCensus =
                                geoData.metadata.data_census.frequency_hour[i]}
                            {@const barColor = hourFreqCensus
                                ? getColorFromGradient(
                                      avg_speed,
                                      hourFreqCensus.p5,
                                      hourFreqCensus.p95,
                                      COLOR_GRADIENT_RED.slice().reverse(),
                                  )
                                : "var(--primary)"}
                            <div
                                class="flex-1 transition-colors rounded-t-[1px] relative group"
                                style="height: {height}%; background-color: {barColor}88;"
                                title="{i}:00 - {avg_speed} km/h"
                            >
                                <div
                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                >
                                    {i}:00: {avg_speed} km/h
                                </div>
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

                    <div class="overflow-x-auto pt-1">
                        <table
                            class="w-full min-w-[860px] border-separate border-spacing-x-[2px] border-spacing-y-1"
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
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                    >
                                        Average speed (km/h)
                                    </th>
                                    {#each Array(24) as _, i}
                                        {@const avgSpeed =
                                            way.hour_speed_avg?.[i]}
                                        <td
                                            class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                            title="{i}:00 hour_speed_avg"
                                        >
                                            {avgSpeed == null ||
                                            typeof avgSpeed !== "number"
                                                ? avgSpeed != null &&
                                                  !isNaN(Number(avgSpeed))
                                                    ? Number(avgSpeed).toFixed(
                                                          1,
                                                      )
                                                    : "-"
                                                : avgSpeed.toFixed(1)}
                                        </td>
                                    {/each}
                                </tr>
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                    >
                                        Median speed (km/h)
                                    </th>
                                    {#each Array(24) as _, i}
                                        {@const medianSpeed =
                                            way.hour_speed_median?.[i]}
                                        <td
                                            class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                            title="{i}:00 hour_speed_median"
                                        >
                                            {medianSpeed == null ||
                                            typeof medianSpeed !== "number"
                                                ? medianSpeed != null &&
                                                  !isNaN(Number(medianSpeed))
                                                    ? Number(
                                                          medianSpeed,
                                                      ).toFixed(1)
                                                    : "-"
                                                : medianSpeed.toFixed(1)}
                                        </td>
                                    {/each}
                                </tr>
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                    >
                                        P75 speed (km/h)
                                    </th>
                                    {#each Array(24) as _, i}
                                        {@const p75Speed =
                                            way.hour_speed_p75?.[i]}
                                        <td
                                            class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                            title="{i}:00 hour_speed_p75"
                                        >
                                            {p75Speed == null ||
                                            typeof p75Speed !== "number"
                                                ? p75Speed != null &&
                                                  !isNaN(Number(p75Speed))
                                                    ? Number(p75Speed).toFixed(
                                                          1,
                                                      )
                                                    : "-"
                                                : p75Speed.toFixed(1)}
                                        </td>
                                    {/each}
                                </tr>
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap"
                                    >
                                        Speed count (nr.)
                                    </th>
                                    {#each Array(24) as _, i}
                                        {@const speedCount =
                                            way.hour_speed_count?.[i]}
                                        <td
                                            class="text-[10px] font-medium text-center px-1 py-1 rounded bg-background/70 border border-border/30"
                                            title="{i}:00 hour_speed_count"
                                        >
                                            {speedCount == null
                                                ? "-"
                                                : speedCount}
                                        </td>
                                    {/each}
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </section>
            {/if}
        </div>
    </div>
{/if}
