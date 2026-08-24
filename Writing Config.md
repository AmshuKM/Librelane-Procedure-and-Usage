# Writing a `config.json`

LibreLane takes one JSON (or YAML) file per design — pure key-value pairs, no
comments, no trailing commas. Any variable not set falls back to a flow
default, PDK default, or standard-cell-library default, in that order.

## 1. The four required variables

```json
{
  "DESIGN_NAME": "my_design",
  "VERILOG_FILES": ["dir::src/my_design.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 10
}
```

| Key | What it means |
|---|---|
| `DESIGN_NAME` | Must exactly match your top-level Verilog module name. |
| `VERILOG_FILES` | List of source files. `dir::` means "relative to this config's folder." Wildcards work: `"dir::src/*.v"`. |
| `CLOCK_PORT` | Name of the clock input port in your top module. |
| `CLOCK_PERIOD` | Target clock period **in nanoseconds**. 10 ns = 100 MHz. |

Everything below is override territory — add a key only when you need to
change flow behavior.

## 2. Floorplan variables (congestion, die sizing)

| Key | Type | What it controls |
|---|---|---|
| `FP_CORE_UTIL` | int, 0–100 | Target core utilization %. Lower = more empty space, easier routing, less timing headroom to spare. |
| `PL_TARGET_DENSITY` | float, 0–1.0 | Placer's target density. Rule of thumb: `FP_CORE_UTIL + 1–5%` as a fraction, e.g. `FP_CORE_UTIL: 40` → `PL_TARGET_DENSITY: 0.45`. |
| `FP_ASPECT_RATIO` | float | Core height/width ratio. |
| `FP_SIZING` | `"relative"` \| `"absolute"` | `relative` (default) auto-sizes from `FP_CORE_UTIL`. `absolute` requires `DIE_AREA` explicitly. |
| `DIE_AREA` | `[x0, y0, x1, y1]` (µm) | Explicit die boundary, only used with `FP_SIZING: absolute`. |
| `CELL_PAD` | int | Spacing (in sites) around every cell. Higher = more routing room, lower density. |

**Rule of thumb for congestion:** drop `FP_CORE_UTIL` first, keep
`PL_TARGET_DENSITY` a few points above it.

## 3. Synthesis variables

| Key | What it controls |
|---|---|
| `SYNTH_STRATEGY` | Yosys optimization strategy — area vs. speed presets (`"AREA 0"`, `"DELAY 4"`, etc). |
| `MAX_FANOUT_CONSTRAINT` | Caps fanout per net during synthesis. Directly relevant to `large fanout` warnings. Typical: `4`–`6`. |
| `SYNTH_MAX_FANOUT` | Older/PDK-scoped name for the same idea in some flow versions. |

## 4. Global routing / congestion variables

| Key | What it controls |
|---|---|
| `GRT_ADJUSTMENT` | Fraction of routing capacity reserved as margin per layer (0–1). Raise it for high-overflow congestion reports. |
| `GRT_MACRO_EXTENSION` | Keep-out routing margin (in tracks) around hard macros — matters once a memory macro (e.g. an SRAM block) is in the design. |
| `ROUTING_CORES` | Parallel threads for routing — speed, not correctness. |
| `DIODE_INSERTION_STRATEGY` | Antenna-effect mitigation strategy during routing. |

## 5. PDK / standard cell library

```json
"PDK": "sky130A",
"STD_CELL_LIBRARY": "sky130_fd_sc_hd"
```

If omitted, LibreLane uses whatever default your environment (Volare) is
configured with.

## 6. Conditional overrides: `pdk::` and `scl::` scoping

Values can be scoped to a specific PDK or standard-cell library — useful if
the same design ever gets ported to another node:

```json
{
  "DESIGN_NAME": "spm",
  "VERILOG_FILES": "dir::src/*.v",
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 100,

  "pdk::sky130A": {
    "FP_CORE_UTIL": 40,
    "MAX_FANOUT_CONSTRAINT": 6,
    "PL_TARGET_DENSITY": "expr::($FP_CORE_UTIL + 5.0) / 100.0",

    "scl::sky130_fd_sc_hd": {
      "CLOCK_PERIOD": 15
    }
  }
}
```

- `"expr::..."` writes a value as a formula referencing another variable,
  evaluated at runtime.
- Nesting `scl::` inside `pdk::` scopes it to that PDK+library combo
  specifically.

## 7. Worked example — congested / memory-adjacent design

A config tuned for a design with routing congestion and a large-fanout net —
the profile a RAM/memory-heavy design tends to hit:

```json
{
  "DESIGN_NAME": "[ram_design_name]",
  "VERILOG_FILES": [
    "dir::ram_top.v",
    "dir::ram_controller.v",
    "dir::ram_model.v"
  ],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 25,

  "FP_CORE_UTIL": 35,
  "PL_TARGET_DENSITY": 0.40,

  "MAX_FANOUT_CONSTRAINT": 6,
  "GRT_ADJUSTMENT": 0.3,

  "RUN_HEURISTIC_DIODE_INSERTION": true
}
```

If congestion persists after `FP_CORE_UTIL` / `PL_TARGET_DENSITY` tuning,
check whether the RTL itself is the real problem — e.g. a memory array
synthesized as flip-flops instead of instantiated as a macro. No config knob
fixes a structurally oversized net.

## 8. Where to find every variable

- **Universal Flow Configuration Variables** (LibreLane docs) — the full list
  exposed to every step/flow, with types and defaults.
- Each step's own docs page — some variables are step-scoped rather than
  universal and only show up there.

Search the variable name before guessing its type — some (like
`PL_TARGET_DENSITY` vs `PL_TARGET_DENSITY_PCT`) look similar but take
different units (fraction vs. percent) depending on flow version.

## 9. Practical workflow for tuning a config

1. Start minimal — only the four required keys.
2. Run the flow. Read the **first** error, not just the last one.
3. Add one override group at a time (floorplan, then synthesis, then routing)
   — don't guess a pile of values at once, or you won't know what fixed it.
4. If congestion persists after floorplan/placement tuning, check whether the
   underlying RTL is the real problem.
