#!/usr/bin/env Rscript

library(data.table)
library(dplyr)
options(scipen = 10)
options(datatable.fread.datatable=FALSE)

args <- commandArgs(trailingOnly = TRUE)
baseinpdir <- args[1]
outdir <- args[2]

## list of output data frames
OutDataList <- list()

bool_DF <- FALSE

ddlist <- list.dirs(path=baseinpdir, full.names=TRUE, recursive=FALSE)
for (i in 1:length(ddlist)) {
	inpdir <- ddlist[i]
	if (file.exists(paste0(inpdir, '/1.sannot.gz')) == FALSE) {
		next
	}
	cat(sprintf("\n\n\n ==>>> processing directory : %s number : %s ", inpdir, i))
	for (chrnum in seq(1,22)) {
		inpfile <- paste0(inpdir, '/', chrnum, '.sannot.gz')
		inpdata <- data.table::fread(inpfile, header=T)
		if (bool_DF == FALSE) {
			OutDataList[[chrnum]] <- inpdata			
		} else {
			OutDataList[[chrnum]] <- dplyr::full_join(inpdata, OutDataList[[chrnum]])
		}
		cat(sprintf(" --- chr : %s entries : %s ", chrnum, nrow(OutDataList[[chrnum]])))
	}
	bool_DF <- TRUE
}

for (chrnum in seq(1,22)) {
	outfile <- paste0(outdir, '/', chrnum, '.sannot')
	OutDataList[[chrnum]][is.na(OutDataList[[chrnum]])] <- 0
	write.table(OutDataList[[chrnum]], outfile, row.names=F, col.names=T, sep="\t", quote=F, append=F)	
	system(paste("gzip", outfile))
}

