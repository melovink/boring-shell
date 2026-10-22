import contextlib
import io
import json
from pathlib import Path
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

import wallpaper_thumbnails as thumbnails


def make_png(path, width=1040, height=768, color=b"\x44\x88\xcc"):
    def chunk(name, data):
        return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))

    pixels = (b"\x00" + color * width) * height
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


@unittest.skipUnless(shutil.which("vipsthumbnail") or shutil.which("magick"), "thumbnail encoder required")
class ThumbnailTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "wallpaper with spaces.png"
        make_png(self.source)

    def refresh(self, image_format="webp"):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            thumbnails.refresh(self.directory, image_format)
        return [json.loads(line) for line in output.getvalue().splitlines()]

    def test_generates_bounded_preview_and_keeps_original_unchanged(self):
        before = self.source.read_bytes()
        events = self.refresh()
        self.assertEqual(events[0]["type"], "index")
        self.assertFalse(events[0]["entries"][0]["thumbnail"])
        generated = next(event for event in events if event["type"] == "thumbnail")
        self.assertEqual(generated["path"], str(self.source))
        preview = self.directory / "thumbnail" / (self.source.name + ".webp")
        self.assertTrue(preview.is_file())
        self.assertEqual(self.source.read_bytes(), before)
        if shutil.which("magick"):
            result = thumbnails.subprocess.check_output(
                ["magick", "identify", "-format", "%w %h", str(preview)], text=True)
            width, height = map(int, result.split())
            self.assertLessEqual(width, thumbnails.WIDTH)
            self.assertLessEqual(height, thumbnails.HEIGHT)

    def test_warm_cache_is_returned_without_reencoding(self):
        self.refresh()
        with patch.object(thumbnails, "generate", side_effect=AssertionError("cache was not reused")):
            events = self.refresh()
        self.assertTrue(events[0]["entries"][0]["thumbnail"])
        self.assertFalse(any(event["type"] == "thumbnail" for event in events))

    def test_cached_previews_are_emitted_before_new_files_are_encoded(self):
        self.refresh()
        make_png(self.directory / "a new image.png")
        events = []
        original_generate = thumbnails.generate

        def generate(*args):
            self.assertEqual(events[0]["type"], "index")
            self.assertEqual(events[0]["entries"][0]["name"], self.source.name)
            self.assertTrue(events[0]["entries"][0]["thumbnail"])
            original_generate(*args)

        with patch.object(thumbnails, "emit", side_effect=events.append), patch.object(thumbnails, "generate", side_effect=generate):
            thumbnails.refresh(self.directory, "webp")
        self.assertTrue(any(event["type"] == "thumbnail" for event in events))

    def test_changed_original_refreshes_its_preview(self):
        first = self.refresh()[0]["entries"][0]["key"]
        make_png(self.source, color=b"\xff\x22\x00")
        events = self.refresh()
        self.assertNotEqual(events[0]["entries"][0]["key"], first)
        self.assertTrue(any(event["type"] == "thumbnail" for event in events))

    def test_failed_refresh_keeps_old_preview_and_retries_next_open(self):
        self.refresh()
        make_png(self.source, color=b"\x22\xff\x00")
        with patch.object(thumbnails, "generate", side_effect=RuntimeError("test conversion failure")) as generate:
            first = self.refresh()
            second = self.refresh()
        self.assertEqual(generate.call_count, 2)
        self.assertTrue(first[0]["entries"][0]["thumbnail"])
        self.assertTrue(any(event["type"] == "error" for event in second))

    def test_missing_preview_is_recreated_and_deleted_original_is_removed_from_index(self):
        self.refresh()
        preview = self.directory / "thumbnail" / (self.source.name + ".webp")
        preview.unlink()
        self.assertTrue(any(event["type"] == "thumbnail" for event in self.refresh()))
        self.source.unlink()
        events = self.refresh()
        self.assertEqual(events[0]["entries"], [])
        self.assertTrue(preview.exists())

    def test_avif_generation_when_qt_supports_it(self):
        if thumbnails.preferred_format() != "avif":
            self.skipTest("Qt AVIF image plugin is unavailable")
        events = self.refresh("avif")
        self.assertTrue(any(event["type"] == "thumbnail" for event in events))
        self.assertTrue((self.directory / "thumbnail" / (self.source.name + ".avif")).is_file())

    def test_local_file_urls_and_corrupt_index(self):
        self.assertEqual(thumbnails.local_path(self.source.as_uri()), self.source)
        cache = self.directory / "thumbnail"
        cache.mkdir()
        (cache / "index.json").write_text("{not valid JSON")
        events = self.refresh()
        self.assertTrue(any(event["type"] == "thumbnail" for event in events))
        self.assertEqual(thumbnails.read_index(cache / "index.json")["version"], thumbnails.VERSION)


if __name__ == "__main__":
    unittest.main()
