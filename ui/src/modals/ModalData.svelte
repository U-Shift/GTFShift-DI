<script lang="ts">
    import { untrack } from "svelte";
    import type { Feature } from "geojson";
    import {
        TableHandler,
        Datatable,
        ThSort,
        ThFilter,
        Search,
        RowsPerPage,
    } from "@vincjo/datatables";
    import ThFilterNumeric from "../components/ThFilterNumeric.svelte";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
    import { Button } from "$lib/components/ui/button/index.js";
    import { getDisturbanceIndex } from "../lib/utils";

    let {
        open = $bindable(false),
        geoData,
        hour,
        rt_data,
        demand_data,
        visible_way_ids = [],
        onWaySelect = (wayId) => {},
        onRouteSelect = (shapeId) => {},
    }: {
        open: boolean;
        geoData: GeoPrioritisation;
        hour: number;
        rt_data: boolean;
        demand_data: boolean;
        visible_way_ids?: string[];
        onWaySelect?: (wayId: string) => void;
        onRouteSelect?: (shapeId: string) => void;
    } = $props();

    let data_filtered = $state<Feature[]>([]);
    let table = $state<TableHandler<any> | null>(null);
    let show_filters = $state<boolean>(false);

    $effect(() => {
        if (geoData) {
            const visibleWayIdSet = new Set(visible_way_ids);

            data_filtered = Array.from(visibleWayIdSet)
                .filter((wayId) => !!geoData.wayData[wayId])
                .map((wayId: string) => {
                    const wayData = geoData.wayData[wayId];
                    const di = getDisturbanceIndex(wayData, hour);
                    return {
                        properties: {
                            way_osm_id: wayId,
                            ...wayData,
                            frequency: wayData.hour_frequency?.[hour],
                            route_names: wayData.routes?.join(", ") || "",
                            disturbance_index: di,
                            di_percent: di !== undefined ? Number((di * 100).toFixed(1)) : undefined,
                        },
                    } as unknown as Feature;
                });
        }

        untrack(() => {
            if (data_filtered) {
                if (!table) {
                    table = new TableHandler([] as Feature[], {
                        rowsPerPage: 15,
                    });
                }
                table.setRows([...data_filtered]);
            }
        });
    });
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[2000] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel: same margins as the left sidebar (1rem all around, starts after 350px sidebar) -->
    <div
        class="fixed z-[2010] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden h-fit max-h-[calc(100vh-2rem)]
               top-4 left-4 right-4 sm:left-[calc(1rem+350px+0.5rem)] sm:right-4"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-3 border-b shrink-0 gap-3"
        >
            <h2 class="text-lg font-bold flex items-center gap-2">
                <i class="fas fa-table text-primary"></i>
                Attribute table
                <span class="text-muted-foreground font-normal text-sm"
                    >at {hour}:00 (Showing {table?.rows.length ?? data_filtered.length} of {data_filtered.length} rows)</span
                >
            </h2>
            <div class="flex items-center gap-2">
                <Button
                    variant={show_filters ? "secondary" : "outline"}
                    size="sm"
                    onclick={() => (show_filters = !show_filters)}
                    class="h-8 text-xs gap-1.5 cursor-pointer"
                    title={show_filters ? "Hide column filters" : "Show column filters"}
                >
                    <i class="fas fa-filter text-xs"></i>
                    <span>{show_filters ? "Hide filters" : "Filter columns"}</span>
                </Button>
                {#if show_filters}
                    <Button
                        variant="ghost"
                        size="sm"
                        onclick={() => table?.clearFilters()}
                        class="h-8 text-xs text-muted-foreground hover:text-foreground cursor-pointer"
                        title="Clear all column filters"
                    >
                        Clear filters
                    </Button>
                {/if}
                <Button
                    variant="ghost"
                    size="sm"
                    onclick={() => (open = false)}
                    class="h-8 w-8 p-0 cursor-pointer"
                >
                    <i class="fas fa-times"></i>
                </Button>
            </div>
        </div>

        <!-- Table -->
        <div class="flex-1 overflow-auto px-4 py-3">
            {#if table}
                <div class="border rounded-md">
                    <Datatable basic {table}>
                        {#snippet header()}
                            <Search {table} />
                            <RowsPerPage {table} options={[5, 10, 15, 20, 50, 100]} />
                        {/snippet}
                        <table class="w-full text-sm">
                            <thead class="bg-muted/50 border-b sticky top-0">
                                <tr>
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.way_osm_id}
                                        >OSM ID</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) =>
                                            r.properties.name &&
                                            typeof r.properties.name ===
                                                "string"
                                                ? r.properties.name
                                                : ""}>Name</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.frequency}
                                        >Frequency <small>(Buses/h)</small
                                        ></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.is_bus_lane}
                                        >Bus Lane</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) =>
                                            r.properties.n_lanes_circulation}
                                        >Nr<br />lanes
                                        <small>(circulation)</small></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) =>
                                            r.properties.n_lanes_parking}
                                        >Nr lanes <small>(parking)</small
                                        ></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.n_directions}
                                        >Nr directions</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) =>
                                            r.properties
                                                .n_lanes_circulation_direction}
                                        >Nr lanes/dir</ThSort
                                    >
                                    {#if rt_data}
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.speed_avg}
                                            >Avg speed <small>(km/h)</small
                                            ></ThSort
                                        >
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.speed_median}
                                            >Median speed <small>(km/h)</small
                                            ></ThSort
                                        >
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.speed_p85}
                                            >P85 speed <small>(km/h)</small
                                            ></ThSort
                                        >
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.speed_count}
                                            >Speed count <small
                                                >(nr measurements)</small
                                            ></ThSort
                                        >
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.disturbance_index ??
                                                -999}
                                            >DI <small>(%)</small></ThSort
                                        >
                                    {/if}
                                    {#if demand_data}
                                        <ThSort
                                            {table}
                                            field={(r) => r.properties.demand}
                                        >Demand <small
                                                >(passengers/day)</small
                                            ></ThSort
                                        >
                                    {/if}
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.length_m}
                                        >Length <small>(m)</small></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.route_names}
                                        >Routes</ThSort
                                    >
                                </tr>
                                {#if show_filters}
                                    <tr class="bg-muted/30 border-b filter-row">
                                        <ThFilter
                                            {table}
                                            field={(r) => r.properties.way_osm_id}
                                        />
                                        <ThFilter
                                            {table}
                                            field={(r) =>
                                                r.properties.name &&
                                                typeof r.properties.name ===
                                                    "string"
                                                    ? r.properties.name
                                                    : ""}
                                        />
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) => r.properties.frequency}
                                        />
                                        <ThFilter
                                            {table}
                                            field={(r) =>
                                                r.properties.is_bus_lane
                                                    ? "Yes"
                                                    : "No"}
                                        />
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) =>
                                                r.properties.n_lanes_circulation}
                                        />
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) =>
                                                r.properties.n_lanes_parking}
                                        />
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) =>
                                                r.properties.n_directions}
                                        />
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) =>
                                                r.properties
                                                    .n_lanes_circulation_direction}
                                        />
                                        {#if rt_data}
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.speed_avg}
                                            />
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.speed_median}
                                            />
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.speed_p85}
                                            />
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.speed_count}
                                            />
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.di_percent}
                                                placeholder="±%"
                                            />
                                        {/if}
                                        {#if demand_data}
                                            <ThFilterNumeric
                                                {table}
                                                field={(r) =>
                                                    r.properties.demand}
                                            />
                                        {/if}
                                        <ThFilterNumeric
                                            {table}
                                            field={(r) =>
                                                r.properties.length_m}
                                        />
                                        <ThFilter
                                            {table}
                                            field={(r) =>
                                                r.properties.route_names}
                                        />
                                    </tr>
                                {/if}
                            </thead>
                            <tbody class="divide-y">
                                {#each table.rows as row}
                                    <tr
                                        class="hover:bg-muted/30 transition-colors"
                                    >
                                        <td class="px-4 py-2">
                                            <Tooltip.Provider delayDuration={0}>
                                                <Tooltip.Root>
                                                    <Tooltip.Trigger>
                                                        {#snippet child({
                                                            props,
                                                        })}
                                                            <button
                                                                {...props}
                                                                onclick={() => {
                                                                    open = false;
                                                                    if (
                                                                        onWaySelect
                                                                    )
                                                                        onWaySelect(
                                                                            row
                                                                                .properties
                                                                                .way_osm_id,
                                                                        );
                                                                }}
                                                                class="text-primary hover:underline font-mono cursor-pointer"
                                                            >
                                                                {row.properties
                                                                    .way_osm_id}
                                                            </button>
                                                        {/snippet}
                                                    </Tooltip.Trigger>
                                                    <Tooltip.Content
                                                        class="z-[1100]"
                                                        >Show on map</Tooltip.Content
                                                    >
                                                </Tooltip.Root>
                                            </Tooltip.Provider>
                                        </td>
                                        <td class="px-4 py-2"
                                            >{row.properties.name &&
                                            typeof row.properties.name ===
                                                "string"
                                                ? row.properties.name
                                                : "-"}</td
                                        >
                                        <td class="px-4 py-2"
                                            >{row.properties.frequency}</td
                                        >
                                        <td class="px-4 py-2"
                                            >{row.properties.is_bus_lane
                                                ? "Yes"
                                                : "No"}</td
                                        >
                                        <td class="px-4 py-2">
                                            {row.properties.n_lanes_circulation}
                                        </td>
                                        <td class="px-4 py-2">
                                            {row.properties.n_lanes_parking}
                                        </td>
                                        <td class="px-4 py-2"
                                            >{row.properties.n_directions}</td
                                        >
                                        <td class="px-4 py-2"
                                            >{row.properties
                                                .n_lanes_circulation_direction}</td
                                        >
                                        {#if rt_data}
                                            <td class="px-4 py-2"
                                                >{row.properties.speed_avg?.toFixed(
                                                    1,
                                                ) || "-"}</td
                                            >
                                            <td class="px-4 py-2"
                                                >{row.properties.speed_median?.toFixed(
                                                    1,
                                                ) || "-"}</td
                                            >
                                            <td class="px-4 py-2"
                                                >{row.properties.speed_p85?.toFixed(
                                                    1,
                                                ) || "-"}</td
                                            >
                                            <td class="px-4 py-2"
                                                >{row.properties
                                                    .speed_count}</td
                                            >
                                            <td class="px-4 py-2"
                                                >{row.properties.disturbance_index !== undefined
                                                    ? `${row.properties.disturbance_index > 0 ? "+" : ""}${(row.properties.disturbance_index * 100).toFixed(1)}%`
                                                    : "-"}</td
                                            >
                                        {/if}
                                        {#if demand_data}
                                            <td class="px-4 py-2"
                                                >{row.properties.demand?.toLocaleString() ||
                                                    "-"}</td
                                            >
                                        {/if}
                                        <td class="px-4 py-2"
                                            >{row.properties.length_m.toFixed(
                                                1,
                                            )}</td
                                        >
                                        <td class="px-4 py-2 max-w-[300px]">
                                            {#if row.properties.shapes && row.properties.shapes.length > 0}
                                                <div
                                                    class="flex flex-wrap gap-1"
                                                >
                                                    {#each row.properties.shapes as shape_id}
                                                        {@const route =
                                                            geoData.shapes[
                                                                shape_id
                                                            ]}
                                                        {@const routeColor =
                                                            route?.route_color
                                                                ? `${route.route_color}`
                                                                : null}
                                                        <Tooltip.Provider
                                                            delayDuration={0}
                                                        >
                                                            <Tooltip.Root>
                                                                <Tooltip.Trigger
                                                                >
                                                                    {#snippet child({
                                                                        props,
                                                                    })}
                                                                        <button
                                                                            {...props}
                                                                            onclick={() => {
                                                                                open = false;
                                                                                if (
                                                                                    onRouteSelect
                                                                                )
                                                                                    onRouteSelect(
                                                                                        shape_id,
                                                                                    );
                                                                            }}
                                                                            class="px-2 py-0.5 text-[10px] font-bold rounded border cursor-pointer hover:brightness-90 transition-all text-left"
                                                                            style={routeColor
                                                                                ? `background-color: ${routeColor}22; border-color: ${routeColor}44; color: ${routeColor};`
                                                                                : ""}
                                                                        >
                                                                            {route?.route_short_name ||
                                                                                shape_id}
                                                                        </button>
                                                                    {/snippet}
                                                                </Tooltip.Trigger>
                                                                <Tooltip.Content
                                                                    class="z-[1100]"
                                                                >
                                                                    <p>
                                                                        {route?.route_short_name}:
                                                                        {route?.route_long_name}
                                                                        ({route?.direction_id
                                                                            ? "DESC"
                                                                            : "ASC"})
                                                                    </p>
                                                                </Tooltip.Content>
                                                            </Tooltip.Root>
                                                        </Tooltip.Provider>
                                                    {/each}
                                                </div>
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
                    </Datatable>
                </div>
            {/if}
        </div>
    </div>
{/if}

<style>
    :global(.svelte-simple-datatable button) {
        white-space: nowrap !important;
        font-weight: bold;
    }
    :global(.svelte-simple-datatable th:nth-child(1)) {
        width: 8rem;
    } /* OSM ID */
    :global(.svelte-simple-datatable th:nth-child(2)) {
        min-width: 200px;
    } /* Name */
    :global(.svelte-simple-datatable th:nth-child(3)) {
        width: 7rem;
    } /* Frequency */
    :global(.svelte-simple-datatable th:nth-child(4)) {
        width: 6rem;
    } /* Bus Lane */
    :global(.svelte-simple-datatable th:nth-child(5)) {
        width: 8rem;
        text-align: center;
    } /* Nr lanes */
    :global(.svelte-simple-datatable th:nth-child(6)) {
        width: 7rem;
        text-align: center;
    } /* Nr directions */
    :global(.svelte-simple-datatable th:nth-child(7)) {
        width: 6rem;
        text-align: center;
    } /* Nr lanes/dir */
    :global(.svelte-simple-datatable th:nth-child(8)) {
        width: 7rem;
    } /* RT Speed or Length */
    :global(.svelte-simple-datatable th:nth-child(9)) {
        width: 8rem;
    } /* RT Speed Count or Routes */
    :global(.svelte-simple-datatable th:nth-last-child(2)) {
        width: 6rem;
    } /* Always Length */
    :global(.svelte-simple-datatable th:last-child) {
        min-width: 300px;
    } /* Always Routes */

    :global(.filter-row th) {
        padding: 4px 6px !important;
        background-color: var(--muted, rgba(120, 120, 120, 0.08)) !important;
    }
    :global(.filter-row input) {
        height: 26px !important;
        font-size: 11px !important;
        padding: 2px 8px !important;
        background-color: var(--background, #fff) !important;
        color: var(--foreground, #000) !important;
        border: 1px solid var(--border, rgba(120, 120, 120, 0.25)) !important;
        border-radius: 4px !important;
        transition: border-color 0.15s, box-shadow 0.15s;
    }
    :global(.filter-row input:focus) {
        border-color: var(--primary, #3b82f6) !important;
        box-shadow: 0 0 0 1px var(--primary, #3b82f6) !important;
    }
    :global(.filter-row input::placeholder) {
        color: var(--muted-foreground, #888) !important;
        font-size: 11px !important;
    }
</style>
