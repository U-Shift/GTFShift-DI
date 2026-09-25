import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import type { GeoPrioritisation } from "../types/GeoPrioritisation";
import type { LineWeightMetric } from "../types/LineWeightMetric";

export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs));
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChild<T> = T extends { child?: any } ? Omit<T, "child"> : T;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChildren<T> = T extends { children?: any } ? Omit<T, "children"> : T;
export type WithoutChildrenOrChild<T> = WithoutChildren<WithoutChild<T>>;
export type WithElementRef<T, U extends HTMLElement = HTMLElement> = T & { ref?: U | null };

/**
 * Interpolates a color from a gradient based on a value and a range.
 */
export function getColorFromGradient(
    value: number | string | undefined | null,
    min: number | string | undefined | null,
    max: number | string | undefined | null,
    gradient: string[],
) {
    if (!gradient || gradient.length === 0) return "#000000";
    if (gradient.length === 1) return gradient[0];

    const v = typeof value === "number" ? value : parseFloat(String(value));
    const mn = typeof min === "number" ? min : parseFloat(String(min));
    const mx = typeof max === "number" ? max : parseFloat(String(max));

    if (isNaN(v) || isNaN(mn) || isNaN(mx)) return gradient[0];
    if (mn === mx) return gradient[0];

    const percent = Math.min(Math.max((v - mn) / (mx - mn), 0), 1);
    const index = percent * (gradient.length - 1);
    const lowIndex = Math.floor(index);
    const highIndex = Math.ceil(index);
    const fraction = index - lowIndex;

    const hexToRgb = (hex: string) => {
        if (!hex || typeof hex !== "string" || hex[0] !== "#") return [0, 0, 0];
        const r = parseInt(hex.substring(1, 3), 16);
        const g = parseInt(hex.substring(3, 5), 16);
        const b = parseInt(hex.substring(5, 7), 16);
        return [isNaN(r) ? 0 : r, isNaN(g) ? 0 : g, isNaN(b) ? 0 : b];
    };

    const rgbToHex = (r: number, g: number, b: number) => {
        return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
    };

    const color1 = hexToRgb(gradient[lowIndex]);
    const color2 = hexToRgb(gradient[highIndex]);

    const r = Math.round(color1[0] + (color2[0] - color1[0]) * fraction);
    const g = Math.round(color1[1] + (color2[1] - color1[1]) * fraction);
    const b = Math.round(color1[2] + (color2[2] - color1[2]) * fraction);

    return rgbToHex(r, g, b);
}

/**
 * Interpolates color from a diverging color palette centered at 0.
 * Left half represents negative values (from -maxAbs to 0).
 * Center represents 0.
 * Right half represents positive values (from 0 to +maxAbs).
 */
export function getDivergingColor(
    value: number | string | undefined | null,
    maxAbs: number,
    gradient: string[],
): string {
    if (!gradient || gradient.length === 0) return "#808080";
    const v = typeof value === "number" ? value : parseFloat(String(value));
    if (isNaN(v)) return "#808080";
    if (maxAbs <= 0) return gradient[Math.floor(gradient.length / 2)];

    // Map [-maxAbs, maxAbs] to [0, 1]
    const clampedRatio = Math.max(-1, Math.min(1, v / maxAbs));
    const percent = (clampedRatio + 1) / 2;

    const index = percent * (gradient.length - 1);
    const lowIndex = Math.floor(index);
    const highIndex = Math.ceil(index);
    const fraction = index - lowIndex;

    const hexToRgb = (hex: string) => {
        if (!hex || typeof hex !== "string" || hex[0] !== "#") return [0, 0, 0];
        const r = parseInt(hex.substring(1, 3), 16);
        const g = parseInt(hex.substring(3, 5), 16);
        const b = parseInt(hex.substring(5, 7), 16);
        return [isNaN(r) ? 0 : r, isNaN(g) ? 0 : g, isNaN(b) ? 0 : b];
    };

    const rgbToHex = (r: number, g: number, b: number) => {
        return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
    };

    const color1 = hexToRgb(gradient[lowIndex]);
    const color2 = hexToRgb(gradient[highIndex]);

    const r = Math.round(color1[0] + (color2[0] - color1[0]) * fraction);
    const g = Math.round(color1[1] + (color2[1] - color1[1]) * fraction);
    const b = Math.round(color1[2] + (color2[2] - color1[2]) * fraction);

    return rgbToHex(r, g, b);
}

export function getWayHourlyFrequency(
    wayProps:
        | {
            hour_frequency?: Record<string | number, number | string | undefined>;
        }
        | undefined,
    criteriaHour: number,
): number {
    const frequency = Number(wayProps?.hour_frequency?.[criteriaHour]);
    return Number.isNaN(frequency) ? 0 : frequency;
}

export function getFrequencyWeightedLineWidth(
    frequency: number | string | undefined | null,
    p5: number | string | undefined | null,
    p95: number | string | undefined | null,
    minWeight = 2.5,
    maxWeight = 7,
    fallbackWeight = 3.5,
    invert = false,
): number {
    const freq = Number(frequency);
    const minFreq = Number(p5);
    const maxFreq = Number(p95);

    if (Number.isNaN(freq) || Number.isNaN(minFreq) || Number.isNaN(maxFreq)) {
        return fallbackWeight;
    }
    if (maxFreq <= minFreq) return (minWeight + maxWeight) / 2;

    const ratio = (freq - minFreq) / (maxFreq - minFreq);
    const normalizedRatio = invert ? 1 - ratio : ratio;
    const clampedRatio = Math.max(0, Math.min(1, normalizedRatio));
    return minWeight + clampedRatio * (maxWeight - minWeight);
}

function toNumberOrUndefined(value: unknown): number | undefined {
    const parsed = Number(value);
    return Number.isNaN(parsed) ? undefined : parsed;
}

export function getDisturbanceIndex(
    wayProps: Record<string, any> | undefined,
    criteriaHour: number,
): number | undefined {
    if (!wayProps) return undefined;
    const di =
        wayProps.hour_disturbance_index?.[criteriaHour] ??
        wayProps.hour_disturbance_index?.[String(criteriaHour)];
    if (di === undefined || di === null) return undefined;
    const num = Number(di);
    return isNaN(num) ? undefined : num;
}

export type DICategory = {
    label: string;
    color: string;
    rangeLabel: string;
};

export function getDisturbanceIndexCategories(
    low = 0.05,
    high = 0.2,
): DICategory[] {
    const lowPct = (low * 100).toFixed(0);
    const highPct = (high * 100).toFixed(0);
    return [
        { label: "Much faster", color: "#0B3C5D", rangeLabel: `≥ +${highPct}%` },
        { label: "Faster", color: "#328CC1", rangeLabel: `+${lowPct}% to +${highPct}%` },
        { label: "Regular speed", color: "#2ECC71", rangeLabel: `-${lowPct}% to +${lowPct}%` },
        { label: "Slower", color: "#E67E22", rangeLabel: `-${highPct}% to -${lowPct}%` },
        { label: "Much slower", color: "#E74C3C", rangeLabel: `< -${highPct}%` },
    ];
}

export const DISTURBANCE_INDEX_CATEGORIES: DICategory[] = getDisturbanceIndexCategories(0.05, 0.2);

export function getDisturbanceIndexCategory(
    di: number,
    low = 0.05,
    high = 0.2,
): DICategory {
    const cats = getDisturbanceIndexCategories(low, high);
    if (di >= high) return cats[0];
    if (di > low) return cats[1];
    if (di >= -low) return cats[2];
    if (di >= -high) return cats[3];
    return cats[4];
}

export function getWayMetricValue(
    wayProps: Record<string, any> | undefined,
    criteriaHour: number,
    lineWeightBy: LineWeightMetric,
): number | undefined {
    if (lineWeightBy === "none") return undefined;
    if (lineWeightBy === "frequency") {
        return getWayHourlyFrequency(wayProps, criteriaHour);
    }
    if (lineWeightBy === "lanes") {
        return toNumberOrUndefined(wayProps?.n_lanes_circulation_direction);
    }
    if (
        lineWeightBy === "speed_avg_min" ||
        lineWeightBy === "speed_avg_max" ||
        lineWeightBy === "speed_min" ||
        lineWeightBy === "speed_max"
    ) {
        return toNumberOrUndefined(wayProps?.speed_avg);
    }
    if (
        lineWeightBy === "speed_median_min" ||
        lineWeightBy === "speed_median_max"
    ) {
        return toNumberOrUndefined(wayProps?.speed_median);
    }
    if (
        lineWeightBy === "speed_p85_min" ||
        lineWeightBy === "speed_p85_max"
    ) {
        return toNumberOrUndefined(wayProps?.speed_p85);
    }
    if (lineWeightBy === "disturbance_index") {
        const di = getDisturbanceIndex(wayProps, criteriaHour);
        return di !== undefined ? Math.abs(di) : undefined;
    }
    if (lineWeightBy === "demand") {
        return toNumberOrUndefined(wayProps?.demand);
    }
    return undefined;
}

export function getLineWeight(
    geoData: GeoPrioritisation,
    wayProps: Record<string, any> | undefined,
    criteriaHour: number,
    lineWeightBy: LineWeightMetric,
): number {
    if (lineWeightBy === "none") return 3.5;

    const value = getWayMetricValue(wayProps, criteriaHour, lineWeightBy);
    if (value === undefined) return 3.5;

    if (lineWeightBy === "frequency") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p5,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p95,
        );
    }
    if (lineWeightBy === "lanes") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.lanes_length?.p5,
            geoData.metadata.data_census.lanes_length?.p95,
        );
    }
    if (
        lineWeightBy === "speed_avg_min" ||
        lineWeightBy === "speed_min" ||
        lineWeightBy === "speed_median_min" ||
        lineWeightBy === "speed_p85_min"
    ) {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.speed_avg_length?.p5,
            geoData.metadata.data_census.speed_avg_length?.p95,
            2.5,
            7,
            3.5,
            true,
        );
    }
    if (
        lineWeightBy === "speed_avg_max" ||
        lineWeightBy === "speed_max" ||
        lineWeightBy === "speed_median_max" ||
        lineWeightBy === "speed_p85_max"
    ) {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.speed_avg_length?.p5,
            geoData.metadata.data_census.speed_avg_length?.p95,
        );
    }
    if (lineWeightBy === "disturbance_index") {
        return getFrequencyWeightedLineWidth(value, 0, 0.4, 2.5, 7, 3.5);
    }
    if (lineWeightBy === "demand") {
        return getFrequencyWeightedLineWidth(
            value,
            geoData.metadata.data_census.demand_length?.p5,
            geoData.metadata.data_census.demand_length?.p95,
        );
    }

    return 3.5;
}

export function computeWeightedStatistics(
    values: { value: number; weight: number }[],
): import("../types/GeoPrioritisation").StatisticsBundle | undefined {
    const valid = values.filter(
        (v) =>
            v.value !== undefined &&
            v.value !== null &&
            !isNaN(v.value) &&
            isFinite(v.value) &&
            v.weight !== undefined &&
            v.weight !== null &&
            !isNaN(v.weight) &&
            v.weight > 0,
    );

    if (valid.length === 0) return undefined;

    // Sort ascending by value
    valid.sort((a, b) => a.value - b.value);

    const totalWeight = valid.reduce((acc, v) => acc + v.weight, 0);
    if (totalWeight <= 0) return undefined;

    // Weighted mean
    const weightedSum = valid.reduce((acc, v) => acc + v.value * v.weight, 0);
    const mean = weightedSum / totalWeight;

    // Weighted variance and sd
    const weightedVarSum = valid.reduce(
        (acc, v) => acc + v.weight * Math.pow(v.value - mean, 2),
        0,
    );
    const variance = weightedVarSum / totalWeight;
    const sd = Math.sqrt(variance);

    const min = valid[0].value;
    const max = valid[valid.length - 1].value;

    // Helper for weighted percentile
    const getPercentile = (p: number) => {
        const target = p * totalWeight;
        let cum = 0;
        for (let i = 0; i < valid.length; i++) {
            cum += valid[i].weight;
            if (cum >= target) {
                return valid[i].value;
            }
        }
        return valid[valid.length - 1].value;
    };

    const p5 = getPercentile(0.05);
    const p25 = getPercentile(0.25);
    const median = getPercentile(0.5);
    const p75 = getPercentile(0.75);
    const p85 = getPercentile(0.85);
    const p95 = getPercentile(0.95);

    // Median below p85
    const belowP85 = valid.filter((v) => v.value <= p85);
    let median_below_p85 = median;
    if (belowP85.length > 0) {
        const totalWeightBelow = belowP85.reduce((acc, v) => acc + v.weight, 0);
        const targetBelow = 0.5 * totalWeightBelow;
        let cumBelow = 0;
        for (let i = 0; i < belowP85.length; i++) {
            cumBelow += belowP85[i].weight;
            if (cumBelow >= targetBelow) {
                median_below_p85 = belowP85[i].value;
                break;
            }
        }
    }

    return {
        n: valid.length,
        min,
        max,
        p5,
        p25,
        p75,
        p95,
        mean,
        median,
        median_below_p85,
        variance,
        sd,
    };
}

/**
 * Converts a string (e.g. UPPERCASE GTFS stop name) to Capital Case / Title Case.
 */
export function toCapitalCase(str: string | undefined | null): string {
    if (!str) return "";
    return str
        .toLowerCase()
        .replace(/(?:^|[\s\-\/\(\)\.,;:])\w/g, (match) => match.toUpperCase());
}
