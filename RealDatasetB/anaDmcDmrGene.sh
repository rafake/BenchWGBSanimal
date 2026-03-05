#!/usr/bin/env bash
# Configurable local paths; override via env vars if needed.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
resultDir="${RESULT_DIR:-${REPO_DIR}/result/realRes}"
script="${SCRIPT_HELPER_DIR:-${SCRIPT_DIR}}"
annoFilePath="${ANNO_DIR:-${REPO_DIR}/annotation}"
PYTHON_BIN="${PYTHON_BIN:-python3}"


speciesList=(human cattle pig)
for species in "${speciesList[@]}"
do
	## the analysis of DMC
	${PYTHON_BIN} ${script}/dmcAnalysis3.py \
		-a ${resultDir}/${species}/dssRes2/bismarkbwt2_DML.txt \
		-b ${resultDir}/${species}/dssRes2/bsmap_DML.txt \
		-c ${resultDir}/${species}/dssRes2/bwameth_DML.txt \
		-d ${resultDir}/${species}/dssRes2/walt_DML.txt \
		-o ${resultDir}/${species}/dmcRes/ \
		-r ${annoFilePath}/${species}/${species}rmskchr.bed \
		-cg ${annoFilePath}/${species}/CGIandNonCGI.bed

	## the analysis of DMR
	${PYTHON_BIN} ${script}/dmrAna.py \
		-a ${resultDir}/${species}/dssRes2/bismarkbwt2_DMR.txt \
		-b ${resultDir}/${species}/dssRes2/bsmap_DMR.txt \
		-c ${resultDir}/${species}/dssRes2/bwameth_DMR.txt \
		-d ${resultDir}/${species}/dssRes2/walt_DMR.txt \
		-o ${resultDir}/${species}/dmr/${species} \
		-r ${annoFilePath}/${species}/${species}rmskchr.bed \
		-cg ${annoFilePath}/${species}/CGIandNonCGI.bed

	## the analysis of DMR-related gene
	mapperList=(bismarkbwt2 bsmap bwameth walt)
	for mapper in "${mapperList[@]}"
	do
		${PYTHON_BIN} ${script}/textToBedDmr.py -i ${resultDir}/${species}/dssRes2/${mapper}_DMR.txt -o ${resultDir}/${species}/dssRes2/${mapper}_DMR.bed
		bedtools intersect -a ${annoFilePath}/${species}/${species}GeneCoo.bed -b ${resultDir}/${species}/dssRes2/${mapper}_DMR.bed -wao > ${resultDir}/${species}/gene/${mapper}_gene_DMR.txt
		${PYTHON_BIN} ${script}/geneRelaDmr.py -i ${resultDir}/${species}/gene/${mapper}_gene_DMR.txt -o ${resultDir}/${species}/gene/${mapper}_gene_DMR_Res.txt
	done
	${PYTHON_BIN} ${script}/geneVenn.py \
		-a ${resultDir}/${species}/gene/bismarkbwt2_gene_DMR_Res.txt \
		-b ${resultDir}/${species}/gene/bsmap_gene_DMR_Res.txt \
		-c ${resultDir}/${species}/gene/bwameth_gene_DMR_Res.txt \
		-d ${resultDir}/${species}/gene/walt_gene_DMR_Res.txt \
		-o ${resultDir}/${species}/gene/gene_DMR_Venn_report.txt
	
	## the analysis of signaling pathway in KEGG
	${PYTHON_BIN} ${script}/keggVenn.py \
		-a ${resultDir}/${species}/kegg/${species}_bismarkbwt2_enrichKEGG_depth10.txt \
		-b ${resultDir}/${species}/kegg/${species}_bsmap_enrichKEGG_depth10.txt \
		-c ${resultDir}/${species}/kegg/${species}_bwameth_enrichKEGG_depth10.txt \
		-d ${resultDir}/${species}/kegg/${species}_walt_enrichKEGG_depth10.txt \
		-o ${resultDir}/${species}/kegg/${species}_kegg_venn.txt
done

