# SLDP (signed LD profile regression)


Enrichment of a given set of SNPs with respect to their 
directional effect of a signed functional annotation on a heritable trait using GWAS summary statistics. 

Sourya Bhattacharyya

La Jolla Institute for Immunology, La Jolla, CA 92037, USA


----------------------

Objectives
============

Implements a wrapper for the Signed LD profile regression package (https://github.com/yakirr/sldp), to estimate the enrichment of a set of QTLs (variants) with respect to their directional effect of a signed functional annotation on a heritable trait using GWAS summary statistics. 


Reference genome
==================

Currently the package supports GWAS files with respect to the reference genome hg19 
(as mentioned in the original Stratified LD score regression package ldsc)

For GWAS files with hg38 reference genome configuration, users are requested to first use 
the liftover tool (https://genome.ucsc.edu/cgi-bin/hgLiftOver) to convert the genomic coordinates 
from hg38 to hg19.


Installation
=============

	1. Use python 2.7.* 

	2. Run "pip install sldp" to install sldp package.

	3. Download the source code of "ldsc" from GitHub (https://github.com/bulik/ldsc). 

		- Path of this downloaded source code (containing the python and bash scripts of this package) needs to be provided as a configuration parameter (check the parameter *LDSCCodeDir*)	

	4. Install these R (version > 3.6.1) libraries: data.table, dplyr, GenomicRanges, gridExtra


Configuration
================

First edit the configuration file *configfile_SNP*. The parameters are mentioned below:

	DataDir=
		- Directory where SLDP related datasets will be downloaded.

	LDSCCodeDir=
		- Directory containing the downloaded "ldsc" GitHub code.

	OutDir=
		- Base directory to store the output results.
		- Output directory for the current QTL and GWAS summary statistics would be *OutDir*/*VariantType*/*GWASTraitName* 

	QTLFile=
		- File containing input QTLs (like eQTLs) whose enrichment to be computed.

	VariantType=
		- Name / type of variant - a string

	chrcol=
		- column containing the chromosome name in the input eQTL / variant file

	poscol=
		- column containing the SNP position in the input eQTL / variant file
		- User needs to make sure that the position is with respect to hg19 coordinates

	InpGWASFile=
		- Input GWAS file 
		- Currently GWAS SNPs with hg19 coordinates are supported
		- for hg38 based GWAS files, we will convert the GWAS to hg19 coordinates using liftover tool

	GWASsamplesize=
		- Integer value
		- check if the GWAS input file has sample size (N) column.
		- *if the sample size column is not present in the GWAS summary file*, use this parameter to provide a sample size (check the GWAS catalog and the corresponding study / publication to retrieve the sample size)
		- *if GWAS summary statistics contains a sample size column*, keep this parameter as blank

	GWASTraitName=
		- Name of the GWAS trait - a string

	A1IncAllele=
		- set to 1 if in the GWAS Summary statistics, A1 is the increasing allele
		- Default = 0


Execution
==========

	1. First edit the configuration file as per the mentioned parameters.
	2. Then, edit the sample script *qsub_SLDP_job.sh* and execute.



Output
========

	- With respect to the specified output directory (parameter *OutDir*), check the file *\*.results*

		- Following fields are important:

			1. *z* : z-score.
			2. *p* : p-value. p-value < 0.05 (at least) is required to label the corresponding annotation significant for the given trait.
			3. *rf* : effect size. Positive effect size together with significant p-values determine the importance of the current annotation with respect to the given trait.


Contact
==========

For any queries, please create an issue and we'll respond. Otherwise, please e-mail

Sourya Bhattacharyya: sourya@lji.org

Ferhat Ay: ferhatay@lji.org


