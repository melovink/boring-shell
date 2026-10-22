// Linux aggregate CPU counters. Guest time is already included in user/nice.
function parseCpu(text) {
    const match = text.match(/^cpu\s+(.+)$/m);
    if (!match) return null;
    const fields = match[1].trim().split(/\s+/).map(Number);
    if (fields.length < 4) return null;
    let total = 0;
    for (let i = 0; i < Math.min(8, fields.length); i++) {
        if (!isFinite(fields[i]) || fields[i] < 0) return null;
        total += fields[i];
    }
    if (total <= 0) return null;
    return { total: total, idle: fields[3] + (fields[4] || 0) };
}

// The first sample establishes a baseline; usage describes the polling interval.
function cpuUsage(previous, current) {
    if (!previous || !current) return null;
    const total = current.total - previous.total;
    const idle = current.idle - previous.idle;
    if (total <= 0 || idle < 0) return null;
    return Math.max(0, Math.min(1, 1 - idle / total));
}

// MemAvailable includes reclaimable caches, so cached RAM is not counted as used.
function parseMemory(text) {
    const totalMatch = text.match(/^MemTotal:\s+(\d+)\s+kB\s*$/m);
    const availableMatch = text.match(/^MemAvailable:\s+(\d+)\s+kB\s*$/m);
    if (!totalMatch || !availableMatch) return null;
    const total = Number(totalMatch[1]) * 1024;
    if (total <= 0) return null;
    const available = Math.max(0, Math.min(total, Number(availableMatch[1]) * 1024));
    return { total: total, used: total - available };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseCpu, cpuUsage, parseMemory };
}
