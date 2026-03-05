# BenchWGBSanimal Manifest

## 1) What this repository is (layman view)
This project compares multiple software tools that map DNA methylation sequencing reads (WGBS) in mammals.

In plain language:
- The same biological data is processed by many mapping tools.
- The results are compared for accuracy, consistency, speed, and memory usage.
- Outputs include methylation calls, differential methylation analyses (DMC/DMR), overlap/venn summaries, and plots.

## 2) Main workflow (high-level)
The repository has two data tracks:
- Simulated datasets: known ground truth, used for controlled benchmarking.
- Real datasets: human/cattle/pig datasets, used for practical comparison and downstream biology analyses.

Typical order:
1. Build genome indexes for each mapper.
2. Map reads per species/sample.
3. Extract CpG methylation and convert to DSS input.
4. Run differential methylation (DSS) and downstream analyses.
5. Generate summary plots/tables.

## 3) Directory map
- `RealDatasetA/`: real-data benchmarking scripts (alignment/runtime/unimap comparison).
- `RealDatasetB/`: real-data pipeline from mapping to CpG/DMC/DMR analyses and plots.
- `SimulatedDatasetA/`: simulated-data benchmark scripts (large benchmark set).
- `SimulatedDatasetB/`: additional simulated-data depth/error workflows.
- `annotation/`: species annotation files (CGI, repeats, genes, etc.).
- `data/`: sequencing input data (generated/linked/downloaded locally).
- `index/`: mapper indexes (generated locally).
- `result/`: outputs/results.
- `soft/`: expected external tool layout (many scripts reference this).
- `logs/`: run logs and skip logs (added for reproducibility/debugging).

## 4) Core script roles (technical)
- Index generation:
  - `SimulatedDatasetA/indexFa.sh`
- Mapping + benchmark:
  - `SimulatedDatasetA/mappedTwoMillionSimData.sh`
  - `SimulatedDatasetB/mapSimulatedDataDepth5.sh`
  - `RealDatasetA/humanRealBench.sh`
  - `RealDatasetA/cattleRealBench.sh`
  - `RealDatasetA/pigRealBench.sh`
  - `RealDatasetB/mappedHuman.sh`
  - `RealDatasetB/mappedCattle.sh`
  - `RealDatasetB/mappedPig.sh`
- Real-data downstream:
  - `RealDatasetB/dm3.R`
  - `RealDatasetB/anaCpg.sh`
  - `RealDatasetB/anaDmcDmrGene.sh`

## 5) Environment and execution model
Current recommended model on Apple Silicon:
- Mapping env (x64): `benchwgbsanimal-x64` (or `benchwgbs-map-x64`), includes bsbolt/samtools/MethylDackel.
- R env (x64): `benchwgbs-r-x64`, includes DSS/bsseq/clusterProfiler and annotation DB packages.

Supporting files:
- `environment.map-x64.yml`
- `environment.r-x64.yml`
- `check_dependencies.sh`
- `RUN_LOCAL.md`

## 6) Minimal smoke-test model
Added helpers for fast local verification:
- `prepare_smoke_inputs.sh`
  - prepares tiny inputs (e.g., chr22 + small read subset) and builds bsbolt index.
  - supports internet download mode.
  - writes logs to `logs/prepare_smoke_inputs_*.log`.
- `run_smoke_bsbolt.sh`
  - runs one-sample bsbolt mapping/CpG extraction path.
  - writes logs to `logs/run_smoke_bsbolt_*.log`.

## 7) New robustness behavior (skip missing tools)
To make partial runs possible on machines missing some mapper toolchains:
- Several scripts now skip unavailable mappers instead of hard-failing.
- Skip entries are written to `logs/*_skip_*.log`.
- This does not change core algorithm logic for mappers that do run.

Currently patched with skip logging:
- `RealDatasetB/mappedHuman.sh`
- `RealDatasetB/mappedCattle.sh`
- `RealDatasetB/mappedPig.sh`
- `SimulatedDatasetA/indexFa.sh`
- `SimulatedDatasetB/mapSimulatedDataDepth5.sh`
- `RealDatasetA/humanRealBench.sh`
- `RealDatasetA/cattleRealBench.sh`
- `RealDatasetA/pigRealBench.sh`
- `SimulatedDatasetA/mappedTwoMillionSimData.sh`

## 8) Data/tool assumptions
- Most scripts assume species-specific files exist under `data/`, `index/`, and `annotation/`.
- Many original paths assume tools under `soft/`.
- Some referenced binaries are Linux builds in original repo and may be unavailable on macOS.

## 9) What “full paper-level run” means in practice
You need all of the following ready:
- Full datasets for all species/samples.
- Full mapper toolchain availability (or accepted skip strategy).
- Complete indexes for all required mappers and species.
- R/Bioconductor dependency stack for downstream analyses and plotting.

## 10) Reproducibility notes
- Generated artifacts are ignored via `.gitignore`: `data/`, `index/`, `result/`, `logs/`.
- Use logs as provenance for what ran vs what was skipped.
- For strict reproduction, pin env versions and capture exact command lines from logs.
