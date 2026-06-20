#!/usr/bin/env python3
"""Resolve Transfermarkt IDs from Wikidata using DOB + nationality confidence scoring."""

from __future__ import annotations

import csv
import datetime as dt
import json
import random
import re
import ssl
import time
import unicodedata
import urllib.parse
import urllib.request
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

BASE_DIR = Path(__file__).resolve().parent
INPUT_CSV = BASE_DIR / "legendary_players.csv"
OUTPUT_WITH_ID = BASE_DIR / "legendary_players_with_tm_id.csv"
OUTPUT_MANUAL = BASE_DIR / "legendary_players_manual_review.csv"
CACHE_PATH = BASE_DIR / ".wikidata_cache.json"
PROGRESS_PATH = BASE_DIR / ".resolve_progress.json"
AUDIT_LOG_PATH = BASE_DIR / "wikidata_lookup_audit.log"

WITH_ID_FIELDS = [
    "Player Name",
    "Nationality",
    "DOB",
    "Position",
    "Senior Clubs Played For",
    "transfermarkt_id",
    "wikidata_qid",
    "match_confidence",
    "match_method",
]

MANUAL_FIELDS = [
    "Player Name",
    "Nationality",
    "DOB",
    "Position",
    "Senior Clubs Played For",
    "candidate_transfermarkt_id",
    "candidate_wikidata_qid",
    "candidate_name",
    "candidate_dob",
    "candidate_nationality",
    "match_confidence",
    "review_reason",
]

WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "ShiftTac-LegendaryMatcher/1.0 (Wikidata P2446 resolver)"

REQUEST_TIMEOUT_SECONDS = 25
MAX_QUERY_RETRIES = 4


def normalize_text(value: str) -> str:
    value = (value or "").strip().lower()
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = re.sub(r"[^a-z0-9\s]", " ", value)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


NATIONALITY_ALIASES = {
    "dutch": "netherlands",
    "the netherlands": "netherlands",
    "holland": "netherlands",
    "czechia": "czech republic",
    "ivory coast": "cote d ivoire",
    "cote divoire": "cote d ivoire",
    "usa": "united states",
    "united states of america": "united states",
    "england": "united kingdom",
}


def canonical_nationality(value: str) -> str:
    normalized = normalize_text(value)
    return NATIONALITY_ALIASES.get(normalized, normalized)


def parse_input_dob(raw: str) -> dt.date | None:
    text = (raw or "").strip()
    if not text:
        return None
    for fmt in ("%b %d, %Y", "%B %d, %Y", "%Y-%m-%d"):
        try:
            return dt.datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def parse_wikidata_dob(raw: str) -> dt.date | None:
    text = (raw or "").strip()
    if not text:
        return None
    if "T" in text:
        text = text.split("T", 1)[0]
    try:
        return dt.datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None


def parse_qid(entity_uri: str) -> str:
    return entity_uri.rsplit("/", 1)[-1]


def load_cache() -> dict[str, Any]:
    if not CACHE_PATH.exists():
        return {}
    try:
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_cache(cache: dict[str, Any]) -> None:
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding="utf-8")


def load_progress() -> dict[str, Any]:
    if not PROGRESS_PATH.exists():
        return {"completed_indices": [], "with_id_rows": [], "manual_rows": []}
    try:
        data = json.loads(PROGRESS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"completed_indices": [], "with_id_rows": [], "manual_rows": []}
    return {
        "completed_indices": list(data.get("completed_indices", [])),
        "with_id_rows": list(data.get("with_id_rows", [])),
        "manual_rows": list(data.get("manual_rows", [])),
    }


def save_progress(
    completed_indices: list[int],
    with_id_rows: list[dict[str, str]],
    manual_rows: list[dict[str, str]],
) -> None:
    PROGRESS_PATH.write_text(
        json.dumps(
            {
                "completed_indices": completed_indices,
                "with_id_rows": with_id_rows,
                "manual_rows": manual_rows,
                "updated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def clear_progress() -> None:
    if PROGRESS_PATH.exists():
        PROGRESS_PATH.unlink()


def write_outputs(with_id_rows: list[dict[str, str]], manual_rows: list[dict[str, str]]) -> None:
    with OUTPUT_WITH_ID.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=WITH_ID_FIELDS)
        writer.writeheader()
        writer.writerows(with_id_rows)

    with OUTPUT_MANUAL.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=MANUAL_FIELDS)
        writer.writeheader()
        writer.writerows(manual_rows)


def log_audit(message: str) -> None:
    timestamp = dt.datetime.now(dt.timezone.utc).isoformat()
    with AUDIT_LOG_PATH.open("a", encoding="utf-8") as file:
        file.write(f"[{timestamp}] {message}\n")


def build_query(name: str) -> str:
    normalized = normalize_text(name)
    terms = [part for part in normalized.split(" ") if part]
    # Use up to 3 longest terms to balance recall and precision.
    terms = sorted(terms, key=len, reverse=True)[:3]
    label_filters = " && ".join([f'CONTAINS(LCASE(?playerLabel), "{term}")' for term in terms]) or "true"
    return f"""
SELECT ?player ?playerLabel ?tmId ?dob ?nationalityLabel WHERE {{
  ?player wdt:P106 wd:Q937857;
          rdfs:label ?playerLabel;
          wdt:P2446 ?tmId.
  FILTER(LANG(?playerLabel) = "en")
  FILTER({label_filters})
  OPTIONAL {{ ?player wdt:P569 ?dob. }}
  OPTIONAL {{
    ?player wdt:P27 ?nationality.
    ?nationality rdfs:label ?nationalityLabel.
    FILTER(LANG(?nationalityLabel) = "en")
  }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
LIMIT 50
""".strip()


def fetch_wikidata(query: str) -> list[dict[str, str]]:
    params = urllib.parse.urlencode({"query": query})
    request = urllib.request.Request(
        f"{WIKIDATA_ENDPOINT}?{params}",
        headers={"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except Exception as error:
        is_cert_error = isinstance(error, ssl.SSLCertVerificationError) or "CERTIFICATE_VERIFY_FAILED" in str(error)
        if not is_cert_error:
            raise
        log_audit("ssl_cert_failure fallback=unverified_context")
        # Some environments have stale CA bundles; fallback keeps the batch moving.
        insecure_context = ssl._create_unverified_context()
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS, context=insecure_context) as response:
            payload = json.loads(response.read().decode("utf-8"))
    return payload.get("results", {}).get("bindings", [])


def fetch_candidates_with_retries(name: str, cache: dict[str, Any], use_cache: bool = False) -> list[dict[str, str]]:
    cache_key = normalize_text(name)
    if use_cache and cache_key in cache:
        entry = cache.get(cache_key, {})
        if isinstance(entry, dict) and isinstance(entry.get("candidates"), list):
            log_audit(f"cache_hit name={name} candidates={len(entry['candidates'])}")
            return entry["candidates"]

    query = build_query(name)
    for attempt in range(1, MAX_QUERY_RETRIES + 1):
        try:
            results = fetch_wikidata(query)
            candidates: list[dict[str, str]] = []
            for row in results:
                tm_id = row.get("tmId", {}).get("value", "").strip()
                if not tm_id:
                    continue
                candidates.append(
                    {
                        "qid": parse_qid(row.get("player", {}).get("value", "")),
                        "name": row.get("playerLabel", {}).get("value", "").strip(),
                        "transfermarkt_id": tm_id,
                        "dob": row.get("dob", {}).get("value", "").strip(),
                        "nationality": row.get("nationalityLabel", {}).get("value", "").strip(),
                    }
                )
            cache[cache_key] = {"fetched_at": dt.datetime.now(dt.timezone.utc).isoformat(), "candidates": candidates}
            return candidates
        except Exception as error:
            wait_seconds = (2 ** (attempt - 1)) + random.uniform(0.1, 0.8)
            log_audit(f"retry name={name} attempt={attempt} wait={wait_seconds:.2f}s error={error}")
            time.sleep(wait_seconds)
    return []


def fallback_name_variants(name: str) -> list[str]:
    normalized = normalize_text(name)
    variants = [normalized.title()]
    alias_map = {
        "pele": "Pele",
        "luis figo": "Luis Figo",
        "ronaldo nazario": "Ronaldo Nazario",
    }
    if normalized in alias_map:
        variants.append(alias_map[normalized])
    return list(dict.fromkeys(v for v in variants if v and v != name))


@dataclass
class ScoredCandidate:
    candidate: dict[str, str]
    score: int
    exact_dob_match: bool
    nationality_match: bool
    rejected: bool
    reject_reason: str


def score_candidate(player_row: dict[str, str], candidate: dict[str, str]) -> ScoredCandidate:
    input_dob = parse_input_dob(player_row.get("DOB", ""))
    cand_dob = parse_wikidata_dob(candidate.get("dob", ""))
    score = 0
    rejected = False
    reject_reason = ""
    exact_dob_match = False
    nationality_match = False

    if input_dob and cand_dob:
        if input_dob == cand_dob:
            score += 80
            exact_dob_match = True
        elif input_dob.year == cand_dob.year:
            score += 20
        else:
            rejected = True
            reject_reason = "low_confidence"
    elif not cand_dob:
        pass

    if not rejected:
        input_nat = player_row.get("Nationality", "")
        cand_nat = candidate.get("nationality", "")
        input_nat_norm = normalize_text(input_nat)
        cand_nat_norm = normalize_text(cand_nat)
        if input_nat_norm and cand_nat_norm:
            if input_nat_norm == cand_nat_norm:
                score += 20
                nationality_match = True
            elif canonical_nationality(input_nat) == canonical_nationality(cand_nat):
                score += 15
                nationality_match = True
            else:
                rejected = True
                score = 0
                reject_reason = "low_confidence"

    if not rejected:
        input_name = normalize_text(player_row.get("Player Name", ""))
        cand_name = normalize_text(candidate.get("name", ""))
        similarity = SequenceMatcher(a=input_name, b=cand_name).ratio()
        score += max(0, min(10, int(round(similarity * 10))))

    return ScoredCandidate(
        candidate=candidate,
        score=score if not rejected else 0,
        exact_dob_match=exact_dob_match,
        nationality_match=nationality_match,
        rejected=rejected,
        reject_reason=reject_reason,
    )


def process_player(
    row: dict[str, str],
    cache: dict[str, Any],
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    player_name = (row.get("Player Name") or "").strip()
    with_id_rows: list[dict[str, str]] = []
    manual_rows: list[dict[str, str]] = []

    candidates = fetch_candidates_with_retries(player_name, cache, use_cache=True)
    if not candidates:
        for fallback in fallback_name_variants(player_name):
            log_audit(f"fallback_query player={player_name} fallback={fallback}")
            candidates = fetch_candidates_with_retries(fallback, cache, use_cache=True)
            if candidates:
                break

    scored = [score_candidate(row, candidate) for candidate in candidates]
    scored = sorted(scored, key=lambda item: item.score, reverse=True)
    nonzero = [item for item in scored if item.score > 0]

    selected: ScoredCandidate | None = nonzero[0] if nonzero else None
    has_tie = bool(selected) and sum(1 for item in nonzero if item.score == selected.score) > 1

    auto_accept = bool(
        selected
        and selected.score >= 90
        and selected.exact_dob_match
        and selected.nationality_match
        and not has_tie
        and selected.candidate.get("transfermarkt_id")
    )

    if auto_accept and selected:
        with_id_rows.append(
            {
                "Player Name": row.get("Player Name", ""),
                "Nationality": row.get("Nationality", ""),
                "DOB": row.get("DOB", ""),
                "Position": row.get("Position", ""),
                "Senior Clubs Played For": row.get("Senior Clubs Played For", ""),
                "transfermarkt_id": selected.candidate.get("transfermarkt_id", ""),
                "wikidata_qid": selected.candidate.get("qid", ""),
                "match_confidence": str(selected.score),
                "match_method": "auto",
            }
        )
    else:
        review_reason = "low_confidence"
        if not candidates:
            review_reason = "low_confidence"
        elif has_tie:
            review_reason = "multiple_candidates"
        elif selected and not parse_wikidata_dob(selected.candidate.get("dob", "")):
            review_reason = "missing_dob"
        elif selected and not selected.candidate.get("nationality", "").strip():
            review_reason = "missing_nationality"
        elif selected and selected.score >= 60:
            review_reason = "ambiguous_name"

        source_rows = nonzero[:5] if nonzero else []
        if not source_rows:
            manual_rows.append(
                {
                    "Player Name": row.get("Player Name", ""),
                    "Nationality": row.get("Nationality", ""),
                    "DOB": row.get("DOB", ""),
                    "Position": row.get("Position", ""),
                    "Senior Clubs Played For": row.get("Senior Clubs Played For", ""),
                    "candidate_transfermarkt_id": "",
                    "candidate_wikidata_qid": "",
                    "candidate_name": "",
                    "candidate_dob": "",
                    "candidate_nationality": "",
                    "match_confidence": "0",
                    "review_reason": review_reason,
                }
            )
        else:
            for item in source_rows:
                manual_rows.append(
                    {
                        "Player Name": row.get("Player Name", ""),
                        "Nationality": row.get("Nationality", ""),
                        "DOB": row.get("DOB", ""),
                        "Position": row.get("Position", ""),
                        "Senior Clubs Played For": row.get("Senior Clubs Played For", ""),
                        "candidate_transfermarkt_id": item.candidate.get("transfermarkt_id", ""),
                        "candidate_wikidata_qid": item.candidate.get("qid", ""),
                        "candidate_name": item.candidate.get("name", ""),
                        "candidate_dob": item.candidate.get("dob", ""),
                        "candidate_nationality": item.candidate.get("nationality", ""),
                        "match_confidence": str(item.score),
                        "review_reason": review_reason,
                    }
                )

    return with_id_rows, manual_rows


def main() -> None:
    random.seed()
    cache = load_cache()
    rows = list(csv.DictReader(INPUT_CSV.open("r", encoding="utf-8-sig", newline="")))
    progress = load_progress()
    completed_indices = set(progress["completed_indices"])
    with_id_rows: list[dict[str, str]] = list(progress["with_id_rows"])
    manual_rows: list[dict[str, str]] = list(progress["manual_rows"])

    if completed_indices:
        resume_from = max(completed_indices) + 1
        log_audit(f"resume from_index={resume_from} completed={len(completed_indices)}")
        print(
            f"Resuming: {len(completed_indices)}/{len(rows)} already done, "
            f"starting at [{resume_from}/{len(rows)}]",
            flush=True,
        )

    for index, row in enumerate(rows, start=1):
        if index in completed_indices:
            continue

        player_name = (row.get("Player Name") or "").strip()
        log_audit(f"processing index={index} player={player_name}")
        safe_name = player_name.encode("ascii", errors="backslashreplace").decode("ascii")
        print(f"[{index}/{len(rows)}] {safe_name}", flush=True)

        player_with_id, player_manual = process_player(row, cache)
        with_id_rows.extend(player_with_id)
        manual_rows.extend(player_manual)

        completed_indices.add(index)
        save_cache(cache)
        save_progress(sorted(completed_indices), with_id_rows, manual_rows)
        write_outputs(with_id_rows, manual_rows)

        time.sleep(random.uniform(0.25, 0.8))

    clear_progress()
    write_outputs(with_id_rows, manual_rows)

    print(f"Auto accepted: {len(with_id_rows)}")
    print(f"Manual review rows: {len(manual_rows)}")
    print(f"Wrote: {OUTPUT_WITH_ID}")
    print(f"Wrote: {OUTPUT_MANUAL}")
    print(f"Audit log: {AUDIT_LOG_PATH}")


if __name__ == "__main__":
    main()
