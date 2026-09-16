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
    const speedP75 = Number(wayProps.speed_p75);
    if (isNaN(speedP75) || speedP75 <= 0) return undefined;

    const hourlySpeedMedian =
        wayProps.hour_speed_median?.[criteriaHour] ??
        wayProps.hour_speed_median?.[String(criteriaHour)];

    if (hourlySpeedMedian === undefined || hourlySpeedMedian === null) {
        return undefined;
    }

    const speedMedian = Number(hourlySpeedMedian);
    if (isNaN(speedMedian)) return undefined;

    return (speedMedian - speedP75) / speedP75;
}

export type DICategory = {
    label: string;
    color: string;
    rangeLabel: string;
};

export const DISTURBANCE_INDEX_CATEGORIES: DICategory[] = [
    { label: "Much faster", color: "#0B3C5D", rangeLabel: "≥ +20%" },
    { label: "Faster", color: "#328CC1", rangeLabel: "+5% to +20%" },
    { label: "Regular speed", color: "#2ECC71", rangeLabel: "-5% to +5%" },
    { label: "Slower", color: "#E67E22", rangeLabel: "-20% to -5%" },
    { label: "Much slower", color: "#E74C3C", rangeLabel: "< -20%" },
];

export function getDisturbanceIndexCategory(di: number): DICategory {
    if (di >= 0.2) return DISTURBANCE_INDEX_CATEGORIES[0];
    if (di > 0.05) return DISTURBANCE_INDEX_CATEGORIES[1];
    if (di >= -0.05) return DISTURBANCE_INDEX_CATEGORIES[2];
    if (di >= -0.2) return DISTURBANCE_INDEX_CATEGORIES[3];
    return DISTURBANCE_INDEX_CATEGORIES[4];
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
        lineWeightBy === "speed_p75_min" ||
        lineWeightBy === "speed_p75_max"
    ) {
        return toNumberOrUndefined(wayProps?.speed_p75);
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
        lineWeightBy === "speed_p75_min"
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
        lineWeightBy === "speed_p75_max"
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
