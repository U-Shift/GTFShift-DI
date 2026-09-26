<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import {
        toCapitalCase,
        getDisturbanceIndexCategory,
        getDisturbanceIndexCategories,
    } from "$lib/utils.js";
    import type {
        GeoPrioritisation,
        TripSpeedProfile,
        TripDaySpeedProfile,
    } from "../types/GeoPrioritisation";

    let {
        selectedTripId = $bindable(),
        selected_shape_id,
        geoData,
        isExpanded = $bindable(false),
        di_threshold_low = 0.05,
        di_threshold_high = 0.2,
    }: {
        selectedTripId?: string;
        selected_shape_id: string;
        geoData: GeoPrioritisation | null;
        isExpanded?: boolean;
        di_threshold_low?: number;
        di_threshold_high?: number;
    } = $props();

    let copied = $state(false);

    $effect(() => {
        if (!selectedTripId) {
            isExpanded = false;
        }
    });

    function handleKeyDown(event: KeyboardEvent) {
        if (event.key === "Escape" && isExpanded) {
            isExpanded = false;
        }
    }

    function copyTripId(id?: string) {
        if (!id || !navigator?.clipboard) return;
        navigator.clipboard.writeText(id);
        copied = true;
        setTimeout(() => {
            copied = false;
        }, 1500);
    }

    function formatDayShort(day: string | number | undefined): string {
        if (!day) return "-";
        const s = String(day);
        if (s.length === 8) {
            // YYYYMMDD
            const m = parseInt(s.slice(4, 6), 10);
            const d = parseInt(s.slice(6, 8), 10);
            const months = [
                "Jan",
                "Feb",
                "Mar",
                "Apr",
                "May",
                "Jun",
                "Jul",
                "Aug",
                "Sep",
                "Oct",
                "Nov",
                "Dec",
            ];
            return `${d} ${months[m - 1] ?? ""}`;
        }
        return s;
    }

    function formatDayFull(day: string | number | undefined): string {
        if (!day) return "-";
        const s = String(day);
        if (s.length === 8) {
            const y = s.slice(0, 4);
            const m = s.slice(4, 6);
            const d = s.slice(6, 8);
            return `${y}-${m}-${d}`;
        }
        return s;
    }

    function formatTime(timestamp?: number): string | null {
        if (!timestamp) return null;
        try {
            const date = new Date(timestamp * 1000);
            return date.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
            });
        } catch {
            return null;
        }
    }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if selectedTripId && selected_shape_id && selected_shape_id !== "all" && geoData}
    {@const shape = geoData.shapes[selected_shape_id]}
    {@const shapeColor = shape?.route_color ?? "var(--primary)"}
    {@const shapeTrips =
        shape?.speed_profile?.trips ??
        geoData.routes?.[shape?.route_id]?.speed_profile?.trips ??
        []}
    {@const trip = shapeTrips.find(
        (t: TripSpeedProfile) => t.trip_id === selectedTripId,
    )}
    {@const rawTripDays =
        shape?.speed_profile?.trip_days ??
        geoData.routes?.[shape?.route_id]?.speed_profile?.trip_days ??
        []}
    {@const tripDays = rawTripDays.filter(
        (d: TripDaySpeedProfile) => d.trip_id === selectedTripId,
    )}
    {@const sortedTripDays = [...tripDays].sort((a, b) =>
        String(a.day).localeCompare(String(b.day)),
    )}
    {@const maxDaySpeed =
        sortedTripDays.length > 0
            ? Math.max(...sortedTripDays.map((d) => d.commercial_speed ?? 0), 1)
            : 1}
    {@const avgDaySpeed =
        trip?.commercial_speed_avg ??
        (sortedTripDays.length > 0
            ? sortedTripDays.reduce(
                  (acc, d) => acc + (d.commercial_speed ?? 0),
                  0,
              ) / sortedTripDays.length
            : null)}
    {@const tripDI = trip?.disturbance_index}
    {@const tripDICategory =
        tripDI != null
            ? getDisturbanceIndexCategory(
                  tripDI,
                  di_threshold_low,
                  di_threshold_high,
              )
            : null}
    {@const maxAbsDayDi =
        sortedTripDays.length > 0
            ? Math.max(
                  ...sortedTripDays.map((d) =>
                      Math.abs(d.disturbance_index ?? 0),
                  ),
                  0.1,
              )
            : 0.1}

    {#if isExpanded}
        <!-- Backdrop: blur behind just like ModalData -->
        <div
            class="fixed inset-0 z-[1058] bg-black/20 backdrop-blur-[1px]"
            onclick={() => (isExpanded = false)}
            role="presentation"
        ></div>
    {/if}

    <div
        id="trip-details-panel"
        class={isExpanded
            ? "fixed top-4 left-4 right-4 sm:left-[calc(1rem+350px+0.5rem)] sm:right-4 z-[1060] flex flex-col h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-xl border p-5 overflow-y-auto gap-4"
            : "absolute top-4 left-4 right-4 sm:left-auto lg:right-[404px] sm:right-4 z-[1015] flex flex-col w-[calc(100vw-2rem)] sm:w-[380px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-xl border p-5 overflow-y-auto gap-4"}
    >
        <div class="w-full flex flex-col gap-4">
            <!-- Header -->
            <div
                class="flex items-start justify-between gap-2 border-b border-border/40 pb-3"
            >
                <div class="space-y-1 min-w-0">
                    <div class="flex items-center gap-2">
                        <Button
                            variant="ghost"
                            size="sm"
                            onclick={() => (selectedTripId = undefined)}
                            class="h-6 px-1.5 text-xs text-muted-foreground hover:text-foreground -ml-1 gap-1 cursor-pointer"
                            title="Back to Route Details"
                        >
                            <i class="fas fa-arrow-left text-[10px]"></i>
                            <span>Back</span>
                        </Button>
                    </div>

                    <div class="flex items-center gap-1.5 pt-0.5">
                        <h3
                            class="{isExpanded
                                ? 'text-lg sm:text-xl'
                                : 'text-sm'} font-mono font-bold text-foreground truncate max-w-[400px]"
                            title={selectedTripId}
                        >
                            {selectedTripId}
                        </h3>
                        <button
                            type="button"
                            class="text-muted-foreground hover:text-foreground text-xs p-1 rounded transition-colors cursor-pointer"
                            onclick={() => copyTripId(selectedTripId)}
                            title="Copy Trip ID"
                        >
                            {#if copied}
                                <i
                                    class="fas fa-check text-emerald-500 text-[11px]"
                                ></i>
                            {:else}
                                <i class="fas fa-copy text-[11px]"></i>
                            {/if}
                        </button>
                    </div>
                </div>

                <div class="flex items-center gap-1.5 shrink-0">
                    <Button
                        variant="ghost"
                        size="icon"
                        onclick={() => {
                            isExpanded = !isExpanded;
                        }}
                        class="rounded-full shrink-0 h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-muted cursor-pointer"
                        title={isExpanded
                            ? "Collapse trip details"
                            : "Extend trip details (widescreen)"}
                        aria-label={isExpanded
                            ? "Collapse trip details"
                            : "Extend trip details"}
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
                            selectedTripId = undefined;
                        }}
                        class="rounded-full shrink-0 h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-muted cursor-pointer"
                        aria-label="Close trip panel"
                    >
                        <i class="fas fa-times text-xs"></i>
                    </Button>
                </div>
            </div>

            <!-- Trip Summary Statistics Cards -->
            {#if trip}
                <div class="space-y-1.5">
                    <div class="flex items-center justify-between">
                        <span
                            class="text-[10px] font-bold uppercase tracking-wider text-muted-foreground"
                        >
                            Commercial Speed Metrics
                        </span>
                        {#if trip.n_days != null}
                            <span
                                class="text-[10px] text-muted-foreground font-mono"
                            >
                                {trip.n_days} days sampled
                            </span>
                        {/if}
                    </div>

                    <div
                        class="grid {isExpanded
                            ? 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-6'
                            : 'grid-cols-3'} gap-2"
                    >
                        {#if trip.commercial_speed_min != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Min Speed
                                </p>
                                <p class="text-sm font-bold">
                                    {Number(trip.commercial_speed_min).toFixed(
                                        1,
                                    )}<span class="text-[9px] font-normal">
                                        km/h</span
                                    >
                                </p>
                            </div>
                        {/if}

                        {#if trip.commercial_speed_avg != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Avg Speed
                                </p>
                                <p class="text-sm font-bold">
                                    {Number(trip.commercial_speed_avg).toFixed(
                                        1,
                                    )}<span class="text-[9px] font-normal">
                                        km/h</span
                                    >
                                </p>
                            </div>
                        {/if}

                        {#if trip.commercial_speed_max != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Max Speed
                                </p>
                                <p class="text-sm font-bold">
                                    {Number(trip.commercial_speed_max).toFixed(
                                        1,
                                    )}<span class="text-[9px] font-normal">
                                        km/h</span
                                    >
                                </p>
                            </div>
                        {/if}

                        {#if trip.commercial_speed_median != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    Median Speed
                                </p>
                                <p class="text-sm font-bold">
                                    {Number(
                                        trip.commercial_speed_median,
                                    ).toFixed(1)}<span
                                        class="text-[9px] font-normal"
                                    >
                                        km/h</span
                                    >
                                </p>
                            </div>
                        {/if}

                        {#if trip.commercial_speed_p85 != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs"
                            >
                                <p
                                    class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                                >
                                    P85 Speed
                                </p>
                                <p class="text-sm font-bold">
                                    {Number(trip.commercial_speed_p85).toFixed(
                                        1,
                                    )}<span class="text-[9px] font-normal">
                                        km/h</span
                                    >
                                </p>
                            </div>
                        {/if}

                        <!-- Disturbance Index Card for Trip -->
                        {#if tripDI != null}
                            <div
                                class="p-2.5 bg-background/80 rounded-xl border border-border/40 text-center shadow-xs relative overflow-hidden flex flex-col justify-between"
                            >
                                <div>
                                    <p
                                        class="text-[9px] font-bold uppercase text-muted-foreground mb-1 truncate"
                                        title="Disturbance Index for this trip (avg speed vs baseline)"
                                    >
                                        DI (Trip)
                                    </p>
                                    <p class="text-sm font-bold">
                                        {tripDI > 0 ? "+" : ""}{(
                                            tripDI * 100
                                        ).toFixed(1)}<span
                                            class="text-[9px] font-normal"
                                            >%</span
                                        >
                                    </p>
                                </div>
                                {#if tripDICategory}
                                    <p
                                        class="text-[9px] font-medium truncate mt-0.5"
                                        style="color: {tripDICategory.color};"
                                        title={tripDICategory.label}
                                    >
                                        {tripDICategory.label}
                                    </p>
                                    <div
                                        class="absolute bottom-0 left-0 right-0 h-[2.5px]"
                                        style="background-color: {tripDICategory.color};"
                                    ></div>
                                {/if}
                            </div>
                        {/if}
                    </div>
                </div>
            {/if}

            <!-- Variation Across Different Days (speed_profile.trip_days) -->
            {#if sortedTripDays.length > 0}
                {@const hasMedian = sortedTripDays.some(
                    (d) => d.speed_median != null,
                )}
                {@const hasP85 = sortedTripDays.some(
                    (d) => d.speed_p85 != null,
                )}
                {@const hasCount = sortedTripDays.some(
                    (d) => d.speed_count != null || d.n_updates != null,
                )}
                <!-- 1. Daily Commercial Speed Chart -->
                <div
                    class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                >
                    <div class="flex items-center justify-between">
                        <h6
                            class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                        >
                            <i
                                class="fas fa-chart-column"
                                style="color: {shapeColor}"
                            ></i>
                            Commercial Speed Across Days
                        </h6>
                        <span
                            class="text-[10px] font-mono text-muted-foreground"
                        >
                            {sortedTripDays.length} runs
                        </span>
                    </div>

                    <p class="text-[10px] text-muted-foreground">
                        Observed commercial speed per date for this scheduled
                        trip.
                    </p>

                    <!-- Daily Bar Chart -->
                    <div
                        class="flex items-end gap-[2px] {isExpanded
                            ? 'h-36'
                            : 'h-28'} border-l border-b border-muted-foreground/30 px-1 pt-2 bg-muted/10 rounded-sm relative"
                    >
                        <!-- Average speed reference dashed line -->
                        {#if avgDaySpeed != null && avgDaySpeed > 0}
                            {@const avgY = Math.min(
                                (avgDaySpeed / maxDaySpeed) * 100,
                                100,
                            )}
                            <div
                                class="absolute left-0 right-0 border-t border-dashed border-primary/50 pointer-events-none z-10"
                                style="bottom: {avgY}%;"
                                title="Average: {avgDaySpeed.toFixed(1)} km/h"
                            ></div>
                        {/if}

                        {#each sortedTripDays as dayData, i}
                            {@const speed = dayData.commercial_speed}
                            {@const height =
                                speed != null && speed > 0
                                    ? Math.max((speed / maxDaySpeed) * 100, 8)
                                    : 0}
                            {@const timeStr = formatTime(dayData.timestamp_min)}
                            <div
                                class="flex-1 rounded-t-[1px] relative group transition-colors cursor-pointer"
                                style="height: {height}%; background-color: {speed !=
                                    null && speed > 0
                                    ? shapeColor + 'cc'
                                    : 'transparent'};"
                            >
                                <!-- Tooltip on hover -->
                                <div
                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 px-2 py-1 bg-foreground text-background text-[10px] rounded shadow-md opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-30 transition-opacity"
                                >
                                    <p class="font-bold">
                                        {formatDayFull(dayData.day)}
                                    </p>
                                    <p>
                                        {speed != null
                                            ? Number(speed).toFixed(1) + " km/h"
                                            : "-"}
                                    </p>
                                    {#if timeStr}
                                        <p class="text-[9px] opacity-80">
                                            Dept: {timeStr}
                                        </p>
                                    {/if}
                                </div>
                            </div>
                        {/each}
                    </div>

                    <!-- X Axis Labels -->
                    <div
                        class="flex justify-between text-[9px] text-muted-foreground font-mono"
                    >
                        <span>{formatDayShort(sortedTripDays[0]?.day)}</span>
                        {#if sortedTripDays.length > 2}
                            <span
                                >{formatDayShort(
                                    sortedTripDays[
                                        Math.floor(sortedTripDays.length / 2)
                                    ]?.day,
                                )}</span
                            >
                        {/if}
                        <span
                            >{formatDayShort(
                                sortedTripDays[sortedTripDays.length - 1]?.day,
                            )}</span
                        >
                    </div>

                    <!-- Daily Speed Metrics Table (as in other speed charts) -->
                    <div class="overflow-x-auto pt-2">
                        <table
                            class="w-full border-separate border-spacing-x-[2px] border-spacing-y-1"
                            style="min-width: {Math.max(
                                sortedTripDays.length * 52 + 130,
                                360,
                            )}px;"
                        >
                            <tbody>
                                <!-- Header Row with Dates -->
                                <tr>
                                    <th
                                        class="text-[9px] font-mono font-semibold text-muted-foreground text-left px-2 py-1 sticky left-0 bg-background/95 backdrop-blur z-10"
                                    >
                                        Metric\Date
                                    </th>
                                    {#each sortedTripDays as d}
                                        <th
                                            class="text-[9px] font-mono font-semibold text-muted-foreground text-center px-1.5 py-1 whitespace-nowrap"
                                            title={formatDayFull(d.day)}
                                        >
                                            {formatDayShort(d.day)}
                                        </th>
                                    {/each}
                                </tr>

                                <!-- Average Commercial Speed -->
                                <tr>
                                    <th
                                        class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                    >
                                        Average speed (km/h)
                                    </th>
                                    {#each sortedTripDays as d}
                                        {@const val =
                                            d.commercial_speed ?? d.speed_avg}
                                        <td
                                            class="text-[10px] font-medium text-center px-1.5 py-1 rounded bg-background/70 border border-border/30 whitespace-nowrap"
                                            title="{formatDayFull(
                                                d.day,
                                            )} avg speed"
                                        >
                                            {val != null && !isNaN(Number(val))
                                                ? Number(val).toFixed(1)
                                                : "-"}
                                        </td>
                                    {/each}
                                </tr>

                                <!-- Median Speed -->
                                {#if hasMedian}
                                    <tr>
                                        <th
                                            class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                        >
                                            Median speed (km/h)
                                        </th>
                                        {#each sortedTripDays as d}
                                            {@const val = d.speed_median}
                                            <td
                                                class="text-[10px] font-medium text-center px-1.5 py-1 rounded bg-background/70 border border-border/30 whitespace-nowrap"
                                                title="{formatDayFull(
                                                    d.day,
                                                )} median speed"
                                            >
                                                {val != null &&
                                                !isNaN(Number(val))
                                                    ? Number(val).toFixed(1)
                                                    : "-"}
                                            </td>
                                        {/each}
                                    </tr>
                                {/if}

                                <!-- P85 Speed -->
                                {#if hasP85}
                                    <tr>
                                        <th
                                            class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                        >
                                            P85 speed (km/h)
                                        </th>
                                        {#each sortedTripDays as d}
                                            {@const val = d.speed_p85}
                                            <td
                                                class="text-[10px] font-medium text-center px-1.5 py-1 rounded bg-background/70 border border-border/30 whitespace-nowrap"
                                                title="{formatDayFull(
                                                    d.day,
                                                )} p85 speed"
                                            >
                                                {val != null &&
                                                !isNaN(Number(val))
                                                    ? Number(val).toFixed(1)
                                                    : "-"}
                                            </td>
                                        {/each}
                                    </tr>
                                {/if}

                                <!-- Speed count -->
                                {#if hasCount}
                                    <tr>
                                        <th
                                            class="text-[9px] font-semibold text-muted-foreground text-left px-2 py-1 whitespace-nowrap sticky left-0 bg-background/95 backdrop-blur z-10"
                                        >
                                            Speed count (nr.)
                                        </th>
                                        {#each sortedTripDays as d}
                                            {@const val =
                                                d.speed_count ?? d.n_updates}
                                            <td
                                                class="text-[10px] font-medium text-center px-1.5 py-1 rounded bg-background/70 border border-border/30 whitespace-nowrap"
                                                title="{formatDayFull(
                                                    d.day,
                                                )} speed count"
                                            >
                                                {val != null ? val : "-"}
                                            </td>
                                        {/each}
                                    </tr>
                                {/if}
                            </tbody>
                        </table>
                    </div>
                </div>

                <!-- 2. Daily Disturbance Index Chart (Diverging bar chart) -->
                {#if sortedTripDays.some((d) => d.disturbance_index != null)}
                    <div
                        class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                    >
                        <div class="flex items-center justify-between">
                            <h6
                                class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                            >
                                <i
                                    class="fas fa-wave-square"
                                    style="color: {shapeColor}"
                                ></i>
                                Disturbance Index Across Days
                            </h6>
                        </div>

                        <p class="text-[10px] text-muted-foreground">
                            Variation relative to shape baseline (positive:
                            faster, negative: slower).
                        </p>

                        <!-- Diverging Bar Chart -->
                        <div
                            class="flex items-center gap-[2px] {isExpanded
                                ? 'h-36'
                                : 'h-28'} border-l border-b border-muted-foreground/30 px-1 relative bg-muted/10 rounded-sm"
                        >
                            <!-- Zero Baseline -->
                            <div
                                class="absolute left-0 right-0 top-1/2 -translate-y-1/2 border-t border-dashed border-muted-foreground/40 pointer-events-none z-0"
                            ></div>
                            <span
                                class="absolute right-1 top-1/2 -translate-y-1/2 text-[8px] font-mono text-muted-foreground/50 pointer-events-none select-none z-0"
                            >
                                0%
                            </span>

                            {#each sortedTripDays as dayData}
                                {@const di = dayData.disturbance_index}
                                <div
                                    class="flex-1 h-full flex flex-col relative group z-10 cursor-pointer"
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
                                            {@const barHeight = Math.min(
                                                Math.max(
                                                    (di / maxAbsDayDi) * 100,
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
                                            {@const barHeight = Math.min(
                                                Math.max(
                                                    (Math.abs(di) /
                                                        maxAbsDayDi) *
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

                                    <!-- Tooltip on hover -->
                                    <div
                                        class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 px-2 py-1 bg-foreground text-background text-[10px] rounded shadow-md opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-30 transition-opacity"
                                    >
                                        <p class="font-bold">
                                            {formatDayFull(dayData.day)}
                                        </p>
                                        {#if di != null}
                                            {@const cat =
                                                getDisturbanceIndexCategory(
                                                    di,
                                                    di_threshold_low,
                                                    di_threshold_high,
                                                )}
                                            <p class="font-mono">
                                                {di > 0 ? "+" : ""}{(
                                                    di * 100
                                                ).toFixed(1)}% ({cat.label})
                                            </p>
                                        {:else}
                                            <p>No DI data</p>
                                        {/if}
                                    </div>
                                </div>
                            {/each}
                        </div>

                        <!-- X Axis Labels -->
                        <div
                            class="flex justify-between text-[9px] text-muted-foreground font-mono"
                        >
                            <span>{formatDayShort(sortedTripDays[0]?.day)}</span
                            >
                            {#if sortedTripDays.length > 2}
                                <span
                                    >{formatDayShort(
                                        sortedTripDays[
                                            Math.floor(
                                                sortedTripDays.length / 2,
                                            )
                                        ]?.day,
                                    )}</span
                                >
                            {/if}
                            <span
                                >{formatDayShort(
                                    sortedTripDays[sortedTripDays.length - 1]
                                        ?.day,
                                )}</span
                            >
                        </div>

                        <!-- Dynamic Legend -->
                        <div
                            class="flex flex-wrap items-center justify-center gap-3 pt-1 text-[9px] font-medium border-t border-border/40"
                        >
                            {#each getDisturbanceIndexCategories(di_threshold_low, di_threshold_high) as cat}
                                <div
                                    class="flex items-center gap-1.5"
                                    title="{cat.label}: {cat.rangeLabel}"
                                >
                                    <div
                                        class="w-2.5 h-2.5 rounded-xs shrink-0"
                                        style="background-color: {cat.color};"
                                    ></div>
                                    <span class="text-muted-foreground"
                                        >{cat.label}</span
                                    >
                                </div>
                            {/each}
                        </div>
                    </div>
                {/if}

                <!-- 3. Daily Breakdown Table -->
                <div
                    class="space-y-2 p-3 bg-background/80 rounded-xl border border-border/40 shadow-xs"
                >
                    <div class="flex items-center justify-between">
                        <h6
                            class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                        >
                            <i class="fas fa-table" style="color: {shapeColor}"
                            ></i>
                            Daily Breakdown
                        </h6>
                        <span class="text-[10px] text-muted-foreground">
                            {sortedTripDays.length} records
                        </span>
                    </div>

                    <div
                        class="overflow-x-auto max-h-60 overflow-y-auto rounded-lg border border-border/40"
                    >
                        <table class="w-full text-[11px] border-collapse">
                            <thead
                                class="bg-muted/50 text-[10px] text-muted-foreground uppercase tracking-wider sticky top-0 backdrop-blur z-10"
                            >
                                <tr>
                                    <th class="text-left py-2 px-2.5 font-bold"
                                        >Date</th
                                    >
                                    <th class="text-center py-2 px-2 font-bold"
                                        >Departure</th
                                    >
                                    <th class="text-right py-2 px-2 font-bold"
                                        >Avg. Speed</th
                                    >
                                    <th class="text-right py-2 px-2.5 font-bold"
                                        >DI</th
                                    >
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-border/30">
                                {#each sortedTripDays as d}
                                    {@const di = d.disturbance_index}
                                    {@const cat =
                                        di != null
                                            ? getDisturbanceIndexCategory(
                                                  di,
                                                  di_threshold_low,
                                                  di_threshold_high,
                                              )
                                            : null}
                                    <tr
                                        class="hover:bg-muted/30 transition-colors"
                                    >
                                        <td
                                            class="py-1.5 px-2.5 font-mono text-[10px] whitespace-nowrap"
                                        >
                                            {formatDayFull(d.day)}
                                        </td>
                                        <td
                                            class="py-1.5 px-2 text-center text-muted-foreground font-mono text-[10px] whitespace-nowrap"
                                        >
                                            {formatTime(d.timestamp_min) ??
                                                (d.hour != null
                                                    ? `${d.hour}:00`
                                                    : "-")}
                                        </td>
                                        <td
                                            class="py-1.5 px-2 text-right font-medium whitespace-nowrap"
                                        >
                                            {d.commercial_speed != null
                                                ? Number(
                                                      d.commercial_speed,
                                                  ).toFixed(1) + " km/h"
                                                : "-"}
                                        </td>
                                        <td
                                            class="py-1.5 px-2.5 text-right whitespace-nowrap"
                                        >
                                            {#if di != null && cat}
                                                <span
                                                    class="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-mono font-semibold"
                                                    style="color: {cat.color}; background-color: {cat.color}15;"
                                                    title="{cat.label}: {di > 0
                                                        ? '+'
                                                        : ''}{(
                                                        di * 100
                                                    ).toFixed(1)}%"
                                                >
                                                    {di > 0 ? "+" : ""}{(
                                                        di * 100
                                                    ).toFixed(1)}%
                                                </span>
                                            {:else}
                                                <span
                                                    class="text-muted-foreground"
                                                    >-</span
                                                >
                                            {/if}
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </div>
                </div>
            {:else}
                <div
                    class="p-4 rounded-xl border border-dashed border-border/60 text-center text-muted-foreground space-y-1"
                >
                    <i
                        class="fas fa-calendar-xmark text-lg text-muted-foreground/60 mb-1"
                    ></i>
                    <p class="text-xs font-semibold">
                        No daily variation records
                    </p>
                    <p class="text-[10px]">
                        No speed_profile.trip_days found for this trip ID.
                    </p>
                </div>
            {/if}
        </div>
    </div>
{/if}
