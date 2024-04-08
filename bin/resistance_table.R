samples <- list.dirs(path = "results/",recursive = FALSE, full.names = FALSE)

dat.out <- data.frame(BactNummer = samples, Resistance = NA)

myres <-list()
for(i in 1:length(samples)){
  # Iterate through all samples and look for resistance.tab file
  fn <- paste0("results/",samples[i],"/4_virulence/",samples[i],"_resistance.tab")
  # If it exists, pull out resistance genes, if not, say "Not Screened"
  if(file.exists(fn)) {
    myres <- read.delim(file = fn)[,c("GENE","X.COVERAGE","X.IDENTITY")]
  } else {
    myres <- data.frame("GENE" = "Not Screened", "X.COVERAGE"=100, "X.IDENTITY"=100)
  }
  
  if(nrow(myres) > 0){
    # Only include genes with coverage 100
    for(j in 1:nrow(myres)){
      myres[j,"out"] <- if(myres[j,2] == "100"){
        # If identity is 100, just include gene name, otherwise add % identity
        if(myres[j,3] == "100"){
          as.character(myres[j,1])
        }else{
          sprintf("%s (%s%%)",myres[j,1],myres[j,3])
        }
      }else{next}
    }
    dat.out[which(dat.out$BactNummer == samples[i]), "Resistance"] <- paste(na.omit(myres$out), collapse = "; ")
  }else{
    dat.out[which(dat.out$BactNummer == samples[i]), "Resistance"] <- NA
  }
}

write.table(x = dat.out,file = "resistances.txt",sep = "\t",row.names = FALSE, quote=FALSE)