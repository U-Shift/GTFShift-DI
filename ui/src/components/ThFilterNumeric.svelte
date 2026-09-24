<script lang="ts">
    import type { TableHandler } from "@vincjo/datatables";

    let {
        table,
        field,
        placeholder = "Filter...",
    }: {
        table: TableHandler<any>;
        field: (row: any) => number | undefined | null;
        placeholder?: string;
    } = $props();

    type Op = "gte" | "lte" | "eq" | "gt" | "lt";

    let op: Op = $state("gte");
    let inputVal = $state("");

    function checkNumeric(entry: unknown, value: unknown): boolean {
        if (value === undefined || value === null || value === "") return true;
        const entryNum = Number(entry);
        if (isNaN(entryNum) || entry === undefined || entry === null) {
            return false;
        }

        const param = value as { op: Op; target: number };
        switch (param.op) {
            case "gte":
                return entryNum >= param.target;
            case "lte":
                return entryNum <= param.target;
            case "eq":
                return Math.abs(entryNum - param.target) < 0.0001;
            case "gt":
                return entryNum > param.target;
            case "lt":
                return entryNum < param.target;
            default:
                return true;
        }
    }

    const filter = table.createFilter(field, checkNumeric);

    function applyFilter() {
        const trimmed = inputVal.trim();
        if (trimmed === "") {
            filter.value = "";
            filter.set();
            return;
        }

        // Support operator typed directly in input (e.g. ">5", "<=10", "=3")
        let parsedOp = op;
        let numStr = trimmed;
        if (trimmed.startsWith(">=")) {
            parsedOp = "gte";
            numStr = trimmed.slice(2).trim();
        } else if (trimmed.startsWith("<=")) {
            parsedOp = "lte";
            numStr = trimmed.slice(2).trim();
        } else if (trimmed.startsWith(">")) {
            parsedOp = "gt";
            numStr = trimmed.slice(1).trim();
        } else if (trimmed.startsWith("<")) {
            parsedOp = "lt";
            numStr = trimmed.slice(1).trim();
        } else if (trimmed.startsWith("=")) {
            parsedOp = "eq";
            numStr = trimmed.slice(1).trim();
        }

        const target = Number(numStr.replace("%", ""));
        if (isNaN(target)) {
            filter.value = "";
            filter.set();
            return;
        }

        filter.value = { op: parsedOp, target };
        filter.set();
    }

    function toggleOp() {
        const order: Op[] = ["gte", "lte", "eq", "gt", "lt"];
        const nextIdx = (order.indexOf(op) + 1) % order.length;
        op = order[nextIdx];
        if (inputVal.trim() !== "") {
            applyFilter();
        }
    }

    const opSymbols: Record<Op, string> = {
        gte: "≥",
        lte: "≤",
        eq: "=",
        gt: ">",
        lt: "<",
    };
</script>

<th>
    <div class="flex items-center gap-0.5 w-full bg-background rounded border border-border/50 px-1 py-0.5 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary">
        <button
            type="button"
            class="text-[11px] font-bold font-mono px-1 py-0.5 rounded hover:bg-muted/80 text-primary cursor-pointer select-none shrink-0"
            onclick={toggleOp}
            title="Click to cycle operator: ≥, ≤, =, >, <"
        >
            {opSymbols[op]}
        </button>
        <input
            type="text"
            class="w-full text-[11px] bg-transparent outline-none p-0 min-w-0"
            {placeholder}
            bind:value={inputVal}
            oninput={applyFilter}
        />
    </div>
</th>
