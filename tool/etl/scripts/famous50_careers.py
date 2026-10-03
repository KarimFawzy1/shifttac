#!/usr/bin/env python3
"""Famous-50 career supplements — allowlisted clubs only.

TM IDs verified against tiki_taka.db (2026-06-15). Several user-supplied IDs
differ from the DB; this module uses the IDs present in the shipped database.
"""
from __future__ import annotations

# TM player_id -> allowlisted club_ids (from senior career × clubs_allowlist.yaml)
FAMOUS_50_CAREERS: dict[str, list[str]] = {
    "8198": ["336", "985", "418", "506"],          # Ronaldo
    "3455": ["610", "506", "46", "131", "5", "583", "985"],  # Zlatan
    "3139": ["985", "418", "5", "583"],            # Beckham
    "3332": ["29", "985"],                         # Rooney
    "3163": ["631", "281"],                        # Lampard
    "4257": ["418", "131", "46", "631", "29"],     # Eto'o
    "3366": ["5", "418"],                          # Kaká
    "5817": ["46", "5", "506"],                    # Pirlo
    "26399": ["13", "281", "131"],                 # Agüero
    "8806": ["11", "131", "631", "162"],           # Fàbregas
    "35518": ["1049", "281"],                      # David Silva
    "7980": ["1049", "131", "13"],                 # David Villa
    "18922": ["1041", "418"],                      # Benzema
    "27992": ["148", "418", "5"],                  # Modrić
    "39381": ["148", "418"],                       # Bale
    "4380": ["11", "985"],                         # van Persie
    "7476": ["31", "418", "27"],                   # Xabi Alonso
    "7767": ["13", "31", "631", "5"],              # Torres
    "3924": ["244", "631", "141"],                 # Drogba
    "3182": ["11", "873", "631", "12"],            # Ashley Cole
    "5658": ["631", "11"],                         # Čech
    "3160": ["631", "405"],                        # Terry
    "4276": ["189", "379", "985", "281", "506"],   # Tevez
    "4360": ["383", "631", "418", "27"],           # Robben
    "4673": ["610", "418", "46", "141", "417"],    # Sneijder
    "15951": ["368", "131", "506", "583"],         # Dani Alves
    "18944": ["985", "131"],                       # Piqué
    "3979": ["418", "720"],                        # Casillas
    "25557": ["368", "418", "583"],                # Ramos
    "44501": ["418"],                              # Marcelo
    "5023": ["506", "583"],                        # Buffon
    "68290": ["221", "131", "583"],                # Neymar
    "44352": ["610", "31", "131", "13"],           # Suárez
    "40433": ["131", "11", "985", "46", "244"],    # Alexis Sánchez
    "39152": ["720", "13", "162", "985", "631", "141"],  # Falcao
    "44779": ["13", "631", "543"],                 # Diego Costa
    "88103": ["720", "162", "418", "27", "29"],     # James
    "122153": ["985", "506"],                      # Pogba
    "2514": ["27", "985"],                         # Schweinsteiger
    "31909": ["27", "15", "418"],                  # Kroos
    "2219": ["27", "79"],                          # Lahm
    "17259": ["27"],                               # Neuer
    "38253": ["16", "27", "131"],                  # Lewandowski
    "50202": ["631", "418"],                       # Hazard
    "88755": ["631", "281"],                       # De Bruyne
    "96341": ["631", "29", "985", "46", "12", "6195"],  # Lukaku
    "128223": ["418", "506", "631", "13", "5"],    # Morata
    "134425": ["31", "281", "631", "11"],          # Sterling
    "148455": ["631", "430", "12", "31"],          # Salah
    "7607": ["131"],                               # Xavi
}

# club_id -> top-5 domestic league (for league_club supplements)
CLUB_TOP5_LEAGUE: dict[str, str] = {
    "418": "ES1", "131": "ES1", "13": "ES1", "1049": "ES1", "368": "ES1",
    "985": "GB1", "31": "GB1", "11": "GB1", "281": "GB1", "631": "GB1",
    "148": "GB1", "29": "GB1", "379": "GB1", "873": "GB1", "543": "GB1", "405": "GB1",
    "27": "L1", "16": "L1", "15": "L1", "79": "L1",
    "506": "IT1", "5": "IT1", "46": "IT1", "12": "IT1", "6195": "IT1", "430": "IT1",
    "583": "FR1", "162": "FR1", "244": "FR1", "1041": "FR1", "417": "FR1",
}

# Human-readable names for qa_club_edges.yaml reasons
CLUB_NAMES: dict[str, str] = {
    "336": "Sporting CP", "985": "Manchester United", "418": "Real Madrid",
    "506": "Juventus", "610": "Ajax", "46": "Inter Milan", "131": "Barcelona",
    "5": "AC Milan", "583": "Paris Saint-Germain", "29": "Everton", "631": "Chelsea",
    "281": "Manchester City", "13": "Atlético Madrid", "11": "Arsenal",
    "162": "Monaco", "1049": "Valencia", "1041": "Lyon", "148": "Tottenham Hotspur",
    "31": "Liverpool", "244": "Marseille", "141": "Galatasaray", "873": "Crystal Palace",
    "12": "AS Roma", "189": "Boca Juniors", "379": "West Ham United",
    "383": "PSV Eindhoven", "417": "Nice", "368": "Sevilla", "720": "FC Porto",
    "221": "Santos", "543": "Wolverhampton Wanderers", "15": "Bayer Leverkusen",
    "79": "VfB Stuttgart", "6195": "Napoli", "430": "Fiorentina",
    "405": "Aston Villa",
}

PLAYER_NAMES: dict[str, str] = {
    "8198": "Cristiano Ronaldo", "3455": "Zlatan Ibrahimović", "3139": "David Beckham",
    "3332": "Wayne Rooney", "3163": "Frank Lampard", "4257": "Samuel Eto'o",
    "3366": "Kaká", "5817": "Andrea Pirlo", "26399": "Sergio Agüero",
    "8806": "Cesc Fàbregas", "35518": "David Silva", "7980": "David Villa",
    "18922": "Karim Benzema", "27992": "Luka Modrić", "39381": "Gareth Bale",
    "4380": "Robin van Persie", "7476": "Xabi Alonso", "7767": "Fernando Torres",
    "3924": "Didier Drogba", "3182": "Ashley Cole", "5658": "Petr Cech",
    "3160": "John Terry", "4276": "Carlos Tevez", "4360": "Arjen Robben",
    "4673": "Wesley Sneijder", "15951": "Dani Alves", "18944": "Gerard Piqué",
    "3979": "Iker Casillas", "25557": "Sergio Ramos", "44501": "Marcelo",
    "5023": "Gianluigi Buffon", "68290": "Neymar", "44352": "Luis Suárez",
    "40433": "Alexis Sánchez", "39152": "Radamel Falcao", "44779": "Diego Costa",
    "88103": "James Rodríguez", "122153": "Paul Pogba", "2514": "Bastian Schweinsteiger",
    "31909": "Toni Kroos", "2219": "Philipp Lahm", "17259": "Manuel Neuer",
    "38253": "Robert Lewandowski", "50202": "Eden Hazard", "88755": "Kevin De Bruyne",
    "96341": "Romelu Lukaku", "128223": "Álvaro Morata", "134425": "Raheem Sterling",
    "148455": "Mohamed Salah", "7607": "Xavi",
}

# User list IDs that differ from DB (for documentation)
USER_ID_CORRECTIONS: dict[str, str] = {
    "22138": "3455",   # Zlatan
    "3751": "3163",    # Lampard
    "3359": "3366",    # Kaká
    "5813": "5817",    # Pirlo
    "10782": "35518",  # David Silva
    "7943": "7980",    # David Villa
    "173095": "39381", # Bale
    "4247": "4380",    # van Persie
    "7536": "7476",    # Alonso
    "7106": "7767",    # Torres
    "4144": "3924",    # Drogba
    "3180": "3182",    # Ashley Cole
    "1185": "5658",    # Čech
    "4272": "4276",    # Tevez
    "3368": "44501",   # Marcelo
    "27684": "40433",  # Alexis
    "93938": "44779",  # Diego Costa
    "89482": "122153", # Pogba
    "88": "2514",      # Schweinsteiger
    "58857": "31909",  # Kroos
    "570": "2219",     # Lahm
    "38272": "38253",  # Lewandowski
    "65706": "96341",  # Lukaku
}
