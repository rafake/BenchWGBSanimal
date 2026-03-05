#!/usr/bin/env bash
# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

indexDir="${INDEX_DIR:-${REPO_DIR}/index}"
softDir="${SOFT_DIR:-${REPO_DIR}/soft}"
realDataDir="${DATA_DIR:-${REPO_DIR}/data}"
resultDir="${RESULT_DIR:-${REPO_DIR}/result/realRes}"
script="${SCRIPT_HELPER_DIR:-${SCRIPT_DIR}}"
dataPath="${DATA_DIR:-${REPO_DIR}/data}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PYTHON3_BIN="${PYTHON3_BIN:-python3}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
SKIP_LOG="${SKIP_LOG:-${LOG_DIR}/mappedCattle_skip_$(date +%Y%m%d_%H%M%S).log}"

log_skip() {
	local mapper="$1"
	local reason="$2"
	echo "[SKIP] ${mapper}: ${reason}" | tee -a "${SKIP_LOG}"
}

mapper_runtime_available() {
	local mapper="$1"
	case "${mapper}" in
		walt) [[ -x "${softDir}/walt-master/bin/walt" ]] ;;
		bwameth) [[ -f "${softDir}/bwa-meth-master/bwameth.py" ]] ;;
		bismarkbwt2) [[ -x "${softDir}/Bismark-0.22.3/bismark" ]] && [[ -x "${softDir}/bowtie2-2.3.5.1-linux-x86_64/bowtie2" ]] ;;
		bsmap) [[ -x "${softDir}/bsmap-2.90/bsmap" ]] ;;
		bsbolt) "${PYTHON3_BIN}" -c "import bsbolt" >/dev/null 2>&1 ;;
		*) return 1 ;;
	esac
}

if [[ -z "${SAMTOOLS_BIN:-}" ]]; then
	if command -v samtools >/dev/null 2>&1; then
		SAMTOOLS_BIN="$(command -v samtools)"
	else
		SAMTOOLS_BIN="${softDir}/samtools-1.12/samtools"
	fi
fi

if [[ -z "${METHYLDACKEL_BIN:-}" ]]; then
	if command -v MethylDackel >/dev/null 2>&1; then
		METHYLDACKEL_BIN="$(command -v MethylDackel)"
	else
		METHYLDACKEL_BIN="${softDir}/MethylDackel"
	fi
fi


genome=bosTau9
species=cattle
genomeLen=2670422299

sampleList=(SRR7528450 SRR7528456 SRR7528458 SRR7528459 SRR7528464 SRR7528465)
if [[ -n "${SAMPLE_LIST:-}" ]]; then read -r -a sampleList <<< "${SAMPLE_LIST}"; fi

mapper_enabled() {
	local candidate="$1"
	if ! mapper_runtime_available "${candidate}"; then
		log_skip "${candidate}" "required tool(s) missing under PATH/SOFT_DIR"
		return 1
	fi
	if [[ -z "${MAPPER_LIST:-}" ]]; then
		return 0
	fi
	for selected in ${MAPPER_LIST}; do
		if [[ "${selected}" == "${candidate}" ]]; then
			return 0
		fi
	done
	return 1
}

if mapper_enabled "walt"; then
echo "map reads to ref genome using walt"
mapper=walt
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	${softDir}/walt-master/bin/walt -i ${indexDir}/${species}/${mapper}/${genome}.dbindex \
        -t 8 \
         -sam \
         -1 ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_1.fastq \
         -2 ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_2.fastq \
         -o ${resultDir}/${species}/${sample}/${mapper}/${sample}.sam \
         -a \
         -u
	samtools view -b -@ 8 ${resultDir}/${species}/${sample}/${mapper}/${sample}.sam -o ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}.sam
	${SAMTOOLS_BIN} sort -@ 10 ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam -o ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	${SAMTOOLS_BIN} index ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
	${METHYLDACKEL_BIN} extract -@ 8 ${indexDir}/${species}/${genome}.fa ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam -o ${resultDir}/${species}/${mapper}_${sample}
	${PYTHON_BIN} ${script}/prepareDSSinput.py -i ${resultDir}/${species}/${mapper}_${sample}_CpG.bedGraph -o ${resultDir}/${species}/${mapper}_${sample}_CpGofDSS.txt
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
done

fi

if mapper_enabled "bwameth"; then
echo "map reads to ref genome using bwameth"
mapper=bwameth
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	${softDir}/bwa-meth-master/bwameth.py \
       --reference ${indexDir}/${species}/${mapper}/${genome}.fa \
       ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_1.fastq \
       ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_2.fastq  \
       -t 8 \
       | samtools view -b - > \
       ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
  ${SAMTOOLS_BIN} sort -@ 10 ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam -o ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	${SAMTOOLS_BIN} index ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
	${METHYLDACKEL_BIN} extract -@ 8 ${indexDir}/${species}/${genome}.fa ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam -o ${resultDir}/${species}/${mapper}_${sample}
	${PYTHON_BIN} ${script}/prepareDSSinput.py -i ${resultDir}/${species}/${mapper}_${sample}_CpG.bedGraph -o ${resultDir}/${species}/${mapper}_${sample}_CpGofDSS.txt
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
done

fi

if mapper_enabled "bismarkbwt2"; then
echo "map reads to ref genome using bismarkbwt2"
mapper=bismarkbwt2
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	${softDir}/Bismark-0.22.3/bismark --path_to_bowtie2 ${softDir}/bowtie2-2.3.5.1-linux-x86_64 \
				--genome ${indexDir}/${species}/${mapper} \
        -1 ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_1.fastq \
        -2 ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_2.fastq \
        --multicore 8 \
				--temp_dir ${resultDir}/${species}/${sample}/${mapper}/temp \
        -o ${resultDir}/${species}/${sample}/${mapper}
  mv ${resultDir}/${species}/${sample}/${mapper}/${sample}_clean_1_bismark_bt2_pe.bam ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
  ${SAMTOOLS_BIN} sort -@ 10 ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam -o ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	${SAMTOOLS_BIN} index ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
	${METHYLDACKEL_BIN} extract -@ 8 ${indexDir}/${species}/${genome}.fa ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam -o ${resultDir}/${species}/${mapper}_${sample}
	${PYTHON_BIN} ${script}/prepareDSSinput.py -i ${resultDir}/${species}/${mapper}_${sample}_CpG.bedGraph -o ${resultDir}/${species}/${mapper}_${sample}_CpGofDSS.txt
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
done

fi

if mapper_enabled "bsmap"; then
echo "map reads to ref genome using bsmap"
mapper=bsmap
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	${softDir}/bsmap-2.90/bsmap -d ${indexDir}/${species}/${mapper}/${genome}.fa \
       -a ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_1.fastq \
       -b ${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_2.fastq \
       -p 8 \
       -o ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
  ${SAMTOOLS_BIN} sort -@ 10 ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam -o ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	${SAMTOOLS_BIN} index ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}.bam
	${METHYLDACKEL_BIN} extract -@ 8 ${indexDir}/${species}/${genome}.fa ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam -o ${resultDir}/${species}/${mapper}_${sample}
	${PYTHON_BIN} ${script}/prepareDSSinput.py -i ${resultDir}/${species}/${mapper}_${sample}_CpG.bedGraph -o ${resultDir}/${species}/${mapper}_${sample}_CpGofDSS.txt
	rm ${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam
done

fi

if mapper_enabled "bsbolt"; then
echo "map reads to ref genome using bsbolt"
mapper=bsbolt
for sample in "${sampleList[@]}"
do
	mkdir -p "${resultDir}/${species}/${sample}/${mapper}"
	"${PYTHON3_BIN}" -m bsbolt Align \
       -DB "${indexDir}/${species}/${mapper}/" \
       -F1 "${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_1.fastq.gz" \
       -F2 "${realDataDir}/${species}/${sample}/cleandata/${sample}_clean_2.fastq.gz" \
       -O "${resultDir}/${species}/${sample}/${mapper}/${sample}" \
       -t 8
  "${SAMTOOLS_BIN}" sort -@ 10 "${resultDir}/${species}/${sample}/${mapper}/${sample}.bam" -o "${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam"
	"${SAMTOOLS_BIN}" index "${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam"
	rm "${resultDir}/${species}/${sample}/${mapper}/${sample}.bam"
	"${METHYLDACKEL_BIN}" extract -@ 8 "${indexDir}/${species}/${genome}.fa" "${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam" -o "${resultDir}/${species}/${mapper}_${sample}"
	"${PYTHON_BIN}" "${script}/prepareDSSinput.py" -i "${resultDir}/${species}/${mapper}_${sample}_CpG.bedGraph" -o "${resultDir}/${species}/${mapper}_${sample}_CpGofDSS.txt"
	rm "${resultDir}/${species}/${sample}/${mapper}/${sample}_sort.bam"
done
fi
