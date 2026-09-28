<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import { ABOUT_METHODOLOGICAL_SLIDES } from "../data";

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
            <p>...</p>

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

            <div class="pt-4 border-t">
                <h4 class="font-bold mb-1">Acknowledgement</h4>
                <p class="mb-4">
                    Developed by <a
                        href="https://ushift.tecnico.ulisboa.pt"
                        target="_blank"
                        class="text-primary hover:underline">U-Shift</a
                    >, a research group from Instituto Superior Técnico, Lisboa,
                    Portugal.
                </p>
                <a
                    href="https://ushift.tecnico.ulisboa.pt"
                    target="_blank"
                    class="block w-48"
                >
                    <img
                        src="static/logo_acknowledgement.png"
                        alt="U-shift research group"
                        class="w-full object-contain"
                    />
                </a>
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
