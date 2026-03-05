#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/prepare_smoke_inputs_$(date +%Y%m%d_%H%M%S).log}"
exec > >(tee -a "${LOG_FILE}") 2>&1

SPECIES="${SPECIES:-human}"
SAMPLE="${SAMPLE:-SRR6373923}"
PYTHON3_BIN="${PYTHON3_BIN:-python3}"

DATA_DIR="${DATA_DIR:-${REPO_DIR}/data}"
INDEX_DIR="${INDEX_DIR:-${REPO_DIR}/index}"

TARGET_FASTQ_DIR="${DATA_DIR}/${SPECIES}/${SAMPLE}/cleandata"
TARGET_FASTQ1="${TARGET_FASTQ_DIR}/${SAMPLE}_clean_1.fastq.gz"
TARGET_FASTQ2="${TARGET_FASTQ_DIR}/${SAMPLE}_clean_2.fastq.gz"

TARGET_GENOME_FA="${INDEX_DIR}/${SPECIES}/hg38.fa"
TARGET_BSBOLT_DIR="${INDEX_DIR}/${SPECIES}/bsbolt"

# Input options:
# 1) Provide local files and avoid downloads
#    REFERENCE_FA=/path/to/hg38.fa
#    FASTQ1_SRC=/path/to/SRR6373923_1.fastq.gz
#    FASTQ2_SRC=/path/to/SRR6373923_2.fastq.gz
#
# 2) Let script download if missing (large downloads)
DOWNLOAD_REFERENCE="${DOWNLOAD_REFERENCE:-0}"
DOWNLOAD_FASTQ="${DOWNLOAD_FASTQ:-0}"
DOWNLOAD_FASTQ_MODE="${DOWNLOAD_FASTQ_MODE:-subset}" # subset | full
READ_PAIRS="${READ_PAIRS:-200000}"

REFERENCE_FA="${REFERENCE_FA:-}"
FASTQ1_SRC="${FASTQ1_SRC:-}"
FASTQ2_SRC="${FASTQ2_SRC:-}"
REFERENCE_PRESET="${REFERENCE_PRESET:-hg38}" # hg38 | chr22

REFERENCE_URL="${REFERENCE_URL:-https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz}"
FASTQ1_URL="${FASTQ1_URL:-https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR637/003/SRR6373923/SRR6373923_1.fastq.gz}"
FASTQ2_URL="${FASTQ2_URL:-https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR637/003/SRR6373923/SRR6373923_2.fastq.gz}"

FORCE_REINDEX="${FORCE_REINDEX:-0}"
RUN_PRECHECK="${RUN_PRECHECK:-1}"

if [[ "${SPECIES}" != "human" ]]; then
  echo "This helper currently prepares only SPECIES=human."
  exit 1
fi

echo "Log file: ${LOG_FILE}"
mkdir -p "${TARGET_FASTQ_DIR}" "${TARGET_BSBOLT_DIR}" "${INDEX_DIR}/${SPECIES}"

need_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
}

link_or_copy_file() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "${src}" ]]; then
    echo "Source file does not exist: ${src}"
    exit 1
  fi
  rm -f "${dst}"
  ln -s "${src}" "${dst}"
  echo "Linked ${dst} -> ${src}"
}

download_to_file() {
  local url="$1"
  local dst="$2"
  need_cmd curl
  echo "Downloading ${url}"
  curl -L --fail --retry 3 --retry-delay 2 -o "${dst}" "${url}"
}

download_fastq_subset() {
  local url="$1"
  local dst="$2"
  local lines=$(( READ_PAIRS * 4 ))
  need_cmd curl
  need_cmd gunzip
  need_cmd gzip
  echo "Streaming first ${READ_PAIRS} read pairs from ${url}"
  # In subset mode, head exits early by design; disable pipefail for this pipeline.
  set +o pipefail
  curl -L --fail --retry 3 --retry-delay 2 "${url}" \
    | gunzip -c \
    | head -n "${lines}" \
    | gzip -c > "${dst}"
  set -o pipefail
}

prepare_reference() {
  if [[ "${REFERENCE_PRESET}" == "chr22" ]]; then
    REFERENCE_URL="https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr22.fa.gz"
    echo "Using smoke reference preset: chr22 (saved as ${TARGET_GENOME_FA})"
  fi

  if [[ -f "${TARGET_GENOME_FA}" ]]; then
    echo "Reference already present: ${TARGET_GENOME_FA}"
    return
  fi

  if [[ -n "${REFERENCE_FA}" ]]; then
    link_or_copy_file "${REFERENCE_FA}" "${TARGET_GENOME_FA}"
    return
  fi

  if [[ "${DOWNLOAD_REFERENCE}" == "1" ]]; then
    local gz_path="${TARGET_GENOME_FA}.gz"
    download_to_file "${REFERENCE_URL}" "${gz_path}"
    need_cmd gunzip
    gunzip -f "${gz_path}"
    echo "Prepared reference: ${TARGET_GENOME_FA}"
    return
  fi

  echo "Missing reference FASTA for index build."
  echo "Provide REFERENCE_FA=/path/to/hg38.fa or set DOWNLOAD_REFERENCE=1."
  exit 1
}

prepare_fastq() {
  if [[ -f "${TARGET_FASTQ1}" && -f "${TARGET_FASTQ2}" ]]; then
    echo "FASTQ files already present in ${TARGET_FASTQ_DIR}"
    return
  fi

  if [[ -n "${FASTQ1_SRC}" || -n "${FASTQ2_SRC}" ]]; then
    if [[ -z "${FASTQ1_SRC}" || -z "${FASTQ2_SRC}" ]]; then
      echo "Set both FASTQ1_SRC and FASTQ2_SRC."
      exit 1
    fi
    link_or_copy_file "${FASTQ1_SRC}" "${TARGET_FASTQ1}"
    link_or_copy_file "${FASTQ2_SRC}" "${TARGET_FASTQ2}"
    return
  fi

  if [[ "${DOWNLOAD_FASTQ}" == "1" ]]; then
    if [[ "${DOWNLOAD_FASTQ_MODE}" == "subset" ]]; then
      download_fastq_subset "${FASTQ1_URL}" "${TARGET_FASTQ1}"
      download_fastq_subset "${FASTQ2_URL}" "${TARGET_FASTQ2}"
    elif [[ "${DOWNLOAD_FASTQ_MODE}" == "full" ]]; then
      download_to_file "${FASTQ1_URL}" "${TARGET_FASTQ1}"
      download_to_file "${FASTQ2_URL}" "${TARGET_FASTQ2}"
    else
      echo "Invalid DOWNLOAD_FASTQ_MODE='${DOWNLOAD_FASTQ_MODE}'. Use subset or full."
      exit 1
    fi
    echo "Downloaded FASTQs into ${TARGET_FASTQ_DIR}"
    return
  fi

  echo "Missing FASTQs for ${SAMPLE}."
  echo "Provide FASTQ1_SRC/FASTQ2_SRC or set DOWNLOAD_FASTQ=1."
  exit 1
}

build_bsbolt_index() {
  if [[ "${FORCE_REINDEX}" != "1" ]]; then
    if find "${TARGET_BSBOLT_DIR}" -type f | grep -q .; then
      echo "BSBolt index directory already has files: ${TARGET_BSBOLT_DIR}"
      return
    fi
  fi

  "${PYTHON3_BIN}" -c 'import bsbolt' >/dev/null 2>&1 || {
    echo "Python module bsbolt is not available for ${PYTHON3_BIN}"
    exit 1
  }

  echo "Building BSBolt index in ${TARGET_BSBOLT_DIR}"
  "${PYTHON3_BIN}" -m bsbolt Index \
    -G "${TARGET_GENOME_FA}" \
    -DB "${TARGET_BSBOLT_DIR}"
}

prepare_reference
prepare_fastq
build_bsbolt_index

if [[ "${RUN_PRECHECK}" == "1" ]]; then
  echo "Running smoke precheck..."
  "${REPO_DIR}/run_smoke_bsbolt.sh" || true
fi

echo "Done."
