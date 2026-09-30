<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import { ABOUT_METHODOLOGICAL_REPORT } from "../data";

    let { open = $bindable(false) } = $props();
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[2000] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel: same margins as the left sidebar -->
    <div
        class="fixed z-[2010] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden h-fit max-h-[calc(100vh-2rem)]
               top-4 left-4 right-4 sm:left-[calc(1rem+350px+0.5rem)] sm:right-4"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-4 border-b shrink-0"
        >
            <div>
                <h2 class="text-lg font-bold flex items-center gap-2">
                    <i class="fas fa-info-circle text-primary"></i>
                    About GTFShift
                </h2>
                <p class="text-sm text-muted-foreground mt-0.5">
                    Bus lane prioritisation & operational analysis tool
                </p>
            </div>
            <Button
                variant="ghost"
                size="sm"
                onclick={() => (open = false)}
                class="h-8 w-8 p-0 shrink-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Content -->
        <div
            class="flex-1 overflow-y-auto px-5 py-4 space-y-4 text-sm leading-relaxed"
        >
            <p>
                <strong>GTFShift</strong> is an open-source framework and methodology
                developed to harmonise public transit data (GTFS and GTFS-Realtime)
                with road infrastructure networks (OpenStreetMap). By linking scheduled
                service, observed operations, and street characteristics, it enables
                comprehensive diagnostics of transit performance to support evidence-based
                planning and public policy.
            </p>

            <p>
                This platform combines <strong
                    >infrastructure prioritisation</strong
                >
                with in-depth
                <strong>route- and trip-level operational analysis</strong>.
                Beyond identifying road segments with the highest potential for
                bus lanes and traffic interventions (evaluating available space,
                speeds, service frequency, and passenger demand), it enables
                detailed diagnosis of service performance, evaluating commercial
                speed and service variability across routes and individual trips
                without requiring programming or GIS skills.
            </p>

            <p>
                Developed by the <strong>U-Shift</strong> research group (CERIS,
                Instituto Superior Técnico) in collaboration with
                <strong>Transportes Metropolitanos de Lisboa (TML)</strong>,
                this edition adapts and extends the GTFShift tool to the
                operational reality of Carris Metropolitana, bridging academic
                research and transit management through open data and
                open-source software.
            </p>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
                <Button
                    variant="outline"
                    href={ABOUT_METHODOLOGICAL_REPORT}
                    target="_blank"
                    class="w-full justify-start"
                >
                    <i class="fa fa-book mr-2"></i> Methodological report
                </Button>
                <Button
                    variant="outline"
                    href="https://github.com/U-Shift/GTFShift-TML/"
                    target="_blank"
                    class="w-full justify-start"
                >
                    <i class="fa fa-github mr-2"></i> Web app repository
                </Button>
            </div>

            <div class="pt-4 border-t">
                <h4 class="font-bold mb-2">Developers</h4>
                <div class="space-y-1">
                    <p class="flex items-center gap-2">
                        Gonçalo F. Matos
                        <span class="text-xs text-muted-foreground"
                            >(Author, Maintainer)</span
                        >
                        <a
                            href="https://orcid.org/0009-0001-3489-1732"
                            target="_blank"
                            class="text-[#A6CE39] hover:opacity-80"
                            aria-label="ORCID for Gonçalo F. Matos"
                        >
                            <i class="fab fa-orcid"></i>
                        </a>
                    </p>
                    <p class="flex items-center gap-2">
                        Rosa Félix
                        <span class="text-xs text-muted-foreground"
                            >(Author)</span
                        >
                        <a
                            href="https://orcid.org/0000-0002-5642-6006"
                            target="_blank"
                            class="text-[#A6CE39] hover:opacity-80"
                            aria-label="ORCID for Rosa Félix"
                        >
                            <i class="fab fa-orcid"></i>
                        </a>
                    </p>
                </div>
            </div>

            <div class="pt-4 border-t space-y-3">
                <h4 class="font-bold mb-1">Funding & Acknowledgements</h4>
                <p>
                    The GTFShift R package and the bus lane prioritisation
                    dashboard were developed as part of research activities at
                    the <a
                        href="https://ushift.tecnico.ulisboa.pt"
                        target="_blank"
                        class="text-primary hover:underline">U-Shift</a
                    >
                    research group, part of
                    <a
                        href="https://ceris.pt"
                        target="_blank"
                        class="text-primary hover:underline">CERIS</a
                    >
                    (<em
                        >Civil Engineering Research and Innovation for
                        Sustainability</em
                    >), at Instituto Superior Técnico, Universidade de Lisboa.
                </p>
                <p>
                    The adaptation and extension of features to the operational
                    domain of Carris Metropolitana, which gave rise to the <strong
                        >GTFShift TML Edition</strong
                    >
                    interactive dashboard, was developed in collaboration with
                    and funded by
                    <a
                        href="https://www.tmlmobilidade.pt"
                        target="_blank"
                        class="text-primary hover:underline"
                        >Transportes Metropolitanos de Lisboa (TML)</a
                    > under a service provision agreement.
                </p>
                <div class="pt-1">
                    <img
                        src="static/logo_acknowledgement_tml.png"
                        alt="U-Shift, CERIS, Instituto Superior Técnico, TML"
                        class="max-w-2xl w-full object-contain"
                    />
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="shrink-0 px-5 py-3 border-t flex justify-end">
            <Button variant="secondary" onclick={() => (open = false)}
                >Close</Button
            >
        </div>
    </div>
{/if}
