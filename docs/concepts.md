# Concepts: Timing, Verification, and Debugging

Background reading for interpreting what LibreLane produces. For commands, see
[usage.md](usage.md); for install, see [installation.md](installation.md).

---

## Timing analysis

Static Timing Analysis (STA) is one of the most important parts of the flow.

### Worst Negative Slack (WNS)

`WNS` is the worst slack across all timing paths.

- `WNS >= 0` → timing is clean
- `WNS < 0`  → the design has a timing violation

### Total Negative Slack (TNS)

`TNS` sums the slack of all failing paths.

- `TNS = 0` → no failing paths
- `TNS < 0` → one or more paths fail timing

### Timing corners (PVT)

LibreLane analyzes the design under multiple Process/Voltage/Temperature corners:

| Corner | Meaning        | Usually critical for |
| ------ | -------------- | -------------------- |
| `TT`   | Typical/Typical| Nominal check        |
| `SS`   | Slow/Slow      | **Setup** timing     |
| `FF`   | Fast/Fast      | **Hold** timing      |

If STA reports negative slack, the usual first move is to increase
`CLOCK_PERIOD`.

---

## Physical verification

### DRC — Design Rule Checking

Confirms the layout obeys the foundry's manufacturing rules: minimum spacing,
minimum width, metal overlap, via rules, and so on. Target: **0 violations**.

### LVS — Layout Versus Schematic

Confirms the physical layout matches the intended netlist (Layout = Netlist).
A passing LVS means the geometry actually implements the circuit you designed.

### Antenna checks

During fabrication, long metal runs can accumulate charge and damage transistor
gates. LibreLane includes antenna checking and mitigation.

---

## Debugging workflow

When a run fails, work from the **first** error, not the last:

```
Run fails
  → check error.log
  → find the FIRST real error
  → identify the failing flow stage
  → open that stage's log + COMMANDS file
  → reproduce the tool invocation by hand
  → fix RTL or config
  → re-run
```

The final error message is often a downstream symptom; the first error is
usually the actual cause.

---

## Common problems

**`librelane: command not found`** — you're not inside the Nix shell:

```
cd ~/librelane && nix-shell
```

**RTL files not found** — use paths relative to the config directory with the
`dir::` prefix:

```json
"VERILOG_FILES": ["dir::src/*.v"]
```

**Negative setup slack** — likely causes: clock target too aggressive, high
fanout, large combinational paths, congestion, poor placement, or high routing
delay.

**Routing congestion** — try: lower core utilization, more routing area, cleaner
RTL, reduced fanout, better macro placement, or adjusted placement density.

---

## LibreLane vs OpenLane

LibreLane is the successor to OpenLane, with a more modular, Python-based flow
architecture. Because many online tutorials still target older OpenLane
versions, commands and config variables may differ.

When following an older tutorial:

```
Old OpenLane tutorial
  → check your LibreLane version
  → verify each config variable against current LibreLane docs
```

Don't assume every OpenLane option works unchanged in LibreLane.
