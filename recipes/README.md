# Recipes

A tiny static recipe site. No build step, no dependencies — open `index.html` in a browser and it works, or serve the folder as-is.

```
recipes/
  index.html      hub page — lists every recipe
  styles.css      shared styles (light + dark, print-friendly)
  kimchi.html     napa cabbage kimchi, scaled from the cabbage weight
  pickles.html    lacto-fermented pickle spears, scaled from the jar count
  hot-sauce.html  garlicky red chile hot sauce, scaled from the target volume
```

## Published at

**https://blog.axkirillov.com/recipes/**

Caddy serves this folder read-only into the container at `/srv/recipes` (see `caddy/docker-compose.yml`), under `handle_path /recipes/*` in `caddy/Caddyfile`. Nothing is copied to the server: publishing is `git pull` plus `docker compose -f caddy/docker-compose.yml up -d` on the VPS, which `deploy.sh` already does. Editing a file here and re-running the deploy is the whole workflow.

For a dedicated `recipes.axkirillov.com`, see the note at the bottom of `caddy/Caddyfile` — it needs an AAAA record first.

## Preview locally

```sh
cd recipes && python3 -m http.server 8000   # then open http://localhost:8000
```

## Adding a recipe

1. Copy `kimchi.html` to `<recipe-name>.html` and rewrite the content.
2. Keep the `.card`, `.layout`, `ol.steps`, `.extras` and `.table` classes so it matches the rest.
3. Add a card for it in `index.html` (the `.recipe-grid` block).
4. Only add CSS to `styles.css` if the new page genuinely needs something new.

## Making amounts adjustable

`kimchi.html` has the pattern worth reusing: a ratio table in the `<script>` block holding every amount **per 1 kg of the base ingredient**, a `scale()` function that turns those ratios into formatted strings, and `<span data-q="key">` placeholders in the prose that get filled in on every change. To adapt it:

- change the ratio table and the label of the input;
- change the ingredient list in `GROUPS` (each item carries its `data-q` key);
- keep safety-critical ratios (salt, curing salt, acid) fixed and say so in the prose — those are the numbers that must not drift.

`pickles.html` follows the same pattern with a different input (number of 1 L jars) and adds a second dimension: a **brine switch** holding two complete ratio sets (`BRINES`), so the same page covers both the strong 25 g / 475 mL brine and the milder 18 g / 532 mL one. Copy that shape when a recipe has a genuine either/or choice rather than a single multiplier.

`hot-sauce.html` scales from a target volume and adds a **derived safety number**: the recipe's 36 mL of 25% essence + 144 mL water is not stored as prose but computed by `acidSplit()`, which takes the pure acetic acid the recipe needs (9 mL) and divides it by whatever strength the label says. Enter 80% and the page gives 22.5 mL in 337.5 mL of water — the same 5% vinegar, no arithmetic by hand. Use that shape whenever a recipe's stated amount depends on a property of an ingredient you have to read off a label.

Batch size is remembered in `localStorage`, and a page can be linked with a preset:

| page | link |
|---|---|
| kimchi | `?kg=3` |
| pickles | `?jars=4` or `?jars=4&brine=mild` |
| hot sauce | `?ml=960&acid=80` |

## Checking a page still renders

`render()` assigns into fixed ids and into every `[data-q]` placeholder. If one of those lookups is missing, the assignment throws and **everything after it stays empty** — the page still looks broadly fine, which is how a half-populated recipe ships by accident. After editing, render the page in headless Chrome and assert the slots are actually filled:

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --virtual-time-budget=3000 \
  --dump-dom "file://$PWD/hot-sauce.html?ml=960&acid=80" | grep -c 'id="acidTable"><tbody>'
```

Check the arithmetic the same way: extract the `<script>` and run `scale()` in node against the recipe's own numbers, so the base batch reproduces the source exactly (480 mL → 3 g salt, 36 mL + 144 mL = 180 mL).
