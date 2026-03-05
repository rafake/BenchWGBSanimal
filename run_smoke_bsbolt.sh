#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}" && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/run_smoke_bsbolt_$(date +%Y%m%d_%H%M%S).log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

SPECIES="${SPECIES:-human}"
SAMPLE="${SAMPLE:-SRR6373923}"
RESULT_DIR="${RESULT_DIR:-${REPO_DIR}/result/realRes}"
PYTHON3_BIN="${PYTHON3_BIN:-python3}"

echo "Log file: ${LOG_FILE}"

if [[ "${SPECIES}" != "human" && "${SPECIES}" != "cattle" && "${SPECIES}" != "pig" ]]; then
  echo "Unsupported SPECIES='${SPECIES}'. Use one of: human, cattle, pig"
  exit 1
fi

case "${SPECIES}" in
  human)
    RUN_SCRIPT="${REPO_DIR}/RealDatasetB/mappedHuman.sh"
    ;;
  cattle)
    RUN_SCRIPT="${REPO_DIR}/RealDatasetB/mappedCattle.sh"
    ;;
  pig)
    RUN_SCRIPT="${REPO_DIR}/RealDatasetB/mappedPig.sh"
    ;;
esac

DATA_R1="${REPO_DIR}/data/${SPECIES}/${SAMPLE}/cleandata/${SAMPLE}_clean_1.fastq.gz"
DATA_R2="${REPO_DIR}/data/${SPECIES}/${SAMPLE}/cleandata/${SAMPLE}_clean_2.fastq.gz"
INDEX_DIR="${REPO_DIR}/index/${SPECIES}/bsbolt"
SAMTOOLS_BIN="${SAMTOOLS_BIN:-}"
METHYLDACKEL_BIN="${METHYLDACKEL_BIN:-}"

if [[ -z "${SAMTOOLS_BIN}" ]]; then
  if command -v samtools >/dev/null 2>&1; then
    SAMTOOLS_BIN="$(command -v samtools)"
  else
    SAMTOOLS_BIN="${REPO_DIR}/soft/samtools-1.12/samtools"
  fi
fi

if [[ -z "${METHYLDACKEL_BIN}" ]]; then
  if command -v MethylDackel >/dev/null 2>&1; then
    METHYLDACKEL_BIN="$(command -v MethylDackel)"
  else
    METHYLDACKEL_BIN="${REPO_DIR}/soft/MethylDackel"
  fi
fi

missing=0

if ! "${PYTHON3_BIN}" -c 'import bsbolt' >/dev/null 2>&1; then
  echo "[MISSING] Python module bsbolt for ${PYTHON3_BIN}"
  missing=1
fi

if [[ ! -x "${SAMTOOLS_BIN}" ]]; then
  echo "[MISSING] ${SAMTOOLS_BIN}"
  missing=1
fi

if [[ ! -x "${METHYLDACKEL_BIN}" ]]; then
  echo "[MISSING] ${METHYLDACKEL_BIN}"
  missing=1
fi

if [[ ! -d "${INDEX_DIR}" ]]; then
  echo "[MISSING] ${INDEX_DIR}"
  missing=1
fi

if [[ ! -f "${DATA_R1}" || ! -f "${DATA_R2}" ]]; then
  echo "[MISSING] Input FASTQ(.gz) files for ${SPECIES}/${SAMPLE} under data/.../cleandata"
  missing=1
fi

if [[ "${missing}" -ne 0 ]]; then
  echo "Smoke precheck failed. Install/provide missing dependencies and rerun."
  exit 1
fi

echo "Smoke precheck OK. Running ${SPECIES} sample ${SAMPLE} with mapper=bsbolt..."

MAPPER_LIST="bsbolt" \
SAMPLE_LIST="${SAMPLE}" \
RESULT_DIR="${RESULT_DIR}" \
PYTHON3_BIN="${PYTHON3_BIN}" \
bash "${RUN_SCRIPT}"

echo "Smoke run completed."
