# Run BenchWGBSanimal Locally

This repository was patched for local reproducibility without changing analysis logic.

## 1) Required directory structure

At repository root:

- `data/`
- `index/`
- `annotation/`
- `soft/`
- `result/`

Expected script layout is already in-repo:

- `RealDatasetA/`
- `RealDatasetB/`
- `SimulatedDatasetA/`
- `SimulatedDatasetB/`

## 2) Environment setup (Apple Silicon, simpler split-env path)

```bash
cd /Users/rafalkelm/Documents/projects/Tool meth/BenchWGBSanimal

# Mapping/tools env (x64 via Rosetta subdir; needed for bsbolt)
CONDA_SUBDIR=osx-64 conda env create -f environment.map-x64.yml

# R/Bioconductor env (x64 prebuilt binaries)
CONDA_SUBDIR=osx-64 conda env create -f environment.r-x64.yml
```

Install BSBolt into mapping env:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-map-x64
python -m pip install --no-cache-dir bsbolt
```

Check mapping env:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-map-x64
CHECK_SCOPE=map ./check_dependencies.sh
```

Check R env:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-r-x64
CHECK_SCOPE=r ./check_dependencies.sh
```

If your tools are under a custom location, set:

```bash
export SOFT_DIR="/absolute/path/to/soft"
```

## 3) Minimal smoke test (single species/sample)

Run one species (`human`) and one sample through real-data mapping + CpG extraction + DSS-input generation:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-map-x64
export RESULT_DIR="$PWD/result/realRes"
./run_smoke_bsbolt.sh
```

This keeps output structure unchanged, but limits runtime/data volume.

## 4) Full run order

### A. Build indexes (simulated workflows)

```bash
bash SimulatedDatasetA/indexFa.sh
```

### B. Simulated data generation + mapping + plotting

```bash
bash SimulatedDatasetB/generateSimulatedDataDepth5.sh
bash SimulatedDatasetB/mapSimulatedDataDepth5.sh
bash SimulatedDatasetB/downsteamAnalysisForMappedRes.sh
Rscript SimulatedDatasetB/SimulatedDatasetBPlot.R

bash SimulatedDatasetA/mappedTwoMillionSimData.sh
Rscript SimulatedDatasetA/benchPlot.R
```

### C. Real dataset A benchmarking + plotting

```bash
bash RealDatasetA/generateRealDatasetB.sh
bash RealDatasetA/humanRealBench.sh
bash RealDatasetA/cattleRealBench.sh
bash RealDatasetA/pigRealBench.sh
Rscript RealDatasetA/realDatasetAPlot.R
```

### D. Real dataset B pipeline (mapping -> DSS -> DMC/DMR/CpG -> plots)

1. Mapping + CpG calling + DSS input preparation:

```bash
bash RealDatasetB/mappedHuman.sh
bash RealDatasetB/mappedCattle.sh
bash RealDatasetB/mappedPig.sh
```

2. Differential methylation (DSS):

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-r-x64
Rscript RealDatasetB/dm3.R
```

3. CpG consistency/discrepancy analyses:

```bash
bash RealDatasetB/anaCpg.sh
```

4. DMC/DMR/gene/KEGG venn analyses:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-r-x64
bash RealDatasetB/anaDmcDmrGene.sh
Rscript RealDatasetB/KEGG.R
```

5. Plotting:

```bash
source /opt/homebrew/Caskroom/miniforge/base/bin/activate benchwgbs-r-x64
Rscript RealDatasetB/RealDatasetBPolt.R
```

## 5) Troubleshooting

- `command not found` for tools: activate `benchwgbs-map-x64` first, or point `SOFT_DIR` to your local tool bundle.
- `No such file or directory` for data/index/annotation: verify required root folders and species/sample subfolders.
- R package errors: activate `benchwgbs-r-x64` and rerun `CHECK_SCOPE=r ./check_dependencies.sh`.
- Python module `bsbolt` missing: activate `benchwgbs-map-x64` and run `python -m pip install --no-cache-dir bsbolt`.
- If you run scripts from outside repo root, keep defaults by using absolute `RESULT_DIR`, `SOFT_DIR`, etc.
- Minimal full-run mode: selected scripts now auto-skip unavailable mappers/tools instead of hard-failing. Skip reasons are written to `logs/*_skip_*.log`.
