#!/bin/bash

usage(){
cat << EOF

Options:
   	-C  ConfigFile		Name of the configuration file storing the parameters.
EOF
}

while getopts "C:" opt;
do
	case "$opt" in
		C) ConfigFile=$OPTARG;;
		\?) usage
			echo "error: unrecognized option -$OPTARG";
			exit 1
			;;
	esac
done

echo -e "\n\n ================ Parsing input configuration file ================= \n\n"

# separator used in the config file
IFS="="
while read -r name value
do
	param=$name
	paramval=${value//\"/}
	if [[ -n $param ]]; then
		if [[ $param != \#* ]]; then
			# if there are multiple parameter values (separated by # - old values are kept)
			# then the following operation selects the current one
			paramval=$(echo "$paramval" | awk -F['#\t'] '{print $1}' | tr -d '[:space:]');
			echo -e "Content of $param is $paramval"
			if [ $param == "DataDir" ]; then
				DATADIR=$paramval
			fi
			if [ $param == "InpGWASFile" ]; then
				InpGWASFile=$paramval
			fi
			if [ $param == "GWASsamplesize" ]; then
				GWASsamplesize=$paramval
			fi			
			# if [ $param == "GWASSumStatsFile" ]; then
			# 	GWASSumStatsFile=$paramval
			# fi						
			if [ $param == "LDSCCodeDir" ]; then
				LDSCCodeDir=$paramval
			fi
			if [ $param == "OutDir" ]; then
				BaseOutDir=$paramval
			fi
			if [ $param == "GWASTraitName" ]; then
				GWASTraitName=$paramval
			fi
			if [ $param == "A1IncAllele" ]; then
				A1IncAllele=$paramval
			fi
			if [ $param == "VariantType" ]; then
				VariantType=$paramval
			fi
			if [ $param == "QTLFile" ]; then
				QTLFile=$paramval
			fi
			if [ $param == "chrcol" ]; then
				chrcol=$paramval
			fi
			if [ $param == "poscol" ]; then
				poscol=$paramval
			fi
		fi
	fi
done < $ConfigFile

## identify the directory containing this script
currworkdir=`pwd`
echo 'currworkdir : '$currworkdir

currscriptdir=`dirname $0`
cd $currscriptdir
echo 'currscriptdir : '$currscriptdir

## create the base output directory
mkdir -p $BaseOutDir

## create the data output directory
mkdir -p $DATADIR

PythonExec=`which python2`
echo 'PythonExec : '$PythonExec

RScriptExec=`which Rscript`
echo 'RScriptExec : '$RScriptExec

##================================
## step 1: download the reference LD score data
## Downloading reference LD score datasets, SNPs, etc. from the web repository of the developer group.
## From the link: https://alkesgroup.broadinstitute.org/SLDP/
## as suggested in the GitHub page
## https://github.com/yakirr/sldp
##================================

cd $DATADIR

## download the SNP list from the LDSC repository
inpfile='w_hm3.snplist'
if [[ ! -f $inpfile ]]; then
	wget https://storage.googleapis.com/broad-alkesgroup-public/LDSCORE/w_hm3.snplist.bz2
	bunzip2 w_hm3.snplist.bz2
fi

inpfile='pickrell_ldblocks.hg19.eur.bed'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/refpanel/pickrell_ldblocks.hg19.eur.bed --no-check-certificate
fi

inpfile='KG3.tar.gz'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/refpanel/KG3.tar.gz --no-check-certificate
	tar -xzf KG3.tar.gz
fi

inpfile='KG3.hm3.tar.gz'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/refpanel/KG3.hm3.tar.gz --no-check-certificate
	tar -xzf KG3.hm3.tar.gz
fi

inpfile='svds_95percent.tar'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/refpanel/svds_95percent.tar --no-check-certificate
	tar -xf svds_95percent.tar 
fi

inpfile='LDscore.tar.gz'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/refpanel/LDscore.tar.gz --no-check-certificate
	tar -xzf LDscore.tar.gz
fi

inpfile='maf5.tar.gz'
if [[ ! -f $inpfile ]]; then
	wget https://data.broadinstitute.org/alkesgroup/SLDP/background/maf5.tar.gz --no-check-certificate
	tar -xzf maf5.tar.gz
fi

## directory to download a reference signed functional annotations from SLDP package
## and merge all such reference annotations
RefGWASDir=$DATADIR'/Ref_Signed_Functional_Annotations_MERGED'
mkdir -p $RefGWASDir
filecnt=`ls -l ${RefGWASDir}/*.sannot.gz | wc -l`
if [[ $filecnt -lt 22 ]]; then
	## the merged reference annotations are not present
	## so, first download the individual datasets
	## and then merge all those annotations
	tempRefGWASDir=$DATADIR'/Ref_Signed_Functional_Annotations_TEMP'
	mkdir -p $tempRefGWASDir
	cd $tempRefGWASDir
	wget https://storage.googleapis.com/broad-alkesgroup-public/SLDP/annots/basset.tar --no-check-certificate
	tar -xf basset.tar
	## extract all TF specific signed score archieves
	## we process 10 files at a time - using the "mapfile" concept
	## https://stackoverflow.com/questions/68124740/iterate-over-a-fixed-number-of-files-with-bash-shell
	# for ff in `find $tempRefGWASDir -maxdepth 1 -type f -name "*.tar.gz"`; do
	find "$tempRefGWASDir" -maxdepth 1 -type f -name "*.tar.gz" -print0 |
		# Map a list of maximum ten files
		while mapfile -n 10 files_per_ten && [ ${#files_per_ten[@]} -gt 0 ]; do
			# Iterate indexes in the list
			for ff in "${files_per_ten[@]}"; do
				bf=$(basename ${ff})
				echo 'processing file : '$ff
				echo 'basename : '$bf
				onlydirname="${bf%.*.*}"
				echo 'onlydirname : '$onlydirname
				outdir=$tempRefGWASDir'/'$onlydirname
				mkdir -p $outdir
				tar -xzf $ff -C $outdir'/'
			done
			# Wait all background tasks
    		wait			
		done

	## merge all the annotations in the final file
	Rscript $currscriptdir'/Merge_Annot.R' $tempRefGWASDir $RefGWASDir

	## delete the temporary directory
	rm -r $tempRefGWASDir
fi

## return to the current script directory
cd $currscriptdir


##================================
## step 2: Convert the GWAS summary statistics to the S-LDSC compatible .sumstats format
## we assume that input GWAS summary statistics is provided in hg19 reference genome
## required for computing LDSC
## check https://github.com/bulik/ldsc/wiki/Summary-Statistics-File-Format
##================================

## code to convert summary statistics into .sumstats format
## provided in LDSC GitHub package
GWAASSumstatCodeExec=$LDSCCodeDir'/munge_sumstats.py'

## directory which will store the converted .sumstats file
SumStatsDir=$BaseOutDir'/GWAS_sumstats/'$GWASTraitName
mkdir -p $SumStatsDir
GWASSumstatsoutprefix=$SumStatsDir'/'$GWASTraitName

## reference SNPList downloaded from the LDSC repository (step 1)
SNPListFile=$DATADIR'/w_hm3.snplist'

GWASSumStatsFile=$GWASSumstatsoutprefix'.sumstats.gz'

## if the GWASSumStatsFile is not provided 
## then compute the sumstats formatted GWAS summary file
if [[ ! -f $GWASSumStatsFile ]]; then

	if [[ $A1IncAllele == 1 ]]; then
		if [[ $GWASsamplesize != "" ]]; then
			## sample size is not present in the GWAS input file
			## to be provided explicitly
			${PythonExec} ${GWAASSumstatCodeExec} --sumstats ${InpGWASFile} --merge-alleles ${SNPListFile} --out ${GWASSumstatsoutprefix} --a1-inc --N ${GWASsamplesize}
		else
			${PythonExec} ${GWAASSumstatCodeExec} --sumstats ${InpGWASFile} --merge-alleles ${SNPListFile} --out ${GWASSumstatsoutprefix} --a1-inc
		fi
	else
		if [[ $GWASsamplesize != "" ]]; then
			## sample size is not present in the GWAS input file
			## to be provided explicitly
			${PythonExec} ${GWAASSumstatCodeExec} --sumstats ${InpGWASFile} --merge-alleles ${SNPListFile} --out ${GWASSumstatsoutprefix} --N ${GWASsamplesize}
		else
			${PythonExec} ${GWAASSumstatCodeExec} --sumstats ${InpGWASFile} --merge-alleles ${SNPListFile} --out ${GWASSumstatsoutprefix}
		fi
	fi
fi


##================================
## step 3: preprocess the GWAS summary statistics (in the .sumstats.gz format)
## to convert it into SLDP compatible format
## use the "preprocesspheno" routine from SLDP package.
##================================

## we can also parallelize over individual chromosomes by adding the parameter "--chroms i" for i'th chromosome
for chrnum in {1..22}; do
	if [[ ! -f ${GWASSumstatsoutprefix}'.KG3.95/'$chrnum'.pss.gz' ]]; then	
		preprocesspheno --sumstats-stem ${GWASSumstatsoutprefix} --refpanel-name KG3.95 --svd-stem ${DATADIR}/svds_95percent/ --print-snps ${DATADIR}/1000G_hm3_noMHC.rsid --ldscores-chr ${DATADIR}/LDscore/LDscore. --ld-blocks ${DATADIR}/pickrell_ldblocks.hg19.eur.bed --bfile-chr ${DATADIR}/plink_files/1000G.EUR.QC. --chroms $chrnum
	fi
done

##================================
## step 4: use the input eQTL / variant file 
## and define the signed annotations
## currently, we use binary annotations - means, eQTLs are 1, all others are 0 (or we can try with -1)
##================================
cd $currscriptdir
echo 'before making QTL annotations - current working directory : '`pwd`

QTLAnnotDir=$BaseOutDir'/QTL_Annotation/'$VariantType
mkdir -p $QTLAnnotDir

## use the SNPs provided in the $DATADIR'/maf5' folder
## to define the annotations
## here we test with binary annotations
## SNPs overlapping with the current eQTL / variant set: 1
## all other SNPs are -1
filecnt=`ls -l ${QTLAnnotDir}/*.sannot.gz | wc -l`
if [[ $filecnt -lt 22 ]]; then
	$RScriptExec ${currscriptdir}/Make_input_QTL_Annotations.R $QTLFile $chrcol $poscol $VariantType $QTLAnnotDir $DATADIR'/maf5'
fi

##================================
## step 5: create signed LD profile
## corresponding to the input set of variants
## check https://github.com/yakirr/sldp/wiki/Preprocessing-instructions
## section Preprocessing signed functional annotations
##================================

## we can also parallelize over individual chromosomes by adding the parameter "--chroms i" for i'th chromosome
for chrnum in {1..22}; do
	if [[ ! -f $QTLAnnotDir'/'$chrnum'.RV.gz' ]]; then	
		preprocessannot --sannot-chr $QTLAnnotDir'/' --bfile-chr $DATADIR'/plink_files/1000G.EUR.QC.' --print-snps $DATADIR'/1000G_hm3_noMHC.rsid' --ld-blocks $DATADIR'/pickrell_ldblocks.hg19.eur.bed' --chroms $chrnum
	fi
done

##================================
## run sldp on our data
##================================

## create the output directory
## for the current GWAS and QTL input
CurrOutDir=$BaseOutDir'/'$VariantType'/'$GWASTraitName
mkdir -p $CurrOutDir

sldp --pss-chr ${GWASSumstatsoutprefix}.KG3.95/ --sannot-chr ${QTLAnnotDir}/ --background-sannot-chr ${DATADIR}/maf5/ --outfile-stem ${CurrOutDir}/${GWASTraitName}_${VariantType} --ld-blocks ${DATADIR}/pickrell_ldblocks.hg19.eur.bed --svd-stem ${DATADIR}/svds_95percent/ --bfile-reg-chr ${DATADIR}/plink_files/1000G.EUR.QC.hm3_noMHC. --seed 0

##===========
## now go back to the original working directory
##===========
cd $currworkdir
echo 'Thank you !! SLDP is executed.'

