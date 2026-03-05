#!/usr/bin/env bash

# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
indexDir="${INDEX_DIR:-${REPO_DIR}/index}"
simudataDir="${SIM_DATA_DIR:-${REPO_DIR}/data/simudate}"
softDir="${SOFT_DIR:-${REPO_DIR}/soft}"
resultDir="${RESULT_DIR:-${REPO_DIR}/result/bench}"
scriptDir="${SCRIPT_HELPER_DIR:-${SCRIPT_DIR}}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
SKIP_LOG="${SKIP_LOG:-${LOG_DIR}/mappedTwoMillionSimData_skip_$(date +%Y%m%d_%H%M%S).log}"

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
		batmeth2) [[ -x "${softDir}/BatMeth2/bin/BatMeth2" ]] ;;
		bismarkhis2) [[ -x "${softDir}/Bismark-0.22.3/bismark" ]] && [[ -x "${softDir}/hisat2-2.1.0/hisat2" ]] ;;
		bsseeker2bt) [[ -f "${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py" ]] && [[ -x "${softDir}/bowtie-1.3.0-linux-x86_64/bowtie" ]] ;;
		bsseeker2bt2end|bsseeker2bt2loc) [[ -f "${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py" ]] && [[ -x "${softDir}/bowtie2-2.3.4.3-linux-x86_64/bowtie2" ]] ;;
		bsseeker2soap) [[ -f "${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py" ]] && [[ -x "${softDir}/soap/2.21" ]] ;;
		hisat_3n|hisat_3n_repeat) [[ -x "${softDir}/hisat-3n/hisat-3n" ]] ;;
		bsbolt) ${PYTHON3_BIN:-$PYTHON_BIN} -c "import bsbolt" >/dev/null 2>&1 ;;
		abismal) [[ -x "${softDir}/abismal-3.0.0/bin/abismal" ]] ;;
		*) return 1 ;;
	esac
}

mapper_enabled() {
	local mapper="$1"
	if ! mapper_runtime_available "${mapper}"; then
		log_skip "${mapper}" "required tool(s) missing under PATH/SOFT_DIR"
		return 1
	fi
	return 0
}
PYTHON3_BIN="${PYTHON3_BIN:-python3}"



speciesList=(human cattle pig)
genomeList=(hg38 bosTau9 susScr11)

for i in "${!speciesList[@]}"
do
	MAPPERLIST=(bismarkbwt2 bismarkhis2 bsmap bwameth walt batmeth2 bsseeker2bt bsseeker2bt2end bsseeker2bt2loc bsseeker2soap hisat_3n hisat_3n_repeat bsbolt abismal) 
	ERRORRATE=(0 0.25 0.5 0.75 1)
	sampleDuplicationList=(1 2 3)

	for Num in "${sampleDuplicationList[@]}"
	do
		mkdir -p ${resultDir}/${speciesList[$i]}
		echo "map reads to ref genome using walt"
		mapper=walt
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/walt-master/bin/walt -i ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.dbindex \
				-t 1 \
				-sam \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam          
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using batmeth2"
		mapper=batmeth2
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do	
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/BatMeth2/bin/BatMeth2 align \
				-g ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.fa \
				-p 1 \
				-of SAM \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-o simulatedErrRates${errorRate//./}Num${Num}
				mv ./simulatedErrRates${errorRate//./}Num${Num}.sam \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/
			mv ./simulatedErrRates${errorRate//./}Num${Num}.run.log \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/	          
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bwameth"
		mapper=bwameth
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/bwa-meth-master/bwameth.py \
				--reference ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.fa \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-t 1 \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bismarkbwt2"
		mapper=bismarkbwt2
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/Bismark-0.22.3/bismark --path_to_bowtie2 ${softDir}/bowtie2-2.3.5.1-linux-x86_64 \
				--genome ${indexDir}/${speciesList[$i]}/${mapper} \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				--sam \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/temp \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			mv ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}_1_bismark_bt2_pe.sam \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bismarkhis2"
		mapper=bismarkhis2
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/Bismark-0.22.3/bismark --hisat2 --genome ${indexDir}/${speciesList[$i]}/${mapper} \
				--path_to_hisat2  ${softDir}/hisat2-2.1.0 \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq  \
				--sam \
				--temp_dir ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/temp \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper} 
			mv ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}_1_bismark_hisat2_pe.sam \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam		
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi


		echo "map reads to ref genome using bsseeker2bt"
		mapper=bsseeker2bt
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			LD_PRELOAD=${softDir}/glibc-2.14/lib/libc-2.14.so \
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-g ${genomeList[$i]}.fa \
				-d ${indexDir}/${speciesList[$i]}/${mapper} \
				-f sam \
				--bt-p 1 \
				--aligner=bowtie \
				-p ${softDir}/bowtie-1.3.0-linux-x86_64 \
				--temp_dir=${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/ \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi


		echo "map reads to ref genome using bsseeker2bt2end"
		mapper=bsseeker2bt2end
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-g ${genomeList[$i]}.fa \
				-d ${indexDir}/${speciesList[$i]}/bsseeker2bt2 \
				-f sam \
				--bt2-p 1 \
				--bt2--end-to-end \
				--aligner=bowtie2 \
				-p ${softDir}/bowtie2-2.3.4.3-linux-x86_64 \
				--temp_dir=${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/ \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bsseeker2bt2loc"
		mapper=bsseeker2bt2loc
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-g ${genomeList[$i]}.fa \
				-d ${indexDir}/${speciesList[$i]}/bsseeker2bt2 \
				-f sam \
				--bt2-p 1 \
				--aligner=bowtie2 \
				-p ${softDir}/bowtie2-2.3.4.3-linux-x86_64 \
				--temp_dir=${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/ \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bsseeker2soap"
		mapper=bsseeker2soap
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-g ${genomeList[$i]}.fa \
				-d ${indexDir}/${speciesList[$i]}/${mapper} \
				-f sam \
				--soap-p 1 \
				--soap-r 1 \
				--aligner=soap \
				-p ${softDir}/soap/2.21 \
				--temp_dir=${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/ \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using bsmap"
		mapper=bsmap
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/bsmap-2.90/bsmap -d ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.fa \
				-a ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-b ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-p 1 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam  	
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi
		
		echo "map reads to ref genome using hisat_3n"
		mapper=hisat_3n
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/hisat-3n/hisat-3n -x ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]} \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-S ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-p 1 \
				--directional-mapping \
				--base-change C,T			
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo "map reads to ref genome using hisat_3n_repeat"
		mapper=hisat_3n_repeat
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/hisat-3n/hisat-3n -x ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]} \
				-1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-S ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-p 1 \
				--directional-mapping \
				--base-change C,T \
				--repeat
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi
		
		echo "map reads to ref genome using bsbolt"
		mapper=bsbolt
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${PYTHON3_BIN} -m bsbolt Align \
				-F1 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				-F2 ${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-DB ${indexDir}/${speciesList[$i]}/${mapper}/ \
				-O ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num} \
				-t 1
			samtools view -h ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.bam \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi
		
		echo "map reads to ref genome using abismal"
		mapper=abismal
		if mapper_enabled "$mapper"; then
		for errorRate in "${ERRORRATE[@]}"
		do
			mkdir -p ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}
			echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv
			/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv -a \
			${softDir}/abismal-3.0.0/bin/abismal \
				-i ${indexDir}/${speciesList[$i]}/${mapper}/${genomeList[$i]}.abismalidx \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_1.fastq \
				${simudataDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}_2.fastq \
				-t 1
			${PYTHON_BIN} ${scriptDir}/SimuDataAccuUni.py \
				-i ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/simulatedErrRates${errorRate//./}Num${Num}.sam \
				-t ${mapper} \
				-s ${speciesList[$i]} \
				-e ${errorRate} \
				-l 0 \
				-r 150 \
				-o ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv
			awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/Bench.csv \
				${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/SimuDataAccuUni.csv \
				> ${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapper}/BenchSimuDataAccuUni.csv
		done
		fi

		echo -e "mapper\tspecies\terrorRate\tseedLength\treadLength\tmacroAvgPrecision\tmacroAvgRecall\tmacroF1Score\tmicroAvgPrecision\tmicroAvgRecall\tmicroF1Score\tavgAccuracy\tmatchedReads\tmem\tRSS\trealTime\tcpusysTime\tcpuuserTime" > ${resultDir}/${speciesList[$i]}/${speciesList[$i]}BenchSimuDataAccuUniConbine${Num}.csv
		for errorRate in "${ERRORRATE[@]}"
		do
			for mapperlist in "${MAPPERLIST[@]}"
			do
				if [[ -f "${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapperlist}/BenchSimuDataAccuUni.csv" ]]; then
					cat "${resultDir}/${speciesList[$i]}/simulatedErrRates${errorRate//./}Num${Num}/${mapperlist}/BenchSimuDataAccuUni.csv" \
					| sed -n 2p \
					>> "${resultDir}/${speciesList[$i]}/${speciesList[$i]}BenchSimuDataAccuUniConbine${Num}.csv"
				else
					log_skip "${mapperlist}" "missing BenchSimuDataAccuUni.csv for errorRate=${errorRate} Num=${Num} during combine"
				fi
			done
		done
	done
done
