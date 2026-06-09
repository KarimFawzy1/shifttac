"""Shared Wikimedia Commons thumbnail URL helpers for player image ETL."""
from __future__ import annotations

import urllib.parse
import urllib.request

COMMONS_HOST = "commons.wikimedia.org"
DEFAULT_THUMBNAIL_WIDTH = 128
USER_AGENT = "ShiftTacEtl/1.0 (player-image-etl; +https://github.com/KarimFawzy1/shifttac)"


def tm_id(raw: str) -> str:
    trimmed = raw.strip()
    return trimmed if trimmed.startswith("tm:") else f"tm:{trimmed}"


def tm_numeric(player_id: str) -> str:
    return tm_id(player_id).removeprefix("tm:")


def filename_from_p18_uri(p18_uri: str) -> str:
    """Extract decoded Commons filename from a Wikidata P18 URI."""
    raw = p18_uri.strip()
    if "Special:FilePath/" in raw:
        raw = raw.split("Special:FilePath/", 1)[1]
    elif raw.startswith("http://") or raw.startswith("https://"):
        raw = raw.rsplit("/", 1)[-1]
    return urllib.parse.unquote(raw).strip()


def build_commons_thumbnail_url(
    filename: str,
    *,
    width: int = DEFAULT_THUMBNAIL_WIDTH,
) -> str:
    """Build HTTPS Commons thumbnail URL with single-pass encoding."""
    decoded = urllib.parse.unquote(filename.strip())
    encoded = urllib.parse.quote(decoded, safe="")
    return (
        f"https://{COMMONS_HOST}/wiki/Special:FilePath/{encoded}?width={width}"
    )


def commons_file_from_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url.strip())
    if "Special:FilePath/" not in parsed.path:
        return ""
    raw = parsed.path.split("Special:FilePath/", 1)[1]
    return urllib.parse.unquote(raw)


def is_valid_commons_image_url(url: str) -> bool:
    trimmed = url.strip()
    if not trimmed:
        return False
    if "transfermarkt" in trimmed.lower():
        return False
    parsed = urllib.parse.urlparse(trimmed)
    if parsed.scheme != "https" or parsed.netloc != COMMONS_HOST:
        return False
    return "Special:FilePath" in parsed.path


def verify_commons_image_url(
    url: str,
    *,
    timeout: float = 20.0,
    user_agent: str = USER_AGENT,
) -> bool:
    """Return True when URL responds with an image content type."""
    if not is_valid_commons_image_url(url):
        return False

    headers = {"User-Agent": user_agent, "Range": "bytes=0-0"}
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            content_type = response.headers.get("Content-Type", "")
            return response.status in (200, 206) and content_type.startswith("image/")
    except urllib.error.HTTPError as exc:
        return exc.code in (200, 206) and exc.headers.get("Content-Type", "").startswith(
            "image/"
        )
    except (urllib.error.URLError, TimeoutError, OSError):
        return False
