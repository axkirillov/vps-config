# Recipes

A tiny static recipe site. No build step, no dependencies — open `index.html` in a browser and it works, or serve the folder as-is.

```
recipes/
  index.html      hub page — lists every recipe
  styles.css      shared styles (light + dark, print-friendly)
  kimchi.html     napa cabbage kimchi, scaled from the cabbage weight and the brining pot
  pickles.html    lacto-fermented pickle spears, scaled from the jar count
  hot-sauce.html  garlicky red chile hot sauce, scaled from the target volume
  oatmeal-cookies.html  oatmeal cookies, scaled from the cookie count
```

## Published at

**https://blog.axkirillov.com/recipes/**

Caddy serves this folder read-only into the container at `/srv/recipes` (see `caddy/docker-compose.yml`), under `handle_path /recipes/*` in `caddy/Caddyfile`. Nothing is copied to the server: publishing is `git pull` plus `docker compose -f caddy/docker-compose.yml up -d` on the VPS, which `deploy.sh` already does. Editing a file here and re-running the deploy is the whole workflow.

For a dedicated `recipes.axkirillov.com`, see the note at the bottom of `caddy/Caddyfile` — it needs an AAAA record first.

## Preview locally

```sh
cd recipes && python3 -m http.server 8000   # then open http://localhost:8000
```

## Design

The look is borrowed from NYT Cooking. The parts worth knowing before you edit a page:

**Type.** NYT ships Cheltenham (display), Imperial (editorial prose), Karnak (caps labels) and Franklin (UI) as licensed webfonts. This site stays dependency-free by falling back the way NYT's own stylesheets do — Cheltenham, Imperial and Karnak all land on Georgia, Franklin lands on Arial — so the four roles survive as `--display`, `--body`, `--label` and `--ui`. The contrast between a light serif and a plain sans is the whole trick; do not collapse it.

**Colour.** A warm off-white page (`#f8f8f5`) with white surfaces, near-black text (`#222`), one accent red (`#df321b`, NYT's primary action) reserved for the kicker, links on hover and the primary button, and one warm yellow (`#f8e19a`, NYT's selected-tab value) used only for selected state and live values. Dark mode reuses NYT's dark tokens (`#121212` page, `#1c1c1e` surface, `#aeaeb2` subdued).

**Structure.** There are no cards. A recipe opens with the kicker, a serif title at `clamp(2.125rem,5vw,2.875rem)`, a serif dek, a `Yield` / `Total Time` row, then a **3px black rule** above the two-column body — that rule is the site's loudest single element, so nothing else needs to shout. Sections are labelled in bold uppercase Georgia (`INGREDIENTS`, `INSTRUCTIONS`), with the smaller caps treatment for ingredient groups and extras headings.

**Things the CSS does for you.** `.card` is neutralised into an unstyled block (only `.controls` draws a border); ingredient amounts render **first** on the line via `order:-1` on `.qty`, the way NYT writes an ingredient, so nothing in the markup has to be reordered; `small` sub-notes and the `optional` badge become italic parentheticals through `::before`/`::after`; steps are numbered by a CSS counter printing `Step N`, so a step is just an `<li>` with an `<h3>` and paragraphs; and every `<span class="q">` live value gets a yellow highlighter that is stripped for print.

**Print** is a first-class target: controls, buttons and the backlink are hidden, the body stays two columns, and sizes follow NYT's print scale (title 25pt, dek 11pt, step prose 10pt, ingredient lines 10.5pt, section labels 9pt). Check it by printing to PDF rather than by resizing the window.

## Adding a recipe

1. Copy `kimchi.html` to `<recipe-name>.html` and rewrite the content.
2. Keep the structure: a `.hero` with `.backlink`, `.kicker`, `h1`, `p.dek` and a `<dl class="meta">` carrying **Total Time** and **Yield** (point the yield `dd` at a live `data-q` slot so it follows the batch), then `.controls`, then `.layout` with `.ingredients` and `ol.steps`, then `.extras` and `.table`.
3. Add a card for it in `index.html` (the `.recipe-grid` block).
4. Only add CSS to `styles.css` if the new page genuinely needs something new — and if it does, keep it inside the existing token vocabulary rather than introducing a second accent or a bordered box.

## Making amounts adjustable

`kimchi.html` has the pattern worth reusing: a ratio table in the `<script>` block holding every amount **per 1 kg of the base ingredient**, a `scale()` function that turns those ratios into formatted strings, and `<span data-q="key">` placeholders in the prose that get filled in on every change. To adapt it:

- change the ratio table and the label of the input;
- change the ingredient list in `GROUPS` (each item carries its `data-q` key);
- keep safety-critical ratios (salt, curing salt, acid) fixed and say so in the prose — those are the numbers that must not drift.

`pickles.html` follows the same pattern with a different input (number of 1 L jars) and adds a second dimension: a **brine switch** holding two complete ratio sets (`BRINES`), so the same page covers both the strong 25 g / 475 mL brine and the milder 18 g / 532 mL one. Copy that shape when a recipe has a genuine either/or choice rather than a single multiplier.

`kimchi.html` carries a second input that is **not** a multiplier: the diameter of the brining pot (`?kg=2&pot=28`). Its brine is modelled rather than scaled — `kg × 1.45 L` fills the gaps between the cabbage quarters, plus `πr² × 2 cm` of cover, which is derived from the pot's mouth and not from the batch. That is why 1 kg in a 28 cm pot takes more than half of what 2 kg takes: the cover term does not shrink with the batch. Anything derived from a vessel's geometry belongs in a term like this, not in the per-kg ratio table, and the page should say out loud that the pot changes the amount (`potHint`, `brineNote`). The salt is computed from the rounded brine volume, never from the cabbage, so the 65 g/L floor holds at every pot size.

`hot-sauce.html` scales from a target volume and adds a **derived safety number**: the recipe's 36 mL of 25% essence + 144 mL water is not stored as prose but computed by `acidSplit()`, which takes the pure acetic acid the recipe needs (9 mL) and divides it by whatever strength the label says. Enter 80% and the page gives 22.5 mL in 337.5 mL of water — the same 5% vinegar, no arithmetic by hand. Use that shape whenever a recipe's stated amount depends on a property of an ingredient you have to read off a label.

`oatmeal-cookies.html` scales from the cookie count, which is the one dimension that is **not continuous**: 18 cookies needs 50 g of whole egg plus 17 g of yolk, and 12 cookies needs two thirds of an egg. Rather than pretend otherwise, the page weighs the egg like everything else and spells out what that means for the batch in hand — the ingredient line carries the fraction ("33 g (≈ ⅔ of a large egg)") and a note under step 3 says which eggs to beat. Spices stay genuinely useful at any size because each one also carries a spoon hint, derived from its density, so a small batch does not need a 0.1 g scale.

The page also keeps the source recipe honest about its own yield: 18 cookies from 1½ tablespoon scoops does not agree with a dough that weighs 775 g, so the "scoop size" card states both readings and lets the batch size decide the count. When a source's yield and its scoop size disagree, say so on the page instead of quietly picking one.

Batch size is remembered in `localStorage`, and a page can be linked with a preset:

| page | link |
|---|---|
| kimchi | `?kg=3` or `?kg=2&pot=28` |
| pickles | `?jars=4` or `?jars=4&brine=mild` |
| hot sauce | `?ml=960&acid=80` |
| oatmeal cookies | `?cookies=24` |

## Checking a page still renders

`render()` assigns into fixed ids and into every `[data-q]` placeholder. If one of those lookups is missing, the assignment throws and **everything after it stays empty** — the page still looks broadly fine, which is how a half-populated recipe ships by accident. After editing, render the page in headless Chrome and assert the slots are actually filled:

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --virtual-time-budget=3000 \
  --dump-dom "file://$PWD/hot-sauce.html?ml=960&acid=80" | grep -c 'id="acidTable"><tbody>'
```

Check the arithmetic the same way: extract the `<script>` and run `scale()` in node against the recipe's own numbers, so the base batch reproduces the source exactly (480 mL → 3 g salt, 36 mL + 144 mL = 180 mL).
