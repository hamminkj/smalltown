# Small Town: Starting Village Roster v0

Matches the prototype numbers in `design-spec.md`, section 8: 30 villagers, 10 households, 8 children, 16 adults, 6 elders. Names are placeholders; swap them freely. Language T is the town language; language H is the heritage language.

## 1. Locations

| ID | Location | Domain | Notes |
|---|---|---|---|
| 1 to 10 | Homes (one per household) | home | Arranged in a ring in ID order |
| 11 | Packing Plant | work | Largest employer |
| 12 | Clinic and Town Office | work | One building for v0 |
| 13 | School | school | Teacher and aide work here |
| 14 | Market | public | Vendors work here; everyone shops |
| 15 | Park | public | Free-time default |
| 16 | Cafe (buildable) | public | Costs a shared-space nudge |
| 17 | Laundromat (buildable) | public | Costs a shared-space nudge |

**Ring geometry matters.** Homes 1 to 4 are the H households and sit together. Homes 4 and 5, and homes 10 and 1, are the only cross-group neighbor seams. This gives the town a built-in weak-tie structure for the player to discover.

## 2. Villagers

Proficiency columns are starting values for `p[T]` and `p[H]`. Threshold is the number of distinct sources needed to adopt a new variant (3 if shyness is above 0.7).

| ID | Name | Stage | Home | Role | p[T] | p[H] | Open | Shy | Thr |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Oren | Elder | 1 | Retired | 0.10 | 0.95 | 0.3 | 0.6 | 2 |
| 2 | Salma | Adult | 1 | Plant worker | 0.30 | 0.90 | 0.6 | 0.4 | 2 |
| 3 | Dani | Child | 1 | Student | 0.50 | 0.85 | 0.8 | 0.3 | 2 |
| 4 | Reza | Adult | 2 | Plant worker | 0.25 | 0.90 | 0.5 | 0.5 | 2 |
| 5 | Lina | Adult | 2 | Market vendor | 0.40 | 0.90 | 0.8 | 0.2 | 2 |
| 6 | Yusuf | Child | 2 | Student | 0.60 | 0.85 | 0.9 | 0.2 | 2 |
| 7 | Mirela | Elder | 3 | Retired | 0.05 | 0.95 | 0.3 | 0.8 | 3 |
| 8 | Anton | Adult | 3 | Plant worker | 0.20 | 0.90 | 0.4 | 0.75 | 3 |
| 9 | Sofi | Child | 3 | Student | 0.45 | 0.85 | 0.7 | 0.5 | 2 |
| 10 | Kofi | Adult | 4 | Plant worker | 0.30 | 0.90 | 0.6 | 0.3 | 2 |
| 11 | Amina | Adult | 4 | Seeking work | 0.15 | 0.90 | 0.7 | 0.6 | 2 |
| 12 | Jun | Child | 4 | Student | 0.50 | 0.85 | 0.8 | 0.4 | 2 |
| 13 | Walt | Elder | 5 | Retired | 0.95 | 0.10 | 0.3 | 0.5 | 2 |
| 14 | Grace | Adult | 5 | Teacher | 0.90 | 0.10 | 0.8 | 0.3 | 2 |
| 15 | Ben | Child | 5 | Student | 0.80 | 0.10 | 0.7 | 0.4 | 2 |
| 16 | Dolores | Elder | 6 | Retired | 0.95 | 0.10 | 0.4 | 0.8 | 3 |
| 17 | Marcus | Adult | 6 | Clinic aide | 0.90 | 0.10 | 0.7 | 0.3 | 2 |
| 18 | Ava | Child | 6 | Student | 0.80 | 0.10 | 0.6 | 0.5 | 2 |
| 19 | Earl | Elder | 7 | Retired | 0.95 | 0.10 | 0.2 | 0.6 | 2 |
| 20 | Patty | Adult | 7 | Plant supervisor | 0.90 | 0.10 | 0.5 | 0.2 | 2 |
| 21 | Cody | Child | 7 | Student | 0.80 | 0.10 | 0.8 | 0.3 | 2 |
| 22 | Ruth | Elder | 8 | Retired | 0.95 | 0.10 | 0.5 | 0.4 | 2 |
| 23 | Hank | Adult | 8 | Market vendor | 0.90 | 0.10 | 0.6 | 0.2 | 2 |
| 24 | Lily | Child | 8 | Student | 0.80 | 0.10 | 0.8 | 0.3 | 2 |
| 25 | Carla | Adult | 9 | Office clerk | 0.90 | 0.10 | 0.7 | 0.3 | 2 |
| 26 | Joe | Adult | 9 | Plant worker | 0.90 | 0.10 | 0.5 | 0.5 | 2 |
| 27 | Nina | Adult | 9 | Clinic cleaner | 0.90 | 0.10 | 0.8 | 0.4 | 2 |
| 28 | Sam | Adult | 10 | Plant driver | 0.90 | 0.10 | 0.4 | 0.4 | 2 |
| 29 | Tess | Adult | 10 | Market vendor | 0.90 | 0.10 | 0.7 | 0.2 | 2 |
| 30 | Pete | Adult | 10 | School aide | 0.90 | 0.10 | 0.5 | 0.8 | 3 |

**Totals check:** 18 T-dominant (IDs 13 to 30), 12 H-dominant (IDs 1 to 12). Children 8, adults 16, elders 6.

## 3. Jobs and language requirements

| Job | Workplace | Required `p[T]` | Holders |
|---|---|---|---|
| Plant worker | Packing Plant | 0.40 | Salma, Reza, Anton, Kofi, Joe |
| Plant driver | Packing Plant | 0.50 | Sam |
| Plant supervisor | Packing Plant | 0.80 | Patty |
| Clinic aide | Clinic and Office | 0.70 | Marcus |
| Office clerk | Clinic and Office | 0.80 | Carla |
| Clinic cleaner | Clinic and Office | 0.30 | Nina |
| Market vendor | Market | 0.50 | Lina, Hank, Tess |
| Teacher | School | 0.90 | Grace |
| School aide | School | 0.60 | Pete |
| (none) | n/a | n/a | Amina (seeking work) |

Starting job access: Anton (0.20 vs 0.40) and Reza (0.25 vs 0.40) and Salma (0.30 vs 0.40) and Kofi (0.30 vs 0.40) are all below their requirement, and Lina (0.40 vs 0.50) is just under. Real jobs are at risk, which gives the job-access metric immediate stakes.

## 4. Starting ties

- **Family:** all pairs within a household, `w` 0.8 (30 ties).
- **Neighbor:** ring-adjacent homes, `w` 0.2 (10 ties). Seams are 4-5 and 10-1.
- **Work:** all pairs within a workplace, `w` 0.4.
- **School:** all children to each other, and to Grace and Pete, `w` 0.4.
- All `s` start at 0.5.

## 5. Schedule templates

Four slots per day (morning, midday, afternoon, evening); days 1 to 5 are weekdays, days 6 and 7 are the weekend. Probabilistic choices are rolled once per villager per day from the seeded RNG.

| Group | Weekday | Weekend |
|---|---|---|
| Child | Morning, midday: School. Afternoon: School (70%) or Park (30%). Evening: Home | Morning: Home. Midday: Park (60%) or Home. Afternoon: Park (40%) or Home. Evening: Home |
| Employed adult | Morning, midday: Workplace. Afternoon: Workplace (70%) or Market (30%). Evening: Home (80%) or Park (20%) | Morning: Home. Midday: Market (50%) or Home. Afternoon: Park (30%) or Home. Evening: Home |
| Market vendor | Morning, midday, afternoon: Market. Evening: Home | Midday, afternoon: Market (60%) or Home. Otherwise Home |
| Seeking work (Amina) | Morning: Home. Midday: Market (50%) or Home. Afternoon: Park (40%) or Home. Evening: Home | Same as employed adult |
| Elder | Morning: Home. Midday: Park (40%), Market (30%), or Home. Afternoon: Park (30%) or Home. Evening: Home | Same as weekday |

## 6. Starting variants

One concept to start: the word for a fizzy drink.

- **Variants:** "soda" and "pop" (both language T).
- **Default:** everyone prefers "soda."
- **Seed:** three peripheral villagers prefer "pop": **Earl (19)**, **Ava (18)**, **Joe (26)**. They sit in different households and workplaces, so you can see whether complex contagion needs clusters or can cross weak ties.
- **Expected behavior:** with a threshold of 2 to 3 distinct sources, "pop" should mostly fail to spread without help. A nudge (signage, an event) should tip it in some neighborhoods and not others.

A second concept can wait for the next version; add an H-language word for one of the same objects to test cross-language variants.

## 7. Natural brokers to watch

These villagers should end up carrying much of the town, which is a good test of the fragility metric:

- **Lina (5):** market vendor, high openness, partial T. Contact with everyone.
- **Yusuf (6):** child with the best T among H speakers, strong school ties, links to the H household.
- **Marcus (17) and Carla (25):** T speakers in public-facing work, high openness.

If no villager emerges as a broker after a few simulated seasons, the schedules are probably too separated.
