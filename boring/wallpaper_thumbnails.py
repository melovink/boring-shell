#!/usr/bin/env python3
"""Stream a wallpaper index, reusing disk previews before generating missing ones."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit


EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".avif"}
VERSION = 1
WIDTH, HEIGHT = 520, 384


def emit(event: dict) -> None:
    print(json.dumps(event, ensure_ascii=False), flush=True)


def local_path(value: str) -> Path:
    if value.startswith("file:"):
        value = unquote(urlsplit(value).path)
    return Path(value).expanduser().absolute()


def read_index(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        if data.get("version") == VERSION and isinstance(data.get("entries"), list):
            return data
    except (OSError, ValueError, AttributeError):
        pass
    return {"version": VERSION, "entries": []}


def save_index(path: Path, entries: list[dict]) -> None:
    data = {"version": VERSION, "width": WIDTH, "height": HEIGHT, "entries": entries}
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        temporary.write_text(json.dumps(data, ensure_ascii=False))
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def preferred_format() -> str:
    # AVIF requires the Qt image plugin as well as an encoder. WebP is the fallback.
    plugin_roots = [Path(p) for p in os.environ.get("QT_PLUGIN_PATH", "").split(":") if p]
    plugin_roots += [Path("/usr/lib/qt6/plugins"), Path("/usr/lib/x86_64-linux-gnu/qt6/plugins")]
    if any(list((root / "imageformats").glob("*avif*")) for root in plugin_roots):
        return "avif"
    return "webp"


def fingerprint(path: Path) -> str:
    stat = path.stat()
    value = f"{VERSION}:{WIDTH}:{HEIGHT}:{stat.st_size}:{stat.st_mtime_ns}"
    return hashlib.sha256(value.encode()).hexdigest()[:20]


def scan(directory: Path, cache: Path, image_format: str, previous: dict) -> list[dict]:
    known = {entry.get("path"): entry for entry in previous["entries"] if isinstance(entry, dict)}
    entries = []
    for source in directory.iterdir():
        if source.suffix.lower() not in EXTENSIONS or not source.is_file():
            continue
        try:
            key = fingerprint(source)
            target = cache / f"{source.name}.{image_format}"
            old = known.get(str(source), {})
            fresh = target.is_file() and target.stat().st_size > 0 and (
                (old.get("key") == key and old.get("fresh") is True)
                or (not old.get("key") and target.stat().st_mtime_ns >= source.stat().st_mtime_ns)
            )
            # An outdated thumbnail is still a useful immediate preview while replacing it.
            preview = target.as_uri() + "?v=" + (key if fresh else str(target.stat().st_mtime_ns)) if target.is_file() else ""
            entries.append({"path": str(source), "name": source.name, "key": key,
                            "thumbnail": preview, "fresh": fresh})
        except OSError:
            continue
    return sorted(entries, key=lambda entry: (not bool(entry["thumbnail"]), entry["name"].casefold(), entry["name"]))


def generate(source: Path, target: Path, image_format: str) -> None:
    descriptor, filename = tempfile.mkstemp(prefix=".preview-", suffix=f".{image_format}", dir=target.parent)
    os.close(descriptor)
    temporary = Path(filename)
    commands = []
    if shutil.which("vipsthumbnail"):
        options = "Q=55,effort=2,compression=av1,bitdepth=8,keep=none" if image_format == "avif" else "Q=80,effort=2,keep=none"
        commands.append(["vipsthumbnail", str(source), "--size", f"{WIDTH}x{HEIGHT}",
                         "--path", str(temporary) + "[" + options + "]", "--vips-concurrency", "2",
                         "--vips-cache-max-memory", "16777216"])
    if shutil.which("magick"):
        commands.append(["magick", "-limit", "thread", "2", "-limit", "memory", "64MiB",
                         "-limit", "map", "128MiB", str(source) + "[0]", "-auto-orient",
                         "-thumbnail", f"{WIDTH}x{HEIGHT}>", "-strip", "-quality", "65", str(temporary)])
    try:
        error = "Install libvips or ImageMagick to generate wallpaper previews."
        for command in commands:
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=60, check=False)
            except subprocess.TimeoutExpired:
                error = "Thumbnail conversion timed out."
                continue
            if result.returncode == 0 and temporary.stat().st_size > 0:
                temporary.replace(target)
                return
            error = result.stderr.strip() or "Thumbnail conversion failed."
        raise RuntimeError(error)
    finally:
        temporary.unlink(missing_ok=True)


def refresh(directory: Path, image_format: str) -> None:
    cache = directory / "thumbnail"
    cache.mkdir(parents=True, exist_ok=True)
    manifest = cache / "index.json"
    # A second shell instance can show its cache immediately while the first warms it.
    previous = read_index(manifest)
    entries = scan(directory, cache, image_format, previous)
    emit({"type": "index", "entries": entries})
    with (cache / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        updated = scan(directory, cache, image_format, read_index(manifest))
        if updated != entries:
            emit({"type": "index", "entries": updated})
        entries = updated
        save_index(manifest, entries)
        for entry in entries:
            if entry["fresh"]:
                continue
            target = cache / f"{entry['name']}.{image_format}"
            try:
                generate(Path(entry["path"]), target, image_format)
                entry["thumbnail"] = target.as_uri() + "?v=" + entry["key"]
                entry["fresh"] = True
                save_index(manifest, entries)
                emit({"type": "thumbnail", "path": entry["path"], "thumbnail": entry["thumbnail"]})
            except (OSError, RuntimeError) as error:
                emit({"type": "error", "name": entry["name"], "message": str(error)})
        save_index(manifest, entries)
        emit({"type": "complete"})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory")
    parser.add_argument("--format", choices=("auto", "avif", "webp"), default="auto")
    args = parser.parse_args()
    try:
        refresh(local_path(args.directory), preferred_format() if args.format == "auto" else args.format)
    except (OSError, ValueError) as error:
        emit({"type": "error", "message": str(error)})
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
