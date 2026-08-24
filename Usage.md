# Using LibreLane

LibreLane is an open-source **RTL-to-GDSII** flow: give it Verilog, get back a
manufacturable chip layout. Successor to OpenLane 2, maintained by the FOSSi
Foundation. Under the hood it orchestrates Yosys (synthesis), OpenROAD
(floorplan/place/CTS/route), Magic and KLayout (DRC/LVS/streamout), and OpenSTA
(timing).

## 0. The one rule that matters

**LibreLane only exists inside the Nix shell.** There's no `librelane` on your
normal PATH, and it never appears in `pip list`. Every session starts with:

```bash
cd ~/librelane && nix-shell
```

Your prompt changes to `[nix-shell:~/librelane]$`. If a command "isn't found",
this is almost always why.

To run a single command without staying in the shell:

```bash
nix-shell ~/librelane/shell.nix --run 'librelane --version'
```

## 1. Quick reference

| Goal | Command |
|---|---|
| Enter the environment | `cd ~/librelane && nix-shell` |
| Check it works | `librelane --version` |
| Full self-test | `librelane --smoke-test` |
| Run a design | `librelane path/to/config.json` |
| Copy & run a bundled example | `librelane --run-example spm` |
| View the layout (KLayout) | `librelane --last-run --flow OpenInKLayout path/to/config.json` |
| View the layout (OpenROAD) | `librelane --last-run --flow OpenInOpenROAD path/to/config.json` |
| Re-run, replacing last output | `librelane --last-run --overwrite path/to/config.json` |
| Run only part of the flow | `librelane --from Yosys.Synthesis --to OpenROAD.Floorplan path/to/config.json` |
| Override one variable | `librelane -c CLOCK_PERIOD=30 path/to/config.json` |
| Use more CPU threads | `librelane -j 12 path/to/config.json` |

## 2. Project structure

A LibreLane project is just **a directory with Verilog files and a `config.json`**
— no scaffolding tool, no template.

```bash
mkdir -p ~/my_designs/[design_name]
cd ~/my_designs/[design_name]
```

Minimum viable `config.json` — four required variables:

```json
{
  "DESIGN_NAME": "[design_name]",
  "VERILOG_FILES": ["dir::src/*.v"],
  "CLOCK_PERIOD": 25,
  "CLOCK_PORT": "clk"
}
```

- `DESIGN_NAME` — must match your top-level Verilog module name exactly
- `VERILOG_FILES` — your sources
- `CLOCK_PERIOD` — target period in **nanoseconds**
- `CLOCK_PORT` — clock input port name

The `dir::` prefix means "relative to the directory containing this config
file" — always use it, since bare relative paths resolve against your *current
working directory* and break the moment you run from elsewhere. Other prefixes:
`pdk::` (PDK root), `refg::` (glob).

YAML works too (`config.yaml`) if you prefer comments.

### Run it

```bash
librelane ~/my_designs/[design_name]/config.json
```

Warnings during the run are normal. What matters: `error.log` is empty and the
exit code is 0.

## 3. Reading the output

Every run creates a timestamped directory:

```
~/my_designs/[design_name]/runs/RUN_<timestamp>/
├── 01-verilator-lint/
├── ...
├── 06-yosys-synthesis/
├── 13-openroad-floorplan/
├── 35-openroad-cts/
├── 44-openroad-detailedrouting/
├── 64-magic-drc/
├── 70-netgen-lvs/
├── final/          ← the deliverables, including metrics
├── error.log       ← check this first — empty on success
├── warning.log
├── flow.log        ← full transcript
├── resolved.json   ← every config variable, fully resolved
└── tmp/
```

**Step numbers shift** between flow/version changes — glob for the name (e.g.
`*-magic-drc`) rather than hardcoding a number.

Each step directory holds `*.log`, `COMMANDS` (exact tool invocation — useful for
debugging), `config.json` (variables visible to that step), `state_in/out.json`,
`or_metrics_out.json`, and output artifacts (`.def`, `.odb`, `.nl.v`, `.sdc`).

### The `final/` directory

What you'd hand to a foundry or integrate into a larger chip:

```
gds/  klayout_gds/  mag_gds/   ← the layout
def/  lef/  odb/               ← placement + abstract views
nl/   pnl/  vh/                ← netlists
spef/                          ← extracted parasitics, per corner
lib/  sdf/  sdc/               ← timing models, delays, constraints
spice/  mag/  json_h/          ← SPICE, Magic, JSON header views
render/                        ← PNG render of the layout
metrics.csv  metrics.json      ← all metrics for the run
```

Your GDS: `final/gds/<design>.gds`.

### Metrics

`final/metrics.json` / `.csv` hold ~300 metrics — area, cell count, wirelength,
worst slack per corner, DRC/LVS/antenna counts. Pull specific numbers:

```bash
python3 -c "
import json; m=json.load(open('runs/RUN_.../final/metrics.json'))
for k in ['design__die__area','timing__setup__ws','magic__drc_error__count']:
    print(k, m[k])
"
```

## 4. Looking at your chip

```bash
librelane --last-run --flow OpenInKLayout ~/my_designs/[design_name]/config.json
```

`--last-run` reuses the most recent run directory. For timing/congestion
analysis, the OpenROAD GUI is better:

```bash
librelane --last-run --flow OpenInOpenROAD ~/my_designs/[design_name]/config.json
```

### Inspecting DRC violations visually

1. Open the layout in KLayout (command above)
2. Menu: **Tools ► Marker Browser**
3. **File ► Open**, load `*-klayout-drc/reports/drc.klayout.lyrdb`

| Step | Report | Format |
|---|---|---|
| `*-magic-drc/reports/` | `drc.magic.rpt` | plain text |
| `*-klayout-drc/reports/` | `drc.klayout.lyrdb` | KLayout marker DB |
| `*-klayout-drc/reports/` | `drc.klayout.json` | machine-readable |

## 5. Signoff checks

| Check | What it means | Fails when |
|---|---|---|
| **DRC** | Design Rule Checking — manufacturable? | Shapes violate foundry spacing/width rules |
| **LVS** | Layout vs. Schematic — layout matches netlist? | Layout and netlist disagree |
| **STA** | Static Timing Analysis — fast enough? | Setup/hold slack negative |
| **Antenna** | Fab-time charge damage risk | Long metal runs on unprotected gates |

If STA reports negative slack, the usual first move is to **increase
`CLOCK_PERIOD`**.

## 6. Iterating efficiently

**Step IDs are `Namespace.StepName`, case-sensitive** — not the lowercase names
in the run directory. `06-yosys-synthesis/` on disk is `Yosys.Synthesis` to the
CLI.

```bash
# Stop after floorplanning to check die area
librelane --to OpenROAD.Floorplan ~/my_designs/[design_name]/config.json

# Resume from placement using the previous run's state
librelane --last-run --from OpenROAD.GlobalPlacement ~/my_designs/[design_name]/config.json

# Run exactly one step
librelane --last-run --only Yosys.Synthesis ~/my_designs/[design_name]/config.json

# Try a different clock without editing the config
librelane -c CLOCK_PERIOD=30 ~/my_designs/[design_name]/config.json

# Skip a troublesome step
librelane --skip KLayout.DRC ~/my_designs/[design_name]/config.json

# Name a run so you can find it later
librelane --run-tag baseline ~/my_designs/[design_name]/config.json
```

Commonly-used step IDs:

| Stage | Step ID |
|---|---|
| Synthesis | `Yosys.Synthesis` |
| Floorplan | `OpenROAD.Floorplan` |
| Pin placement | `OpenROAD.IOPlacement` |
| Power grid | `OpenROAD.GeneratePDN` |
| Global placement | `OpenROAD.GlobalPlacement` |
| Detailed placement | `OpenROAD.DetailedPlacement` |
| Clock tree synthesis | `OpenROAD.CTS` |
| Global routing | `OpenROAD.GlobalRouting` |
| Detailed routing | `OpenROAD.DetailedRouting` |
| GDS streamout | `Magic.StreamOut`, `KLayout.StreamOut` |
| DRC | `Magic.DRC`, `KLayout.DRC` |
| LVS | `Netgen.LVS` |

To print the full step list for a flow:

```bash
python3 -c "
from librelane.flows import Flow
for s in Flow.factory.get('Classic').Steps: print(s.id)
"
```

`--overwrite` replaces an existing run directory instead of erroring.

### Alternative flows

`-f/--flow` selects the flow: `classic` (default), `optimizing` (explores
multiple synthesis strategies and picks the best), `vhdlclassic` (VHDL sources),
`chip`, `synthesisexploration`, plus the `openin*` viewer flows.

## 7. PDKs

Default is **sky130A**. PDKs download automatically via Ciel to `~/.volare` on
first use.

```bash
librelane -p sky130A  ~/my_designs/[design_name]/config.json   # default
librelane -p gf180mcuD ~/my_designs/[design_name]/config.json  # GF 180nm
librelane -s sky130_fd_sc_hd ~/my_designs/[design_name]/config.json
```

Sky130 standard cell libraries: `hd` (high density, default), `hs` (high speed),
`ls` (low speed), `ms`, `lp`.

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `librelane: command not found` | Not in the Nix shell — see §0 |
| `DESIGN_NAME` errors / empty synthesis | Must exactly match top-level module name |
| Files not found | Missing `dir::` prefix |
| Negative slack | Increase `CLOCK_PERIOD` |
| Routing congestion / placement failures | Lower `FP_CORE_UTIL` (e.g. 45 → 35) |
| `Could not resolve host` during builds | DNS trouble — see `docs/installation.md` §3.3 |

**Debugging a specific step:** read `COMMANDS` in that step's directory to see
the exact tool invocation and reproduce it by hand. `--reproducible <step-id>`
packages a step into a standalone reproducible case.

## Where to read more

- Repo: <https://github.com/librelane/librelane>
- Newcomers' tutorial: `~/librelane/docs/source/getting_started/newcomers/index.md`
- Usage guides (macros, PDN, timing closure, custom flows/steps, VHDL, ECOs):
  `~/librelane/docs/source/usage/`
- FAQ: `~/librelane/docs/source/faq.md`
- Worked examples: `~/librelane/librelane/examples/`
