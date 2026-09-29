<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { toCapitalCase } from "$lib/utils.js";

    interface StopInfo {
        stop_id: string;
        stop_name?: string;
        lat: number;
        lon: number;
        stop_sequence?: number;
        departure_time?: string;
    }

    let {
        map,
        stops,
        departureStop,
        arrivalStop,
        routeColor = "#2563eb",
    }: {
        map: L.Map;
        stops?: StopInfo[];
        departureStop?: StopInfo;
        arrivalStop?: StopInfo;
        routeColor?: string;
    } = $props();

    let layerGroup: L.LayerGroup | null = $state(null);

    function createStopIcon(type: "departure" | "arrival"): L.DivIcon {
        const isDep = type === "departure";
        const innerColor = isDep ? "#16a34a" : "#dc2626";

        return L.divIcon({
            className: "terminal-stop-node",
            html: `
                <div style="
                    width: 14px;
                    height: 14px;
                    border-radius: 50%;
                    background: #ffffff;
                    border: 3px solid ${innerColor};
                    box-shadow: 0 1px 4px rgba(0,0,0,0.4);
                    box-sizing: border-box;
                    cursor: pointer;
                "></div>
            `,
            iconSize: [14, 14],
            iconAnchor: [7, 7],
            popupAnchor: [0, -7],
        });
    }

    function createIntermediateStopIcon(color: string): L.DivIcon {
        return L.divIcon({
            className: "intermediate-stop-node",
            html: `
                <div style="
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: #ffffff;
                    border: 2px solid #a6a6a6;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.3);
                    box-sizing: border-box;
                    cursor: pointer;
                "></div>
            `,
            iconSize: [8, 8],
            iconAnchor: [4, 4],
            popupAnchor: [0, -4],
        });
    }

    $effect(() => {
        if (!map) return;

        const group = L.layerGroup();

        const dep = departureStop || stops?.[0];
        const arr =
            arrivalStop ||
            (stops && stops.length > 1 ? stops[stops.length - 1] : undefined);
        const intermediates =
            stops && stops.length > 2 ? stops.slice(1, -1) : [];

        // Intermediate stops as secondary dots
        for (const stop of intermediates) {
            if (stop.lat && stop.lon) {
                const marker = L.marker([stop.lat, stop.lon], {
                    icon: createIntermediateStopIcon(routeColor),
                    zIndexOffset: 500,
                });
                const rawName = stop.stop_name || stop.stop_id;
                const stopName = toCapitalCase(rawName);
                const seqText =
                    stop.stop_sequence != null
                        ? ` <span style="opacity: 0.65;">(#${stop.stop_sequence})</span>`
                        : "";
                marker.bindTooltip(
                    `<strong>Stop:</strong> ${stopName}${seqText}`,
                    {
                        direction: "top",
                        offset: [0, -5],
                        opacity: 0.9,
                    },
                );
                marker.addTo(group);
            }
        }

        // First stop (departure)
        if (dep && dep.lat && dep.lon) {
            const depMarker = L.marker([dep.lat, dep.lon], {
                icon: createStopIcon("departure"),
                zIndexOffset: 1000,
            });
            const rawName = dep.stop_name || dep.stop_id;
            const depName = toCapitalCase(rawName);
            depMarker.bindTooltip(`<strong>From:</strong> ${depName}`, {
                direction: "top",
                offset: [0, -8],
                opacity: 0.9,
            });
            depMarker.addTo(group);
        }

        // Last stop (arrival)
        if (arr && arr.lat && arr.lon) {
            const arrMarker = L.marker([arr.lat, arr.lon], {
                icon: createStopIcon("arrival"),
                zIndexOffset: 1000,
            });
            const rawName = arr.stop_name || arr.stop_id;
            const arrName = toCapitalCase(rawName);
            arrMarker.bindTooltip(`<strong>To:</strong> ${arrName}`, {
                direction: "top",
                offset: [0, -8],
                opacity: 0.9,
            });
            arrMarker.addTo(group);
        }

        group.addTo(map);

        untrack(() => {
            layerGroup = group;
        });

        return () => {
            if (layerGroup) {
                map.removeLayer(layerGroup);
                layerGroup = null;
            }
        };
    });
</script>
