import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { parseCpu, cpuUsage, parseMemory } = require("./system_metrics.js");

test("CPU sampling uses the aggregate and counts guest time only once", () => {
    assert.deepEqual(parseCpu("cpu  100 20 30 400 50 6 7 8 80 10\ncpu0 1 2 3 4\n"),
        { total: 621, idle: 450 });
});

test("CPU usage reflects elapsed busy time and treats iowait as idle", () => {
    const previous = parseCpu("cpu 100 0 100 700 100 0 0 0\n");
    const current = parseCpu("cpu 125 0 100 750 125 0 0 0\n");
    assert.equal(cpuUsage(previous, current), 0.25);
    assert.equal(cpuUsage(current, { total: 1200, idle: 975 }), 0);
    assert.equal(cpuUsage(current, { total: 1200, idle: 875 }), 1);
});

test("CPU needs two advancing samples and discards reset counters", () => {
    const sample = { total: 100, idle: 80 };
    assert.equal(cpuUsage(null, sample), null);
    assert.equal(cpuUsage(sample, sample), null);
    assert.equal(cpuUsage(sample, { total: 50, idle: 20 }), null);
    assert.equal(cpuUsage(sample, { total: 150, idle: 70 }), null);
});

test("CPU rejects missing or malformed aggregate counters", () => {
    for (const text of ["", "cpu0 1 2 3 4", "cpu 1 2", "cpu 1 2 bad 4", "cpu 1 2 3 -4", "cpu 0 0 0 0"]) {
        assert.equal(parseCpu(text), null);
    }
});

test("RAM uses available memory, including cache, and converts KiB to bytes", () => {
    assert.deepEqual(parseMemory("MemTotal: 16000 kB\nMemFree: 1000 kB\nMemAvailable: 10000 kB\nCached: 9000 kB\n"),
        { total: 16384000, used: 6144000 });
});

test("RAM accepts fully used memory and bounds inconsistent availability", () => {
    assert.deepEqual(parseMemory("MemTotal: 100 kB\nMemAvailable: 0 kB\n"),
        { total: 102400, used: 102400 });
    assert.deepEqual(parseMemory("MemTotal: 100 kB\nMemAvailable: 200 kB\n"),
        { total: 102400, used: 0 });
});

test("RAM rejects missing, invalid and zero totals", () => {
    for (const text of ["", "MemTotal: 100 kB", "MemTotal: 0 kB\nMemAvailable: 0 kB", "MemTotal: bad kB\nMemAvailable: 1 kB"]) {
        assert.equal(parseMemory(text), null);
    }
});
