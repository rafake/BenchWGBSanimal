#!/usr/bin/env bash
# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
indexDir="${INDEX_DIR:-${REPO_DIR}/index}"
softDir="${SOFT_DIR:-${REPO_DIR}/soft}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PYTHON3_BIN="${PYTHON3_BIN:-python3}"
LOG_DIR="${LOG_DIR:-${REPO_DIR}/logs}"
mkdir -p "${LOG_DIR}"
SKIP_LOG="${SKIP_LOG:-${LOG_DIR}/indexFa_skip_$(date +%Y%m%d_%H%M%S).log}"

log_skip() {
	local step="$1"
	local reason="$2"
	echo "[SKIP] ${step}: ${reason}" | tee -a "${SKIP_LOG}"
}

run_or_skip() {
	local step="$1"
	local check_cmd="$2"
	shift 2
	if eval "${check_cmd}"; then
		echo "run ${step}"
		"$@"
	else
		log_skip "${step}" "required tool(s) missing under PATH/SOFT_DIR"
	fi
}


speciesList=(human cattle pig)
genomeList=(hg38 bosTau9 susScr11)

for i in "${!speciesList[@]}"
do
	MAPPERLIST=(bismarkbwt2 bismarkhis2 bsmap bwameth walt batmeth2 bsseeker2bt bsseeker2bt2 bsseeker2soap hisat_3n hisat_3n_repeat bsbolt abismal)
	#creat folder of index
	for mapper in "${MAPPERLIST[@]}"
	do
		mkdir -p ${indexDir}/${speciesList[$i]}/${mapper}
		ln -s ${indexDir}/${speciesList[$i]}/${genomeList[$i]}.fa ${indexDir}/${speciesList[$i]}/${mapper}
	done

	run_or_skip "bismarkbwt2 index" "[[ -x \"${softDir}/Bismark-0.22.3/bismark_genome_preparation\" ]] && [[ -x \"${softDir}/bowtie2-2.3.5.1-linux-x86_64/bowtie2\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bismarkbwt2/${genomeList[$i]}.fa\" ]]" \
	${softDir}/Bismark-0.22.3/bismark_genome_preparation \
            --bowtie2 --path_to_aligner ${softDir}/bowtie2-2.3.5.1-linux-x86_64 \
             ${indexDir}/${speciesList[$i]}/bismarkbwt2

	run_or_skip "bismarkhis2 index" "[[ -x \"${softDir}/Bismark-0.22.3/bismark_genome_preparation\" ]] && [[ -x \"${softDir}/hisat2-2.1.0/hisat2\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bismarkhis2/${genomeList[$i]}.fa\" ]]" \
	${softDir}/Bismark-0.22.3/bismark_genome_preparation \
             --hisat2 --path_to_aligner ${softDir}/hisat2-2.1.0 \
             ${indexDir}/${speciesList[$i]}/bismarkhis2

	run_or_skip "bwameth index" "[[ -f \"${softDir}/bwa-meth-master/bwameth.py\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bwameth/${genomeList[$i]}.fa\" ]]" \
	${softDir}/bwa-meth-master/bwameth.py index \
	${indexDir}/${speciesList[$i]}/bwameth/${genomeList[$i]}.fa

	run_or_skip "walt index" "[[ -x \"${softDir}/walt-master/bin/makedb\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/walt/${genomeList[$i]}.fa\" ]]" \
	${softDir}/walt-master/bin/makedb \
             -c ${indexDir}/${speciesList[$i]}/walt/${genomeList[$i]}.fa \
             -o ${indexDir}/${speciesList[$i]}/walt/${genomeList[$i]}.dbindex

	run_or_skip "batmeth2 index" "[[ -x \"${softDir}/BatMeth2/bin/BatMeth2\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/batmeth2/${genomeList[$i]}.fa\" ]]" \
	${softDir}/BatMeth2/bin/BatMeth2 build_index \
	${indexDir}/${speciesList[$i]}/batmeth2/${genomeList[$i]}.fa

	run_or_skip "bsseeker2bt index" "[[ -f \"${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py\" ]] && [[ -x \"${softDir}/bowtie-1.3.0-linux-x86_64/bowtie\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bsseeker2bt/${genomeList[$i]}.fa\" ]]" \
	env LD_PRELOAD=${softDir}/glibc-2.14/lib/libc-2.14.so \
	${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py \
      -f ${indexDir}/${speciesList[$i]}/bsseeker2bt/${genomeList[$i]}.fa \
      --aligner=bowtie \
      -p ${softDir}/bowtie-1.3.0-linux-x86_64 \
      -d ${indexDir}/${speciesList[$i]}/bsseeker2bt
      
	run_or_skip "bsseeker2bt2 index" "[[ -f \"${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py\" ]] && [[ -x \"${softDir}/bowtie2-2.3.4.3-linux-x86_64/bowtie2\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bsseeker2bt2/${genomeList[$i]}.fa\" ]]" \
	${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py \
      -f ${indexDir}/${speciesList[$i]}/bsseeker2bt2/${genomeList[$i]}.fa \
      --aligner=bowtie2 \
      -p ${softDir}/bowtie2-2.3.4.3-linux-x86_64 \
      -d ${indexDir}/${speciesList[$i]}/bsseeker2bt2
      
	run_or_skip "bsseeker2soap index" "[[ -f \"${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py\" ]] && [[ -x \"${softDir}/soap/2.21\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/bsseeker2soap/${genomeList[$i]}.fa\" ]]" \
	${PYTHON_BIN} ${softDir}/BSseeker2-BSseeker2-v2.1.8/bs_seeker2-build.py \
      -f ${indexDir}/${speciesList[$i]}/bsseeker2soap/${genomeList[$i]}.fa  \
      --aligner=soap \
      -p ${softDir}/soap/2.21 \
      -d ${indexDir}/${speciesList[$i]}/bsseeker2soap
  
  run_or_skip "hisat_3n index" "[[ -x \"${softDir}/hisat-3n/hisat-3n-build\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/hisat_3n/${genomeList[$i]}.fa\" ]]" \
  ${softDir}/hisat-3n/hisat-3n-build \
      --base-change C,T \
      ${indexDir}/${speciesList[$i]}/hisat_3n/${genomeList[$i]}.fa \
      ${indexDir}/${speciesList[$i]}/hisat_3n/${genomeList[$i]}
  
  run_or_skip "hisat_3n_repeat index" "[[ -x \"${softDir}/hisat-3n/hisat-3n-build\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/hisat_3n_repeat/${genomeList[$i]}.fa\" ]]" \
  ${softDir}/hisat-3n/hisat-3n-build \
      --base-change T,C \
      --repeat-index ${indexDir}/${speciesList[$i]}/hisat_3n_repeat/${genomeList[$i]}.fa \
      ${indexDir}/${speciesList[$i]}/hisat_3n_repeat/${genomeList[$i]}
  
  run_or_skip "bsbolt index" "${PYTHON3_BIN} -c 'import bsbolt' >/dev/null 2>&1 && [[ -f \"${indexDir}/${speciesList[$i]}/bsbolt/${genomeList[$i]}.fa\" ]]" \
  ${PYTHON3_BIN} -m bsbolt \
      Index -G ${indexDir}/${speciesList[$i]}/bsbolt/${genomeList[$i]}.fa \
      -DB ${indexDir}/${speciesList[$i]}/bsbolt/
  
  run_or_skip "abismal index" "[[ -x \"${softDir}/abismal-3.0.0/bin/abismalidx\" ]] && [[ -f \"${indexDir}/${speciesList[$i]}/abismal/${genomeList[$i]}.fa\" ]]" \
  ${softDir}/abismal-3.0.0/bin/abismalidx \
      ${indexDir}/${speciesList[$i]}/abismal/${genomeList[$i]}.fa \
      ${indexDir}/${speciesList[$i]}/abismal/${genomeList[$i]}.abismalidx
done
