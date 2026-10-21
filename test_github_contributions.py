import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import URLError

from github_contributions import ContributionParser, fetch_calendar


# Deliberately in weekday-row order, as GitHub serves its HTML table.
CALENDAR = """
<h2 id="js-contribution-activity-description">1,234 contributions in the last year</h2>
<td id="sun" data-date="2026-10-18" data-level="0"></td>
<td id="mon" data-date="2026-10-19" data-level="1"></td>
<td id="tue" data-date="2026-10-20" data-level="2"></td>
<td id="wed" data-date="2026-10-21" data-level="4"></td>
<td id="thu" data-date="2026-10-15" data-level="0"></td>
<td id="fri" data-date="2026-10-16" data-level="0"></td>
<td id="sat" data-date="2026-10-17" data-level="0"></td>
<tool-tip for="mon">1 contribution on October 19th.</tool-tip>
<tool-tip for="tue">2 contributions on October 20th.</tool-tip>
<tool-tip for="wed">1,231 contributions on October 21st.</tool-tip>
"""


class ContributionTests(unittest.TestCase):
    def parse(self, html):
        parser = ContributionParser()
        parser.feed(html)
        return parser.calendar()

    def test_weekday_rows_become_sunday_first_columns_with_future_padding(self):
        calendar = self.parse(CALENDAR)
        self.assertEqual(calendar["weeks"], 2)
        self.assertEqual(calendar["cells"][:4], [None] * 4)
        self.assertEqual(calendar["cells"][4]["date"], "2026-10-15")
        self.assertEqual(calendar["cells"][7]["date"], "2026-10-18")
        self.assertEqual(calendar["cells"][11:], [None] * 3)

    def test_counts_and_levels_come_from_cells_and_tooltips(self):
        calendar = self.parse(CALENDAR)
        self.assertEqual(calendar["total"], 1234)
        self.assertEqual(calendar["cells"][8]["count"], 1)
        self.assertEqual(calendar["cells"][10]["count"], 1231)
        self.assertEqual(calendar["cells"][10]["level"], 4)
        self.assertEqual(calendar["cells"][4]["count"], 0)

    def test_no_activity_is_a_valid_calendar(self):
        calendar = self.parse('<td data-date="2026-10-21" data-level="0"></td>')
        self.assertEqual(calendar["total"], 0)

    def test_missing_active_tooltip_and_incomplete_calendar_are_rejected(self):
        for html in (
            '<td data-date="2026-10-21" data-level="1"></td>',
            '<td data-date="2026-10-19"></td><td data-date="2026-10-21"></td>',
            '<html>Service unavailable</html>',
        ):
            with self.subTest(html=html), self.assertRaises(ValueError):
                self.parse(html)

    def test_offline_refresh_preserves_the_last_successful_calendar(self):
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory)
            with patch("github_contributions.urlopen", return_value=io.BytesIO(CALENDAR.encode())):
                live = fetch_calendar("melovink", cache_dir)
            self.assertFalse(live["stale"])
            with patch("github_contributions.urlopen", side_effect=URLError("offline")):
                cached = fetch_calendar("melovink", cache_dir)
            self.assertTrue(cached["stale"])
            self.assertEqual(cached["cells"], live["cells"])
            self.assertEqual(cached["total"], 1234)

    def test_bad_response_does_not_overwrite_cached_data(self):
        with tempfile.TemporaryDirectory() as directory:
            cache_dir = Path(directory)
            with patch("github_contributions.urlopen", return_value=io.BytesIO(CALENDAR.encode())):
                fetch_calendar("melovink", cache_dir)
            with patch("github_contributions.urlopen", return_value=io.BytesIO(b"<html>Error</html>")):
                cached = fetch_calendar("melovink", cache_dir)
            self.assertTrue(cached["stale"])
            self.assertEqual(cached["total"], 1234)

    def test_invalid_username_does_not_make_a_request(self):
        with patch("github_contributions.urlopen") as request:
            self.assertIn("error", fetch_calendar("../other-user", Path("/tmp")))
            request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
