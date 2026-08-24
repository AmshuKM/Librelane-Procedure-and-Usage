# LibreLane Procedure and Usage

A practical, beginner-friendly guide for installing, configuring, and using **LibreLane** for open-source ASIC design.

This repository documents the complete journey from **Verilog RTL to GDSII**, including installation, project configuration, timing analysis, physical verification, debugging, and example designs.

## What is LibreLane?

[LibreLane](https://github.com/librelane/librelane) is an open-source ASIC implementation flow developed and maintained by the FOSSi Foundation.

It automates the digital ASIC flow using tools such as:

* **Verilator** — RTL linting
* **Yosys** — Logic synthesis
* **OpenROAD** — Floorplanning, placement, CTS, routing, and timing optimization
* **OpenSTA** — Static Timing Analysis
* **Magic** — Layout generation and DRC
* **KLayout** — Layout viewing and DRC
* **Netgen** — LVS verification

The overall flow is:

```text
Verilog RTL
    │
    ▼
RTL Linting
    │
    ▼
Logic Synthesis
    │
    ▼
Floorplanning
    │
    ▼
Pin Placement + PDN
    │
    ▼
Placement
    │
    ▼
Clock Tree Synthesis
    │
    ▼
Timing Optimization
    │
    ▼
Global Routing
    │
    ▼
Detailed Routing
    │
    ▼
DRC / LVS / STA
    │
    ▼
GDSII
```

---

# Repository Goals

This repository is designed to help students, beginners, and VLSI enthusiasts understand how to use LibreLane for their own RTL designs.

It covers:

* Installing LibreLane
* Understanding the ASIC RTL-to-GDSII flow
* Creating a LibreLane project
* Writing Verilog RTL
* Simulating and verifying RTL
* Writing `config.json`
* Running a complete LibreLane flow
* Understanding the generated run directory
* Reading timing reports
* Viewing layouts in KLayout and OpenROAD
* Understanding PDKs and standard-cell libraries
* Debugging common flow failures
* Timing and congestion optimization

---




# Quick Start

## 1. Install LibreLane

The recommended method is to follow the LibreLane installation documentation.

Official LibreLane repository:

[LibreLane](https://github.com/librelane/librelane)

After installation, verify that LibreLane is available:

```bash
librelane --version
```

For a Nix-based installation:

```bash
cd ~/librelane
nix-shell
```

Then run:

```bash
librelane --version
```

---

# Your First LibreLane Design

This repository includes a simple **4-bit Up/Down Counter** example.

The basic project structure is:

```text
counter/
├── src/
│   └── counter.v
├── tb/
│   └── counter_tb.v
└── config.json
```

A minimal LibreLane configuration looks like:

```json
{
  "DESIGN_NAME": "counter",
  "VERILOG_FILES": ["dir::src/counter.v"],
  "CLOCK_PERIOD": 25,
  "CLOCK_PORT": "clk"
}
```

Run the design using:

```bash
librelane examples/counter/config.json
```

LibreLane will automatically execute the RTL-to-GDSII flow.

---

# Understanding the Flow

A typical LibreLane run performs the following stages:

| Stage            | Description                                     |
| ---------------- | ----------------------------------------------- |
| RTL Linting      | Checks the Verilog design for common RTL issues |
| Synthesis        | Converts RTL into a gate-level netlist          |
| Floorplanning    | Defines the chip/core area                      |
| IO Placement     | Places input and output pins                    |
| PDN              | Creates the power distribution network          |
| Placement        | Places standard cells                           |
| CTS              | Builds the clock tree                           |
| Timing Repair    | Optimizes setup and hold timing                 |
| Global Routing   | Estimates routing paths                         |
| Detailed Routing | Creates the final physical routes               |
| DRC              | Checks physical design rules                    |
| LVS              | Verifies layout against the netlist             |
| Streamout        | Generates the final GDSII layout                |

---

# Understanding LibreLane Runs

Each execution creates a run directory:

```text
runs/
└── RUN_<timestamp>/
    │
    ├── error.log
    ├── warning.log
    ├── flow.log
    ├── resolved.json
    │
    ├── ...
    │
    └── final/
        ├── gds/
        ├── def/
        ├── lef/
        ├── nl/
        ├── sdc/
        ├── spef/
        ├── metrics.json
        └── metrics.csv
```

The first files to check when something goes wrong are:

```text
error.log
warning.log
flow.log
```

The final results are typically available inside:

```text
final/
```

---

# Important Outputs

## GDSII

The final chip layout is usually located in:

```text
final/gds/
```

The GDSII file can be opened using **KLayout**.

---

## DEF

The physical design representation can be found in:

```text
final/def/
```

---

## Netlists

Generated netlists are available in:

```text
final/nl/
```

---

## Timing and Metrics

The complete flow metrics are available in:

```text
final/metrics.json
```

and:

```text
final/metrics.csv
```

Important metrics include:

```text
design__die__area
design__core__area

timing__setup__ws
timing__setup__tns

timing__hold__ws
timing__hold__tns

power__internal__total
power__switching__total
power__leakage__total
power__total

magic__drc_error__count
```

---

# Timing Analysis

Static Timing Analysis is one of the most important parts of the ASIC flow.

Key metrics include:

## Worst Slack

```text
WNS = Worst Negative Slack
```

For a timing-clean design:

```text
WNS >= 0
```

If:

```text
WNS < 0
```

the design has a timing violation.

---

## Total Negative Slack

```text
TNS = Total Negative Slack
```

For a timing-clean design:

```text
TNS = 0
```

A negative TNS indicates one or more failing timing paths.

---

## Typical Timing Corners

LibreLane may analyze the design under multiple PVT conditions.

Examples include:

```text
TT — Typical / Typical
SS — Slow / Slow
FF — Fast / Fast
```

Generally:

```text
Slow corner
    ↓
Often critical for setup timing

Fast corner
    ↓
Often critical for hold timing
```

---

# Physical Verification

## DRC — Design Rule Checking

DRC checks whether the layout follows manufacturing rules.

Examples include:

* Minimum spacing violations
* Minimum width violations
* Metal overlap
* Via violations

A successful design should ideally have:

```text
DRC violations = 0
```

---

## LVS — Layout Versus Schematic

LVS checks whether the generated layout matches the intended circuit/netlist.

A successful LVS run confirms:

```text
Layout
   =
Netlist
```

---

## Antenna Checks

During fabrication, long metal connections can accumulate charge and potentially damage transistor gates.

LibreLane includes antenna checking and mitigation mechanisms.

---

# Viewing Your Design

## Open in KLayout

```bash
librelane --last-run \
    --flow OpenInKLayout \
    path/to/config.json
```

KLayout can be used to inspect:

* Standard cells
* Routing
* Metal layers
* Pins
* DRC violations
* Final GDSII layout

---

## Open in OpenROAD

```bash
librelane --last-run \
    --flow OpenInOpenROAD \
    path/to/config.json
```

OpenROAD is useful for analyzing:

* Floorplan
* Placement
* Routing
* Congestion
* Clock tree
* Timing-related physical issues

---

# Configuration

Every LibreLane design requires a configuration file.

A minimal configuration is:

```json
{
  "DESIGN_NAME": "my_design",
  "VERILOG_FILES": ["dir::src/my_design.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 10
}
```

These parameters define:

| Variable        | Description                        |
| --------------- | ---------------------------------- |
| `DESIGN_NAME`   | Top-level Verilog module name      |
| `VERILOG_FILES` | Verilog source files               |
| `CLOCK_PORT`    | Clock input port                   |
| `CLOCK_PERIOD`  | Target clock period in nanoseconds |

For example:

```text
CLOCK_PERIOD = 10 ns
```

corresponds to:

```text
Frequency = 100 MHz
```

More configuration options are covered in the documentation.

---

# Example Designs

## Up/Down Counter

The Counter example is intended as a simple introduction to the complete ASIC flow.

It demonstrates:

```text
RTL
 ↓
Simulation
 ↓
Synthesis
 ↓
Floorplan
 ↓
Placement
 ↓
Routing
 ↓
Timing Analysis
 ↓
DRC / LVS
 ↓
GDSII
```

This is the recommended starting point for new LibreLane users.

---

## DDR4 Example

The repository also contains a larger DDR4-related example.

This example is useful for studying:

* Large RTL designs
* High cell counts
* Fanout problems
* Slew violations
* Setup timing violations
* Hold timing violations
* Routing complexity

> **Note:** A completed LibreLane flow does not necessarily mean that the design is timing-closed. Always inspect WNS, TNS, DRC, LVS, slew, fanout, and other signoff metrics.

---

# Debugging Workflow

When a LibreLane run fails:

```text
Run fails
   │
   ▼
Check error.log
   │
   ▼
Find the first actual error
   │
   ▼
Identify the failing flow stage
   │
   ▼
Check the stage log
   │
   ▼
Check COMMANDS
   │
   ▼
Reproduce the issue
   │
   ▼
Modify RTL or configuration
   │
   ▼
Run again
```

Do not focus only on the final error. The first error is often the actual cause of later failures.

---

# Common Problems

### `librelane: command not found`

You may not be inside the LibreLane environment.

For Nix installations:

```bash
cd ~/librelane
nix-shell
```

---

### RTL files are not found

Use paths relative to the configuration directory:

```json
"VERILOG_FILES": [
  "dir::src/*.v"
]
```

---

### Negative Setup Slack

Possible causes include:

* Clock target is too aggressive
* High fanout
* Large combinational paths
* Congestion
* Poor placement
* High routing delay

---

### Routing Congestion

Possible solutions include:

* Reduce core utilization
* Increase available routing area
* Improve RTL structure
* Reduce excessive fanout
* Review macro placement
* Adjust placement density

---

# LibreLane and OpenLane

LibreLane is the successor to the newer OpenLane infrastructure and introduces a more modular and Python-based flow architecture.

Because many online tutorials still use older OpenLane versions, configuration variables and commands may differ.

When following an older tutorial:

```text
Old OpenLane tutorial
        ↓
Check LibreLane version
        ↓
Verify configuration variables
        ↓
Check current LibreLane documentation
```

Do not assume that every OpenLane configuration option works unchanged in LibreLane.

---

# Documentation Roadmap

The goal is to expand this repository into a structured practical reference covering:

* [ ] Installation guide
* [ ] Quick-start tutorial
* [ ] RTL simulation
* [ ] Writing `config.json`
* [ ] Running the RTL-to-GDSII flow
* [ ] Understanding run directories
* [ ] Timing reports
* [ ] Setup and hold timing
* [ ] Timing closure
* [ ] Power analysis
* [ ] DRC analysis
* [ ] LVS analysis
* [ ] Antenna violations
* [ ] PDK and standard-cell libraries
* [ ] Macro integration
* [ ] Debugging failed flows
* [ ] Reproducible LibreLane runs
* [ ] LibreLane vs OpenLane
* [ ] Automated regression testing

---

# Useful Resources

* [LibreLane Repository](https://github.com/librelane/librelane)
* [LibreLane Documentation](https://librelane.readthedocs.io/)
* [FOSSi Foundation](https://fossi-foundation.org/)
* [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD)
* [Yosys](https://github.com/YosysHQ/yosys)
* [SkyWater SKY130 PDK](https://github.com/google/skywater-pdk)

---

# Contributing

Contributions, corrections, improvements, and additional examples are welcome.

If you find an outdated command, incorrect configuration variable, or missing explanation, feel free to open an issue or submit a pull request.

---

# License

A license for this repository will be added.

---

## Author

**Amshu**

Master's student focused on **VLSI, Electronics, ASIC Design, and Open-Source EDA**.

---

## Project Goal

The goal of this repository is simple:

```text
Learn RTL
     ↓
Verify RTL
     ↓
Understand ASIC Implementation
     ↓
Run LibreLane
     ↓
Analyze Timing
     ↓
Fix Errors
     ↓
Generate GDSII
     ↓
Learn by Building
```

If this repository helps you take your first RTL design through an open-source ASIC flow, then it has achieved its purpose.
