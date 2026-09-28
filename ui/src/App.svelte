<script lang="ts">
  import { untrack } from "svelte";
  import * as L from "leaflet";
  import "leaflet/dist/leaflet.css";

  import * as maplibregl from "maplibre-gl";
  import maplibreWorkerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url";
  import "maplibre-gl/dist/maplibre-gl.css";
  import "@maplibre/maplibre-gl-leaflet";

  if (maplibregl.setWorkerUrl) {
    maplibregl.setWorkerUrl(maplibreWorkerUrl);
  }

  if (typeof window !== "undefined" && !(window as any).maplibregl) {
    (window as any).maplibregl = maplibregl;
  }

  import Dashboard from "./Dashboard.svelte";

  import {
    BASEMAPS,
    type BasemapDef,
    MAP_INIT_ZOOM,
    MAP_INIT_CENTER,
  } from "./data";

  let map: L.Map | null = $state(null);
  let tileLayer: any = $state(null);
  let light_mode = $state(true);
  let selected_basemap = $state("simplified");

  function getActiveBasemapConfig(basemapId: string, isLight: boolean) {
    const def = BASEMAPS[basemapId] || BASEMAPS.simplified;
    if (def.id === "simplified") {
      return {
        url: isLight ? def.lightUrl! : def.darkUrl!,
        vector: true,
        opacity: isLight ? (def.lightOpacity ?? 0.5) : (def.darkOpacity ?? 0.9),
      };
    }
    return {
      url: def.url!,
      vector: def.vector,
      attribution: def.attribution,
      opacity: def.opacity ?? 0.9,
    };
  }

  function applyTileLayer(m: L.Map, basemapId: string, isLight: boolean) {
    if (tileLayer) {
      m.removeLayer(tileLayer);
      tileLayer = null;
    }
    // Clean attribution control to avoid concatenating old basemap attributions
    if (m.attributionControl) {
      (m.attributionControl as any)._attributions = {};
      (m.attributionControl as any)._update();
    }
    const config = getActiveBasemapConfig(basemapId, isLight);
    if (config.vector) {
      tileLayer = (L as any)
        .maplibreGL({
          style: config.url,
          attribution: config.attribution,
        })
        .addTo(m);
    } else {
      tileLayer = L.tileLayer(config.url, {
        attribution: config.attribution,
        maxZoom: 19,
      }).addTo(m);
    }
    (m.attributionControl as any)._update();
    if (tileLayer && tileLayer.getContainer()) {
      tileLayer.getContainer().style.opacity = config.opacity.toString();
    }
    if (tileLayer && typeof (tileLayer as any).bringToBack === "function") {
      (tileLayer as any).bringToBack();
    }
  }

  const createMap = (container: HTMLElement) => {
    let m = L.map(container, {
      zoomControl: false,
      zoomSnap: 0.1,
      zoomDelta: 0.1,
    }).setView(MAP_INIT_CENTER, MAP_INIT_ZOOM);

    // Initial base layer
    applyTileLayer(m, selected_basemap, light_mode);

    // Zoom control
    L.control
      .zoom({
        position: "topright",
      })
      .addTo(m);

    // Basemap switch control
    const BasemapControl = L.Control.extend({
      options: { position: "topright" },
      onAdd: function () {
        const container = L.DomUtil.create(
          "div",
          "leaflet-bar leaflet-control leaflet-control-basemap",
        );
        L.DomEvent.disableClickPropagation(container);
        L.DomEvent.disableScrollPropagation(container);

        const btn = L.DomUtil.create("a", "leaflet-basemap-btn", container);
        btn.href = "#";
        btn.title = "Change basemap";
        btn.setAttribute("role", "button");
        btn.setAttribute("aria-label", "Change basemap");
        btn.innerHTML = '<i class="fa-solid fa-layer-group"></i>';

        const dropdown = L.DomUtil.create(
          "div",
          "leaflet-basemap-dropdown hidden",
          container,
        );

        const basemapKeys = Object.keys(BASEMAPS);
        basemapKeys.forEach((key) => {
          const item = L.DomUtil.create(
            "button",
            "leaflet-basemap-item",
            dropdown,
          );
          item.type = "button";
          item.dataset.basemap = key;
          item.innerText = BASEMAPS[key].name;
          if (key === selected_basemap) {
            item.classList.add("active");
          }
          L.DomEvent.on(item, "click", (e) => {
            L.DomEvent.stop(e);
            selected_basemap = key;
            dropdown.classList.add("hidden");
            updateDropdownActive(dropdown, key);
          });
        });

        L.DomEvent.on(btn, "click", (e) => {
          L.DomEvent.stop(e);
          dropdown.classList.toggle("hidden");
        });

        // Close on document click outside
        const onDocClick = (e: MouseEvent) => {
          if (!container.contains(e.target as Node)) {
            dropdown.classList.add("hidden");
          }
        };
        document.addEventListener("click", onDocClick);

        return container;
      },
    });

    new BasemapControl().addTo(m);

    return m;
  };

  function updateDropdownActive(dropdown: HTMLElement, activeKey: string) {
    const items = dropdown.querySelectorAll(".leaflet-basemap-item");
    items.forEach((it) => {
      const el = it as HTMLElement;
      if (el.dataset.basemap === activeKey) {
        el.classList.add("active");
      } else {
        el.classList.remove("active");
      }
    });
  }

  const mapAction = (container: HTMLElement) => {
    map = createMap(container);
    return {
      destroy: () => {
        map?.remove();
      },
    };
  };

  // Subscribe to theme and basemap changes and swap tile layer
  $effect(() => {
    const bId = selected_basemap;
    const isLight = light_mode;
    untrack(() => {
      if (map) {
        applyTileLayer(map, bId, isLight);
        const dropdown = document.querySelector(
          ".leaflet-basemap-dropdown",
        ) as HTMLElement;
        if (dropdown) {
          updateDropdownActive(dropdown, bId);
        }
      }
    });
  });

  // Theme synchronization
  $effect(() => {
    if (typeof document !== "undefined") {
      if (!light_mode) {
        document.documentElement.classList.add("dark");
      } else {
        document.documentElement.classList.remove("dark");
      }
    }
  });
</script>

<svelte:head>
  <!-- In the REPL you need to do this. In a normal Svelte app, use a CSS Rollup plugin and import it from the leaflet package. -->
  <link
    rel="stylesheet"
    href="https://unpkg.com/leaflet@1.6.0/dist/leaflet.css"
    integrity="sha512-xwE/Az9zrjBIphAcBb3F6JVqxf46+CDLwfLMHloNu6KEQCAWi6HcDUbeOfBIptF7tcCzusKFjFw2yuvEpDL9wQ=="
    crossorigin=""
  />
</svelte:head>

<main>
  {#if map}
    <Dashboard {map} bind:light_mode />
  {/if}

  <div id="map" style="height:100vh;width:100vw" use:mapAction></div>
</main>

<style>
  :global(.leaflet-top) {
    z-index: 999 !important;
  }
  :global(.leaflet-control-zoom) {
    margin: 1rem 1rem 0 0 !important;
    border-radius: calc(0.625rem + 4px) !important;
    overflow: hidden;
    border: 1px solid var(--border) !important;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15) !important;
  }
  :global(.leaflet-bar a) {
    background-color: var(--card) !important;
    color: var(--foreground) !important;
    border-bottom: 1px solid var(--border) !important;
    transition:
      background-color 0.15s ease,
      color 0.15s ease;
  }
  :global(.leaflet-bar a:last-child) {
    border-bottom: none !important;
  }
  :global(.leaflet-bar a:hover) {
    background-color: var(--accent) !important;
    color: var(--accent-foreground) !important;
  }
  :global(.leaflet-bar a.leaflet-disabled) {
    background-color: var(--muted) !important;
    color: var(--muted-foreground) !important;
  }
  :global(.leaflet-touch .leaflet-bar a) {
    border-radius: 0 !important;
  }
  :global(.leaflet-touch .leaflet-bar a:first-child) {
    border-top-left-radius: calc(0.625rem + 3px) !important;
    border-top-right-radius: calc(0.625rem + 3px) !important;
  }
  :global(.leaflet-touch .leaflet-bar a:last-child) {
    border-bottom-left-radius: calc(0.625rem + 3px) !important;
    border-bottom-right-radius: calc(0.625rem + 3px) !important;
  }

  :global(.leaflet-control-basemap) {
    margin-top: 0.5rem !important;
    margin-right: 1rem !important;
    border-radius: calc(0.625rem + 4px) !important;
    position: relative;
    border: 1px solid var(--border) !important;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15) !important;
  }
  :global(
      .leaflet-control-basemap .leaflet-basemap-btn,
      .leaflet-touch .leaflet-bar a
    ) {
    display: flex !important;
    align-items: center;
    justify-content: center;
    width: 30px !important;
    height: 30px !important;
    line-height: 30px !important;
    text-align: center;
    text-decoration: none;
    border-radius: calc(0.625rem + 3px) !important;
    font-size: 13px !important;
  }
  :global(.leaflet-touch .leaflet-control-basemap .leaflet-basemap-btn) {
    width: 34px !important;
    height: 34px !important;
    line-height: 34px !important;
  }
  :global(.leaflet-basemap-dropdown) {
    position: absolute;
    top: 0;
    right: calc(100% + 8px);
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 4px;
    background-color: var(--card);
    border: 1px solid var(--border);
    border-radius: calc(0.625rem + 4px);
    box-shadow: 0 6px 20px rgba(0, 0, 0, 0.2);
    min-width: 140px;
    z-index: 1000;
  }
  :global(.leaflet-basemap-dropdown.hidden) {
    display: none !important;
  }
  :global(.leaflet-basemap-item) {
    display: block;
    width: 100%;
    text-align: left;
    padding: 6px 10px;
    font-size: 12px;
    font-weight: 500;
    color: var(--foreground);
    background: transparent;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    transition:
      background-color 0.15s ease,
      color 0.15s ease;
    white-space: nowrap;
  }
  :global(.leaflet-basemap-item:hover) {
    background-color: var(--accent);
    color: var(--accent-foreground);
  }
  :global(.leaflet-basemap-item.active) {
    background-color: var(--primary);
    color: var(--primary-foreground);
    font-weight: 600;
  }
</style>
