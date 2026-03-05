#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}" && pwd)"
SOFT_DIR="${SOFT_DIR:-${REPO_DIR}/soft}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
R_BIN="${R_BIN:-Rscript}"
CHECK_SCOPE="${CHECK_SCOPE:-full}" # full | map | r

missing=0

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [OK] $label ($cmd in PATH)"
  else
    echo "  [MISSING] $label ($cmd not in PATH)"
    missing=1
  fi
}

check_file() {
  local file_path="$1"
  local label="$2"
  if [[ -e "$file_path" ]]; then
    echo "  [OK] $label ($file_path)"
  else
    echo "  [MISSING] $label ($file_path)"
    missing=1
  fi
}

if [[ "${CHECK_SCOPE}" != "full" && "${CHECK_SCOPE}" != "map" && "${CHECK_SCOPE}" != "r" ]]; then
  echo "Invalid CHECK_SCOPE='${CHECK_SCOPE}'. Use one of: full, map, r"
  exit 1
fi

if [[ "${CHECK_SCOPE}" == "full" || "${CHECK_SCOPE}" == "map" ]]; then
echo "Checking external tools..."

check_cmd "$PYTHON_BIN" "Python interpreter"

if command -v samtools >/dev/null 2>&1; then
  echo "  [OK] samtools (in PATH)"
elif [[ -x "${SOFT_DIR}/samtools-1.12/samtools" ]]; then
  echo "  [OK] samtools (${SOFT_DIR}/samtools-1.12/samtools)"
else
  echo "  [MISSING] samtools (PATH or ${SOFT_DIR}/samtools-1.12/samtools)"
  missing=1
fi

if command -v MethylDackel >/dev/null 2>&1; then
  echo "  [OK] MethylDackel (in PATH)"
elif [[ -x "${SOFT_DIR}/MethylDackel" ]]; then
  echo "  [OK] MethylDackel (${SOFT_DIR}/MethylDackel)"
else
  echo "  [MISSING] MethylDackel (PATH or ${SOFT_DIR}/MethylDackel)"
  missing=1
fi

if "$PYTHON_BIN" -c "import bsbolt" >/dev/null 2>&1; then
  echo "  [OK] Python module bsbolt"
else
  echo "  [MISSING] Python module bsbolt"
  missing=1
fi

if [[ "${CHECK_SCOPE}" == "full" ]]; then
  check_cmd bedtools "bedtools"
  # Tools referenced from scripts in ../soft
  check_file "${SOFT_DIR}/walt-master/bin/walt" "WALT"
  check_file "${SOFT_DIR}/bwa-meth-master/bwameth.py" "bwa-meth"
  check_file "${SOFT_DIR}/Bismark-0.22.3/bismark" "Bismark"
  check_file "${SOFT_DIR}/Bismark-0.22.3/bismark_genome_preparation" "bismark_genome_preparation"
  check_file "${SOFT_DIR}/bsmap-2.90/bsmap" "BSMAP"
  check_file "${SOFT_DIR}/BatMeth2/bin/BatMeth2" "BatMeth2"
  check_file "${SOFT_DIR}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py" "BSseeker2 align"
  check_file "${SOFT_DIR}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py" "BSseeker2 build"
  check_file "${SOFT_DIR}/bowtie2-2.3.5.1-linux-x86_64/bowtie2" "bowtie2"
  check_file "${SOFT_DIR}/bowtie-1.3.0-linux-x86_64/bowtie" "bowtie"
  check_file "${SOFT_DIR}/hisat2-2.1.0/hisat2" "hisat2"
  check_file "${SOFT_DIR}/hisat-3n/hisat-3n-build" "hisat-3n-build"
  check_file "${SOFT_DIR}/abismal-master/abismal" "abismal"
  check_file "${SOFT_DIR}/seqtk-master/seqtk" "seqtk"
  check_file "${SOFT_DIR}/sherman/Sherman" "Sherman"
fi
fi

if [[ "${CHECK_SCOPE}" == "full" || "${CHECK_SCOPE}" == "r" ]]; then
echo "Checking required R packages..."
check_cmd "$R_BIN" "Rscript"
"$R_BIN" -e "pkgs <- c('data.table','DSS','bsseq','ggplot2','pheatmap','ggpubr','RColorBrewer','stringr','VennDiagram','biomaRt','clusterProfiler','org.Hs.eg.db','org.Bt.eg.db','org.Ss.eg.db'); miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly=TRUE)]; if (length(miss)) { cat('[MISSING] R packages:', paste(miss, collapse=', '), '\n'); quit(status=1) } else { cat('[OK] R packages\n') }" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "  [OK] R package set"
else
  echo "  [MISSING] One or more required R packages"
  missing=1
fi
fi

if [[ "$missing" -ne 0 ]]; then
  printf "\nDependency check finished with missing items.\n"
  exit 1
fi

printf "\nAll checked dependencies are available.\n"
