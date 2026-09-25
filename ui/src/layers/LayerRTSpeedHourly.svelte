<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED, COLOR_GRAY } from "../data";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
    import type { LineWeightMetric } from "../types/LineWeightMetric";
    import type { Feature } from "geojson";
    import {
        bindWayValueTooltip,
        handleWayMouseOut,
        handleWayMouseOver,
    } from "../lib/layerInteractions";

    let {
        map,
        geoData,
        criteriaHour,
        speedMetric = "avg",
        lineWeightBy = "frequency",
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onVisibleWayIdsChange = (wayIds) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritisation;
        criteriaHour: number;
        speedMetric: "avg" | "median" | "p85";
        lineWeightBy: LineWeightMetric;
        selectedWayId: string | undefined;
        selectedShapeId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onVisibleWayIdsChange: (wayIds: string[]) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    let wayLayerMap: Map<string, L.Path> = new Map();

    import { getColorFromGradient, getLineWeight } from "../lib/utils";

    function getHourlySpeed(props: Record<string, any> | undefined): number | undefined {
        if (!props) return undefined;
        const hourKey = criteriaHour;
        const hourStr = String(criteriaHour);

        let val: any;
        if (speedMetric === "median") {
            val = props.hour_speed_median?.[hourKey] ?? props.hour_speed_median?.[hourStr];
        } else if (speedMetric === "p85") {
            val = props.hour_speed_p85?.[hourKey] ?? props.hour_speed_p85?.[hourStr];
        } else {
            val = props.hour_speed_avg?.[hourKey] ?? props.hour_speed_avg?.[hourStr];
        }

        if (val !== undefined && val !== null && !isNaN(Number(val))) {
            return Number(val);
        }
        return undefined;
    }

    function formatSpeedLabel(wayId: string): string {
        const speedValue = getHourlySpeed(geoData.wayData[wayId]);
        const metricLabel =
            speedMetric === "median"
                ? "Median speed"
                : speedMetric === "p85"
                  ? "P85 speed"
                  : "Avg speed";

        if (speedValue === undefined) return `${metricLabel} (${criteriaHour}:00): n/a`;
        return `${metricLabel} (${criteriaHour}:00): ${speedValue.toFixed(1)} km/h`;
    }

    function getSpeedStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const speedValue = getHourlySpeed(props);
        let color = COLOR_GRAY;
        const weight = getLineWeight(
            geoData,
            props,
            criteriaHour,
            lineWeightBy,
        );
        if (speedValue !== undefined) {
            const hourKey = criteriaHour;
            const hourStr = String(criteriaHour);
            const census =
                speedMetric === "median"
                    ? (geoData.metadata.data_census.speed_median_hour_length?.[hourKey] ??
                       geoData.metadata.data_census.speed_median_hour_length?.[hourStr] ??
                       geoData.metadata.data_census.speed_median_length)
                    : speedMetric === "p85"
                      ? (geoData.metadata.data_census.speed_p85_hour_length?.[hourKey] ??
                         geoData.metadata.data_census.speed_p85_hour_length?.[hourStr] ??
                         geoData.metadata.data_census.speed_p85_length)
                      : (geoData.metadata.data_census.speed_avg_hour_length?.[hourKey] ??
                         geoData.metadata.data_census.speed_avg_hour_length?.[hourStr] ??
                         geoData.metadata.data_census.speed_avg_length);

            color = getColorFromGradient(
                speedValue,
                census?.p5 || 0,
                census?.p95 || 1,
                COLOR_GRADIENT_RED.slice().reverse(),
            );
        }
        return {
            color,
            weight,
        };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter out features with no hourly speed data
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                if (
                    selectedShapeId &&
                    selectedShapeId !== "all" &&
                    !props?.shapes?.includes(selectedShapeId)
                ) {
                    return false;
                }
                return getHourlySpeed(props) !== undefined;
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by hourly speed asc, to plot higher speeds on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (getHourlySpeed(propsA) || 0) - (getHourlySpeed(propsB) || 0);
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getSpeedStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatSpeedLabel(wayId));
                    }
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        handleWayMouseOver(layer, wayId, selectedWayId);
                    });
                    layer.on("mouseout", () => {
                        handleWayMouseOut(
                            layer,
                            wayId,
                            selectedWayId,
                            getSpeedStyle,
                        );
                    });
                },
            },
        ).addTo(map);

        // Update parent state
        untrack(() => {
            currentLayer = newLayer;
            onLayerCreate(newLayer);
            onVisibleWayIdsChange(visibleWayIds);
        });

        // Zoom to operations layer (only if there are features with valid bounds)
        if (geoData.features.length > 0) {
            const opsLayer = L.geoJSON(geoData.features);
            const bounds = opsLayer.getBounds();
            if (bounds.isValid()) map.fitBounds(bounds, { padding: [10, 10] });
        }

        // Cleanup
        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
            wayLayerMap = new Map();
            onVisibleWayIdsChange([]);
        };
    });

    // Highlight the selected way reactively
    $effect(() => {
        const selected = selectedWayId;
        wayLayerMap.forEach((path, wayId) => {
            if (wayId === selected) {
                path.setStyle({ weight: 7, color: "#FFD4B8", opacity: 1 });
                path.bringToFront();
            } else {
                path.setStyle(getSpeedStyle(wayId));
            }
        });
    });
</script>
