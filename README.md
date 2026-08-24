# LibreLane: Procedure and Usage

A practical, beginner-friendly guide to installing, configuring, and running
**[LibreLane](https://github.com/librelane/librelane)** for open-source ASIC design —
the full journey from **Verilog RTL to GDSII**.

Built for students and VLSI newcomers who want to push their own RTL through a
real open-source implementation flow and understand what comes out the other end.

---

## What is LibreLane?

[LibreLane](https://github.com/librelane/librelane) is an open-source RTL-to-GDSII
flow maintained by the FOSSi Foundation (the successor to OpenLane 2). It
orchestrates a full open-source EDA toolchain:

| Tool         | Role                                             |
| ------------ | ------------------------------------------------ |
| **Verilator**| RTL linting                                      |
| **Yosys**    | Logic synthesis                                  |
| **OpenROAD** | Floorplan, placement, CTS, routing, timing opt   |
| **OpenSTA**  | Static timing analysis                           |
| **Magic**    | Layout generation and DRC                        |
| **KLayout**  | Layout viewing and DRC                           |
| **Netgen**   | LVS verification                                 |

The flow, end to end:

```
Verilog RTL → Lint → Synthesis → Floorplan → PDN → Placement → CTS
→ Timing Opt → Global Route → Detailed Route → DRC / LVS / STA → GDSII
```

---

## Documentation

| Guide | What's inside |
| ----- | ------------- |
| **[Installation](docs/installation.md)** | Nix setup, the binary cache, disk/RAM requirements, common install traps |
| **[Usage](docs/usage.md)** | Command reference, project layout, reading run output, viewing layouts, iterating on the flow |
| **[Writing config.json](docs/writing-config.md)** | Every config variable, path prefixes, PDK and standard-cell options |
| **[Concepts](docs/concepts.md)** | Timing analysis (WNS/TNS/corners), physical verification (DRC/LVS/antenna), debugging workflow, LibreLane vs OpenLane |

---

## Quick start

**1. Install** — follow **[docs/installation.md](docs/installation.md)**. LibreLane
runs inside a Nix shell, so every session starts with:

```
cd ~/librelane && nix-shell
librelane --version
```

**2. Run your first design** — this repo ships a simple 4-bit up/down counter:

```
librelane examples/counter/config.json
```

A minimal `config.json` needs just four variables:

```json
{
  "DESIGN_NAME": "counter",
  "VERILOG_FILES": ["dir::src/counter.v"],
  "CLOCK_PORT": "clk",
  "CLOCK_PERIOD": 25
}
```

LibreLane runs the full RTL-to-GDSII flow and drops results in a timestamped
`runs/RUN_<timestamp>/final/` directory. Your GDS lands at `final/gds/`.
See **[docs/usage.md](docs/usage.md)** for how to read the output.

---

## Examples

| Example | Purpose |
| ------- | ------- |
| **[counter](examples/counter/)** | Minimal starting point — a full flow on a tiny design |
| **[ddr4](examples/ddr4/)** | Larger design for studying fanout, slew, setup/hold violations, and routing congestion |

> A completed flow does **not** mean a clean design. Always inspect WNS, TNS,
> DRC, LVS, slew, and fanout before calling it closed.

---

## Repository structure

```
.
├── README.md            You are here
├── docs/                Detailed guides
├── examples/            Runnable example designs
└── assets/images/       Screenshots used in the docs
```

---

## Roadmap

Planned additions: RTL simulation walkthrough, timing-closure guide, power
analysis, PDK and standard-cell deep dive, macro integration, reproducible runs,
and automated regression testing.

---

## Useful resources

- [LibreLane repository](https://github.com/librelane/librelane) ·
  [LibreLane docs](https://librelane.readthedocs.io/)
- [FOSSi Foundation](https://fossi-foundation.org/)
- [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) ·
  [Yosys](https://github.com/YosysHQ/yosys)
- [SkyWater SKY130 PDK](https://github.com/google/skywater-pdk)

---

## Contributing

Corrections, improvements, and additional examples are welcome. Found an outdated
command or a config variable that's changed? Open an issue or a pull request.

## License

See [LICENSE](LICENSE).

## Author

**Amshu** — Master's student focused on VLSI, ASIC design, and open-source EDA.
