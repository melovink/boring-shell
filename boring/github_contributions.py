"""Read GitHub's public contribution calendar without an API token."""

import argparse
import json
import re
from datetime import date, timedelta
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen


class ContributionParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.days = {}
        self.tooltips = {}
        self.tooltip_id = None
        self.heading = ""
        self.in_heading = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("td", "rect") and "data-date" in attrs:
            day = date.fromisoformat(attrs["data-date"])
            level = int(attrs.get("data-level", "0"))
            if not 0 <= level <= 4:
                raise ValueError("Invalid contribution level")
            self.days[day] = {
                "date": day.isoformat(),
                "level": level,
                "count": int(attrs["data-count"]) if "data-count" in attrs else None,
                "id": attrs.get("id", ""),
            }
        elif tag == "tool-tip":
            self.tooltip_id = attrs.get("for")
            self.tooltips[self.tooltip_id] = ""
        elif tag == "h2" and attrs.get("id") == "js-contribution-activity-description":
            self.in_heading = True

    def handle_data(self, text):
        if self.tooltip_id is not None:
            self.tooltips[self.tooltip_id] += text
        if self.in_heading:
            self.heading += text

    def handle_endtag(self, tag):
        if tag == "tool-tip":
            self.tooltip_id = None
        elif tag == "h2":
            self.in_heading = False

    def calendar(self):
        if not self.days:
            raise ValueError("GitHub did not return a contribution calendar")

        days = sorted(self.days)
        if len(days) != (days[-1] - days[0]).days + 1:
            raise ValueError("GitHub returned an incomplete contribution calendar")

        # GitHub sends weekday rows; the desktop grid needs Sunday-first columns.
        start = days[0] - timedelta(days=(days[0].weekday() + 1) % 7)
        weeks = (days[-1] - start).days // 7 + 1
        cells = [None] * (weeks * 7)
        months = []
        for day in days:
            cell = self.days[day].copy()
            tooltip = self.tooltips.get(cell.pop("id"), "")
            if cell["count"] is None:
                count = re.search(r"([\d,]+)\s+contributions?\b", tooltip)
                if count:
                    cell["count"] = int(count[1].replace(",", ""))
                elif cell["level"] == 0:
                    cell["count"] = 0
                else:
                    raise ValueError("GitHub omitted a contribution count")
            offset = (day - start).days
            cells[offset] = cell
            if day.day == 1 and offset // 7 < weeks - 2:
                months.append({"week": offset // 7, "name": day.strftime("%b")})

        total = re.search(r"([\d,]+)\s+contributions?\b", self.heading)
        return {
            "cells": cells,
            "weeks": weeks,
            "months": months,
            "total": int(total[1].replace(",", "")) if total else sum(
                cell["count"] for cell in cells if cell is not None
            ),
        }


def fetch_calendar(username, cache_dir):
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?", username):
        return {"error": "Set a valid GitHub username"}

    cache_file = cache_dir / (username.lower() + ".json")
    try:
        request = Request(
            f"https://github.com/users/{username}/contributions",
            headers={"User-Agent": "Quickshell-GitHub-Calendar", "Accept-Language": "en-US"},
        )
        with urlopen(request, timeout=20) as response:
            html = response.read(2_000_000).decode("utf-8")
        parser = ContributionParser()
        parser.feed(html)
        calendar = parser.calendar()
    except (OSError, URLError, ValueError) as error:
        try:
            calendar = json.loads(cache_file.read_text())
            if not calendar.get("cells") or calendar.get("username") != username.lower():
                raise ValueError("Invalid cached calendar")
            return {**calendar, "stale": True}
        except (OSError, ValueError, AttributeError):
            return {"error": "Could not load GitHub contributions", "detail": str(error)}

    calendar.update(username=username.lower(), stale=False)
    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
        temporary = cache_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(calendar))
        temporary.replace(cache_file)
    except OSError:
        # A read-only cache must not prevent a freshly fetched graph from displaying.
        pass
    return calendar


if __name__ == "__main__":
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("username")
    args.add_argument("--cache-dir", type=Path, required=True)
    options = args.parse_args()
    print(json.dumps(fetch_calendar(options.username, options.cache_dir)))
