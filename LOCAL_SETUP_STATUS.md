# Local Setup Status (Living Doc)

Last updated: 2026-03-05

## Goal
Make local execution incremental and simpler: run a smoke test first, then expand.

## What was changed in this update

1. Added optional mapper filtering in real-data mapping scripts:
- `RealDatasetB/mappedHuman.sh`
- `RealDatasetB/mappedCattle.sh`
- `RealDatasetB/mappedPig.sh`

New env var:
- `MAPPER_LIST`

Behavior:
- If `MAPPER_LIST` is unset: all mapper blocks run (original behavior).
- If set, only listed mappers run.

Examples:
- `export MAPPER_LIST="bsbolt"`
- `export MAPPER_LIST="bsmap bsbolt"`

2. Existing optional env vars still supported:
- `SAMPLE_LIST` to run only selected samples.
- `RESULT_DIR`, `SOFT_DIR`, etc. for custom paths.

## Why this helps

- You can do a minimal smoke test without provisioning every mapper tool immediately.
- This keeps the biological/statistical logic unchanged while reducing setup burden.

## Current environment recommendation: arm64 vs osx-64

Observed facts:
- `bsbolt` failed to build in native arm64 with x86 SIMD (`emmintrin.h`) compile errors.
- `bsbolt` installation succeeded in your `osx-64` Conda environment.

Conclusion:
- For this project, use `osx-64` Conda env (Rosetta) if you need BSBolt.
- Native arm64 is possible only if you skip BSBolt or maintain separate workarounds.

Note on mapper binaries in `soft/`:
- Several expected paths are explicitly Linux builds (e.g., `*-linux-x86_64`).
- Those binaries will not run directly on macOS regardless of Conda architecture.
- Prefer macOS-native installs and symlink/wrap to expected script paths, or adjust `SOFT_DIR` layout.

## Recommended smoke test path

```bash
conda activate benchwgbsanimal-x64
cd "/Users/rafalkelm/Documents/projects/Tool meth/BenchWGBSanimal"

export MAPPER_LIST="bsbolt"
export SAMPLE_LIST="SRR6373923"
export RESULT_DIR="$PWD/result/realRes"

bash RealDatasetB/mappedHuman.sh
```

## Next updates planned

- Add the same `MAPPER_LIST` filter to `RealDatasetA/*RealBench.sh` (optional).
- Optionally add a strict smoke-test script that checks one mapper + one sample + one output file.

## Incremental update: smoke-run usability

Added space-safe path handling in:
- `RealDatasetB/mappedHuman.sh`
- `RealDatasetB/mappedCattle.sh`
- `RealDatasetB/mappedPig.sh`

Implementation detail:
- Path variables are escaped to tolerate repository paths containing spaces.

Added wrapper:
- `run_smoke_bsbolt.sh`

Wrapper purpose:
- Precheck for required smoke-test inputs/tools (`bsbolt`, `samtools`, `MethylDackel`, index, FASTQ files).
- Run one sample with `MAPPER_LIST=bsbolt` only.

Usage:

```bash
conda activate benchwgbsanimal-x64
cd "/Users/rafalkelm/Documents/projects/Tool meth/BenchWGBSanimal"

# defaults: SPECIES=human, SAMPLE=SRR6373923
./run_smoke_bsbolt.sh

# custom
SPECIES=human SAMPLE=SRR6373923 ./run_smoke_bsbolt.sh
```

## Incremental update: tool path fallback (Step B simplification)

`RealDatasetB/mapped*.sh` now auto-resolve these tools in this order:
1. Explicit env var (`SAMTOOLS_BIN`, `METHYLDACKEL_BIN`)
2. Tool in `PATH`
3. Legacy `soft/` path fallback

This removes the hard requirement to mirror exact `soft/` layout for smoke runs.

`run_smoke_bsbolt.sh` precheck was updated to use the same fallback logic.

## Current automated setup status (executed)

Completed by automation in `benchwgbsanimal-x64`:
- `samtools` installed and detected in PATH.
- `MethylDackel` installed and detected in PATH.
- `bsbolt` python module detected.
- `RealDatasetB/mapped*.sh` now support:
  - `MAPPER_LIST` (single-mapper smoke runs)
  - path fallback for `SAMTOOLS_BIN` / `METHYLDACKEL_BIN`.
- Smoke wrapper now fails only on missing local inputs.

Remaining blockers for smoke test:
- `index/human/bsbolt` does not exist.
- `data/human/SRR6373923/cleandata/*` does not exist.

Note:
- Full multi-mapper benchmark still requires many mapper binaries not present in local `soft/`.

## Incremental update: split-env and architecture check (Option 3/4/5)

Observed on this machine:
- Host architecture: `arm64`
- Conda default subdir: `osx-arm64`

Validation outcomes:
1. Native ARM (`osx-arm64`) cannot satisfy this project as-is:
- `bsbolt` is not available via conda on `osx-arm64`.
- `bioconductor-bsseq` failed in ARM solve in this setup.

2. `osx-64` split env path works better:
- Created `benchwgbs-r-x64` successfully with prebuilt Bioconductor stack.
- Verified required R packages in `benchwgbs-r-x64`: `OK`.

3. Mapping env approach:
- Created `benchwgbs-map-x64` with `samtools`, `MethylDackel`, `bedtools`, and build utilities.
- `bsbolt` still requires `pip` build/install (not available as conda package in tested channels).

Repository updates for this path:
- Added `environment.map-x64.yml`
- Added `environment.r-x64.yml`
- Updated `RUN_LOCAL.md` to use split envs
- Updated `check_dependencies.sh` with scoped checks:
  - `CHECK_SCOPE=map`
  - `CHECK_SCOPE=r`
  - `CHECK_SCOPE=full` (legacy all-in check)
