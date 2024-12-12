# jitter-attack-scripts
# Attack Scripts Repository

This repository contains scripts for running and analyzing attack scenarios on various congestion control algorithms (CCAs), specifically targeting BBR and Copa. The setup includes automation for launching experiments, logging results, and generating plots to analyze the effectiveness of the attacks.

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [Running Experiments](#running-experiments)
  - [Plotting Results](#plotting-results)
- [Key Scripts](#key-scripts)
  - [sweep_param.sh](#sweep_paramsh)
  - [run_experiment.sh](#run_experimentsh)
  - [bottleneck_box.sh](#bottleneck_boxsh)
  - [sender.sh](#sendersh)
- [Logging and Output Files](#logging-and-output-files)

---

## Overview
This repository is designed to facilitate the testing of congestion control algorithms under adversarial attack scenarios. It provides automation for:

1. Configuring experiments for BBR and Copa CCAs.
2. Executing attacks and logging results.
3. Analyzing the impact of attacks through plotting scripts.

## Prerequisites
1. **Mahimahi Modules**: Ensure the required Mahimahi modules (`mm-bbr-attack`, `mm-copa-attack`) are cloned and installed.
2. **CopaCrossTrafficAttack**: Required for Copa Attack 2 scenario. Install the binaries (sender and receiver) in `/usr/local/bin`.
3. **Dependencies**: Install Python dependencies for plotting and log parsing (e.g., `matplotlib`, `pandas`).
4. **Permissions**: Ensure all scripts have executable permissions (`chmod +x script_name.sh`).

## Usage

### Running Experiments
Use the `sweep_param.sh` script to initiate experiments.

**Usage**:
```bash
./sweep_param.sh <attack flag> <cca> <1 or 2>
```

- `<attack flag>`: `true` for attack scenario, `false` for non-attack scenario.
- `<cca>`: Specify the congestion control algorithm (e.g., `bbr`, `copa`).
- `<1 or 2>`: Specify the attack model (e.g., Attack 1 or Attack 2).

**Examples**:
```bash
./sweep_param.sh true copa 1
./sweep_param.sh false bbr
```

### Plotting Results
For Copa Attack 1 and 2 scenarios, plots are generated automatically by calling `run_plotting.sh` at the end of the `sweep_param.sh` script. This script processes logs and creates visualizations.

For BBR Attack scenarios, run the plotting script manually:
```bash
python3 parse_mahimahi.py -i <input_file> -o <output_file>
```

## Key Scripts

### sweep_param.sh
- The entry point for all experiments.
- Defines parameters such as `pkts_ms`, `inter_burst_duration`, `burst_duration`, `delay_budget`, `delay_ms`, and `ccs_choice`.
- Determines the scenario (attack or non-attack) and CCA type.
- Calls `run_experiment.sh` to execute experiments.

### run_experiment.sh
- Configures logfile paths and launches sender and receiver processes.
- Manages main attack modules (`mm-bbr-attack` and `mm-copa-attack`).
- Calls `bottleneck_box.sh`.

### bottleneck_box.sh
- Configures the network bottleneck.
- Calls `sender.sh` to launch the sender script based on the CCA type.

### sender.sh
- Performs calculations for Copa Attack 2.
- Launches the appropriate sender process for BBR and Copa Attack scenarios.
- Calls the attacker sender in Copa Attack 2.

## Logging and Output Files
- Logs are created for each attack scenario and can be found in the paths defined within `run_experiment.sh`.
- Naming conventions for logs vary depending on the CCA type and scenario mode (attack/non-attack).

## Notes
- Ensure the correct CCA type is set in `sweep_param.sh` before running experiments.
- For Copa Attack 2, ensure binaries from the CopaCrossTrafficAttack repository are installed in `/usr/local/bin`.
- For BBR Attack scenarios, manually provide input/output files for plotting.




