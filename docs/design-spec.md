# Small Town: Design Spec v0.1

A community-connector sim about how language spreads through a social network. The player nudges; they never command. Built in Godot later; this spec is engine-agnostic.

## 1. Core idea

- Villagers move through daily schedules, talk to whoever shares their location, and pick up or lose language through those conversations.
- The player spends a limited budget of nudges each season (shared spaces, introductions, events, helpers, signage).
- At the start, the player picks a **town charter**: weights over outcomes (jobs, trust, kids, elders, economy, heritage language). The sim underneath never changes; only the scoring does.
- Chosen outcomes show on the dashboard. The rest are tracked silently and revealed in the end-of-run report.

## 2. Complex-systems features (and where each lives)

| Feature | Where it lives |
|---|---|
| Complex contagion | Variant adoption requires N distinct sources (section 6, step 4) |
| Weak ties and brokers | Cross-group ties, broker burnout, fragility metric |
| Homophily | Partner selection weighting (section 6, step 2) |
| Competing variants | Concept objects with multiple variants |
| Adaptive network | Periodic tie rewiring (section 6, step 6) |
| Decay and forgetting | Unused proficiency decays (section 6, step 5) |
| Tipping points, hysteresis | Emerges from thresholds plus decay; surface in replay |
| Delayed feedback | Nudge effects ramp up over weeks; dashboard shows noisy weekly averages |

## 3. Shared primitives

- `p[i][L]`: villager i's proficiency in language L, range 0 to 1
- `m[i][j] = max over L of min(p[i][L], p[j][L])`: mutual intelligibility
- `w[i][j]`: tie strength, 0 to 1
- `s[i][j]`: recent conversation success rate (exponential moving average)

Every outcome metric is derived from these three things plus domain use. Do not add metrics that need new state.

## 4. Outcome metrics (0 to 1)

- **Job access:** share of working-age villagers whose proficiency in the workplace language meets their job's required level.
- **Neighbor trust:** mean of `w * s` over all ties; cross-group ties count 1.5x.
- **Kids' school success:** mean over children of `0.7 * p[kid][school lang] + 0.3 * max(p[parent][school lang])`.
- **Elder connection:** mean over elders of the average `m` across their family ties.
- **Economic vitality:** successful transactions per week divided by capacity. A transaction succeeds with probability `m` between buyer and seller.
- **Heritage vitality:** mean over households of `min(p[parent][H], p[kid][H]) * home use of H`. A language counts as alive only if it passes between generations.

**Hidden metrics (end report):**
- **Segregation:** assortativity of ties by home language. Lower is better.
- **Fragility:** drop in network connectivity if the top two brokers are removed.
- **Broker burnout:** share of helpers above their burnout threshold.

**Design rules for the charter:**
- Some metrics must conflict (fast convergence lowers elder connection and heritage vitality), or the charter choice is cosmetic.
- Some must reinforce each other (trust lifts nearly everything), so players discover synergies.

## 5. Data model

**Villager**
- Identity: id, age, life stage (child, adult, elder), household id, job id
- Language state: `p` per language; domain use (`home`, `work`, `public`, `school`) per language; variant preference per concept
- Personality: openness (0 to 1), shyness (0 to 1), adoption threshold (2 or 3 distinct sources)
- Memory: recent exposures as (concept, variant, source id, tick)
- Schedule: one location per time slot
- Broker state: burnout meter

**Tie:** a, b, type (family, work, neighbor, school), `w`, `s`, last contact tick

**Location:** id, type, domain, capacity, nudge modifiers

**Concept:** id, list of variants, each tagged with its language

**Nudge:** type, cost, duration, effect parameters

In Godot, Villager, Tie, Location, and Concept map well to custom `Resource` classes so scenarios save as data files.

## 6. Per-tick loop

1. **Move.** Each villager goes to the location in their schedule for this slot.
2. **Pair.** Co-located villagers pick conversation partners. Weight = `(0.3 + w) * (1 + h * m)`, where `h` is the homophily strength.
3. **Talk.** Pick the language that maximizes `min(p[i][L], p[j][L])`, with ties broken by the location's domain norm. Success happens with probability `m`. Update `s`, `w`, and exposures; raise `p` in the language used.
4. **Adopt.** A variant is adopted when the number of distinct sources in the exposure window reaches the villager's threshold.
5. **Decay.** Proficiency in languages unused for a stretch fades slowly.
6. **Rewire.** Periodically, villagers drop ties with low `s` and form ties with people they converse with easily.

## 7. Nudge toolkit

| Nudge | Effect | Duration |
|---|---|---|
| Shared space | New high-capacity location with random mixing, attracts adults in free slots | Permanent |
| Introduction | Creates a tie between two villagers and forces one co-located tick | Instant |
| Event | Boosts conversations at a location, mixes groups | 1 week |
| Bilingual helper | Adds a broker with high proficiency in both languages and a burnout meter | Permanent, burnout-limited |
| Signage | Adds one "sign" source to exposures for a variant in the public domain | Permanent |

## 8. Starter numbers (prototype v0)

All values are **tunable guesses** to be calibrated by playtesting. Do not treat them as realistic.

**Scale and time**
- 30 villagers, 10 households (3 each)
- Life stages: 8 children, 16 adults, 6 elders
- Two languages: **T** (town language) and **H** (heritage language)
- Start: 18 villagers are T-dominant (p[T] about 0.9, p[H] about 0.1); 12 are H-dominant (p[H] about 0.9, p[T] about 0.2 for adults and elders, about 0.5 for children)
- 4 time slots per day (morning, midday, afternoon, evening); 1 tick = 1 slot
- 28 ticks per week; 1 season = 12 weeks = 336 ticks
- Run length: 4 seasons

**Locations (v0):** 10 homes, 2 workplaces, 1 school, 1 park, 1 market. Buildable: cafe, laundromat.

**Talking and learning**
- Conversations per villager per tick: 1 (2 at events)
- Homophily strength `h`: 1.0
- Proficiency gain per successful conversation: `0.02 * (1 - p) * age_mult * (0.5 + 0.5 * openness)`
  - `age_mult`: child 1.5, adult 1.0, elder 0.6
- Decay: if a language is unused for 14 ticks, lose `0.0005` per tick; never decay below 0.15 for anyone who once exceeded 0.6 (heritage languages fade slowly, but they do fade)

**Contagion**
- Adoption threshold: 2 distinct sources (3 if shyness above 0.7)
- Exposure window: 56 ticks (2 weeks)
- Each concept starts with 2 variants; the newer variant starts with 3 of 30 villagers

**Ties**
- Initial `w`: family 0.8, work 0.4, school 0.4, neighbor 0.2
- On success: `w += 0.02`, `s` moves 0.1 toward 1. On failure: `s` moves 0.1 toward 0
- Idle decay: `w -= 0.001` per tick without contact (floor 0.05, except family)
- Rewiring check: every 28 ticks, each villager has a 10% chance to drop their weakest tie with `s < 0.3` and form one with a villager met recently with `s > 0.6`

**Brokers**
- Burnout rises 0.05 per cross-group conversation where the helper is carrying the exchange
- Recovers 0.03 per tick spent at home
- Above 1.0: the helper withdraws for 1 week

**Nudge budget and costs (4 points per season)**
- Shared space: 3
- Event: 2
- Bilingual helper: 2
- Introduction: 1
- Signage: 1

**Sanity checks for the first playtests**
- With no nudges, language clusters should still be visible after 12 weeks. If the town fully converges, lower the gain rate or raise `h`.
- Adult H-dominant villagers should reach roughly 0.4 to 0.6 in T after one season with a good nudge strategy. If they reach 0.9, learning is too fast.
- Two different charters should produce visibly different winning nudge patterns. If one strategy wins every charter, the metrics are not conflicting enough.
- Variant adoption should show an S-curve, not a straight line. If it is linear, the threshold is too low.

## 9. Open questions

- Add a third language later, and with it a "lingua franca" dynamic?
- Should villagers have visible thought bubbles, or only the replay view reveal why things happened?
- How noisy should the weekly dashboard be, so players feel delayed feedback without feeling cheated?
