#!/usr/bin/env Rscript

##===================
## script to create signed annotations for SLDP 
## with respect to input set of variants
##===================
library(data.table)
library(dplyr)
options(scipen = 10)
options(datatable.fread.datatable=FALSE)

## SNPs outside the given set of variants will be assigned this default value
NON_ANNOT_VAL <- -1 	# 0

args <- commandArgs(TRUE)
QTLFile <- as.character(args[1])
chrcol <- as.integer(args[2])
poscol <- as.integer(args[3])
VariantType <- as.character(args[4])
AnnotDir <- as.character(args[5])
RefSLDPAnnotDir <- as.character(args[6])

system(paste("mkdir -p", AnnotDir))

QTLData <- data.table::fread(QTLFile, header=T)
QTLData <- unique(QTLData[, c(chrcol, poscol)])
cat(sprintf("\n\n Input QTL file : %s -- number of unique entries : %s ", QTLFile, nrow(QTLData)))

chrlist <- as.vector(unique(QTLData[,1]))
for (i in 1:length(chrlist)) {
	currchr <- chrlist[i]
	chrnum <- gsub("chr", "", currchr)
	cat(sprintf("\n Processing chromosome : %s number : %s ", currchr, chrnum))

	## reference annotation file
	## 382 TFs from SLDP site
	RefAnnotFile_currchr <- paste0(RefSLDPAnnotDir, '/', chrnum, '.sannot.gz')
	if (file.exists(RefAnnotFile_currchr) == FALSE) {
		next
	}
	outfile <- paste0(AnnotDir, '/', chrnum, '.sannot')	
	if (file.exists(paste0(outfile, ".gz"))) {
		next
	}
	
	##========
	## read the eQTL / variants for the current chromosome
	QTLData_currchr <- QTLData[which(QTLData[,1] == currchr), ]
	cat(sprintf("\n Number of QTLs for this chromosome : %s ", nrow(QTLData_currchr)))
	## remove the "chr" string
	QTLData_currchr[,1] <- as.integer(gsub("chr", "", QTLData_currchr[,1]))
	## define eQTL annotation
	QTLData_currchr$NEWFIELD <- rep(1, nrow(QTLData_currchr))
	colnames(QTLData_currchr) <- c('CHR', 'BP', VariantType)

	##========
	## read the reference annotations for the current chromosome
	RefAnnotData <- data.table::fread(RefAnnotFile_currchr, header=T, sep="\t", stringsAsFactors=F, quote=F)
	RefAnnotData <- RefAnnotData[, c(1:3,5:6)]
	colnames(RefAnnotData) <- c('CHR', 'BP', 'SNP', 'A1', 'A2')

	##========
	## create the variant annotation (binary)
	AnnotDF <- dplyr::left_join(RefAnnotData, QTLData_currchr)
	idx <- which(is.na(AnnotDF[, ncol(AnnotDF)]))
	if (length(idx) > 0) {
		AnnotDF[idx, ncol(AnnotDF)] <- NON_ANNOT_VAL
		cat(sprintf("\n NA (non-matching bim file entries) : %s ", length(idx)))		
	}

	## only extract the fields SNP, A1, A2 and annotname
	## check https://github.com/yakirr/sldp/wiki/Preprocessing-instructions
	AnnotDF <- AnnotDF[, 3:ncol(AnnotDF)]

	## write the output annotations	
	write.table(AnnotDF, outfile, row.names=F, col.names=T, sep="\t", quote=F, append=F)
	system(paste("gzip", outfile))
}


