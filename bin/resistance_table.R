samples <- list.dirs(path = "results/",recursive = FALSE, full.names = FALSE)

dat.out <- data.frame(BactNummer = samples, Resistance = NA)

myres <-list()
for(i in 1:length(samples)){
  myres <- read.delim(file = paste0("results/",samples[i],"/4_virulence/",samples[i],"_resistance.tab"))[,c("GENE","X.COVERAGE","X.IDENTITY")]
  
  if(nrow(myres) > 0){
    for(j in 1:nrow(myres)){
      myres[j,"out"] <- if(myres[j,2] == "100"){
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

#library(DT)
#datatable(dat.out,rownames = FALSE)

write.table(x = dat.out,file = "resistances.txt",sep = "\t",row.names = FALSE, quote=FALSE)
