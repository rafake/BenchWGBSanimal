#!/usr/bin/env bash

# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
indexDir="${INDEX_DIR:-${REPO_DIR}/index}"
simudataDir="${SIM_DATA_DIR:-${REPO_DIR}/data/simudate/depth5}"
softDir="${SOFT_DIR:-${REPO_DIR}/soft}"
resultDir="${RESULT_DIR:-${REPO_DIR}/result/depth5}"
simuDataAccuScript="${SIMU_ACCU_SCRIPT:-${REPO_DIR}/SimulatedDatasetA/SimuDataAccuUni.py}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PYTHON3_BIN="${PYTHON3_BIN:-python3}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
SKIP_LOG="${SKIP_LOG:-${LOG_DIR}/mapSimulatedDataDepth5_skip_$(date +%Y%m%d_%H%M%S).log}"

log_skip() {
	local mapper="$1"
	local reason="$2"
	echo "[SKIP] ${mapper}: ${reason}" | tee -a "${SKIP_LOG}"
}

mapper_runtime_available() {
	local mapper="$1"
	case "${mapper}" in
		bwameth) [[ -f "${softDir}/bwa-meth-master/bwameth.py" ]] ;;
		bsmap) [[ -x "${softDir}/bsmap-2.90/bsmap" ]] ;;
		walt) [[ -x "${softDir}/walt-master/bin/walt" ]] ;;
		bismarkbwt2) [[ -x "${softDir}/Bismark-0.22.3/bismark" ]] && [[ -x "${softDir}/bowtie2-2.3.5.1-linux-x86_64/bowtie2" ]] ;;
		bsbolt) "${PYTHON3_BIN}" -c "import bsbolt" >/dev/null 2>&1 ;;
		*) return 1 ;;
	esac
}



speciesList=(human cattle pig)
genomeList=(hg38 bosTau9 susScr11)
errorRateList=(0 1)
numList=(1 2 3)


for i in "${!speciesList[@]}"
do
	for errorRate in "${errorRateList[@]}"
	do
		echo "map reads to ref genome using bwameth"
		mapper=bwameth
		if mapper_runtime_available "${mapper}"; then
		for num in "${numList[@]}"
		do
		mkdir -p ${resultDir}/${speciesList[$i]}${num}/${mapper}
			${softDir}/bwa-meth-master/bwameth.py \
				--reference ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.fa \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_1.fastq \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_2.fastq \
				-t 8 \
				> ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
			${PYTHON_BIN} ${simuDataAccuScript} \
				-i ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/SimuDataAccuUni${errorRate}.csv
			samtools view -b -@ 8 ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam -o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.bam
			rm ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
		done
		else
			log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		fi

		echo "map reads to ref genome using bsmap"
		mapper=bsmap
		if mapper_runtime_available "${mapper}"; then
		for num in "${numList[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}${num}/${mapper}
			${softDir}/bsmap-2.90/bsmap -d ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.fa \
				-a ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_1.fastq \
				-b ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_2.fastq \
				-p 8 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
			${PYTHON_BIN} ${simuDataAccuScript} \
				-i ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/SimuDataAccuUni${errorRate}.csv
			samtools view -b -@ 8 ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam -o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.bam
			rm ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
		done
		else
			log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		fi

		echo "map reads to ref genome using walt"
		mapper=walt
		if mapper_runtime_available "${mapper}"; then
		for num in "${numList[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}${num}/${mapper}
			${softDir}/walt-master/bin/walt -i ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.dbindex \
				-t 8 \
				-sam \
				-a \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_2.fastq \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
			${PYTHON_BIN} ${simuDataAccuScript} \
				-i ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/SimuDataAccuUni${errorRate}.csv
			samtools view -b -@ 8 ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam -o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.bam
			rm ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
		done
		else
			log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		fi


		echo "map reads to ref genome using bismarkbwt2"
		mapper=bismarkbwt2
		if mapper_runtime_available "${mapper}"; then
		for num in "${numList[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}${num}/${mapper}
			${softDir}/Bismark-0.22.3/bismark --path_to_bowtie2 ${softDir}/bowtie2-2.3.5.1-linux-x86_64 \
				--genome ${indexDir}/${speciesList[$i]}/${mapper} \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_2.fastq \
				--sam \
				--ambiguous \
				--temp_dir ${resultDir}/${speciesList[$i]}${num}/${mapper}/temp \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}
			mv ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}_1_bismark_bt2_pe.sam \
				${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
			${PYTHON_BIN} ${simuDataAccuScript} \
				-i ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/SimuDataAccuUni${errorRate}.csv
			samtools view -b -@ 3 ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam -o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.bam
			rm ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
		done
		else
			log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		fi

			echo "map reads to ref genome using bsbolt"
			mapper=bsbolt
		if mapper_runtime_available "${mapper}"; then
		for num in "${numList[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}${num}/${mapper}
			${PYTHON3_BIN} -m bsbolt Align \
				-F1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_1.fastq \
				-F2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate}Depth5Num${num}_2.fastq \
				-DB ${indexDir}/${speciesList[$i]}/${mapper}/ \
				-O ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num} \
				-t 8
			${softDir}/samtools-1.12/bin/samtools view -h -@ 4 \
				${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.bam \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
			${PYTHON_BIN} ${simuDataAccuScript} \
				-i ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}${num}/${mapper}/SimuDataAccuUni${errorRate}.csv
			rm ${resultDir}/${speciesList[$i]}${num}/${mapper}/simulatedErrRates${errorRate}Depth5Num${num}.sam
		done
		else
			log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		fi
	done
done
