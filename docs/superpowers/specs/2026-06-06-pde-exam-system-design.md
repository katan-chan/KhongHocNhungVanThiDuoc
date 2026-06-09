# PDE Exam Knowledge System — Design

**Date:** 2026-06-06
**Goal:** Systematize PDE (phương trình đạo hàm riêng) study into a clean, fast-lookup exam-carry document, backed by a knowledge graph and an HTML feedback layer. Allowed-materials exam.

---

## Core idea

One **expansion engine** drives everything: given a new *dạng bài* (problem type), the system lists near-neighbor problem types + their approaches (**no solving on first pass**) and defines the theory of every *khái niệm* (concept) involved. Three output modules consume the engine's analysis.

## Entities (backbone)

Three cross-linked entities, separate md files, wikilink edges:

- **Khái niệm** (concept) — `knowledge/concepts/<id>.md`
- **Dạng bài** (problem type) — `knowledge/problem-types/<id>.md`
- **Phương pháp** (method) — `knowledge/methods/<id>.md`

"Neighbor" = problems sharing concept/method edges. Edges from links between these files.

## Two layers (source of truth)

- **md thinking layer** (`knowledge/`) — truth for theory + graph. Drives known/unknown + neighbors. Renders to HTML feedback.
- **LaTeX exam artifact** (`exam/`) — the carry-into-exam document. References concepts by shared id. Concept `.tex` fragments are **derived by the LaTeX agent from the md** (regen by id — theory authored once, in md).

Shared `<id>` glues the two layers.

## Known/unknown rule

**Concept file exists in `knowledge/concepts/` ⇒ known.** Referenced but missing ⇒ unknown → agent creates stub + defines theory.

## Folder layout

```
knowledge/                      # md thinking layer (truth for theory + graph)
  concepts/<id>.md              # khái niệm: theory, [[links]]. EXISTS = known
  problem-types/<id>.md         # dạng bài: neighbors, concept/method links
  methods/<id>.md               # phương pháp: điều kiện áp dụng
exam/                           # LaTeX artifact (carry into exam)
  main.tex                      # master, auto mục lục (\tableofcontents)
  problem-types/<id>/prob.tex   # one subfolder per dạng bài
  shared/concepts/<id>.tex      # DRY \input fragments
  shared/methods/<id>.tex
feedback/<date>-<topic>.html    # compiled math, for human discussion
.claude/
  hooks/capture.*               # keyword hook (UserPromptSubmit)
  agents/                       # analyzer + 3 writers
```

DRY: `exam/shared/concepts/<id>.tex` `\input` by any `prob.tex` needing it.

## Expansion engine (first pass = NO solving)

Input: new dạng bài, typed in chat with marker. Output:

1. **Concept extraction** — list every khái niệm. Each tagged `[đã biết / mới]` by graph presence.
2. **Neighbor dạng bài** — agent recalls canonical PDE-syllabus neighbors from **its own domain knowledge** (e.g. heat-IVP → wave-IVP, Laplace-BVP, separation-of-variables family). Each tagged `[đã có / mới]` vs graph.
3. **Phương pháp per problem** — method name + điều kiện áp dụng. No worked solution.
4. **Theory defs** — define every concept (especially `mới`).

Solving happens only on a later explicit second pass.

## Orchestration

Fleet model: **3+1+1 sweep** for search+KG, plus 2 downstream writers.

```
keyword in chat (#capture <problem>)
   │  UserPromptSubmit hook injects capture instructions
   ▼
EXPLORE (parallel, 3x Opus, diverse lenses)
   ├─ explorer:by-concept       → khái niệm + neighbors sharing them
   ├─ explorer:by-method        → phương pháp + neighbors solved same way
   └─ explorer:by-equation-type → PDE class (bậc/tuyến tính/elliptic|parabolic|hyperbolic/IVP|BVP) + same-class neighbors
   ▼
SYNTHESIZE (1x Opus)            → merge + dedup → one structured analysis
   │  fan-out (parallel)
   ├─ KG-writer (Sonnet)   → write/update knowledge/*.md, wire [[links]], stub unknowns
   ├─ LaTeX-writer (Sonnet)→ exam/problem-types/<id>/, \input shared fragments, update main.tex
   └─ HTML-writer (Sonnet) → feedback/<date>.html (math compiled) for review
```

Total per capture: 3 explorers + 1 synthesizer + 3 writers = 7 agents.
Explorers + synthesizer = knowledge search; writers = artifact generation.

### Model assignment
- Explorers, Synthesizer: **Opus** (domain recall + dedup judgment).
- All 3 writers: **Sonnet** (mechanical file ops).

### Agent interaction contract (file-based, decoupled)

Agents never talk peer-to-peer. They interact through a per-capture scratch workspace.
Each agent reads named input files, writes named output files, returns only a short status.

```
.capture/<slug>/
  input.md                      # raw problem (hook writes this)
  explore/
    by-concept.json             # explorer:by-concept output
    by-method.json              # explorer:by-method output
    by-equation-type.json       # explorer:by-equation-type output
  analysis.json                 # synthesizer output = canonical handoff to writers
```

Pipeline + handoff:

1. Hook writes `.capture/<slug>/input.md`, injects "run capture for <slug>".
2. Orchestrator dispatches 3 explorers in ONE message (parallel). Each reads
   `input.md` + scans `knowledge/`, writes `explore/<lens>.json`, returns `done`.
3. Orchestrator dispatches synthesizer: reads the 3 `explore/*.json`, writes
   `analysis.json`, returns `done`.
4. Orchestrator dispatches 3 writers in parallel, each reads `analysis.json`:
   - KG-writer   → `knowledge/*.md`
   - LaTeX-writer→ `exam/**`
   - HTML-writer → `feedback/*.html`

Race safety: explorers write disjoint files; writers touch disjoint trees
(`knowledge/`, `exam/`, `feedback/`). No write conflicts → safe parallel.
Resumability: rerun reads existing scratch files; only missing/stale stages rerun.

Inter-agent payload = JSON. Human-facing result = HTML + LaTeX.

### Explorer lenses (overlap allowed = signal)
- `by-concept`: extract every khái niệm; neighbor = problem sharing concepts.
- `by-method`: identify applicable phương pháp; neighbor = problem solved by same method.
- `by-equation-type`: classify the PDE; neighbor = same equation class.

Each explorer blind to the others → catches neighbors a single angle misses. Synthesizer reconciles.

Note: UserPromptSubmit hook injects *context*, not spawns agents. Hook detects marker → injects "run capture workflow"; main agent dispatches subagents via Task.

## Toolchains (Windows)

- **HTML feedback**: md → HTML via pandoc + KaTeX (or MathJax CDN). Self-contained, browser-openable.
- **Exam PDF**: LaTeX via tectonic (single binary) or latexmk + MiKTeX.

## Open items (defaults pending confirmation)

- Concept dual-form: md theory → LaTeX agent derives `.tex`. **Default: yes.**
- Marker keyword: `#capture` vs `#batbai`. **Default: `#capture`.**
- PDF tool: tectonic vs MiKTeX. **Default: assume tectonic until verified.**

## Status

Architecture approved 2026-06-06. Next: write per-agent prompts (analyzer + 3 writers) for the knowledge-exploration workflow.
