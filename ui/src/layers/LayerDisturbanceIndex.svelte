<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRAY } from "../data";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
    import type { LineWeightMetric } from "../types/LineWeightMetric";
    import type { Feature } from "geojson";
    import {
        bindWayValueTooltip,
        handleWayMouseOut,
        handleWayMouseOver,
    } from "../lib/layerInteractions";
    import {
        getDisturbanceIndex,
        getDisturbanceIndexCategory,
        getLineWeight,
    } from "../lib/utils";

    let {
        map,
        geoData,
        criteriaHour,
        lineWeightBy = "frequency",
        diThresholdLow = 0.05,
        diThresholdHigh = 0.2,
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onVisibleWayIdsChange = (wayIds) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritisation;
        criteriaHour: number;
        lineWeightBy: LineWeightMetric;
        diThresholdLow?: number;
        diThresholdHigh?: number;
        selectedWayId: string | undefined;
        selectedShapeId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onVisibleWayIdsChange: (wayIds: string[]) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    let wayLayerMap: Map<string, L.Path> = new Map();

    function formatDILabel(wayId: string): string {
        const props = geoData.wayData[wayId];
        const di = getDisturbanceIndex(props, criteriaHour);
        if (di === undefined) return "Disturbance Index: n/a";
        const cat = getDisturbanceIndexCategory(di, diThresholdLow, diThresholdHigh);
        const percentStr = (di * 100).toFixed(1);
        const sign = di > 0 ? "+" : "";
        return `Disturbance Index: ${sign}${percentStr}% (${cat.label})`;
    }

    function getDIStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const di = getDisturbanceIndex(props, criteriaHour);
        let color = COLOR_GRAY;
        const weight = getLineWeight(
            geoData,
            props,
            criteriaHour,
            lineWeightBy,
        );
        if (di !== undefined) {
            color = getDisturbanceIndexCategory(di, diThresholdLow, diThresholdHigh).color;
        }
        return {
            color,
            weight,
        };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter out features with no valid Disturbance Index data
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
                const di = getDisturbanceIndex(props, criteriaHour);
                return di !== undefined;
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by DI ascending, so lower DI (more disturbed/slower) renders on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                const diA = getDisturbanceIndex(propsA, criteriaHour) ?? 0;
                const diB = getDisturbanceIndex(propsB, criteriaHour) ?? 0;
                return diA - diB;
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getDIStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatDILabel(wayId));
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
                            getDIStyle,
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
                path.setStyle(getDIStyle(wayId));
            }
        });
    });
</script>
