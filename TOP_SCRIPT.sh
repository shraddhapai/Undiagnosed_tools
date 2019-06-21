#!/bin/bash

# Script that annotates a patient VCF file by integrating with data sources
# Produces a table of SNP annotations and a list of significant genes

# patient VCF file
vcfFile=/root/notebooks/patient-data/WGS/DeepVariant_VCFs/SQ9887_L00.reheader.vcf.gz
# directory where all output files generated by this script are stored
outDir=/root/annot/outdir 
# directory with all processed annotation sources
annoDir=/root/annot/annot_sources ### dir with annotation files


mkdir -p $outDir

# annotation sources
dbSNP=${annoDir}/dbsnp151.chr1-22_X_Y.bed.sorted.bed
eQTLfile=${annoDir}/GTEx_Analysis_v7_eQTL/gut.sigeqtls.txt  
opFile=${annoDir}/gut.op.chrom.bed  
clinVar=${annoDir}/clinvar.bed
GWAShits=${annoDir}/GWAShits.tmp

# --------------------------------------------------------

baseF=`basename $vcfFile .vcf`
outPfx=${outDir}/${baseF}
snpBedFile=${outDir}/${baseF}_rsID.bed
vcfBedSorted=${outPfx}.sorted.bed

# Annotate vcf file with rsIDs
echo "* Map SNP to rsIDs"
zcat $vcfFile | grep -v \# | awk 'BEGIN {OFS="\t";}{print "chr"$1,$2-1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' > ${outPfx}.bed
echo -e "\tSort SNP bed file"
sort -k1,1 -k2,2n -k3,3n ${outPfx}.bed > $vcfBedSorted

echo -e "\tMap to rsID"
bedtools intersect -wa -wb -a $vcfBedSorted -b $dbSNP > $snpBedFile

echo ""
echo  "* Intersect snp with open chromatin in gut tissue"
bedtools intersect -wa -wb -a $snpBedFile -b $opFile | cut -f12-19 > ${snpBedFile}.openchrom.txt

echo  "* Intersect with gut eQTLs"
bedtools intersect -wa -wb -a $snpBedFile -b $eQTLfile | cut -f 12-15,20-21 | uniq >  ${snpBedFile}.eQTL.txt

echo  "Combine sources"
final_table=${outDir}/final_table.txt
Rscript final_join.R $snpBedFile $clinVar $GWAShits ${snpBedFile}.openchrom.txt ${snpBedFile}.eQTL.txt $final_table

echo  "Prepare output"
cat $final_table  | awk '{ if ($8 < 0.00000005){print}}' > ${outDir}/GWASsignificant.txt
cat $final_table  | awk '{ if ($8 < 0.00000005){print}}' | awk '{print $4"_"$7}' | sort | uniq > ${outDir}/GWASsignificant_genes.unique.txt