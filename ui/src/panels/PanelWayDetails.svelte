<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import { Input } from "$lib/components/ui/input/index.js";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import * as Accordion from "$lib/components/ui/accordion/index.js";
    import {
        getColorFromGradient,
        getDisturbanceIndex,
        getDisturbanceIndexCategory,
        getDisturbanceIndexCategories,
    } from "$lib/utils.js";
    import { COLOR_GRADIENT, COLOR_GRADIENT_RED, COLOR_TEAL } from "../data.js";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";

    let {
        selectedWayId = $bindable(),
        selected_shape_id = $bindable(),
        isExpanded = $bindable(false),
        geoData,
        criteria_hour,
        display_rt,
        di_threshold_low = 0.05,
        di_threshold_high = 0.2,
    }: {
        selectedWayId: string | undefined;
        selected_shape_id: string | undefined;
        isExpanded?: boolean;
        geoData: GeoPrioritisation | null;
        criteria_hour: number;
        display_rt: boolean;
        di_threshold_low?: number;
        di_threshold_high?: number;
    } = $props();

    let copied = $state(false);
    let routeSearchQuery = $state("");
    let openAccordionSections = $state<string[]>(["overview", "speed-di"]);

    const allSectionKeys = [
        "overview",
        "speed-di",
        "hourly-variations",
        "routes",
    ];

    function toggleAllSections() {
        if (openAccordionSections.length === allSectionKeys.length) {
            openAccordionSections = ["overview"];
        } else {
            openAccordionSections = [...allSectionKeys];
        }
    }

    function copyWayId(id?: string) {
        if (!id || !navigator?.clipboard) return;
        navigator.clipboard.writeText(id);
        copied = true;
        setTimeout(() => {
            copied = false;
        }, 1500);
    }

    $effect(() => {
        if (!selectedWayId) {
            isExpanded = false;
        }
    });

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === "Escape" && isExpanded) {
            isExpanded = false;
        }
    }
</script>

<svelte:window onkeydown={handleKeyDown} />

<!-- Right Details Panel -->
{#if selectedWayId && geoData && geoData.wayData[selectedWayId]}
    {@const way = geoData.wayData[selectedWayId]}
    {@const wayName =
        way.name && typeof way.name === "string"
            ? way.name
            : "Unnamed Road Segment"}
    {@const hKey = criteria_hour}
    {@const hStr = String(criteria_hour)}
    {@const hourSpeedAvg =
        way.hour_speed_avg?.[hKey] ?? way.hour_speed_avg?.[hStr]}
    {@const hourSpeedMedian =
        way.hour_speed_median?.[hKey] ?? way.hour_speed_median?.[hStr]}
    {@const hourSpeedP85 =
        way.hour_speed_p85?.[hKey] ?? way.hour_speed_p85?.[hStr]}
    {@const currentHourDi = getDisturbanceIndex(way, criteria_hour)}
    {@const currentHourDiCat =
        currentHourDi != null
            ? getDisturbanceIndexCategory(
                  currentHourDi,
                  di_threshold_low,
                  di_threshold_high,
              )
            : null}
    {@const hasAssociatedRoutes = way.shapes && way.shapes.length > 0}
    {@const freq = way.hour_frequency?.[criteria_hour] ?? 0}
    {@const freqCensus =
        geoData.metadata?.data_census?.frequency_hour?.[criteria_hour]}
    {@const freqColor = freqCensus
        ? getColorFromGradient(
              freq,
              freqCensus.p5,
              freqCensus.p95,
              COLOR_GRADIENT,
          )
        : null}
    {@const lanesDir = way.n_lanes_circulation_direction ?? 0}
    {@const lanesCensus = geoData.metadata?.data_census?.lanes_length}
    {@const lanesColor = lanesCensus
        ? getColorFromGradient(
              lanesDir,
              lanesCensus.p5,
              lanesCensus.p95,
              COLOR_GRADIENT,
          )
        : null}
    {@const demand = way.demand != null ? Number(way.demand) : NaN}
    {@const demandCensus = geoData.metadata?.data_census?.demand_length}
    {@const demandColor =
        demandCensus && !Number.isNaN(demand)
            ? getColorFromGradient(
                  demand,
                  demandCensus.p5,
                  demandCensus.p95,
                  COLOR_GRADIENT,
              )
            : null}
    {@const censusAvg =
        geoData.metadata?.data_census?.speed_avg_hour_length?.[hKey] ??
        geoData.metadata?.data_census?.speed_avg_length}
    {@const hourlyAvgColor =
        censusAvg && hourSpeedAvg != null
            ? getColorFromGradient(
                  Number(hourSpeedAvg),
                  censusAvg.p5,
                  censusAvg.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const censusMedian =
        geoData.metadata?.data_census?.speed_median_hour_length?.[hKey] ??
        geoData.metadata?.data_census?.speed_median_length}
    {@const hourlyMedianColor =
        censusMedian && hourSpeedMedian != null
            ? getColorFromGradient(
                  Number(hourSpeedMedian),
                  censusMedian.p5,
                  censusMedian.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const censusP85 =
        geoData.metadata?.data_census?.speed_p85_hour_length?.[hKey] ??
        geoData.metadata?.data_census?.speed_p85_length}
    {@const hourlyP85Color =
        censusP85 && hourSpeedP85 != null
            ? getColorFromGradient(
                  Number(hourSpeedP85),
                  censusP85.p5,
                  censusP85.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const speedCensusAvg = geoData.metadata?.data_census?.speed_avg_length}
    {@const allDayAvgColor =
        speedCensusAvg && way.speed_avg != null
            ? getColorFromGradient(
                  way.speed_avg,
                  speedCensusAvg.p5,
                  speedCensusAvg.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const speedCensusMedian =
        geoData.metadata?.data_census?.speed_median_length}
    {@const allDayMedianColor =
        speedCensusMedian && way.speed_median != null
            ? getColorFromGradient(
                  way.speed_median,
                  speedCensusMedian.p5,
                  speedCensusMedian.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const speedCensusP85 = geoData.metadata?.data_census?.speed_p85_length}
    {@const allDayP85Color =
        speedCensusP85 && way.speed_p85 != null
            ? getColorFromGradient(
                  way.speed_p85,
                  speedCensusP85.p5,
                  speedCensusP85.p95,
                  COLOR_GRADIENT_RED.slice().reverse(),
              )
            : null}
    {@const hourDis = Array.from({ length: 24 }, (_, i) =>
        getDisturbanceIndex(way, i),
    )}
    {@const maxAbsDi = Math.max(
        0.25,
        ...(hourDis.filter((v) => v != null) as number[]).map((v) =>
            Math.abs(v),
        ),
    )}

    {#if isExpanded}
        <!-- Backdrop: blur behind just like ModalData -->
        <div
            class="fixed inset-0 z-[1040] bg-black/20 backdrop-blur-[1px]"
            onclick={() => (isExpanded = false)}
            role="presentation"
        ></div>
    {/if}

    <div
        id="details-panel"
        class={isExpanded
            ? "fixed top-4 left-4 right-4 sm:left-[calc(1rem+350px+0.5rem)] sm:right-4 z-[1050] flex flex-col h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-xl border p-5 overflow-y-auto gap-4"
            : "absolute top-4 left-4 right-4 sm:left-auto sm:right-4 z-[1010] flex flex-col w-[calc(100vw-2rem)] sm:w-[380px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-5 overflow-y-auto gap-4"}
    >
        <div class="w-full flex flex-col gap-4">
            <!-- Header -->
            <div
                class="flex items-start justify-between gap-3 border-b border-border/40 pb-3"
            >
                <div class="min-w-0 space-y-1">
                    <div class="flex items-center gap-2">
                        {#if isExpanded}
                            <span
                                class="px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wider bg-primary/10 text-primary rounded-full"
                            >
                                Extended View
                            </span>
                        {/if}
                    </div>

                    <h3
                        class="{isExpanded
                            ? 'text-xl sm:text-2xl'
                            : 'text-base'} font-bold text-foreground leading-snug truncate"
                        title={wayName}
                    >
                        {wayName}
                    </h3>

                    <div
                        class="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] text-muted-foreground font-mono"
                    >
                        <div class="flex items-center gap-1">
                            <span>OSM ID:</span>
                            <a
                                href="https://www.openstreetmap.org/way/{selectedWayId}"
                                target="_blank"
                                class="text-blue-500 hover:underline inline-flex items-center gap-0.5"
                                title="Open in OpenStreetMap"
                            >
                                <span>{selectedWayId}</span>
                                <i class="fas fa-external-link-alt text-[9px]"
                                ></i>
                            </a>
                            <button
                                type="button"
                                class="text-muted-foreground hover:text-foreground p-0.5 rounded transition-colors cursor-pointer"
                                onclick={() => copyWayId(selectedWayId)}
                                title="Copy OSM ID"
                            >
                                {#if copied}
                                    <i
                                        class="fas fa-check text-emerald-500 text-[10px]"
                                    ></i>
                                {:else}
                                    <i class="fas fa-copy text-[10px]"></i>
                                {/if}
                            </button>
                        </div>
                    </div>
                </div>

                <div class="flex items-center gap-1.5 shrink-0">
                    {#if isExpanded}
                        <Button
                            variant="outline"
                            size="sm"
                            onclick={toggleAllSections}
                            class="h-8 text-xs gap-1.5 text-muted-foreground hover:text-foreground hidden sm:flex cursor-pointer"
                            title={openAccordionSections.length ===
                            allSectionKeys.length
                                ? "Collapse all sections"
                                : "Expand all sections"}
                        >
                            <i
                                class="fas {openAccordionSections.length ===
                                allSectionKeys.length
                                    ? 'fa-compress'
                                    : 'fa-expand'} text-[10px]"
                            ></i>
                            <span
                                >{openAccordionSections.length ===
                                allSectionKeys.length
                                    ? "Collapse Sections"
                                    : "Expand All Sections"}</span
                            >
                        </Button>
                    {/if}
                    <Button
                        variant="ghost"
                        size="icon"
                        onclick={() => (isExpanded = !isExpanded)}
                        class="rounded-full shrink-0 h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-muted cursor-pointer"
                        title={isExpanded
                            ? "Collapse way analysis"
                            : "Extend way analysis (widescreen)"}
                        aria-label={isExpanded
                            ? "Collapse way analysis"
                            : "Extend way analysis"}
                    >
                        <i
                            class="fas {isExpanded
                                ? 'fa-compress'
                                : 'fa-expand'} text-xs"
                        ></i>
                    </Button>
                    <Button
                        variant="ghost"
                        size="icon"
                        onclick={() => {
                            isExpanded = false;
                            selectedWayId = undefined;
                        }}
                        class="rounded-full shrink-0 h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-muted cursor-pointer"
                        title="Close"
                        aria-label="Close way analysis"
                    >
                        <i class="fas fa-times text-xs"></i>
                    </Button>
                </div>
            </div>

            <!-- Sections Accordion -->
            <Accordion.Root
                type="multiple"
                bind:value={openAccordionSections}
                class="w-full space-y-2"
            >
                <!-- Section 1: Overview & Physical Indicators -->
                <Accordion.Item
                    value="overview"
                    class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                >
                    <Accordion.Trigger class="py-3 hover:no-underline">
                        <div class="flex items-center gap-2 text-start">
                            <i class="fas fa-road text-xs text-muted-foreground"
                            ></i>
                            <span
                                class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                            >
                                Physical & Transit Overview
                            </span>
                        </div>
                    </Accordion.Trigger>
                    <Accordion.Content class="pt-1 pb-3 space-y-3">
                        <div
                            class="grid {isExpanded
                                ? 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-6'
                                : 'grid-cols-2 sm:grid-cols-3'} gap-2"
                        >
                            <!-- Transit Frequency -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1 truncate"
                                        title="Buses per hour at {criteria_hour}:00"
                                    >
                                        Buses/h ({criteria_hour}h)
                                    </p>
                                    <p class="text-sm font-bold">
                                        {freq}
                                    </p>
                                </div>
                                <p
                                    class="text-[9px] text-muted-foreground mt-0.5"
                                >
                                    frequency
                                </p>
                                {#if freqColor}
                                    <div
                                        class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                        style="background-color: {freqColor}"
                                    ></div>
                                {/if}
                            </div>

                            <!-- Bus Lane -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Bus Lane
                                    </p>
                                    <p
                                        class="text-sm font-bold {way.is_bus_lane
                                            ? 'text-teal-600 dark:text-teal-400'
                                            : ''}"
                                    >
                                        {way.is_bus_lane ? "Yes" : "No"}
                                    </p>
                                </div>
                                <p
                                    class="text-[9px] text-muted-foreground mt-0.5"
                                >
                                    dedicated
                                </p>
                                {#if way.is_bus_lane}
                                    <div
                                        class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                        style="background-color: {COLOR_TEAL}"
                                    ></div>
                                {/if}
                            </div>

                            <!-- Lanes / Direction -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Lanes/Dir
                                    </p>
                                    <p class="text-sm font-bold">
                                        {lanesDir || "N/A"}
                                    </p>
                                </div>
                                <p
                                    class="text-[9px] text-muted-foreground mt-0.5"
                                >
                                    circulation
                                </p>
                                {#if lanesColor}
                                    <div
                                        class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                        style="background-color: {lanesColor}"
                                    ></div>
                                {/if}
                            </div>

                            <!-- Demand -->
                            {#if !Number.isNaN(demand)}
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                >
                                    <div>
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Demand
                                        </p>
                                        <p
                                            class="text-sm font-bold leading-tight"
                                        >
                                            {Math.round(
                                                demand,
                                            ).toLocaleString()}
                                        </p>
                                    </div>
                                    <p
                                        class="text-[9px] text-muted-foreground mt-0.5"
                                    >
                                        pax/day
                                    </p>
                                    {#if demandColor}
                                        <div
                                            class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                            style="background-color: {demandColor}"
                                        ></div>
                                    {/if}
                                </div>
                            {/if}

                            <!-- Extension -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Extension
                                    </p>
                                    <p class="text-sm font-bold">
                                        {typeof way.length_m === "number"
                                            ? way.length_m.toFixed(1)
                                            : way.length_m != null
                                              ? Number(way.length_m).toFixed(1)
                                              : "-"}
                                        <span class="text-[9px] font-normal"
                                            >m</span
                                        >
                                    </p>
                                </div>
                                <p
                                    class="text-[9px] text-muted-foreground mt-0.5"
                                >
                                    segment length
                                </p>
                            </div>

                            <!-- Total Lanes Breakdown -->
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                    >
                                        Total Lanes
                                    </p>
                                    <p class="text-sm font-bold">
                                        {(way.n_lanes_circulation ?? 0) +
                                            (way.n_lanes_parking ?? 0)}
                                    </p>
                                </div>
                                <p
                                    class="text-[9px] text-muted-foreground mt-0.5"
                                    title="{way.n_lanes_circulation ??
                                        0} circulation + {way.n_lanes_parking ??
                                        0} parking"
                                >
                                    {way.n_lanes_circulation ?? 0}c + {way.n_lanes_parking ??
                                        0}p
                                </p>
                            </div>

                            <!-- Nr Directions -->
                            {#if way.n_directions != null}
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                >
                                    <div>
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Directions
                                        </p>
                                        <p class="text-sm font-bold">
                                            {way.n_directions}
                                        </p>
                                    </div>
                                    <p
                                        class="text-[9px] text-muted-foreground mt-0.5"
                                    >
                                        flow ways
                                    </p>
                                </div>
                            {/if}

                            <!-- Speed count -->
                            {#if way.speed_count != null}
                                <div
                                    class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                >
                                    <div>
                                        <p
                                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                        >
                                            Speed Count
                                        </p>
                                        <p class="text-sm font-bold">
                                            {way.speed_count}
                                        </p>
                                    </div>
                                    <p
                                        class="text-[9px] text-muted-foreground mt-0.5"
                                    >
                                        updates
                                    </p>
                                </div>
                            {/if}
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <!-- Section 2: Speed & Disturbance Index -->
                {#if display_rt || way.speed_avg != null || way.speed_median != null || way.speed_p85 != null}
                    <Accordion.Item
                        value="speed-di"
                        class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                    >
                        <Accordion.Trigger class="py-3 hover:no-underline">
                            <div class="flex items-center gap-2 text-start">
                                <i
                                    class="fas fa-gauge-high text-xs text-muted-foreground"
                                ></i>
                                <span
                                    class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                                >
                                    Speed & Disturbance Index
                                </span>
                            </div>
                        </Accordion.Trigger>
                        <Accordion.Content class="pt-1 pb-3 space-y-3">
                            <!-- Criteria Hour Speed & DI -->
                            {#if display_rt}
                                <div class="space-y-2">
                                    <p
                                        class="text-[10px] text-muted-foreground"
                                    >
                                        Criteria hour ({criteria_hour
                                            .toString()
                                            .padStart(2, "0")}:00)
                                    </p>

                                    <div
                                        class="grid grid-cols-2 sm:grid-cols-4 gap-2"
                                    >
                                        <!-- Criteria Hour DI Card -->
                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1 truncate"
                                                >
                                                    Disturbance Index
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {#if currentHourDi != null}
                                                        {currentHourDi > 0
                                                            ? "+"
                                                            : ""}{(
                                                            currentHourDi * 100
                                                        ).toFixed(1)}<span
                                                            class="text-[9px] font-normal"
                                                            >%</span
                                                        >
                                                    {:else}
                                                        N/A
                                                    {/if}
                                                </p>
                                            </div>
                                            <p
                                                class="text-[9px] text-muted-foreground truncate mt-0.5"
                                            >
                                                {currentHourDiCat
                                                    ? currentHourDiCat.label
                                                    : "vs P85 speed"}
                                            </p>
                                            {#if currentHourDiCat}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {currentHourDiCat.color}"
                                                ></div>
                                            {/if}
                                        </div>

                                        <!-- Criteria Hour Avg Speed -->
                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    Avg Speed
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {hourSpeedAvg != null
                                                        ? Number(
                                                              hourSpeedAvg,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            <p
                                                class="text-[9px] text-muted-foreground mt-0.5"
                                            >
                                                at {criteria_hour}h
                                            </p>
                                            {#if hourlyAvgColor}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {hourlyAvgColor}"
                                                ></div>
                                            {/if}
                                        </div>

                                        <!-- Criteria Hour Median Speed -->
                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    Median Speed
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {hourSpeedMedian != null
                                                        ? Number(
                                                              hourSpeedMedian,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            <p
                                                class="text-[9px] text-muted-foreground mt-0.5"
                                            >
                                                at {criteria_hour}h
                                            </p>
                                            {#if hourlyMedianColor}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {hourlyMedianColor}"
                                                ></div>
                                            {/if}
                                        </div>

                                        <!-- Criteria Hour P85 Speed -->
                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    P85 Speed
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {hourSpeedP85 != null
                                                        ? Number(
                                                              hourSpeedP85,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            <p
                                                class="text-[9px] text-muted-foreground mt-0.5"
                                            >
                                                at {criteria_hour}h
                                            </p>
                                            {#if hourlyP85Color}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {hourlyP85Color}"
                                                ></div>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            {/if}

                            <!-- All-Day Speed Summary -->
                            {#if way.speed_avg != null || way.speed_median != null || way.speed_p85 != null}
                                <div class="space-y-2 pt-1">
                                    <p
                                        class="text-[10px] text-muted-foreground"
                                    >
                                        All-day speed metrics
                                    </p>

                                    <div class="grid grid-cols-3 gap-2">
                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    All-Day Avg
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {way.speed_avg != null
                                                        ? Number(
                                                              way.speed_avg,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            {#if allDayAvgColor}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {allDayAvgColor}"
                                                ></div>
                                            {/if}
                                        </div>

                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    All-Day Median
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {way.speed_median != null
                                                        ? Number(
                                                              way.speed_median,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            {#if allDayMedianColor}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {allDayMedianColor}"
                                                ></div>
                                            {/if}
                                        </div>

                                        <div
                                            class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                                        >
                                            <div>
                                                <p
                                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                                >
                                                    All-Day P85
                                                </p>
                                                <p class="text-sm font-bold">
                                                    {way.speed_p85 != null
                                                        ? Number(
                                                              way.speed_p85,
                                                          ).toFixed(1)
                                                        : "-"}
                                                    <span
                                                        class="text-[9px] font-normal"
                                                        >km/h</span
                                                    >
                                                </p>
                                            </div>
                                            {#if allDayP85Color}
                                                <div
                                                    class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                                    style="background-color: {allDayP85Color}"
                                                ></div>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            {/if}
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}

                <!-- Section 3: Hourly Variations (Charts + Table) -->
                <Accordion.Item
                    value="hourly-variations"
                    class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                >
                    <Accordion.Trigger class="py-3 hover:no-underline">
                        <div class="flex items-center gap-2 text-start">
                            <i
                                class="fas fa-chart-column text-xs text-muted-foreground"
                            ></i>
                            <span
                                class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                            >
                                Hourly Variations (24h)
                            </span>
                        </div>
                    </Accordion.Trigger>
                    <Accordion.Content class="pt-1 pb-3 space-y-4">
                        <div
                            class={isExpanded
                                ? "grid grid-cols-1 lg:grid-cols-2 gap-4"
                                : "space-y-4"}
                        >
                            <!-- 24h Disturbance Index Chart -->
                            {#if display_rt && way.speed_p85 != null && way.hour_speed_median && Object.values(way.hour_speed_median)?.some((v) => v != null)}
                                <div
                                    class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                                >
                                    <div
                                        class="flex items-center justify-between"
                                    >
                                        <h6
                                            class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                        >
                                            <i
                                                class="fas fa-wave-square text-primary/70"
                                            ></i>
                                            Disturbance Index per Hour
                                        </h6>
                                        {#if currentHourDi != null && currentHourDiCat}
                                            <span
                                                class="text-[10px] font-mono text-muted-foreground"
                                            >
                                                {criteria_hour}:00: {currentHourDi >
                                                0
                                                    ? "+"
                                                    : ""}{(
                                                    currentHourDi * 100
                                                ).toFixed(1)}%
                                            </span>
                                        {/if}
                                    </div>
                                    <p
                                        class="text-[10px] text-muted-foreground"
                                    >
                                        Relative difference from baseline
                                        (positive: faster, negative: slower).
                                    </p>

                                    <!-- Diverging bar chart -->
                                    <div
                                        class="flex items-center gap-[2px] {isExpanded
                                            ? 'h-36'
                                            : 'h-28'} border-l border-b border-muted-foreground/30 px-1 relative bg-muted/10 rounded-sm"
                                    >
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
                                            {@const isSelectedHour =
                                                i === criteria_hour}
                                            <div
                                                class="flex-1 h-full flex flex-col relative group z-10 {isSelectedHour
                                                    ? 'bg-primary/10 rounded-sm'
                                                    : ''}"
                                            >
                                                <!-- Top half: positive values -->
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
                                                        {@const barHeight =
                                                            Math.min(
                                                                Math.max(
                                                                    (di /
                                                                        maxAbsDi) *
                                                                        100,
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

                                                <!-- Bottom half: negative values -->
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
                                                        {@const barHeight =
                                                            Math.min(
                                                                Math.max(
                                                                    (Math.abs(
                                                                        di,
                                                                    ) /
                                                                        maxAbsDi) *
                                                                        100,
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

                                                <!-- Tooltip -->
                                                <div
                                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-30 shadow-md"
                                                >
                                                    {#if di != null}
                                                        {@const cat =
                                                            getDisturbanceIndexCategory(
                                                                di,
                                                                di_threshold_low,
                                                                di_threshold_high,
                                                            )}
                                                        {i}:00: {di > 0
                                                            ? "+"
                                                            : ""}{(
                                                            di * 100
                                                        ).toFixed(1)}% ({cat.label})
                                                    {:else}
                                                        {i}:00: no data
                                                    {/if}
                                                </div>
                                            </div>
                                        {/each}
                                    </div>

                                    <div
                                        class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                                    >
                                        <span>0h</span><span>6h</span><span
                                            >12h</span
                                        ><span>18h</span><span>23h</span>
                                    </div>

                                    <!-- Category legend chips -->
                                    <div
                                        class="flex flex-wrap items-center justify-between gap-1 pt-1 border-t border-border/40 text-[9px]"
                                    >
                                        {#each getDisturbanceIndexCategories(di_threshold_low, di_threshold_high) as cat}
                                            <div
                                                class="flex items-center gap-1"
                                                title="{cat.label}: {cat.rangeLabel}"
                                            >
                                                <span
                                                    class="w-2 h-2 rounded-xs inline-block"
                                                    style="background-color: {cat.color}"
                                                ></span>
                                                <span
                                                    class="text-muted-foreground"
                                                    >{cat.label}</span
                                                >
                                            </div>
                                        {/each}
                                    </div>
                                </div>
                            {/if}

                            <!-- 24h Transit Frequency Chart -->
                            <div
                                class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                            >
                                <div class="flex items-center justify-between">
                                    <h6
                                        class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                    >
                                        <i
                                            class="fas fa-chart-bar text-primary/70"
                                        ></i>
                                        Scheduled Frequency (Buses/h)
                                    </h6>
                                    <span
                                        class="text-[10px] font-mono text-muted-foreground"
                                    >
                                        {criteria_hour}:00: {way
                                            .hour_frequency?.[criteria_hour] ??
                                            0} buses
                                    </span>
                                </div>
                                <p class="text-[10px] text-muted-foreground">
                                    Hourly scheduled bus frequency passing
                                    through this segment.
                                </p>

                                <div
                                    class="flex items-end gap-[2px] {isExpanded
                                        ? 'h-36'
                                        : 'h-28'} border-l border-b border-muted-foreground/30 px-1 pt-2 bg-muted/10 rounded-sm"
                                >
                                    {#each Array(24) as _, i}
                                        {@const hFreq =
                                            way.hour_frequency?.[i] || 0}
                                        {@const maxFreq = Math.max(
                                            ...(Object.values(
                                                way.hour_frequency || { 0: 1 },
                                            ) as number[]),
                                            1,
                                        )}
                                        {@const height = Math.max(
                                            (hFreq / maxFreq) * 100,
                                            hFreq > 0 ? 8 : 0,
                                        )}
                                        {@const hourFreqCensus =
                                            geoData.metadata?.data_census
                                                ?.frequency_hour?.[i]}
                                        {@const barColor = hourFreqCensus
                                            ? getColorFromGradient(
                                                  hFreq,
                                                  hourFreqCensus.p5,
                                                  hourFreqCensus.p95,
                                                  COLOR_GRADIENT,
                                              )
                                            : "var(--primary)"}
                                        {@const isSelectedHour =
                                            i === criteria_hour}
                                        <div
                                            class="flex-1 rounded-t-[1px] relative group transition-colors {isSelectedHour
                                                ? 'ring-1 ring-primary ring-offset-1 ring-offset-background'
                                                : ''}"
                                            style="height: {height}%; background-color: {hFreq >
                                            0
                                                ? barColor
                                                : 'transparent'};"
                                        >
                                            {#if hFreq > 0}
                                                <div
                                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                                >
                                                    {i}:00: {hFreq} buses
                                                </div>
                                            {/if}
                                        </div>
                                    {/each}
                                </div>

                                <div
                                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                                >
                                    <span>0h</span><span>6h</span><span
                                        >12h</span
                                    ><span>18h</span><span>23h</span>
                                </div>
                            </div>

                            <!-- 24h Speed Chart -->
                            {#if display_rt && ((way.hour_speed_avg && Object.values(way.hour_speed_avg)?.some((v) => v != null)) || (way.hour_speed_median && Object.values(way.hour_speed_median)?.some((v) => v != null)))}
                                <div
                                    class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs {isExpanded
                                        ? 'lg:col-span-2'
                                        : ''}"
                                >
                                    <div
                                        class="flex items-center justify-between"
                                    >
                                        <h6
                                            class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                        >
                                            <i
                                                class="fas fa-chart-line text-primary/70"
                                            ></i>
                                            24h Observed Speed
                                        </h6>
                                        {#if way.hour_speed_avg?.[criteria_hour] != null}
                                            <span
                                                class="text-[10px] font-mono text-muted-foreground"
                                            >
                                                {criteria_hour}:00: {Number(
                                                    way.hour_speed_avg[
                                                        criteria_hour
                                                    ],
                                                ).toFixed(1)} km/h
                                            </span>
                                        {/if}
                                    </div>

                                    <div
                                        class="flex items-end gap-[2px] {isExpanded
                                            ? 'h-36'
                                            : 'h-28'} border-l border-b border-muted-foreground/30 px-1 pt-2 bg-muted/10 rounded-sm"
                                    >
                                        {#each Array(24) as _, i}
                                            {@const avg_speed =
                                                way.hour_speed_avg?.[i] || 0}
                                            {@const maxSpeed = Math.max(
                                                ...(Object.values(
                                                    way.hour_speed_avg || {
                                                        0: 1,
                                                    },
                                                ) as number[]),
                                                1,
                                            )}
                                            {@const height = Math.max(
                                                (avg_speed / maxSpeed) * 100,
                                                avg_speed > 0 ? 8 : 0,
                                            )}
                                            {@const hourSpeedCensus =
                                                geoData.metadata?.data_census
                                                    ?.speed_avg_hour_length?.[
                                                    i
                                                ] ??
                                                geoData.metadata?.data_census
                                                    ?.speed_avg_length}
                                            {@const barColor =
                                                hourSpeedCensus && avg_speed > 0
                                                    ? getColorFromGradient(
                                                          avg_speed,
                                                          hourSpeedCensus.p5,
                                                          hourSpeedCensus.p95,
                                                          COLOR_GRADIENT_RED.slice().reverse(),
                                                      )
                                                    : "var(--primary)"}
                                            {@const isSelectedHour =
                                                i === criteria_hour}
                                            <div
                                                class="flex-1 rounded-t-[1px] relative group transition-colors {isSelectedHour
                                                    ? 'ring-1 ring-primary ring-offset-1 ring-offset-background'
                                                    : ''}"
                                                style="height: {height}%; background-color: {avg_speed >
                                                0
                                                    ? barColor
                                                    : 'transparent'};"
                                            >
                                                {#if avg_speed > 0}
                                                    <div
                                                        class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                                    >
                                                        {i}:00: {Number(
                                                            avg_speed,
                                                        ).toFixed(1)} km/h
                                                    </div>
                                                {/if}
                                            </div>
                                        {/each}
                                    </div>

                                    <div
                                        class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                                    >
                                        <span>0h</span><span>6h</span><span
                                            >12h</span
                                        ><span>18h</span><span>23h</span>
                                    </div>
                                </div>
                            {/if}
                        </div>

                        <!-- Hourly Breakdown Table -->
                        {#if display_rt && ((way.hour_speed_avg && Object.values(way.hour_speed_avg)?.some((v) => v != null)) || (way.hour_frequency && Object.values(way.hour_frequency)?.some((v) => v != null)))}
                            <div
                                class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                            >
                                <h6
                                    class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                                >
                                    <i class="fas fa-table text-primary/70"></i>
                                    24-Hour Metrics Breakdown
                                </h6>
                                <div class="overflow-x-auto pt-1">
                                    <table
                                        class="w-full min-w-[780px] border-separate border-spacing-x-[2px] border-spacing-y-1"
                                    >
                                        <tbody>
                                            <tr>
                                                <th
                                                    class="text-[9px] font-mono font-semibold text-muted-foreground text-left px-2 py-1 sticky left-0 bg-background/95 backdrop-blur z-10"
                                                >
                                                    Metric\Hour
                                                </th>
                                                {#each Array(24) as _, i}
                                                    <th
                                                        class="text-[9px] font-mono font-semibold {i ===
                                                        criteria_hour
                                                            ? 'text-primary font-bold'
                                                            : 'text-muted-foreground'} text-center px-1 py-1"
                                                    >
                                                        {i}h
                                                    </th>
                                                {/each}
                                            </tr>

                                            <!-- Buses / Hour -->
                                            <tr>
                                                <th
                                                    class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                                >
                                                    Frequency (buses)
                                                </th>
                                                {#each Array(24) as _, i}
                                                    {@const tableFreq =
                                                        way.hour_frequency?.[i]}
                                                    <td
                                                        class="text-[10px] font-medium text-center px-1 py-1 rounded {i ===
                                                        criteria_hour
                                                            ? 'bg-primary/10 border-primary/40'
                                                            : 'bg-background/70'} border border-border/30"
                                                    >
                                                        {tableFreq != null
                                                            ? tableFreq
                                                            : "-"}
                                                    </td>
                                                {/each}
                                            </tr>

                                            <!-- Average speed -->
                                            {#if way.hour_speed_avg}
                                                <tr>
                                                    <th
                                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                                    >
                                                        Avg speed (km/h)
                                                    </th>
                                                    {#each Array(24) as _, i}
                                                        {@const avgSpeed =
                                                            way
                                                                .hour_speed_avg?.[
                                                                i
                                                            ]}
                                                        <td
                                                            class="text-[10px] font-medium text-center px-1 py-1 rounded {i ===
                                                            criteria_hour
                                                                ? 'bg-primary/10 border-primary/40'
                                                                : 'bg-background/70'} border border-border/30"
                                                        >
                                                            {avgSpeed != null &&
                                                            !isNaN(
                                                                Number(
                                                                    avgSpeed,
                                                                ),
                                                            )
                                                                ? Number(
                                                                      avgSpeed,
                                                                  ).toFixed(1)
                                                                : "-"}
                                                        </td>
                                                    {/each}
                                                </tr>
                                            {/if}

                                            <!-- Median speed -->
                                            {#if way.hour_speed_median}
                                                <tr>
                                                    <th
                                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                                    >
                                                        Median speed (km/h)
                                                    </th>
                                                    {#each Array(24) as _, i}
                                                        {@const medianSpeed =
                                                            way
                                                                .hour_speed_median?.[
                                                                i
                                                            ]}
                                                        <td
                                                            class="text-[10px] font-medium text-center px-1 py-1 rounded {i ===
                                                            criteria_hour
                                                                ? 'bg-primary/10 border-primary/40'
                                                                : 'bg-background/70'} border border-border/30"
                                                        >
                                                            {medianSpeed !=
                                                                null &&
                                                            !isNaN(
                                                                Number(
                                                                    medianSpeed,
                                                                ),
                                                            )
                                                                ? Number(
                                                                      medianSpeed,
                                                                  ).toFixed(1)
                                                                : "-"}
                                                        </td>
                                                    {/each}
                                                </tr>
                                            {/if}

                                            <!-- P85 speed -->
                                            {#if way.hour_speed_p85}
                                                <tr>
                                                    <th
                                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                                    >
                                                        P85 speed (km/h)
                                                    </th>
                                                    {#each Array(24) as _, i}
                                                        {@const p85Speed =
                                                            way
                                                                .hour_speed_p85?.[
                                                                i
                                                            ]}
                                                        <td
                                                            class="text-[10px] font-medium text-center px-1 py-1 rounded {i ===
                                                            criteria_hour
                                                                ? 'bg-primary/10 border-primary/40'
                                                                : 'bg-background/70'} border border-border/30"
                                                        >
                                                            {p85Speed != null &&
                                                            !isNaN(
                                                                Number(
                                                                    p85Speed,
                                                                ),
                                                            )
                                                                ? Number(
                                                                      p85Speed,
                                                                  ).toFixed(1)
                                                                : "-"}
                                                        </td>
                                                    {/each}
                                                </tr>
                                            {/if}

                                            <!-- Speed count -->
                                            {#if way.hour_speed_count}
                                                <tr>
                                                    <th
                                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                                    >
                                                        Speed count (nr.)
                                                    </th>
                                                    {#each Array(24) as _, i}
                                                        {@const count =
                                                            way
                                                                .hour_speed_count?.[
                                                                i
                                                            ]}
                                                        <td
                                                            class="text-[10px] font-medium text-center px-1 py-1 rounded {i ===
                                                            criteria_hour
                                                                ? 'bg-primary/10 border-primary/40'
                                                                : 'bg-background/70'} border border-border/30"
                                                        >
                                                            {count != null
                                                                ? count
                                                                : "-"}
                                                        </td>
                                                    {/each}
                                                </tr>
                                            {/if}
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        {/if}
                    </Accordion.Content>
                </Accordion.Item>

                <!-- Section 4: Associated Routes -->
                {#if hasAssociatedRoutes}
                    <Accordion.Item
                        value="routes"
                        class="border border-border/50 rounded-xl bg-zinc-50/80 dark:bg-zinc-900/40 px-3 overflow-hidden shadow-xs"
                    >
                        <Accordion.Trigger class="py-3 hover:no-underline">
                            <div
                                class="flex items-center justify-between w-full pr-2 text-start"
                            >
                                <div class="flex items-center gap-2">
                                    <i
                                        class="fas fa-route text-xs text-muted-foreground"
                                    ></i>
                                    <span
                                        class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                                    >
                                        Associated Routes
                                    </span>
                                </div>
                                <span
                                    class="text-[10px] font-mono text-muted-foreground"
                                >
                                    {way.shapes.length}
                                    {way.shapes.length === 1
                                        ? "route"
                                        : "routes"}
                                </span>
                            </div>
                        </Accordion.Trigger>
                        <Accordion.Content class="pt-1 pb-3 space-y-2">
                            <!-- Search filter -->
                            {#if way.shapes.length > 5}
                                <div class="relative">
                                    <i
                                        class="fas fa-search absolute left-2.5 top-1/2 -translate-y-1/2 text-[10px] text-muted-foreground pointer-events-none"
                                    ></i>
                                    <Input
                                        type="text"
                                        placeholder="Filter routes..."
                                        bind:value={routeSearchQuery}
                                        class="h-7 text-[11px] pl-7 pr-6 bg-background/80"
                                    />
                                    {#if routeSearchQuery}
                                        <button
                                            type="button"
                                            class="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground text-[10px] p-0.5"
                                            onclick={() =>
                                                (routeSearchQuery = "")}
                                            aria-label="Clear filter"
                                        >
                                            <i class="fas fa-times"></i>
                                        </button>
                                    {/if}
                                </div>
                            {/if}

                            {@const filteredShapes = way.shapes.filter(
                                (shape_id) => {
                                    if (!routeSearchQuery.trim()) return true;
                                    const q = routeSearchQuery.toLowerCase().trim();
                                    const route = geoData.shapes?.[shape_id];
                                    return (
                                        shape_id.toLowerCase().includes(q) ||
                                        (route?.route_short_name &&
                                            route.route_short_name
                                                .toLowerCase()
                                                .includes(q)) ||
                                        (route?.route_long_name &&
                                            route.route_long_name
                                                .toLowerCase()
                                                .includes(q))
                                    );
                                },
                            )}

                            {#if filteredShapes.length === 0}
                                <p class="text-xs text-muted-foreground text-center py-4">
                                    No routes match "{routeSearchQuery}"
                                </p>
                            {:else}
                                <div
                                    class="grid {isExpanded
                                        ? 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-4'
                                        : 'grid-cols-1'} gap-2"
                                >
                                    {#each filteredShapes as shape_id}
                                        {@const route = geoData.shapes?.[shape_id]}
                                        {@const routeColor =
                                            route?.route_color || "var(--primary)"}
                                        <button
                                            type="button"
                                            onclick={() => {
                                                selected_shape_id = shape_id;
                                                selectedWayId = undefined;
                                            }}
                                            class="flex items-center justify-between p-2.5 rounded-xl border border-border/40 bg-background/80 hover:bg-muted/50 transition-colors text-left group cursor-pointer shadow-2xs"
                                        >
                                            <div
                                                class="flex items-center gap-2.5 min-w-0"
                                            >
                                                <span
                                                    class="px-2 py-0.5 rounded text-xs font-bold font-mono shrink-0 shadow-2xs"
                                                    style="background-color: {routeColor}22; border: 1px solid {routeColor}44; color: {routeColor};"
                                                >
                                                    {route?.route_short_name ||
                                                        shape_id}
                                                </span>
                                                <div class="min-w-0">
                                                    <p
                                                        class="text-xs font-semibold text-foreground truncate group-hover:text-primary transition-colors"
                                                        title={route?.route_long_name}
                                                    >
                                                        {route?.route_long_name ||
                                                            "Route " +
                                                                (route?.route_short_name ||
                                                                    shape_id)}
                                                    </p>
                                                    <p
                                                        class="text-[10px] text-muted-foreground font-mono"
                                                    >
                                                        {route?.direction_id
                                                            ? "↙ Descending"
                                                            : "↗ Ascending"}
                                                    </p>
                                                </div>
                                            </div>
                                            <i
                                                class="fas fa-chevron-right text-[10px] text-muted-foreground/60 group-hover:text-foreground transition-colors shrink-0 ml-2"
                                            ></i>
                                        </button>
                                    {/each}
                                </div>
                            {/if}
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}
            </Accordion.Root>
        </div>
    </div>
{/if}
