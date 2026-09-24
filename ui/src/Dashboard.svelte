<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import type { Feature } from "geojson";
    import type { GeoPrioritisation } from "./types/GeoPrioritisation";
    import type { DataRegion, RegionLayer } from "./types/DataRegion";
    import type { LineWeightMetric } from "./types/LineWeightMetric";

    import ModalAbout from "./modals/ModalAbout.svelte";
    import LayerBusLanePrioritisation from "./layers/LayerBusLanePrioritisation.svelte";
    import LayerBusLanes from "./layers/LayerBusLanes.svelte";
    import LayerTransitFrequency from "./layers/LayerTransitFrequency.svelte";
    import LayerNumberOfLanes from "./layers/LayerNumberOfLanes.svelte";
    import LayerParkingLanes from "./layers/LayerParkingLanes.svelte";
    import LayerRTSpeed from "./layers/LayerRTSpeed.svelte";
    import LayerRTSpeedMedian from "./layers/LayerRTSpeedMedian.svelte";
    import LayerRTSpeedP75 from "./layers/LayerRTSpeedP75.svelte";
    import LayerDisturbanceIndex from "./layers/LayerDisturbanceIndex.svelte";
    import LayerDemand from "./layers/LayerDemand.svelte";
    import LayerBoundaries from "./layers/LayerBoundaries.svelte";
    import DataCensusTable from "./components/DataCensusTable.svelte";
    import ModalData from "./modals/ModalData.svelte";
    import ModalDetails from "./modals/ModalDetails.svelte";
    import ModalDownload from "./modals/ModalDownload.svelte";
    import PanelRouteDetails from "./panels/PanelRouteDetails.svelte";
    import PanelWayDetails from "./panels/PanelWayDetails.svelte";

    import { Button } from "$lib/components/ui/button/index.js";
    import { Switch } from "$lib/components/ui/switch/index.js";
    import { Input } from "$lib/components/ui/input/index.js";
    import * as Accordion from "$lib/components/ui/accordion/index.js";
    import * as Select from "$lib/components/ui/select/index.js";
    import * as Popover from "$lib/components/ui/popover/index.js";
    import * as Command from "$lib/components/ui/command/index.js";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import Check from "@lucide/svelte/icons/check";
    import ChevronsUpDown from "@lucide/svelte/icons/chevrons-up-down";

    import {
        DB_REGIONS,
        COLOR_YELLOW,
        COLOR_TEAL,
        COLOR_RED,
        COLOR_GRADIENT,
        COLOR_GRADIENT_RED,
        COLOR_GRADIENT_DIVERGING_BRBG,
    } from "./data";
    import Spinner from "$lib/components/ui/spinner/spinner.svelte";
    import {
        DISTURBANCE_INDEX_CATEGORIES,
        getDisturbanceIndex,
        getDisturbanceIndexCategories,
        computeWeightedStatistics,
    } from "./lib/utils";

    // Map
    let { map, light_mode = $bindable() }: { map: L.Map; light_mode: boolean } =
        $props();
    let geoData: GeoPrioritisation | null = $state(null);

    // User feedback
    let loading: string | undefined = $state(undefined);

    // Dashboard state
    enum DisplayOptions {
        PRIORITISATION,
        BUS_LANES,
        FREQUENCY,
        N_LANES,
        PARKING_LANES,
        RT_SPEED,
        DISTURBANCE_INDEX,
        DEMAND,
    }

    type SpeedMetric = "avg" | "median" | "p75";
    let selected_speed_metric: SpeedMetric = $state("avg");

    let region: DataRegion | undefined = $state(undefined);
    let selected_layer: RegionLayer | undefined = $state(undefined);
    let selected_layer_id: string = $state("");
    let boundaryGeoJSON: any = $state(null);
    let show_boundaries: boolean = $state(true);
    let regionSearchQuery: string = $state("");

    const filteredRegions = $derived.by(() => {
        const query = regionSearchQuery.trim().toLowerCase();
        if (!query) return DB_REGIONS;
        return DB_REGIONS.filter(
            (r: DataRegion) =>
                r.name.toLowerCase().includes(query) ||
                r.region.toLowerCase().includes(query),
        );
    });

    let active_layer: DisplayOptions | undefined = $state(undefined);
    let open_accordion: string | undefined = $state(undefined);
    let selected_shape_id: string = $state("all");
    let route_select_open: boolean = $state(false);
    let display_rt: boolean = $state(false); // true if region has rt-data (optional)
    let display_demand: boolean = $state(false); // true if region has demand data (optional)

    let criteria_hour: number = $state(8);
    let criteria_bus_frequency: number = $state(0);
    let criteria_n_lanes_direction: number = $state(2);
    let criteria_n_lanes_parking: number = $state(1);
    let criteria_avg_speed: number | undefined = $state(undefined);
    let criteria_demand: number | undefined = $state(undefined);
    let criteria_bus_frequency_enabled: boolean = $state(true);
    let criteria_n_lanes_direction_enabled: boolean = $state(true);
    let criteria_n_lanes_parking_enabled: boolean = $state(false);
    let criteria_avg_speed_enabled: boolean = $state(true);
    let criteria_demand_enabled: boolean = $state(false);
    let visible_way_ids: string[] = $state([]);
    let line_weight_by: LineWeightMetric = $state("frequency");

    const lineWeightOptions = $derived.by(() => {
        const hourLabel = `${criteria_hour.toString().padStart(2, "0")}:00`;
        const options: Array<{ value: LineWeightMetric; label: string }> = [
            { value: "none", label: "None (uniform width)" },
            { value: "frequency", label: `Bus frequency (at ${hourLabel})` },
            { value: "lanes", label: "Number of lanes" },
        ];
        if (display_rt) {
            options.push({
                value: "speed_avg_min",
                label: "Average speed (slower roads thicker)",
            });
            options.push({
                value: "speed_avg_max",
                label: "Average speed (faster roads thicker)",
            });
            options.push({
                value: "speed_median_min",
                label: "Median speed (slower roads thicker)",
            });
            options.push({
                value: "speed_median_max",
                label: "Median speed (faster roads thicker)",
            });
            options.push({
                value: "speed_p75_min",
                label: "P75 speed (slower roads thicker)",
            });
            options.push({
                value: "speed_p75_max",
                label: "P75 speed (faster roads thicker)",
            });
            options.push({
                value: "disturbance_index",
                label: "Disturbance index (|DI| thicker)",
            });
        }
        if (display_demand) {
            options.push({ value: "demand", label: "Demand" });
        }
        return options;
    });

    const disturbance_index_census = $derived.by(() => {
        if (!geoData || !display_rt) return null;

        const lengthValues: { value: number; weight: number }[] = [];
        const freqValues: { value: number; weight: number }[] = [];

        for (const way of Object.values(geoData.wayData)) {
            const di = getDisturbanceIndex(way, criteria_hour);
            if (di === undefined) continue;

            const length = Number(way.length_m) || 0;
            if (length > 0) {
                lengthValues.push({ value: di, weight: length });
            }

            const freq = Number(way.hour_frequency?.[criteria_hour]) || 0;
            if (freq > 0) {
                freqValues.push({ value: di, weight: freq });
            }
        }

        const census_length = computeWeightedStatistics(lengthValues);
        const census_freq = computeWeightedStatistics(freqValues);

        if (!census_length) return null;

        return {
            census_length,
            census_freq,
        };
    });

    let di_threshold_low: number = $state(5);
    let di_threshold_high: number = $state(20);
    let di_thresholds_auto: boolean = $state(true);
    let di_palette_mode: "categorized" | "diverging" = $state("categorized");
    let di_filter_mode: "all" | "worst" | "best" = $state("all");
    let di_filter_count: number = $state(150);
    let di_filter_count_auto: boolean = $state(true);

    // Auto-calibrate thresholds and filter count based on census
    $effect(() => {
        if (!disturbance_index_census) return;
        const census = disturbance_index_census.census_length;
        if (!census) return;

        if (di_filter_count_auto && census.n) {
            di_filter_count = Math.max(1, Math.round(census.n * 0.05));
        }

        if (di_thresholds_auto) {
            // Low threshold: magnitude around median/P75 (e.g. boundary of mild disturbance)
            // High threshold: magnitude around P25 (e.g. boundary of severe disturbance)
            const autoLow = Math.max(
                1,
                Math.min(
                    15,
                    Math.round(Math.abs(census.p75) * 100) ||
                        Math.round(Math.abs(census.median) * 100) ||
                        5,
                ),
            );
            const autoHigh = Math.max(
                autoLow + 2,
                Math.min(50, Math.round(Math.abs(census.p25) * 100) || 20),
            );

            di_threshold_low = autoLow;
            di_threshold_high = autoHigh;
        }
    });

    let action_hide_form: boolean = $state(false);
    let action_modal_about_open: boolean = $state(false);
    let action_modal_data_open: boolean = $state(false);
    let action_modal_details_open: boolean = $state(false);
    let action_modal_download_open: boolean = $state(false);
    let any_modal_open: boolean = $derived(
        action_modal_about_open ||
            action_modal_data_open ||
            action_modal_details_open ||
            action_modal_download_open,
    );

    let selectedWayId: string | undefined = $state(undefined);

    // Clear way selection when a modal is opened
    $effect(() => {
        if (
            action_modal_about_open ||
            action_modal_data_open ||
            action_modal_details_open ||
            action_modal_download_open
        ) {
            untrack(() => {
                selectedWayId = undefined;
            });
        }
    });

    // Clear way selection when clicking on empty map area
    $effect(() => {
        if (!map) return;
        const onClick = () => {
            selectedWayId = undefined;
        };
        map.on("click", onClick);
        return () => {
            map.off("click", onClick);
        };
    });

    // Action handlers
    const handleLayerCreate = (layer: L.Layer) => {};
    const handleVisibleWayIdsChange = (wayIds: string[]) => {
        visible_way_ids = wayIds;
    };

    const handleLayerChange = async (layerId: string) => {
        if (!region || !layerId) return;

        const targetLayer = region.layers.find((l) => l.id === layerId);
        if (!targetLayer) return;

        selected_layer = targetLayer;
        selected_layer_id = targetLayer.id;

        active_layer = undefined;
        open_accordion = undefined;
        selected_speed_metric = "avg";
        selected_shape_id = "all";
        visible_way_ids = [];
        geoData = null;
        display_rt = false;
        display_demand = false;
        loading = "data for " + region.name + " (" + selected_layer.name + ")";

        try {
            // Fetch and load new data model components
            const fetchPromises: Promise<Response>[] = [
                fetch(selected_layer.files.ways),
                fetch(selected_layer.files.way_data),
                fetch(selected_layer.files.metadata),
                fetch(selected_layer.files.route_data),
                fetch(selected_layer.files.shape_data),
            ];

            if (selected_layer.files.boundaries) {
                fetchPromises.push(fetch(selected_layer.files.boundaries));
            }

            const results = await Promise.all(fetchPromises);

            const ways = await results[0].json();
            const wayData = await results[1].json();
            const metadata = await results[2].json();
            const routeData = await results[3].json();
            const shapeData = await results[4].json();

            if (selected_layer.files.boundaries && results[5]) {
                boundaryGeoJSON = await results[5].json();
            } else {
                boundaryGeoJSON = null;
            }

            geoData = {
                features: ways.features,
                wayData: wayData,
                metadata: metadata,
                routes: routeData,
                shapes: shapeData,
            } as GeoPrioritisation;
            console.log("geoData", geoData);

            display_rt = Object.values(geoData.wayData).some(
                (data: any) =>
                    data.speed_avg !== undefined && data.speed_avg !== null,
            );
            display_demand = Object.values(geoData.wayData).some(
                (data: any) => {
                    const demandValue = Number(data.demand);
                    return data.demand !== null && !Number.isNaN(demandValue);
                },
            );

            // Set criteria base values
            criteria_hour = 8;
            criteria_n_lanes_direction = 2;
            criteria_n_lanes_parking = 1;
            criteria_bus_frequency =
                geoData.metadata.data_census.frequency.median_below_p85;
            criteria_avg_speed = Math.floor(
                geoData.metadata.data_census.speed_avg_length
                    ?.median_below_p85 ?? 0,
            );
            criteria_demand = Math.floor(
                geoData.metadata.data_census.demand_length?.median_below_p85 ??
                    0,
            );
            criteria_bus_frequency_enabled = true;
            criteria_n_lanes_direction_enabled = true;
            criteria_n_lanes_parking_enabled = false;
            criteria_avg_speed_enabled = display_rt;
            criteria_demand_enabled = display_demand;
            line_weight_by = "speed_p75_min";
            const defaultLayer = display_rt
                ? DisplayOptions.DISTURBANCE_INDEX
                : DisplayOptions.PRIORITISATION;
            active_layer = defaultLayer;
            open_accordion = defaultLayer.toString();

            console.log("Loaded GeoJSON for layer:", selected_layer.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
        }
    };

    const handleRegionChange = async (regionId: string) => {
        if (!regionId) return;

        action_modal_about_open = false;
        action_modal_data_open = false;
        action_modal_details_open = false;
        action_modal_download_open = false;

        region = DB_REGIONS.find((r: DataRegion) => r.id === regionId);
        if (!region || !map) return;

        selected_layer = undefined;
        selected_layer_id = "";

        if (region.layers && region.layers.length === 1) {
            await handleLayerChange(region.layers[0].id);
        }
    };

    // Effect to zoom to selected route
    $effect(() => {
        if (
            !selected_shape_id ||
            selected_shape_id === "all" ||
            !map ||
            !geoData
        )
            return;

        console.log("Filtering by shape:", selected_shape_id);

        // Deselect prioritisation filters when a specific route is selected
        if (selected_shape_id && selected_shape_id !== "all") {
            untrack(() => {
                criteria_bus_frequency_enabled = false;
                criteria_n_lanes_direction_enabled = false;
                criteria_n_lanes_parking_enabled = false;
                if (display_rt) criteria_avg_speed_enabled = false;
                if (display_demand) criteria_demand_enabled = false;
            });
        } else if (selected_shape_id == "all") {
            untrack(() => {
                criteria_bus_frequency_enabled = true;
                criteria_n_lanes_direction_enabled = true;
                criteria_n_lanes_parking_enabled = false;
                if (display_rt) criteria_avg_speed_enabled = true;
                if (display_demand) criteria_demand_enabled = true;
            });
        }
    });

    $effect(() => {
        if (lineWeightOptions.find((o) => o.value === line_weight_by)) return;
        line_weight_by = "speed_p75_min";
    });

    const routeOptions = $derived.by(() => {
        const data = geoData;
        if (!data || !data.shapes) return [];
        return Object.keys(data.shapes)
            .map((s: string) => ({
                id: s,
                label: `${data.shapes[s].route_short_name}: ${data.shapes[s].route_long_name} (${data.shapes[s].direction_id ? "DESC" : "ASC"})`,
                short_name: data.shapes[s].route_short_name,
                color: data.shapes[s].route_color,
            }))
            .sort((a, b) =>
                a.label.localeCompare(b.label, undefined, {
                    numeric: true,
                }),
            );
    });
</script>

<svelte:head>
    <script
        src="https://kit.fontawesome.com/17e93d90c5.js"
        crossorigin="anonymous"
    ></script>
</svelte:head>

<div
    id="controls-panel"
    class="absolute top-4 left-4 z-[1010] flex flex-col items-start w-[calc(100vw-2rem)] sm:w-[350px] max-h-[70vh] sm:max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-4 overflow-y-auto h-fit"
    style={"background-image: url('./static/logo/background_blur_transparent.png'); background-size: auto 7vw; background-position: top right; background-repeat: no-repeat;"}
>
    <!-- Title -->
    <div class="w-full text-left mb-4">
        <div class="flex items-center gap-2 mb-1">
            <h3 class="text-xl font-bold text-primary m-0">GTFShift</h3>
            <Tooltip.Provider delayDuration={0}>
                <Tooltip.Root>
                    <Tooltip.Trigger>
                        {#snippet child({ props })}
                            <button
                                {...props}
                                class="text-muted-foreground hover:text-foreground cursor-pointer"
                                onclick={(e) => {
                                    e.preventDefault();
                                    action_modal_data_open = false;
                                    action_modal_details_open = false;
                                    action_modal_download_open = false;
                                    action_modal_about_open =
                                        !action_modal_about_open;
                                }}
                                aria-label="About"
                            >
                                <i class="fas fa-info-circle"></i>
                            </button>
                        {/snippet}
                    </Tooltip.Trigger>
                    <Tooltip.Content class="z-[1100]">About</Tooltip.Content>
                </Tooltip.Root>
            </Tooltip.Provider>
        </div>
        <p class="text-sm text-muted-foreground">
            Bus lane prioritisation tool<br /><b>TML edition</b>
        </p>
        {#if loading}
            <p
                class="flex items-center gap-2 text-xs text-muted-foreground animate-pulse mt-2"
            >
                <Spinner /> Loading {loading}...
            </p>
        {/if}
    </div>

    <!-- Form 1: Select region -->
    {#if region === undefined}
        <div class="w-full text-left mb-4">
            <h5 class="text-sm font-semibold text-primary mb-1">Data source</h5>
            <p class="text-xs text-muted-foreground mb-2">
                Select the region you want to analyse
            </p>

            <!-- Search bar -->
            <div class="relative w-full mb-3 mt-2">
                <i
                    class="fas fa-search absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground text-xs pointer-events-none"
                ></i>
                <Input
                    type="text"
                    placeholder="Search region by name or location..."
                    class="pl-9 pr-8 py-1 h-9 text-xs bg-background/50 focus-visible:ring-1 focus-visible:ring-primary/50"
                    bind:value={regionSearchQuery}
                />
                {#if regionSearchQuery}
                    <button
                        type="button"
                        class="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground p-0.5 rounded-full hover:bg-muted/50 transition-colors cursor-pointer"
                        onclick={() => (regionSearchQuery = "")}
                        aria-label="Clear search"
                    >
                        <i class="fas fa-times text-[10px]"></i>
                    </button>
                {/if}
            </div>

            <div class="flex flex-col gap-2 mt-3">
                {#each filteredRegions as r}
                    {@const peak = r.layers[0]?.matched_frequencies_peak}
                    <button
                        class="group relative w-full text-left rounded-xl border border-border bg-background transition-all duration-200 p-3 overflow-hidden disabled:opacity-50 disabled:cursor-not-allowed shadow-sm hover:shadow-md"
                        onclick={() => handleRegionChange(r.id)}
                        disabled={loading !== undefined}
                        style="cursor: pointer;"
                        onmouseenter={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = r.color ?? "";
                            el.style.backgroundColor = (r.color ?? "") + "0d";
                            el.querySelector<HTMLElement>(
                                ".region-icon",
                            )!.style.backgroundColor = (r.color ?? "") + "33";
                            el.querySelector<HTMLElement>(
                                ".region-chevron",
                            )!.style.color = r.color ?? "";
                            el.querySelector<HTMLElement>(
                                ".region-accent",
                            )!.style.transform = "scaleX(1)";
                        }}
                        onmouseleave={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = "";
                            el.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".region-icon",
                            )!.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".region-chevron",
                            )!.style.color = "";
                            el.querySelector<HTMLElement>(
                                ".region-accent",
                            )!.style.transform = "scaleX(0)";
                        }}
                    >
                        <div class="flex items-start gap-3">
                            <div
                                class="region-icon mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg transition-colors overflow-hidden"
                                style="background-color: {r.color}1a; color: {r.color};"
                            >
                                {#if r.logo}
                                    <img
                                        src={r.logo}
                                        alt={r.name}
                                        class="h-5 w-5 object-contain grayscale brightness-0 dark:invert"
                                    />
                                {:else}
                                    <i class="fas fa-map-location-dot text-sm"
                                    ></i>
                                {/if}
                            </div>
                            <div class="flex-1 min-w-0">
                                <p
                                    class="text-sm font-semibold text-foreground leading-tight"
                                >
                                    {r.name}
                                </p>
                                <p class="text-xs text-muted-foreground mt-0.5">
                                    <i class="fas fa-map-marker-alt mr-1"></i>
                                    {r.region}
                                </p>
                                <p class="text-xs text-muted-foreground mt-0.5">
                                    <i class="fas fa-calendar-alt mr-1"
                                    ></i>{r.date}
                                </p>
                                {#if r.rt_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-traffic-light mr-1"
                                        ></i> With traffic conditions
                                    </p>
                                {:else}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-road mr-1"></i> Static analysis
                                    </p>
                                {/if}

                                {#if r.demand_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-people-group mr-1"></i>
                                        With passenger demand data
                                    </p>
                                {/if}

                                {#if peak !== undefined}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-chart-simple mr-1"></i>
                                        {peak}% of services matched (at peak)
                                    </p>
                                {/if}
                            </div>
                            <i
                                class="region-chevron fas fa-chevron-right text-xs text-muted-foreground transition-colors mt-1"
                            ></i>
                        </div>
                        <!-- Accent line at bottom on hover -->
                        <div
                            class="region-accent absolute bottom-0 left-0 right-0 h-[2px] transition-transform duration-200 origin-left rounded-b-xl"
                            style="background-color: {r.color}; transform: scaleX(0);"
                        ></div>
                    </button>
                {/each}

                {#if filteredRegions.length === 0}
                    <div
                        class="text-center py-6 border border-dashed rounded-xl bg-muted/20"
                    >
                        <i
                            class="fas fa-map-marked-alt text-muted-foreground text-xl mb-2 block opacity-50"
                        ></i>
                        <p class="text-xs font-semibold text-foreground">
                            No regions found
                        </p>
                        <p class="text-[10px] text-muted-foreground mt-0.5">
                            Try searching for a different name or location
                        </p>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 text-[10px] px-2.5 mt-3 gap-1 cursor-pointer"
                            onclick={() => (regionSearchQuery = "")}
                        >
                            <i class="fas fa-undo text-[9px]"></i> Reset Search
                        </Button>
                    </div>
                {/if}
            </div>
        </div>
    {/if}

    <!-- Form 1.5: Select Layer -->
    {#if region !== undefined && selected_layer === undefined && region.layers && region.layers.length > 1}
        <div class="w-full text-left mb-4">
            <div class="flex items-center gap-2 mb-3">
                {#if region.logo}
                    <img
                        src={region.logo}
                        alt={region.name}
                        class="h-6 w-6 object-contain"
                    />
                {/if}
                <h5 class="text-lg font-semibold text-primary mb-1">
                    {region.name}
                </h5>
            </div>
            <p class="text-xs text-muted-foreground mb-4">
                Select a dataset/layer to begin analysis:
            </p>

            <div class="flex flex-col gap-2 mt-3">
                {#each region.layers as layer}
                    <button
                        class="group relative w-full text-left rounded-xl border border-border bg-background transition-all duration-200 p-3 overflow-hidden shadow-sm hover:shadow-md cursor-pointer"
                        onclick={() => handleLayerChange(layer.id)}
                        disabled={loading !== undefined}
                        onmouseenter={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = region?.color ?? "";
                            el.style.backgroundColor =
                                (region?.color ?? "") + "0d";
                            el.querySelector<HTMLElement>(
                                ".layer-accent",
                            )!.style.transform = "scaleX(1)";
                        }}
                        onmouseleave={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = "";
                            el.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".layer-accent",
                            )!.style.transform = "scaleX(0)";
                        }}
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="flex-1 min-w-0">
                                <p
                                    class="text-sm font-semibold text-foreground leading-tight"
                                >
                                    {layer.name}
                                </p>
                                <p class="text-xs text-muted-foreground mt-1">
                                    <i class="fas fa-calendar-alt mr-1"></i>
                                    {layer.date}
                                </p>
                                {#if layer.rt_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-traffic-light mr-1"
                                        ></i> With traffic conditions
                                    </p>
                                {:else}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-road mr-1"></i> Static analysis
                                    </p>
                                {/if}
                                {#if layer.demand_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-people-group mr-1"></i>
                                        With passenger demand data
                                    </p>
                                {/if}
                                {#if layer.matched_frequencies_peak}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-chart-simple mr-1"></i>
                                        {layer.matched_frequencies_peak}% of
                                        services matched (at peak)
                                    </p>
                                {/if}
                            </div>
                            <i
                                class="fas fa-chevron-right text-xs text-muted-foreground mt-1 group-hover:text-primary transition-colors"
                            ></i>
                        </div>
                        <div
                            class="layer-accent absolute bottom-0 left-0 right-0 h-[2px] transition-transform duration-200 origin-left rounded-b-xl"
                            style="background-color: {region.color}; transform: scaleX(0);"
                        ></div>
                    </button>
                {/each}
            </div>

            <!-- Back button to regions -->
            <Button
                variant="outline"
                size="sm"
                onclick={() => {
                    region = undefined;
                    selected_layer = undefined;
                    selected_layer_id = "";
                }}
                disabled={loading !== undefined}
                class="w-full mt-4"
            >
                <i class="fa-solid fa-arrow-left mr-2"></i> Back to Regions
            </Button>
        </div>
    {/if}

    <!-- Form 2: Region display options -->
    {#if region !== undefined && geoData && !action_hide_form}
        <div class="w-full text-left flex-1" id="form">
            <div class="flex items-center gap-2">
                <img
                    src={region.logo}
                    alt={region.name}
                    class="h-5 w-5 object-contain"
                />
                <h5 class="text-lg font-semibold text-primary mb-1">
                    {region.name}
                </h5>
            </div>
            <div
                class="flex items-center gap-3 text-sm text-muted-foreground mb-4"
            >
                <p class="mr-auto">
                    <i class="fas fa-map-marker-alt mr-1"></i>
                    {region.region}<br />
                    <i class="fas fa-calendar-alt mr-1"></i>
                    {selected_layer?.date ?? region.date}
                    {#if selected_layer?.notes}
                        <br />
                        <span
                            class="text-[11px] italic mt-1 block leading-tight"
                        >
                            <i class="fas fa-circle-info mr-1"></i>
                            {selected_layer.notes}
                        </span>
                    {/if}
                </p>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <button
                                    {...props}
                                    class="hover:text-foreground cursor-pointer"
                                    onclick={(e) => {
                                        e.preventDefault();
                                        action_modal_about_open = false;
                                        action_modal_details_open = false;
                                        action_modal_download_open = false;
                                        action_modal_data_open =
                                            !action_modal_data_open;
                                    }}
                                    aria-label="Attribute table"
                                >
                                    <i class="fas fa-table"></i>
                                </button>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Attribute table</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <button
                                    {...props}
                                    class="hover:text-foreground cursor-pointer"
                                    onclick={(e) => {
                                        e.preventDefault();
                                        action_modal_about_open = false;
                                        action_modal_data_open = false;
                                        action_modal_download_open = false;
                                        action_modal_details_open =
                                            !action_modal_details_open;
                                    }}
                                    aria-label="Details"
                                >
                                    <i class="fas fa-code"></i>
                                </button>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Details</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <button
                                    {...props}
                                    class="hover:text-foreground cursor-pointer"
                                    onclick={(e) => {
                                        e.preventDefault();
                                        action_modal_about_open = false;
                                        action_modal_data_open = false;
                                        action_modal_details_open = false;
                                        action_modal_download_open =
                                            !action_modal_download_open;
                                    }}
                                    aria-label="Download raw data"
                                >
                                    <i class="fas fa-download"></i>
                                </button>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Download raw data</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
            </div>

            {#if region.layers && region.layers.length > 1}
                <div class="w-full mb-6">
                    <h5
                        class="text-xs font-semibold text-muted-foreground mb-2 uppercase tracking-wider"
                    >
                        Active Layer / Dataset
                    </h5>
                    <Select.Root
                        type="single"
                        bind:value={selected_layer_id}
                        onValueChange={(val) => {
                            if (val) handleLayerChange(val);
                        }}
                    >
                        <Select.Trigger
                            class="w-full justify-between bg-background/50 hover:bg-accent transition-colors border text-left"
                        >
                            <span class="truncate">
                                {region.layers.find(
                                    (l) => l.id === selected_layer_id,
                                )?.name ?? "Select active layer"}
                            </span>
                        </Select.Trigger>
                        <Select.Content class="z-[1100]">
                            {#each region.layers as layer}
                                <Select.Item
                                    value={layer.id}
                                    label={layer.name}
                                >
                                    {layer.name}
                                </Select.Item>
                            {/each}
                        </Select.Content>
                    </Select.Root>
                </div>
            {/if}

            <div class="w-full mb-6">
                <h5
                    class="text-xs font-semibold text-muted-foreground mb-2 uppercase tracking-wider"
                >
                    Filter by Route
                </h5>
                <Popover.Root bind:open={route_select_open}>
                    <Popover.Trigger class="w-full">
                        <div
                            class="flex items-center justify-between w-full border rounded-md px-3 py-2 text-sm bg-background/50 hover:bg-accent transition-colors"
                        >
                            <div class="flex items-center gap-2">
                                {#if selected_shape_id === "all"}
                                    <div
                                        class="w-2 h-2 rounded-full bg-muted-foreground shrink-0"
                                    ></div>
                                    <span>All Network</span>
                                {:else}
                                    {@const opt = routeOptions.find(
                                        (o) => o.id === selected_shape_id,
                                    )}
                                    {#if opt}
                                        <div
                                            class="w-2 h-2 rounded-full shrink-0"
                                            style="background-color: {opt.color}"
                                        ></div>
                                        <span class="font-medium text-left"
                                            >{opt.label}</span
                                        >
                                    {:else}
                                        <span>Select Route</span>
                                    {/if}
                                {/if}
                            </div>
                            <ChevronsUpDown
                                class="size-4 opacity-50 shrink-0 ml-2"
                            />
                        </div>
                    </Popover.Trigger>
                    <Popover.Content class="w-[316px] p-0 z-[1100]">
                        <Command.Root>
                            <Command.Input placeholder="Search route..." />
                            <Command.List
                                class="max-h-[300px] overflow-y-auto overflow-x-hidden"
                            >
                                <Command.Empty>No route found.</Command.Empty>
                                <Command.Group>
                                    <Command.Item
                                        value="all"
                                        onSelect={() => {
                                            selected_shape_id = "all";
                                            route_select_open = false;
                                        }}
                                        class="flex items-center justify-between py-2 px-3 cursor-pointer hover:bg-accent rounded-sm"
                                    >
                                        <div class="flex items-center gap-3">
                                            <div
                                                class="w-2.5 h-2.5 rounded-full bg-muted-foreground shrink-0"
                                            ></div>
                                            <span class="font-medium"
                                                >All Network</span
                                            >
                                        </div>
                                        {#if selected_shape_id === "all"}
                                            <Check
                                                class="size-4 text-primary shrink-0"
                                            />
                                        {/if}
                                    </Command.Item>
                                </Command.Group>
                                <Command.Separator />
                                <Command.Group heading="Routes">
                                    {#each routeOptions as opt}
                                        <Command.Item
                                            value={opt.label}
                                            onSelect={() => {
                                                selected_shape_id = opt.id;
                                                route_select_open = false;
                                            }}
                                            class="flex items-center justify-between py-2 px-3 cursor-pointer hover:bg-accent rounded-sm"
                                        >
                                            <div
                                                class="flex items-center gap-3"
                                            >
                                                <div
                                                    class="w-2.5 h-2.5 rounded-full shrink-0"
                                                    style="background-color: {opt.color}"
                                                ></div>
                                                <span class="font-medium"
                                                    >{opt.label}</span
                                                >
                                            </div>
                                            {#if selected_shape_id === opt.id}
                                                <Check
                                                    class="size-4 text-primary shrink-0 ml-2"
                                                />
                                            {/if}
                                        </Command.Item>
                                    {/each}
                                </Command.Group>
                            </Command.List>
                        </Command.Root>
                    </Popover.Content>
                </Popover.Root>
            </div>

            <div class="w-full mb-6">
                <h5
                    class="text-xs font-semibold text-muted-foreground mb-2 uppercase tracking-wider"
                >
                    Line Weight
                </h5>
                <Select.Root type="single" bind:value={line_weight_by}>
                    <Select.Trigger
                        class="w-full justify-between bg-background/50 hover:bg-accent transition-colors border text-left"
                    >
                        <span class="truncate"
                            >{lineWeightOptions.find(
                                (o) => o.value === line_weight_by,
                            )?.label ?? "Bus frequency"}</span
                        >
                    </Select.Trigger>
                    <Select.Content class="z-[1100]">
                        {#each lineWeightOptions as option}
                            <Select.Item
                                value={option.value}
                                label={option.label}>{option.label}</Select.Item
                            >
                        {/each}
                    </Select.Content>
                </Select.Root>
            </div>

            <p class="text-xs font-medium text-muted-foreground mb-2">
                Explore the different layers below
            </p>

            <Accordion.Root
                type="single"
                value={open_accordion}
                onValueChange={(v: string | undefined) => {
                    open_accordion = v;
                    if (v) active_layer = parseInt(v);
                }}
                class="w-full"
            >
                {#if display_rt}
                    <Accordion.Item
                        value={DisplayOptions.DISTURBANCE_INDEX.toString()}
                    >
                        <Accordion.Trigger
                            class="text-sm font-medium hover:no-underline"
                            >Disturbance index</Accordion.Trigger
                        >
                        <Accordion.Content>
                            <div
                                class="text-xs text-muted-foreground space-y-3 pt-2"
                            >
                                <p>
                                    Disturbance Index (<span
                                        class="font-mono bg-muted px-1.5 py-0.5 rounded text-xs"
                                        >DI</span
                                    >) measures the relative difference between
                                    hourly median speed (at
                                    <span class="font-semibold"
                                        >{criteria_hour
                                            .toString()
                                            .padStart(2, "0")}:00</span
                                    >) and baseline 75th percentile speed (<span
                                        class="font-mono bg-muted px-1.5 py-0.5 rounded text-xs"
                                        >speed_P75</span
                                    >):
                                </p>
                                <div
                                    class="bg-muted/40 p-2.5 rounded-lg border border-border/40 text-center my-2 flex items-center justify-center gap-2 select-none"
                                >
                                    <span
                                        class="font-serif italic font-medium text-sm text-foreground"
                                        >DI<sub>{criteria_hour}h</sub></span
                                    >
                                    <span
                                        class="text-sm font-normal text-muted-foreground"
                                        >=</span
                                    >
                                    <div
                                        class="inline-flex flex-col items-center justify-center text-xs"
                                    >
                                        <span
                                            class="font-serif italic pb-0.5 px-1.5 text-foreground"
                                        >
                                            v&#772;<sub
                                                >median,{criteria_hour}h</sub
                                            >
                                            &minus; v<sub>P75</sub>
                                        </span>
                                        <span
                                            class="w-full border-t border-foreground/60"
                                        ></span>
                                        <span
                                            class="font-serif italic pt-0.5 px-1.5 text-foreground"
                                        >
                                            v<sub>P75</sub>
                                        </span>
                                    </div>
                                </div>
                                <div class="flex items-center gap-2 pt-1">
                                    <span
                                        >Disturbance Index for <Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={criteria_hour}
                                            min="0"
                                            max="23"
                                        />:00 hour</span
                                    >
                                </div>

                                <div
                                    class="flex items-center gap-1 p-1 bg-muted/70 rounded-full border border-border/40 w-full"
                                >
                                    <button
                                        type="button"
                                        class="flex-1 py-1 px-2.5 rounded-full text-xs font-medium transition-all text-center cursor-pointer {di_palette_mode ===
                                        'categorized'
                                            ? 'bg-background text-foreground shadow-xs font-semibold'
                                            : 'text-muted-foreground hover:text-foreground hover:bg-background/40'}"
                                        onclick={() =>
                                            (di_palette_mode = "categorized")}
                                    >
                                        Categorized
                                    </button>
                                    <button
                                        type="button"
                                        class="flex-1 py-1 px-2.5 rounded-full text-xs font-medium transition-all text-center cursor-pointer {di_palette_mode ===
                                        'diverging'
                                            ? 'bg-background text-foreground shadow-xs font-semibold'
                                            : 'text-muted-foreground hover:text-foreground hover:bg-background/40'}"
                                        onclick={() =>
                                            (di_palette_mode = "diverging")}
                                    >
                                        Diverging
                                    </button>
                                </div>

                                <div
                                    class="p-2.5 bg-muted/30 rounded-lg border border-border/40 space-y-2"
                                >
                                    <div
                                        class="flex items-center justify-between"
                                    >
                                        <span
                                            class="font-medium text-foreground text-xs"
                                            >Filter Performers</span
                                        >
                                        {#if di_filter_mode !== "all"}
                                            <div
                                                class="flex items-center gap-1"
                                            >
                                                <span
                                                    class="text-[11px] text-muted-foreground"
                                                    >Top</span
                                                >
                                                <Input
                                                    type="number"
                                                    class="w-16 h-6 text-xs text-center px-1"
                                                    bind:value={di_filter_count}
                                                    min="1"
                                                    max={disturbance_index_census?.census_length?.n || 5000}
                                                    oninput={() =>
                                                        (di_filter_count_auto =
                                                            false)}
                                                />
                                            </div>
                                        {/if}
                                    </div>
                                    <div
                                        class="flex items-center gap-1 p-0.5 bg-muted/60 rounded-md border border-border/40 w-full"
                                    >
                                        <button
                                            type="button"
                                            class="flex-1 py-1 px-2 rounded text-xs font-medium transition-all text-center cursor-pointer {di_filter_mode ===
                                            'all'
                                                ? 'bg-background text-foreground shadow-xs font-semibold'
                                                : 'text-muted-foreground hover:text-foreground hover:bg-background/30'}"
                                            onclick={() =>
                                                (di_filter_mode = "all")}
                                        >
                                            All
                                        </button>
                                        <button
                                            type="button"
                                            class="flex-1 py-1 px-2 rounded text-xs font-medium transition-all text-center cursor-pointer {di_filter_mode ===
                                            'worst'
                                                ? 'bg-background text-destructive shadow-xs font-semibold'
                                                : 'text-muted-foreground hover:text-destructive hover:bg-background/30'}"
                                            onclick={() =>
                                                (di_filter_mode = "worst")}
                                            title="Filter slowest roads relative to baseline"
                                        >
                                            Worst {di_filter_count}
                                        </button>
                                        <button
                                            type="button"
                                            class="flex-1 py-1 px-2 rounded text-xs font-medium transition-all text-center cursor-pointer {di_filter_mode ===
                                            'best'
                                                ? 'bg-background text-teal-600 dark:text-teal-400 shadow-xs font-semibold'
                                                : 'text-muted-foreground hover:text-teal-600 dark:hover:text-teal-400 hover:bg-background/30'}"
                                            onclick={() =>
                                                (di_filter_mode = "best")}
                                            title="Filter fastest roads relative to baseline"
                                        >
                                            Best {di_filter_count}
                                        </button>
                                    </div>
                                </div>

                                {#if di_palette_mode === "categorized"}
                                    <div
                                        class="p-2.5 bg-muted/30 rounded-lg border border-border/40 space-y-2"
                                    >
                                        <div
                                            class="flex items-center justify-between"
                                        >
                                            <span
                                                class="font-medium text-foreground text-xs"
                                                >Disturbance Thresholds</span
                                            >
                                            <label
                                                class="flex items-center gap-1.5 cursor-pointer text-[11px] text-muted-foreground"
                                            >
                                                <Switch
                                                    checked={di_thresholds_auto}
                                                    onCheckedChange={(
                                                        v: boolean,
                                                    ) =>
                                                        (di_thresholds_auto =
                                                            v)}
                                                    class="scale-75"
                                                />
                                                Auto (percentiles)
                                            </label>
                                        </div>
                                        <div
                                            class="grid grid-cols-2 gap-2 pt-0.5"
                                        >
                                            <div>
                                                <span
                                                    class="text-[10px] text-muted-foreground block mb-0.5"
                                                    >Regular tolerance (±%)</span
                                                >
                                                <div
                                                    class="flex items-center gap-1"
                                                >
                                                    <span
                                                        class="text-xs text-muted-foreground"
                                                        >±</span
                                                    >
                                                    <Input
                                                        type="number"
                                                        class="h-7 text-xs text-center"
                                                        bind:value={
                                                            di_threshold_low
                                                        }
                                                        min="1"
                                                        max="50"
                                                        oninput={() =>
                                                            (di_thresholds_auto = false)}
                                                    />
                                                    <span
                                                        class="text-xs text-muted-foreground"
                                                        >%</span
                                                    >
                                                </div>
                                            </div>
                                            <div>
                                                <span
                                                    class="text-[10px] text-muted-foreground block mb-0.5"
                                                    >Severe cutoff (±%)</span
                                                >
                                                <div
                                                    class="flex items-center gap-1"
                                                >
                                                    <span
                                                        class="text-xs text-muted-foreground"
                                                        >±</span
                                                    >
                                                    <Input
                                                        type="number"
                                                        class="h-7 text-xs text-center"
                                                        bind:value={
                                                            di_threshold_high
                                                        }
                                                        min="2"
                                                        max="90"
                                                        oninput={() =>
                                                            (di_thresholds_auto = false)}
                                                    />
                                                    <span
                                                        class="text-xs text-muted-foreground"
                                                        >%</span
                                                    >
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="space-y-1.5 pt-1">
                                        {#each getDisturbanceIndexCategories(di_threshold_low / 100, di_threshold_high / 100) as cat}
                                            <div
                                                class="flex items-center justify-between text-xs"
                                            >
                                                <div
                                                    class="flex items-center gap-2"
                                                >
                                                    <span
                                                        class="w-3 h-3 rounded-sm inline-block"
                                                        style="background-color: {cat.color}"
                                                    ></span>
                                                    <span
                                                        class="font-medium text-foreground"
                                                        >{cat.label}</span
                                                    >
                                                </div>
                                                <span
                                                    class="text-muted-foreground font-mono"
                                                    >{cat.rangeLabel}</span
                                                >
                                            </div>
                                        {/each}
                                    </div>
                                {:else}
                                    <div class="space-y-2 pt-1">
                                        <div
                                            class="flex justify-between items-center text-[11px] text-muted-foreground"
                                        >
                                            <span>Slower (Brown)</span>
                                            <span>Baseline (0%)</span>
                                            <span>Faster (Teal)</span>
                                        </div>
                                        <div
                                            class="w-full h-3.5 rounded border border-border/40 shadow-2xs"
                                            style="background: linear-gradient(to right, {COLOR_GRADIENT_DIVERGING_BRBG.join(
                                                ', ',
                                            )});"
                                        ></div>
                                        <div
                                            class="flex justify-between items-center text-xs font-mono text-muted-foreground"
                                        >
                                            <span
                                                >&le; -{Math.max(
                                                    di_threshold_high,
                                                    25,
                                                )}%</span
                                            >
                                            <span>0%</span>
                                            <span
                                                >&ge; +{Math.max(
                                                    di_threshold_high,
                                                    25,
                                                )}%</span
                                            >
                                        </div>
                                    </div>
                                {/if}

                                {#if disturbance_index_census}
                                    <DataCensusTable
                                        census_1={disturbance_index_census.census_length}
                                        census_2={disturbance_index_census.census_freq}
                                        census_1_label="Length"
                                        census_2_label="Frequency"
                                    />
                                {/if}
                            </div>
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}

                <Accordion.Item
                    value={DisplayOptions.PRIORITISATION.toString()}
                >
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Bus lane prioritisation</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-4 pt-2"
                        >
                            <p>
                                Display road segments coloured by bus lane
                                prioritisation criteria:
                                <Tooltip.Provider delayDuration={0}>
                                    <Tooltip.Root>
                                        <Tooltip.Trigger>
                                            {#snippet child({ props })}
                                                <i
                                                    {...props}
                                                    class="fa fa-circle-info ml-1 text-muted-foreground hover:text-foreground"
                                                ></i>
                                            {/snippet}
                                        </Tooltip.Trigger>
                                        <Tooltip.Content class="z-[1100]"
                                            >Frequency, speed and demand
                                            initially set to median values below
                                            the 85th percentile</Tooltip.Content
                                        >
                                    </Tooltip.Root>
                                </Tooltip.Provider>
                            </p>
                            <ul class="space-y-3 mb-3">
                                <li class="flex items-center gap-2">
                                    <Switch
                                        checked={criteria_bus_frequency_enabled}
                                        onCheckedChange={(v: boolean) =>
                                            (criteria_bus_frequency_enabled =
                                                v)}
                                        class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                    />
                                    <span
                                        >Bus frequencies for <Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={criteria_hour}
                                            min="0"
                                            max="23"
                                            disabled={!criteria_bus_frequency_enabled}
                                        />:00 hour with <Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={criteria_bus_frequency}
                                            min="1"
                                            disabled={!criteria_bus_frequency_enabled}
                                        /> or + buses/hour</span
                                    >
                                </li>
                                <li class="flex items-center gap-2">
                                    <Switch
                                        checked={criteria_n_lanes_direction_enabled}
                                        onCheckedChange={(v: boolean) =>
                                            (criteria_n_lanes_direction_enabled =
                                                v)}
                                        class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                    />
                                    <span
                                        ><Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={
                                                criteria_n_lanes_direction
                                            }
                                            min="1"
                                            disabled={!criteria_n_lanes_direction_enabled}
                                        /> or + lanes/direction</span
                                    >
                                </li>
                                <!--
                                <li class="flex items-center gap-2">
                                    <Switch
                                        checked={criteria_n_lanes_parking_enabled}
                                        onCheckedChange={(v: boolean) =>
                                            (criteria_n_lanes_parking_enabled =
                                                v)}
                                        class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                    />
                                    <span
                                        ><Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={
                                                criteria_n_lanes_parking
                                            }
                                            min="1"
                                            disabled={!criteria_n_lanes_parking_enabled}
                                        /> or + lanes/parking</span
                                    >
                                </li>
                                -->
                                {#if display_rt}
                                    <li class="flex items-center gap-2">
                                        <Switch
                                            checked={criteria_avg_speed_enabled}
                                            onCheckedChange={(v: boolean) =>
                                                (criteria_avg_speed_enabled =
                                                    v)}
                                            class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                        />
                                        <span
                                            ><Input
                                                type="number"
                                                class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                                bind:value={criteria_avg_speed}
                                                min="0"
                                                disabled={!criteria_avg_speed_enabled}
                                            /> or - km/h average speed</span
                                        >
                                    </li>
                                {/if}
                                {#if display_demand}
                                    <li class="flex items-center gap-2">
                                        <Switch
                                            checked={criteria_demand_enabled}
                                            onCheckedChange={(v: boolean) =>
                                                (criteria_demand_enabled = v)}
                                            class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                        />
                                        <span
                                            ><Input
                                                type="number"
                                                class="w-20 h-7 inline-block mx-1 px-2 text-center"
                                                bind:value={criteria_demand}
                                                min="0"
                                                disabled={!criteria_demand_enabled}
                                            /> or + passengers/day</span
                                        >
                                    </li>
                                {/if}
                            </ul>
                            <div class="flex gap-2">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    class="h-6 text-[10px] px-2"
                                    onclick={() => {
                                        criteria_bus_frequency_enabled = true;
                                        criteria_n_lanes_direction_enabled = true;
                                        // criteria_n_lanes_parking_enabled = true;
                                        if (display_rt)
                                            criteria_avg_speed_enabled = true;
                                        if (display_demand)
                                            criteria_demand_enabled = true;
                                    }}>Select All</Button
                                >
                                <Button
                                    variant="outline"
                                    size="sm"
                                    class="h-6 text-[10px] px-2"
                                    onclick={() => {
                                        criteria_bus_frequency_enabled = false;
                                        criteria_n_lanes_direction_enabled = false;
                                        // criteria_n_lanes_parking_enabled = false;
                                        if (display_rt)
                                            criteria_avg_speed_enabled = false;
                                        if (display_demand)
                                            criteria_demand_enabled = false;
                                    }}>Deselect All</Button
                                >
                            </div>
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.BUS_LANES.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Existing bus lanes</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <p class="text-xs text-muted-foreground pt-2">
                            Bus lanes obtained from OSM data, using <a
                                href="https://u-shift.github.io/GTFShift/reference/osm_bus_lanes.html"
                                target="_blank"
                                class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono hover:underline"
                                >GTFShift::osm_bus_lanes()</a
                            >.
                        </p>
                        <p class="text-xs text-muted-foreground pt-2">
                            Road segments with bus lanes are shown in <span
                                style="color: {COLOR_TEAL}"
                                class="font-bold">green</span
                            >
                        </p>
                        {#if geoData.metadata.data_census.prioritisation_stats_length}
                            <p class="text-xs text-muted-foreground pt-2">
                                There are {(
                                    geoData.metadata.data_census
                                        .prioritisation_stats_length
                                        .extension_bus_lane / 1000
                                ).toFixed(2)} km of bus lanes, accounting for
                                {(
                                    (geoData.metadata.data_census
                                        .prioritisation_stats_length
                                        .extension_bus_lane /
                                        geoData.metadata.data_census
                                            .prioritisation_stats_length
                                            .extension) *
                                    100
                                ).toFixed(2)}% of the {(
                                    geoData.metadata.data_census
                                        .prioritisation_stats_length.extension /
                                    1000
                                ).toFixed(2)} km bus network
                            </p>
                        {/if}
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.FREQUENCY.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Bus frequency</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-3 pt-2"
                        >
                            <p>
                                Bus frequency determined associating GTFS static
                                data with OSM road segments using <a
                                    href="https://u-shift.github.io/GTFShift/reference/get_way_frequency_hourly.html"
                                    target="_blank"
                                    class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono hover:underline"
                                    >GTFShift::get_way_frequency_hourly()</a
                                >.
                            </p>
                            <p>
                                Road segments with bus service are colored by
                                frequency, for the selected hour, from the <span
                                    style="color: {COLOR_GRADIENT[0]}"
                                    class="bg-black/50 font-bold px-1 rounded"
                                    >P5 ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.p5})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >P95 ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.p95})</span
                                > number of buses per hour, considering:
                            </p>
                            <div class="flex items-center gap-2">
                                <span
                                    >Bus frequencies for <Input
                                        type="number"
                                        class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                        bind:value={criteria_hour}
                                        min="0"
                                        max="23"
                                    />:00 hour</span
                                >
                            </div>
                            {#if geoData.metadata.data_census.frequency_hour[criteria_hour]}
                                <DataCensusTable
                                    census_1={geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]}
                                    census_1_label="Length"
                                />
                            {/if}
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.N_LANES.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Number of lanes</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-3 pt-2"
                        >
                            <p>
                                Number of lanes obtained from OSM data, using <a
                                    href="https://u-shift.github.io/GTFShift/reference/prioritise_lanes.html"
                                    target="_blank"
                                    class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono hover:underline"
                                    >GTFShift::prioritise_lanes()</a
                                >.
                            </p>
                            <p>
                                Road segments with bus service are colored by
                                number of lanes, from the <span
                                    style="color: {COLOR_GRADIENT[0]}"
                                    class="bg-black/50 font-bold px-1 rounded"
                                    >P5 ({geoData.metadata.data_census
                                        .lanes_length?.p5})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >P95 ({geoData.metadata.data_census
                                        .lanes_length?.p95})</span
                                > number of lanes per direction.
                            </p>
                            {#if geoData.metadata.data_census.lanes_length}
                                <DataCensusTable
                                    census_1={geoData.metadata.data_census
                                        .lanes_length}
                                    census_2={geoData.metadata.data_census
                                        .lanes_frequency}
                                    census_1_label="Length"
                                    census_2_label="Frequency"
                                />
                            {/if}
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <!--
                <Accordion.Item value={DisplayOptions.PARKING_LANES.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Parking lanes</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-3 pt-2"
                        >
                            <p>
                                Road segments with bus service are colored by
                                number of parking lanes. Only segments with at
                                least one parking lane are shown.
                            </p>
                        </div>
                    </Accordion.Content>
                </Accordion.Item>
                -->

                {#if display_rt}
                    <Accordion.Item value={DisplayOptions.RT_SPEED.toString()}>
                        <Accordion.Trigger
                            class="text-sm font-medium hover:no-underline"
                            >Speed</Accordion.Trigger
                        >
                        <Accordion.Content>
                            <div
                                class="text-xs text-muted-foreground space-y-3 pt-2"
                            >
                                <div
                                    class="flex items-center gap-1 p-1 bg-muted/70 rounded-full border border-border/40 w-full"
                                >
                                    <button
                                        type="button"
                                        class="flex-1 py-1 px-2.5 rounded-full text-xs font-medium transition-all text-center cursor-pointer {selected_speed_metric ===
                                        'avg'
                                            ? 'bg-background text-foreground shadow-xs font-semibold'
                                            : 'text-muted-foreground hover:text-foreground hover:bg-background/40'}"
                                        onclick={() =>
                                            (selected_speed_metric = "avg")}
                                        title="Average (mean) speed"
                                    >
                                        Average
                                    </button>
                                    <button
                                        type="button"
                                        class="flex-1 py-1 px-2.5 rounded-full text-xs font-medium transition-all text-center cursor-pointer {selected_speed_metric ===
                                        'median'
                                            ? 'bg-background text-foreground shadow-xs font-semibold'
                                            : 'text-muted-foreground hover:text-foreground hover:bg-background/40'}"
                                        onclick={() =>
                                            (selected_speed_metric = "median")}
                                        title="Median speed"
                                    >
                                        Median
                                    </button>
                                    <button
                                        type="button"
                                        class="flex-1 py-1 px-2.5 rounded-full text-xs font-medium transition-all text-center cursor-pointer {selected_speed_metric ===
                                        'p75'
                                            ? 'bg-background text-foreground shadow-xs font-semibold'
                                            : 'text-muted-foreground hover:text-foreground hover:bg-background/40'}"
                                        onclick={() =>
                                            (selected_speed_metric = "p75")}
                                        title="75th percentile speed"
                                    >
                                        P75
                                    </button>
                                </div>

                                {#if selected_speed_metric === "avg"}
                                    <p>
                                        Speed computed based on GTFS-RT updates
                                        with <a
                                            href="https://u-shift.github.io/GTFShift/reference/rt_average_speed.html"
                                            target="_blank"
                                            class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono hover:underline"
                                            >GTFShift::rt_average_speed()</a
                                        >, considering the distance traversed
                                        along the route geometry and the time
                                        between consecutive updates.
                                    </p>
                                    <p>
                                        Road segments with bus service are
                                        colored by the average speed measured
                                        (for the full days of the real-time data
                                        collection interval), from the <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[0]}"
                                            class="font-bold"
                                            >P5 ({geoData.metadata.data_census.speed_avg_length?.p5?.toFixed(
                                                2,
                                            )})</span
                                        >
                                        to the
                                        <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[
                                                COLOR_GRADIENT_RED.length - 1
                                            ]}"
                                            class="bg-black/50 font-bold px-1 rounded"
                                            >P95 ({geoData.metadata.data_census.speed_avg_length?.p95?.toFixed(
                                                2,
                                            )})</span
                                        > values (km/h).
                                    </p>
                                {:else if selected_speed_metric === "median"}
                                    <p>
                                        Median speed computed based on GTFS-RT
                                        updates, considering the distance
                                        traversed along the route geometry and
                                        the time between consecutive updates.
                                    </p>
                                    <p>
                                        Road segments with bus service are
                                        colored by the median speed measured
                                        (for the full days of the real-time data
                                        collection interval), from the <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[0]}"
                                            class="font-bold"
                                            >P5 ({geoData.metadata.data_census.speed_avg_length?.p5?.toFixed(
                                                2,
                                            )})</span
                                        >
                                        to the
                                        <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[
                                                COLOR_GRADIENT_RED.length - 1
                                            ]}"
                                            class="bg-black/50 font-bold px-1 rounded"
                                            >P95 ({geoData.metadata.data_census.speed_avg_length?.p95?.toFixed(
                                                2,
                                            )})</span
                                        > values (km/h).
                                    </p>
                                {:else if selected_speed_metric === "p75"}
                                    <p>
                                        75th percentile speed computed based on
                                        GTFS-RT updates, considering the
                                        distance traversed along the route
                                        geometry and the time between
                                        consecutive updates.
                                    </p>
                                    <p>
                                        Road segments with bus service are
                                        colored by the 75th percentile speed
                                        measured (for the full days of the
                                        real-time data collection interval),
                                        from the <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[0]}"
                                            class="font-bold"
                                            >P5 ({geoData.metadata.data_census.speed_avg_length?.p5?.toFixed(
                                                2,
                                            )})</span
                                        >
                                        to the
                                        <span
                                            style="color: {COLOR_GRADIENT_RED.slice().reverse()[
                                                COLOR_GRADIENT_RED.length - 1
                                            ]}"
                                            class="bg-black/50 font-bold px-1 rounded"
                                            >P95 ({geoData.metadata.data_census.speed_avg_length?.p95?.toFixed(
                                                2,
                                            )})</span
                                        > values (km/h).
                                    </p>
                                {/if}

                                {#if geoData.metadata.data_census.speed_avg_length}
                                    <DataCensusTable
                                        census_1={geoData.metadata.data_census
                                            .speed_avg_length}
                                        census_2={geoData.metadata.data_census
                                            .speed_avg_frequency}
                                        census_1_label="Length"
                                        census_2_label="Frequency"
                                    />
                                {/if}
                            </div>
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}

                {#if display_demand}
                    <Accordion.Item value={DisplayOptions.DEMAND.toString()}>
                        <Accordion.Trigger
                            class="text-sm font-medium hover:no-underline"
                            >Passenger demand</Accordion.Trigger
                        >
                        <Accordion.Content>
                            <div
                                class="text-xs text-muted-foreground space-y-3 pt-2"
                            >
                                {#if geoData.metadata.demand && geoData.metadata.demand.notes}
                                    <p
                                        class="text-xs text-muted-foreground pt-2"
                                    >
                                        {@html geoData.metadata.demand.notes}
                                    </p>
                                {/if}
                                <p>
                                    Road segments with bus service are colored
                                    by passenger demand (cumulative for the
                                    representative day in study), from the <span
                                        style="color: {COLOR_GRADIENT[0]}"
                                        class="bg-black/50 font-bold px-1 rounded"
                                        >P5 ({geoData.metadata.data_census.demand_length?.p5?.toFixed(
                                            0,
                                        )})</span
                                    >
                                    to the
                                    <span
                                        style="color: {COLOR_GRADIENT[
                                            COLOR_GRADIENT.length - 1
                                        ]}"
                                        class="font-bold"
                                        >P95 ({geoData.metadata.data_census.demand_length?.p95?.toFixed(
                                            0,
                                        )})</span
                                    > passengers/day.
                                </p>
                                {#if geoData.metadata.data_census.demand_length}
                                    <DataCensusTable
                                        census_1={geoData.metadata.data_census
                                            .demand_length}
                                        census_2={geoData.metadata.data_census
                                            .demand_frequency}
                                        census_1_label="Length"
                                        census_2_label="Frequency"
                                    />
                                {/if}
                            </div>
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}
            </Accordion.Root>
        </div>
    {/if}

    <!-- Control buttons -->
    <div class="w-full flex gap-2 mt-4 pt-4 border-t">
        {#if region && selected_layer && geoData && geoData.metadata}
            <Button
                variant="outline"
                size="sm"
                onclick={() => {
                    if (region && region.layers && region.layers.length === 1) {
                        region = undefined;
                    }
                    selected_layer = undefined;
                    selected_layer_id = "";
                    geoData = null;
                    active_layer = undefined;
                    open_accordion = undefined;
                    selected_speed_metric = "avg";
                    selected_shape_id = "all";
                    selectedWayId = undefined;
                    action_modal_about_open = false;
                    action_modal_data_open = false;
                    action_modal_details_open = false;
                    action_modal_download_open = false;
                }}
                class="flex-1"
            >
                <i class="fa-solid fa-arrow-left mr-2"></i> Regions
            </Button>
            <Button
                variant="outline"
                size="sm"
                onclick={() => (action_hide_form = !action_hide_form)}
                class="flex-1"
            >
                {@html !action_hide_form
                    ? '<i class="fa-solid fa-map mr-2"></i> Hide'
                    : '<i class="fa-solid fa-sliders mr-2"></i> Layers'}
            </Button>
        {/if}
        <Button
            variant="outline"
            size="sm"
            onclick={() => {
                light_mode = !light_mode;
            }}
            class="flex-1"
        >
            <i class="fa-solid fa-circle-half-stroke mr-2"></i> Theme
        </Button>
    </div>
</div>

<!-- Right Details Panel -->
<PanelWayDetails
    bind:selectedWayId
    bind:selected_shape_id
    {geoData}
    {criteria_hour}
    {display_rt}
    di_threshold_low={di_threshold_low / 100}
    di_threshold_high={di_threshold_high / 100}
/>

<!-- Route Details Panel (shown when a shape is selected and no way is selected) -->
<PanelRouteDetails bind:selected_shape_id {geoData} {selectedWayId} />

<!-- Map caption -->
{#if active_layer !== undefined && !any_modal_open && !selectedWayId}
    <div
        id="caption"
        class="absolute bottom-4 left-4 right-4 sm:bottom-6 sm:left-auto sm:right-6 z-[1000] flex flex-col gap-3 p-4 bg-background/95 backdrop-blur shadow-lg border rounded-xl text-sm w-[calc(100vw-2rem)] sm:w-[350px] max-h-[30vh] sm:max-h-[40vh] overflow-y-auto"
    >
        {#if active_layer === DisplayOptions.PRIORITISATION}
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_YELLOW}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b>
                    with{#if criteria_bus_frequency_enabled}{" "}- {criteria_bus_frequency}
                        bus/h{/if}{#if criteria_n_lanes_direction_enabled}{#if criteria_bus_frequency_enabled}{" "}OR{/if}{" "}-
                        {criteria_n_lanes_direction} lane/dir{/if}{#if criteria_n_lanes_parking_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled}{" "}OR{/if}{" "}-
                        {criteria_n_lanes_parking} parking lane{/if}{#if display_rt && criteria_avg_speed_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled}{" "}OR{/if}{" "}{criteria_avg_speed}
                        or - km/h avg. speed{/if}{#if display_demand && criteria_demand_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled || (display_rt && criteria_avg_speed_enabled)}{" "}OR{/if}{" "}+{criteria_demand}
                        passengers/day{/if}</span
                >
            </p>
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_TEAL}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b>
                    with{#if criteria_bus_frequency_enabled}{" "}+ {criteria_bus_frequency -
                            1} bus/h{/if}{#if criteria_n_lanes_direction_enabled}{#if criteria_bus_frequency_enabled}{" "}AND{/if}{" "}+
                        {criteria_n_lanes_direction - 1} lane/dir{/if}{#if criteria_n_lanes_parking_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled}{" "}AND{/if}{" "}+
                        {criteria_n_lanes_parking - 1} parking lane{/if}{#if display_rt && criteria_avg_speed_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled}{" "}AND{/if}{" "}+
                        {criteria_avg_speed} km/h avg. speed{/if}{#if display_demand && criteria_demand_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled || (display_rt && criteria_avg_speed_enabled)}{" "}AND{/if}{" "}+{criteria_demand}
                        passengers/day{/if}</span
                >
            </p>
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_RED}"
                ></span>
                <span
                    ><b class="text-foreground">NO bus lane</b>
                    with{#if criteria_bus_frequency_enabled}{" "}+ {criteria_bus_frequency -
                            1} bus/h{/if}{#if criteria_n_lanes_direction_enabled}{#if criteria_bus_frequency_enabled}{" "}AND{/if}{" "}+
                        {criteria_n_lanes_direction - 1} lane/dir{/if}{#if criteria_n_lanes_parking_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled}{" "}AND{/if}{" "}+
                        {criteria_n_lanes_parking - 1} parking lane{/if}{#if display_rt && criteria_avg_speed_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled}{" "}AND{/if}{" "}{criteria_avg_speed}
                        or - km/h avg. speed{/if}{#if display_demand && criteria_demand_enabled}{#if criteria_bus_frequency_enabled || criteria_n_lanes_direction_enabled || criteria_n_lanes_parking_enabled || (display_rt && criteria_avg_speed_enabled)}{" "}AND{/if}{" "}+{criteria_demand}
                        passengers/day{/if}</span
                >
            </p>
        {:else if active_layer === DisplayOptions.BUS_LANES}
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_TEAL}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b> with existing bus service</span
                >
            </p>
        {:else if active_layer === DisplayOptions.FREQUENCY}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Transit frequency <span
                        class="text-muted-foreground font-normal"
                        >(buses/hour, at {criteria_hour}:00)</span
                    >
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.frequency_hour[
                            criteria_hour
                        ]?.p5}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.frequency_hour[
                            criteria_hour
                        ]?.p95}</span
                    >
                </div>
            </div>
        {:else if active_layer === DisplayOptions.N_LANES}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Number of lanes per direction
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.lanes_length?.p5}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.lanes_length?.p95}</span
                    >
                </div>
            </div>
        {:else if active_layer === DisplayOptions.PARKING_LANES}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Number of parking lanes
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{(geoData?.metadata.data_census as any)
                            .parking_lanes_length?.p5 ?? 0}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{(geoData?.metadata.data_census as any)
                            .parking_lanes_length?.p95 ?? "—"}</span
                    >
                </div>
                <p class="text-xs text-muted-foreground mt-1">
                    Only segments with ≥ 1 parking lane shown.
                </p>
            </div>
        {:else if active_layer === DisplayOptions.RT_SPEED}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    {selected_speed_metric === "avg"
                        ? "Average speed"
                        : selected_speed_metric === "median"
                          ? "Median speed"
                          : "P75 speed"}
                    <span class="text-muted-foreground font-normal">(km/h)</span
                    >
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.speed_avg_length?.p5 &&
                            Math.floor(
                                geoData.metadata.data_census.speed_avg_length
                                    .p5,
                            )}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT_RED.slice()
                            .reverse()
                            .map((c) => c)
                            .join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.speed_avg_length?.p95 &&
                            Math.ceil(
                                geoData.metadata.data_census.speed_avg_length
                                    .p95,
                            )}</span
                    >
                </div>
            </div>
        {:else if active_layer === DisplayOptions.DISTURBANCE_INDEX}
            <div class="mb-2">
                <div class="flex items-center justify-between mb-2">
                    <p class="text-foreground font-semibold">
                        Disturbance Index <span
                            class="text-muted-foreground font-normal"
                            >({criteria_hour
                                .toString()
                                .padStart(2, "0")}:00)</span
                        >
                    </p>
                    {#if di_filter_mode !== "all"}
                        <span
                            class="text-[10px] font-medium px-1.5 py-0.5 rounded bg-muted text-foreground border border-border/40 capitalize"
                        >
                            {di_filter_mode}
                            {di_filter_count}
                        </span>
                    {/if}
                </div>
                {#if di_palette_mode === "categorized"}
                    <div class="space-y-1 mt-2">
                        {#each getDisturbanceIndexCategories(di_threshold_low / 100, di_threshold_high / 100) as cat}
                            <div
                                class="flex items-center justify-between text-xs"
                            >
                                <div class="flex items-center gap-2">
                                    <span
                                        class="w-3 h-3 rounded-sm inline-block"
                                        style="background-color: {cat.color}"
                                    ></span>
                                    <span class="text-foreground"
                                        >{cat.label}</span
                                    >
                                </div>
                                <span class="text-muted-foreground font-mono"
                                    >{cat.rangeLabel}</span
                                >
                            </div>
                        {/each}
                    </div>
                {:else}
                    <div class="mt-2 space-y-1">
                        <div class="flex gap-2 items-center">
                            <span
                                class="min-w-[40px] text-right text-xs font-mono text-muted-foreground"
                            >
                                -{Math.max(di_threshold_high, 25)}%
                            </span>
                            <div
                                class="flex-1 h-3 rounded border border-border/40"
                                style="background: linear-gradient(to right, {COLOR_GRADIENT_DIVERGING_BRBG.join(
                                    ', ',
                                )});"
                            ></div>
                            <span
                                class="min-w-[40px] text-left text-xs font-mono text-muted-foreground"
                            >
                                +{Math.max(di_threshold_high, 25)}%
                            </span>
                        </div>
                        <div
                            class="flex justify-between items-center text-[10px] text-muted-foreground px-1"
                        >
                            <span>Slower</span>
                            <span>0% (Baseline)</span>
                            <span>Faster</span>
                        </div>
                    </div>
                {/if}
            </div>
        {:else if active_layer === DisplayOptions.DEMAND}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Demand <span class="text-muted-foreground font-normal"
                        >(passengers/day)</span
                    >
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.demand_length?.p5 &&
                            Math.floor(
                                geoData.metadata.data_census.demand_length.p5,
                            )}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.demand_length?.p95 &&
                            Math.ceil(
                                geoData.metadata.data_census.demand_length.p95,
                            )}</span
                    >
                </div>
            </div>
        {/if}

        {#if boundaryGeoJSON}
            <div class="border-t pt-2 mt-1 flex items-center justify-between">
                <span
                    class="text-xs text-muted-foreground flex items-center gap-2"
                >
                    <i
                        class="fa-solid fa-draw-polygon text-[11px]"
                        style="color: {region?.color}"
                    ></i>
                    Operations Area
                </span>
                <button
                    class="relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full transition-colors duration-200 outline-none {show_boundaries
                        ? 'bg-primary'
                        : 'bg-muted'}"
                    style="background-color: {show_boundaries
                        ? region?.color
                        : ''};"
                    onclick={() => (show_boundaries = !show_boundaries)}
                    aria-label="Toggle analysis boundary"
                >
                    <span
                        class="pointer-events-none inline-block h-3.5 w-3.5 transform rounded-full bg-background shadow-lg ring-0 transition duration-200 ease-in-out {show_boundaries
                            ? 'translate-x-4'
                            : 'translate-x-0.5'}"
                    ></span>
                </button>
            </div>
        {/if}
    </div>
{/if}

{#if region && geoData && active_layer !== undefined && map}
    {#if boundaryGeoJSON && show_boundaries}
        <LayerBoundaries {map} {boundaryGeoJSON} color={region.color} />
    {/if}

    {#if active_layer === DisplayOptions.PRIORITISATION}
        <LayerBusLanePrioritisation
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            criteriaBusFrequency={criteria_bus_frequency}
            criteriaBusFrequencyEnabled={criteria_bus_frequency_enabled}
            criteriaNLanesDirection={criteria_n_lanes_direction}
            criteriaNLanesDirectionEnabled={criteria_n_lanes_direction_enabled}
            criteriaNLanesParking={criteria_n_lanes_parking}
            criteriaNLanesParkingEnabled={criteria_n_lanes_parking_enabled}
            criteriaAvgSpeed={criteria_avg_speed}
            criteriaAvgSpeedEnabled={criteria_avg_speed_enabled}
            criteriaDemand={criteria_demand}
            criteriaDemandEnabled={criteria_demand_enabled}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.BUS_LANES}
        <LayerBusLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.FREQUENCY}
        <LayerTransitFrequency
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.N_LANES}
        <LayerNumberOfLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.PARKING_LANES}
        <LayerParkingLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.RT_SPEED}
        {#if selected_speed_metric === "avg"}
            <LayerRTSpeed
                {map}
                {geoData}
                criteriaHour={criteria_hour}
                lineWeightBy={line_weight_by}
                {selectedWayId}
                selectedShapeId={selected_shape_id}
                onWaySelect={(id) => (selectedWayId = id)}
                onLayerCreate={handleLayerCreate}
                onVisibleWayIdsChange={handleVisibleWayIdsChange}
            />
        {:else if selected_speed_metric === "median"}
            <LayerRTSpeedMedian
                {map}
                {geoData}
                criteriaHour={criteria_hour}
                lineWeightBy={line_weight_by}
                {selectedWayId}
                selectedShapeId={selected_shape_id}
                onWaySelect={(id) => (selectedWayId = id)}
                onLayerCreate={handleLayerCreate}
                onVisibleWayIdsChange={handleVisibleWayIdsChange}
            />
        {:else if selected_speed_metric === "p75"}
            <LayerRTSpeedP75
                {map}
                {geoData}
                criteriaHour={criteria_hour}
                lineWeightBy={line_weight_by}
                {selectedWayId}
                selectedShapeId={selected_shape_id}
                onWaySelect={(id) => (selectedWayId = id)}
                onLayerCreate={handleLayerCreate}
                onVisibleWayIdsChange={handleVisibleWayIdsChange}
            />
        {/if}
    {:else if active_layer === DisplayOptions.DISTURBANCE_INDEX}
        <LayerDisturbanceIndex
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            diThresholdLow={di_threshold_low / 100}
            diThresholdHigh={di_threshold_high / 100}
            diPaletteMode={di_palette_mode}
            diFilterMode={di_filter_mode}
            diFilterCount={di_filter_count}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {:else if active_layer === DisplayOptions.DEMAND}
        <LayerDemand
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            lineWeightBy={line_weight_by}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
            onVisibleWayIdsChange={handleVisibleWayIdsChange}
        />
    {/if}
{/if}

<!-- Modals -->
<ModalAbout bind:open={action_modal_about_open} />

{#if geoData}
    <ModalData
        bind:open={action_modal_data_open}
        {geoData}
        hour={criteria_hour}
        rt_data={display_rt}
        demand_data={display_demand}
        {visible_way_ids}
        onRouteSelect={(shapeId) => {
            selected_shape_id = shapeId;
            selectedWayId = undefined;
        }}
        onWaySelect={(wayId) => {
            selectedWayId = wayId;
            if (map && geoData) {
                const feature = geoData.features.find(
                    (f: any) => f.properties?.way_osm_id === wayId,
                );
                if (feature) {
                    const tempLayer = L.geoJSON(feature);
                    map.flyToBounds(tempLayer.getBounds(), {
                        padding: [100, 100],
                        duration: 1,
                    });
                }
            }
        }}
    />
{/if}

<ModalDetails bind:open={action_modal_details_open} {geoData} />

<ModalDownload
    bind:open={action_modal_download_open}
    zipUrl={selected_layer?.files.zip}
/>
