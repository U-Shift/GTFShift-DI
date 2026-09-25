<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { toCapitalCase } from "$lib/utils.js";

    interface StopInfo {
        stop_id: string;
        stop_name?: string;
        lat: number;
        lon: number;
    }

    let {
        map,
        departureStop,
        arrivalStop,
        routeColor = "#2563eb",
    }: {
        map: L.Map;
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

    $effect(() => {
        if (!map) return;

        const group = L.layerGroup();

        if (departureStop && departureStop.lat && departureStop.lon) {
            const depMarker = L.marker([departureStop.lat, departureStop.lon], {
                icon: createStopIcon("departure"),
                zIndexOffset: 1000,
            });
            const rawName = departureStop.stop_name || departureStop.stop_id;
            const depName = toCapitalCase(rawName);
            depMarker.bindTooltip(`<strong>From:</strong> ${depName}`, {
                direction: "top",
                offset: [0, -8],
                opacity: 0.9,
            });
            depMarker.addTo(group);
        }

        if (arrivalStop && arrivalStop.lat && arrivalStop.lon) {
            const arrMarker = L.marker([arrivalStop.lat, arrivalStop.lon], {
                icon: createStopIcon("arrival"),
                zIndexOffset: 1000,
            });
            const rawName = arrivalStop.stop_name || arrivalStop.stop_id;
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
