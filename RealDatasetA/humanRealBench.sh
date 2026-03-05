#!/usr/bin/env bash

# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
indexDir="${INDEX_DIR:-${REPO_DIR}/index}"
softDir="${SOFT_DIR:-${REPO_DIR}/soft}"
realDataDir="${DATA_DIR:-${REPO_DIR}/data}"
resultDir="${RESULT_DIR:-${REPO_DIR}/result/realBench}"
realDataUniMapScript="${REALDATA_UNIMAP_SCRIPT:-${SCRIPT_DIR}/RealDataUniMap.py}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
SKIP_LOG="${SKIP_LOG:-${LOG_DIR}/humanRealBench_skip_$(date +%Y%m%d_%H%M%S).log}"

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
		bsbolt) ${PYTHON_BIN} -c "import bsbolt" >/dev/null 2>&1 ;;
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


MAPPERLIST=(bismarkbwt2 bismarkhis2 bsmap bwameth walt batmeth2 bsseeker2bt bsseeker2bt2end bsseeker2bt2loc bsseeker2soap hisat_3n hisat_3n_repeat bsbolt abismal) 
genome=hg38
species=human
readLen=150

sampleList=(SRR6818517 SRR6373926 SRR6373932)
if [[ -n "${SAMPLE_LIST:-}" ]]; then read -r -a sampleList <<< "${SAMPLE_LIST}"; fi


echo "map reads to ref genome using walt"
mapper=walt
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/walt-master/bin/walt -i ${indexDir}/${species}/${mapper}/${genome}.dbindex \
			-t 1 \
			-sam \
			-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
			-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
			-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using bwameth"
mapper=bwameth
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/bwa-meth-master/bwameth.py \
			--reference ${indexDir}/${species}/${mapper}/${genome}.fa \
			${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
			${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
			-t 1 \
			> ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi


echo "map reads to ref genome using bismarkbwt2"
mapper=bismarkbwt2
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/Bismark-0.22.3/bismark --path_to_bowtie2 ${softDir}/bowtie2-2.3.5.1-linux-x86_64 \
			--genome ${indexDir}/${species}/${mapper} \
			-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
			-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
			--sam \
			--temp_dir ${resultDir}/${species}/${sample}/${mapper}/temp \
			-o ${resultDir}/${species}/${sample}/${mapper}
		mv ${resultDir}/${species}/${sample}/${mapper}/${sample}_clean_readLen150_1_bismark_bt2_pe.sam \
			${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using bsmap"
mapper=bsmap
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/bsmap-2.90/bsmap -d ${indexDir}/${species}/${mapper}/${genome}.fa \
			-a ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
			-b ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
			-p 1 \
			-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using batmeth2"
mapper=batmeth2
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/BatMeth2/bin/BatMeth2 align \
		-g ${indexDir}/${species}/${mapper}/${genome}.fa \
		-p 1 \
		-of SAM \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-o realDataSample${sample}
	mv ./realDataSample${sample}.sam \
		${resultDir}/${species}/${sample}/${mapper}/
	mv realDataSample${sample}.run.log \
		${resultDir}/${species}/${sample}/${mapper}/
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi


echo "map reads to ref genome using bismarkhis2"
mapper=bismarkhis2
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/Bismark-0.22.3/bismark --hisat2 --genome ${indexDir}/${species}/${mapper} \
		--path_to_hisat2  ${softDir}/hisat2-2.1.0 \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq  \
		--sam \
		--temp_dir ${resultDir}/${species}/${sample}/${mapper}/temp \
		-o ${resultDir}/${species}/${sample}/${mapper}
	mv ${resultDir}/${species}/${sample}/${mapper}/${sample}_clean_readLen150_1_bismark_hisat2_pe.sam \
		${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam		
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi


echo "map reads to ref genome using bsseeker2bt"
mapper=bsseeker2bt
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	LD_PRELOAD=${softDir}/glibc-2.14/lib/libc-2.14.so \
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	python ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-g ${genome}.fa \
		-d ${indexDir}/${species}/${mapper} \
		-f sam \
		--bt-p 1 \
		--aligner=bowtie \
		-p ${softDir}/bowtie-1.3.0-linux-x86_64 \
		--temp_dir=${resultDir}/${species}/${sample}/${mapper}/ \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi


echo "map reads to ref genome using bsseeker2bt2end"
mapper=bsseeker2bt2end
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	python ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-g ${genome}.fa \
		-d ${indexDir}/${species}/bsseeker2bt2 \
		-f sam \
		--bt2-p 1 \
		--bt2--end-to-end \
		--aligner=bowtie2 \
		-p ${softDir}/bowtie2-2.3.4.3-linux-x86_64 \
		--temp_dir=${resultDir}/${species}/${sample}/${mapper}/ \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using bsseeker2bt2loc"
mapper=bsseeker2bt2loc
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	python ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-g ${genome}.fa \
		-d ${indexDir}/${species}/bsseeker2bt2 \
		-f sam \
		--bt2-p 1 \
		--aligner=bowtie2 \
		-p ${softDir}/bowtie2-2.3.4.3-linux-x86_64 \
		--temp_dir=${resultDir}/${species}/${sample}/${mapper}/ \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using bsseeker2soap"
mapper=bsseeker2soap
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	python ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-align.py \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-g ${genome}.fa \
		-d ${indexDir}/${species}/${mapper} \
		-f sam \
		--soap-p 1 \
		--soap-r 1 \
		--aligner=soap \
		-p ${softDir}/soap/2.21 \
		--temp_dir=${resultDir}/${species}/${sample}/${mapper}/ \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using hisat_3n"
mapper=hisat_3n
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/hisat-3n/hisat-3n -x ${indexDir}/${species}/${mapper}/${genome} \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-S ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-p 1 \
		--directional-mapping \
		--base-change C,T
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using hisat_3n_repeat"
mapper=hisat_3n_repeat
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/hisat-3n/hisat-3n -x ${indexDir}/${species}/${mapper}/${genome} \
		-1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-S ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-p 1 \
		--directional-mapping \
		--base-change C,T \
		--repeat
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using bsbolt"
mapper=bsbolt
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${PYTHON_BIN} -m bsbolt Align \
		-F1 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		-F2 ${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-DB ${indexDir}/${species}/${mapper}/ \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t 1
	${softDir}/samtools-1.12/bin/samtools view -h -@ 3 \
		${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.bam \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo "map reads to ref genome using abismal"
mapper=abismal
if mapper_enabled "$mapper"; then
for sample in "${sampleList[@]}"
do
	mkdir -p ${resultDir}/${species}/${sample}/${mapper}
	echo -e "mem\tRSS\trealTime\tcpusysTime\tcpuuserTime" >	${resultDir}/${species}/${sample}/${mapper}/Bench.csv
	/usr/bin/time -f "%K\t%M\t%E\t%S\t%U" -o ${resultDir}/${species}/${sample}/${mapper}/Bench.csv -a \
	${softDir}/abismal-3.0.0/bin/abismal \
		-i ${indexDir}/${species}/${mapper}/${genome}.abismalidx \
		-o ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_1.fastq \
		${realDataDir}/${species}/seedReadLen/${sample}_clean_readLen150_2.fastq \
		-t 1
	${PYTHON_BIN} ${realDataUniMapScript} \
		-i ${resultDir}/${species}/${sample}/${mapper}/realDataSample${sample}.sam \
		-t ${mapper} \
		-s ${species} \
		-d ${sample} \
		-l 0 \
		-r ${readLen} \
		-a 2000000 \
		-o ${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv
	awk '{if(NR==FNR){a[FNR]=$0;}else{print $0 "\t" a[FNR]}}' \
		${resultDir}/${species}/${sample}/${mapper}/Bench.csv \
		${resultDir}/${species}/${sample}/${mapper}/RealDataUniMap.csv \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv
	cat ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap1.csv \
		| sed -n 2p \
		> ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv
done
fi

echo -e "tool\tspecies\tdataName\tseedLen\treadLen\tcountMatchReads\tuniMapRate\tmem\tRSS\trealTime\tcpusysTime\tcpuuserTime" > ${resultDir}/${species}/${species}BenchRealDataUniMap.csv

for sample in "${sampleList[@]}"
do
	for mapper in "${MAPPERLIST[@]}"
	do
		if [[ -f "${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv" ]]; then
			cat "${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv" \
			>> "${resultDir}/${species}/${species}BenchRealDataUniMap.csv"
		else
			log_skip "${mapper}" "missing ${resultDir}/${species}/${sample}/${mapper}/BenchRealDataUniMap.csv during combine"
		fi
	done
done
