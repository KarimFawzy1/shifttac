import csv
import yaml
from collections import Counter
from pathlib import Path

FAMOUS = {
    "Celtic", "Rangers", "Southampton", "Nottingham Forest", "Leicester City",
    "Schalke 04", "Queens Park Rangers", "Blackburn Rovers", "Middlesbrough",
    "Stoke City", "Norwich City", "Derby County", "Portsmouth", "Burnley",
    "West Bromwich Albion", "Sunderland", "Sheffield United", "Watford",
    "Borussia Mönchengladbach", "Hamburger SV", "Werder Bremen", "FC Köln",
    "Kaiserslautern", "VfL Wolfsburg", "1860 Munich", "Hertha BSC",
    "Sampdoria", "Parma", "Genoa", "Torino", "Udinese", "Brescia", "Cagliari",
    "Espanyol", "Deportivo La Coruña", "Athletic Bilbao", "Real Sociedad",
    "Real Zaragoza", "Rayo Vallecano", "Real Betis", "Málaga", "Celta Vigo",
    "Bordeaux", "Saint-Étienne", "Nantes", "Montpellier", "Auxerre", "Strasbourg",
    "Guingamp", "Rennes", "Metz",
    "Feyenoord", "Groningen", "Heerenveen", "Twente", "AZ Alkmaar",
    "Braga", "Boavista",
    "Corinthians", "São Paulo", "Fluminense", "Cruzeiro", "Palmeiras", "Grêmio",
    "Vasco da Gama", "Botafogo", "Internacional", "Atlético Mineiro", "Bahia",
    "River Plate", "Newell's Old Boys", "Independiente", "Racing Club",
    "Estudiantes", "Vélez Sarsfield", "San Lorenzo", "Argentinos Juniors",
    "Atlético Nacional", "Millonarios", "América",
    "Red Star Belgrade", "Partizan Belgrade", "Dinamo Zagreb", "Dynamo Kyiv",
    "Sparta Prague", "Steaua Bucharest",
    "Fenerbahçe", "Beşiktaş", "Olympiacos", "Panathinaikos", "AEK Athens",
    "Trabzonspor",
    "Malmö FF", "Rosenborg",
    "New York Cosmos", "New York Red Bulls", "Los Angeles Galaxy", "Los Angeles FC",
    "Los Angeles Aztecs", "D.C. United", "Chicago Fire", "Inter Miami",
    "MetroStars", "Seattle Sounders", "New York City FC",
    "Al-Hilal", "Al-Nassr", "Al-Sadd", "Al-Ahli", "Al-Ittihad", "Al-Shabab",
    "Vissel Kobe", "Kashima Antlers", "Urawa Red Diamonds",
    "Basel", "Anderlecht", "Club Brugge",
    "Cannes", "Bastia", "Lille", "Nice",
}

ROOT = Path(__file__).resolve().parents[1]
rows = list(csv.DictReader((ROOT / "legendary-players/legendary_players_with_tm_id.csv").open(encoding="utf-8")))
clubs_cfg = set(yaml.safe_load((ROOT / "tool/etl/config/clubs_allowlist.yaml").read_text(encoding="utf-8"))["clubs"])
club_counts = Counter()
for row in rows:
    for club in (row.get("Senior Clubs Played For") or "").split(","):
        club = club.strip()
        if club and club not in clubs_cfg:
            club_counts[club] += 1

hits = sorted(((c, club_counts[c]) for c in FAMOUS if c in club_counts), key=lambda x: (-x[1], x[0]))
out = ROOT / "legendary-players/_famous_missing_clubs.txt"
with out.open("w", encoding="utf-8") as f:
    for club, count in hits:
        f.write(f"{count:2d} | {club}\n")
    f.write(f"TOTAL {len(hits)}\n")
print("written", len(hits), "clubs to", out)
