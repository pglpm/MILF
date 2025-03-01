## Author: Battistin, Gonzalo Cogno, Porta Mana
## Last-Updated: 2020-11-26T11:54:48+0100
################
## Script for:
## - outputting samples of prior & posterior distributions
## - calculating posteriors
## Uses Dirichlet prior
################

#### Custom setup ####
## For colour-blind friendly palettes, from https://personal.sron.nl/~pault/
## (consider using khroma package instead)
library('RColorBrewer')

mypurpleblue <- '#4477AA'
myblue <- '#66CCEE'
mygreen <- '#228833'
myyellow <- '#CCBB44'
myred <- '#EE6677'
myredpurple <- '#AA3377'
mygrey <- '#BBBBBB'
mypalette <- c(myblue, myred, mygreen, myyellow, myredpurple, mypurpleblue, mygrey, 'black')
palette(mypalette)
barpalette <- colorRampPalette(c(mypurpleblue,'white',myredpurple),space='Lab')
barpalettepos <- colorRampPalette(c('white','black'),space='Lab')
#dev.off()
####
library('ggplot2')
#library('cowplot')
library('png')
#library('plot3D')
library('foreach')
library('LaplacesDemon') # used for Dirichlet generator
#library('RNetCDF')
#library('Rmpfr')
#library('rgl')
options(bitmapType='cairo')
pdff <- function(filename){pdf(file=paste0(filename,'.pdf'),paper='a4r',height=11.7,width=16.5)} # to output in pdf format
#### End custom setup ####

#######################################
#### FUNCTION TO CALCULATE MUTUAL INFO FROM FREQUENCY PAIRS
## freqs[,S] = response freqs for stimulus S: one column per stimulus
## assumes all stimuli equally probable
mutualinfo <- function(freqs,base=2){##in bits
    stimulusFreqs <- 1/ncol(freqs)
    jointFreqs <- freqs * stimulusFreqs
    responseFreqs <- rowSums(jointFreqs)
    sum(jointFreqs *
        log2(jointFreqs/outer(responseFreqs,rep(stimulusFreqs,ncol(freqs)))),
        na.rm=TRUE)/log2(base)
}


#######################################
#### MAIN FUNCTION TO PLOT SAMPLES, GEOMETRIC BASE DISTR. ####
plotSuperdistrSamplesGeom <- function(dataFiles=NULL, # NULL to plot prior samples
                                  baseWeight=10,
                                  plotTitle,
                                  pdfName,
                                  meanSpikes=0.2, # 5Hz * (40Hz/1000s)
                                  maxSpikes=15,
                                  rootNumSamples=32 # rootNumSamples^2 samples
                                  ){
#### Code for plotting prior or posterior samples ####
    set.seed(149)
    stimulusNames <- c('N', 'S')
    baseDistr <- foreach(i=0:maxSpikes, .combine=c)%do%{dgeom(x=i, prob=1/(meanSpikes+1), log=FALSE)}
    baseDistr <- baseDistr/sum(baseDistr)
    ##
#### Read data and update Dirichlet parameters
    if(length(dataFiles) < 2){# no datafiles are given - plots for prior
        numStimuli <- 2
        sampleFreqs <- foreach(i=1:numStimuli, .combine=cbind)%do%{
            data <- integer(maxSpikes+1)}
        ## mutual info from observed data
        miData <- NA
    } else {# datafiles are given - plots for posterior
        numStimuli <- length(dataFiles)
        sampleFreqs <- foreach(i=1:numStimuli, .combine=cbind)%do%{
            data <- integer(maxSpikes+1)
            fileData <- unlist(read.csv(dataFiles[i],header=FALSE,sep=','))
            data[1:length(fileData)] <- fileData
            data}
        ## mutual info from observed data
        miData <- mutualinfo(t(t(sampleFreqs)/colSums(sampleFreqs)))
    }
    rownames(sampleFreqs) <- paste0(0:maxSpikes,'-counts')
    colnames(sampleFreqs) <- stimulusNames
    ##
    postAlphas <- baseWeight * baseDistr + sampleFreqs
    ## samples: list, 1 item per stimulus; 1 row per spike count, 1 column per sample
    samplePairs <- lapply(1:numStimuli, function(x){
        t(rdirichlet(n=rootNumSamples^2, alpha=postAlphas[,x]))}
        )
#### calculation of mutual info of samples
    miSamples <- foreach(i=1:rootNumSamples^2, .combine=c)%do%{
        mutualinfo(cbind(samplePairs[[1]][,i], samplePairs[[2]][,i]))
    }
    miDistr <- hist(miSamples, breaks=seq(0,1,by=0.02), plot=FALSE)
    miQuantiles <- quantile(x=miSamples, probs=c(0.025,0.5,0.975))
    ##
#### Plots of samples and long-run mutual-info distribution
    rg <- 0:maxSpikes
    ##
    pdff(paste0(pdfName, baseWeight))
    ## Plot of mutual-info prob. distribution
    xmids <- barplot(height=miDistr$density, names.arg=miDistr$mids,
                     ylab='probability density', xlab='long-run mutual info')
    ## add vertical quantile lines and text
    rb <- (xmids[length(xmids)]-xmids[1])/(miDistr$mids[length(miDistr$mids)]-miDistr$mids[1])
    ra <- xmids[1]-rb*miDistr$mids[1]
    for(q in miQuantiles){
        matlines(x=rep(q*rb+ra,2),y=c(-1,1/2)*max(miDistr$density), lty=2, lwd=3, col=mygreen)
    }
    text(x=50, y=max(miDistr$density), labels=paste0('(green dashed)\n2.5%, 50%, 97.5%\n',paste(signif(miQuantiles,3),collapse=', ')),
         adj=c(1,1), cex=1.5)
    ## If this is the posterior case, add line with mutual info of sample
    if(length(dataFiles) >= 2){
        matlines(x=rep(miData*rb+ra,2),y=c(-1,1/2)*max(miDistr$density), lty=1, lwd=4, col='black')
        text(x=50, y=max(miDistr$density)*0.8, labels=paste0('(black solid)\nMI of sampled data = ', signif(miData,3)),
             adj=c(1,1), cex=1.5)
    }
    title(paste0(plotTitle, baseWeight))
    ## Overlappig plot of samples
    ## alternate samples from the two inputs for balanced transparency    
    sample <- cbind(samplePairs[[1]], -samplePairs[[2]])
    sample <- sample[, c(matrix(1:ncol(sample), nrow = 2, byrow = TRUE))] # https://stackoverflow.com/a/18861411/6090141
    matplot(x=rg, y=sample, type='p', pch=NA, cex=0.5,
            col='#000000', ylim=c(-1,1),
            xlab='spike count', ylab='long-run frequency')
    lineStretch <- c(-1, 1) * 0.45
    for(i in rg){# hack to create longer lines
        matlines(x=i+lineStretch, y=rbind(sample[i+1,],sample[i+1,]), type='l', lty=1, lwd=1, col=c('#4477AA22','#EE667722')) 
    }
    ## Distinct plots of samples
    par(mar=c(1,1,1,1)*0.3, mfrow=c(rootNumSamples, rootNumSamples)) # prepare grid
    for(i in 1:rootNumSamples^2){
        barplot(samplePairs[[1]][1:11,i], ylim=c(-1,1), col=mypurpleblue, border=NA,
                axes=FALSE)
        barplot(-samplePairs[[2]][1:11,i], ylim=c(-1,1), col=myred, border=NA,
                axes=FALSE, add=TRUE)
    }
    ##
    dev.off()
                                        #    cbind(test,miDistr$mids)
}
#######################################



#### Calls to plot function ####

#### prior
plotSuperdistrSamplesGeom(dataFiles=NULL,
                      baseWeight=0.1,
                      plotTitle='Prior. Base distr: geometric with mean spike count = 5 Hz. Base weight = ',
                      pdfName='prior_samplepairs_geom-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )

#### posterior, all bins
plotSuperdistrSamplesGeom(dataFiles=c('HistogramSpikeCounts_north.csv', 'HistogramSpikeCounts_south.csv'),
                      baseWeight=0.1,
                      plotTitle='Posterior, all bins. Base distr: geometric with mean spike count = 5 Hz. Base weight = ',
                      pdfName='posterior_allbins_samplepairs_geom-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )

#### posterior, 20 bins
test <- plotSuperdistrSamplesGeom(dataFiles=c('HistogramSpikeCounts_north_20TimeBins.csv', 'HistogramSpikeCounts_south_20TimeBins.csv'),
                      baseWeight=0.1,
                      plotTitle='Posterior, 20 bins. Base distr: geometric with mean spike count = 5 Hz. Base weight = ',
                      pdfName='posterior_20bins_samplepairs_geom-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )




#######################################
#### MAIN FUNCTION TO PLOT SAMPLES, UNIFORM BASE DISTR. ####
plotSuperdistrSamplesUnif <- function(dataFiles=NULL, # NULL to plot prior samples
                                  baseWeight=10,
                                  plotTitle,
                                  pdfName,
                                  meanSpikes=0.2, # 5Hz * (40ms/1000s)
                                  maxSpikes=15,
                                  rootNumSamples=32 # rootNumSamples^2 samples
                                  ){
#### Code for plotting prior or posterior samples ####
    set.seed(149)
    stimulusNames <- c('N', 'S')
    baseDistr <- foreach(i=0:maxSpikes, .combine=c)%do%{1/(maxSpikes+1)}
    ##baseDistr <- foreach(i=0:maxSpikes, .combine=c)%do%{dgeom(x=i, prob=1/(meanSpikes+1), log=FALSE)}
    baseDistr <- baseDistr/sum(baseDistr)
    ##
#### Read data and update Dirichlet parameters
    if(length(dataFiles) < 2){# no datafiles are given - plots for prior
        numStimuli <- 2
        sampleFreqs <- foreach(i=1:numStimuli, .combine=cbind)%do%{
            data <- integer(maxSpikes+1)}
        ## mutual info from observed data
        miData <- NA
    } else {# datafiles are given - plots for posterior
        numStimuli <- length(dataFiles)
        sampleFreqs <- foreach(i=1:numStimuli, .combine=cbind)%do%{
            data <- integer(maxSpikes+1)
            fileData <- unlist(read.csv(dataFiles[i],header=FALSE,sep=','))
            data[1:length(fileData)] <- fileData
            data}
        ## mutual info from observed data
        miData <- mutualinfo(t(t(sampleFreqs)/colSums(sampleFreqs)))
    }
    rownames(sampleFreqs) <- paste0(0:maxSpikes,'-counts')
    colnames(sampleFreqs) <- stimulusNames
    ##
    postAlphas <- baseWeight * baseDistr + sampleFreqs
    ## samples: list, 1 item per stimulus; 1 row per spike count, 1 column per sample
    samplePairs <- lapply(1:numStimuli, function(x){
        t(rdirichlet(n=rootNumSamples^2, alpha=postAlphas[,x]))}
        )
#### calculation of mutual info of samples
    miSamples <- foreach(i=1:rootNumSamples^2, .combine=c)%do%{
        mutualinfo(cbind(samplePairs[[1]][,i], samplePairs[[2]][,i]))
    }
    miDistr <- hist(miSamples, breaks=seq(0,1,by=0.02), plot=FALSE)
    miQuantiles <- quantile(x=miSamples, probs=c(0.025,0.5,0.975))
    ##
#### Plots of samples and long-run mutual-info distribution
    rg <- 0:maxSpikes
    ##
    pdff(paste0(pdfName, baseWeight))
    ## Plot of mutual-info prob. distribution
    xmids <- barplot(height=miDistr$density, names.arg=miDistr$mids,
                     ylab='probability density', xlab='long-run mutual info')
    ## add vertical quantile lines and text
    rb <- (xmids[length(xmids)]-xmids[1])/(miDistr$mids[length(miDistr$mids)]-miDistr$mids[1])
    ra <- xmids[1]-rb*miDistr$mids[1]
    for(q in miQuantiles){
        matlines(x=rep(q*rb+ra,2),y=c(-1,1/2)*max(miDistr$density), lty=2, lwd=3, col=mygreen)
    }
    text(x=50, y=max(miDistr$density), labels=paste0('(green dashed)\n2.5%, 50%, 97.5%\n',paste(signif(miQuantiles,3),collapse=', ')),
         adj=c(1,1), cex=1.5)
    ## If this is the posterior case, add line with mutual info of sample
    if(length(dataFiles) >= 2){
        matlines(x=rep(miData*rb+ra,2),y=c(-1,1/2)*max(miDistr$density), lty=1, lwd=4, col='black')
        text(x=50, y=max(miDistr$density)*0.8, labels=paste0('(black solid)\nMI of sampled data = ', signif(miData,3)),
             adj=c(1,1), cex=1.5)
    }
    title(paste0(plotTitle, baseWeight))
    ## Overlappig plot of samples
    ## alternate samples from the two inputs for balanced transparency    
    sample <- cbind(samplePairs[[1]], -samplePairs[[2]])
    sample <- sample[, c(matrix(1:ncol(sample), nrow = 2, byrow = TRUE))] # https://stackoverflow.com/a/18861411/6090141
    matplot(x=rg, y=sample, type='p', pch=NA, cex=0.5,
            col='#000000', ylim=c(-1,1),
            xlab='spike count', ylab='long-run frequency')
    lineStretch <- c(-1, 1) * 0.45
    for(i in rg){# hack to create longer lines
        matlines(x=i+lineStretch, y=rbind(sample[i+1,],sample[i+1,]), type='l', lty=1, lwd=1, col=c('#4477AA22','#EE667722')) 
    }
    ## Distinct plots of samples
    par(mar=c(1,1,1,1)*0.3, mfrow=c(rootNumSamples, rootNumSamples)) # prepare grid
    for(i in 1:rootNumSamples^2){
        barplot(samplePairs[[1]][1:11,i], ylim=c(-1,1), col=mypurpleblue, border=NA,
                axes=FALSE)
        barplot(-samplePairs[[2]][1:11,i], ylim=c(-1,1), col=myred, border=NA,
                axes=FALSE, add=TRUE)
    }
    ##
    dev.off()
                                        #    cbind(test,miDistr$mids)
}
#######################################


#### Calls to plot function ####

plotSuperdistrSamplesUnif(dataFiles=NULL,
                      baseWeight=0.1,
                      plotTitle='Prior. Base distr: uniform. Base weight = ',
                      pdfName='prior_samplepairs_unif-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )

#### posterior, all bins
plotSuperdistrSamplesUnif(dataFiles=c('HistogramSpikeCounts_north.csv', 'HistogramSpikeCounts_south.csv'),
                      baseWeight=0.1,
                      plotTitle='Posterior, all bins. Base distr: uniform. Base weight = ',
                      pdfName='posterior_allbins_samplepairs_unif-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )

#### posterior, 20 bins
test <- plotSuperdistrSamplesUnif(dataFiles=c('HistogramSpikeCounts_north_20TimeBins.csv', 'HistogramSpikeCounts_south_20TimeBins.csv'),
                      baseWeight=0.1,
                      plotTitle='Posterior, 20 bins. Base distr: uniform. Base weight = ',
                      pdfName='posterior_20bins_samplepairs_unif-distr_w',
                      meanSpikes=0.2, # 5Hz * (40/1000)s
                      maxSpikes=15,
                      rootNumSamples=32 # rootNumSamples^2 samples
                          )










##############################################################
#### Old pieces of code below
##############################################################




## example 10 sequences, each with 15 values
data <- t(sapply(1:15, function(x){rnorm(n=10, mean=x)}))

matplot(x=1:15, y=data, type='p', pch='-', cex=1, col='black')


## example 10 sequences, each with 15 values
data <- t(sapply(1:15, function(x){rnorm(n=10, mean=x)}))

matplot(x=1:15, y=data, type='p', pch='-', cex=1, col='black')
for(dx in seq(-0.3, 0.3, by=0.1)){
    matpoints(x=(1:15)+dx, y=data, type='p', pch='-', cex=1, col='black')
}


# Function to calculate mutual info from frequency pairs
## freqs[,S] = response freqs for stimulus S
## assumes all stimuli equally probable
mutualinfo <- function(freqs,base=2){##in bits
    stimulusFreqs <- 1/ncol(freqs)
    jointFreqs <- freqs * stimulusFreqs
    responseFreqs <- rowSums(jointFreqs)
    sum(jointFreqs *
        log2(jointFreqs/outer(responseFreqs,rep(stimulusFreqs,ncol(freqs)))),
        na.rm=TRUE)/log2(base)
}

freqsampling <- function(freqs,nsamples=5){
    nresps <- nrow(freqs)
    foreach(s=1:ncol(freqs),.combine=cbind)%do%{
        onesample <- sample(1:nresps,nsamples,replace=TRUE,prob=freqs[,s])
        tabulate(onesample,nbins=nresps)
    }    
}


plotsingle <- function(rfreqs0,filename,tit0,nmcsamples=1000,nbreaks='Sturges',base=2){
    nstim <- ncol(rfreqs0)
    nresp <- nrow(rfreqs0)
    milongrun0 <- mutualinfo(rfreqs0)

    misamples0 <- foreach(i=1:nmcsamples,.combine=c)%do%{
        fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
            c(tabulate(sample(x=1:nresp,size=20,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/20)
        }
        mutualinfo(fsample)
    }

    hires <- hist(misamples0,breaks=nbreaks,plot=FALSE)
    maxy <- max(hires$counts)
    minx <- -0.02
    maxx <- 1.02
    ## minx <- min(hires$breaks,milongrun0)-0.02
    ## maxx <- max(hires$breaks,milongrun0)+0.02
    subs <- misamples0[seq(1,length(misamples0),length.out=100)]
    smean <- signif(mean(misamples0),3)
    q1 <- signif(quantile(misamples0,0.16),3)
    q2 <- signif(quantile(misamples0,0.84),3)
    q3 <- signif(quantile(misamples0,0.025),3)
    q4 <- signif(quantile(misamples0,0.975),3)
    smedian <- signif(quantile(misamples0,0.5),3)

    maintext <- paste0('long-run=',signif(milongrun0,3),' bit;  sample: mean=',smean,' bit,  median=',smedian,' bit,  68% in (',q1,', ',q2,') bit,  95% in (',q3,', ',q4,') bit')
    
    pdff(paste0('histo_',filename))
    matplot(x=subs,y=rep(-maxy/20,100),type='p',lty=1,lwd=3,pch=18,cex=1,col=myblue,xlim=c(minx,maxx),ylim=c(-maxy/20,maxy),xlab=paste0('sampled MI/bit'),ylab='',main=maintext)
    hist(misamples0,breaks=nbreaks,xlim=c(minx,maxx),ylim=c(-maxy/20,maxy),xlab='I',ylab='',add=TRUE)
##legend('top',paste0('\nblack: mean, blue: median\nyellow: 16%q'),bty='n')
    matlines(x=rep(milongrun0,2),y=c(-maxy/20,maxy),type='l',lty=1,lwd=3,pch='.',col=myred)
    dev.off()

    pdff(paste0('resp_',filename))
    barplot(t(freqs0),beside=TRUE,xlab='responses',ylab='long-run frequencies',main=tit0,names=1:10,space=c(0.2,1))
    dev.off()
}

freqs0 <- matrix(1/10,10,2)
plotsingle(freqs0,'caseA', 'case A',nmcsamples=10000,nbreaks='Sturges')

pt <- 6
fr <- 100
f1 <- (c((dcoe(0,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100))
freqs0 <- cbind(rev(f1),f1)
plotsingle(freqs0,'caseB', 'case B',nmcsamples=10000,nbreaks='Sturges')

pt <- 6
fr <- 90
f1 <- c((dcoe(0,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100)
pt <- 6
fr <- 90
f2 <- c(rev(dcoe(0,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100)
freqs0 <- cbind(rev(f1),(f2))
plotsingle(freqs0,'caseC', 'case C',nmcsamples=10000,nbreaks='Sturges')

pt <- 5
fr <- 99
f1 <- c(rev(dcoe(1/pt,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100)
freqs0 <- cbind(rev(f1),(f1))
plotsingle(freqs0,'caseD', 'case D',nmcsamples=10000,nbreaks='Sturges')



f1 <- c(rep(1/5,5)*90/100,10/100,rep(0,4))
freqs0 <- cbind(f1,rev(f1))
plotsingle(freqs0,'caseB', 'case B',nmcsamples=10000,nbreaks='Sturges')

f1 <- c(rep(1/5,5),rep(0,5))
freqs0 <- cbind(f1,rev(f1))
plotsingle(freqs0,'caseB', 'case B')


dcoe <- function(a,n=10){(1-n*a)*2/(n^2+n)*(1:n)+a}
f1 <- dcoe(0)
freqs0 <- cbind(f1,rev(f1))
plotsingle(freqs0,'caseC', 'case C')


f1 <- dcoe(0)
freqs0 <- cbind(rev(f1),rev(f1))
plotsingle(freqs0,'test', 'case B')

pt <- 10
fr <- 100
f1 <- c(rev(dcoe(1/pt,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100)
freqs0 <- cbind(rev(f1),(f1))
plotsingle(freqs0,'caseA', 'case A',nmcsamples=10000,nbreaks='Sturges')


pt <- 7
fr <- 100
f1 <- c(rev(dcoe(0,n=pt))*fr/100, rep(1/(10-pt),(10-pt))*(100-fr)/100)
freqs0 <- cbind(rev(f1),f1)
plotsingle(freqs0,'test', 'case C')








f1 <- c((dcoe(0,n=6)), rep(0,4))
freqs0 <- cbind(f1,rev(f1))
plotsingle(freqs0,'test', 'case C')


plotmulti <- function(afreqs,filename,tit0,nmcsamples=1000,nresp=10,ssize=20,base=2){
    nstim <- 2
    if(is.null(dim(afreqs))){afreqs <- cbind(afreqs,afreqs)}

    mcsamples <- foreach(i=1:nmcsamples,.combine=rbind)%do%{
        rfreqs0 <- cbind(c(rdirichlet(n=1,alpha=afreqs[,1])),
                         c(rdirichlet(n=1,alpha=afreqs[,2])))
        
        fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
            tabulate(sample(x=1:nresp,size=ssize,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/ssize
        }
        c(sum((1:nresp)*fsample[,1]), sum((1:nresp)*fsample[,2]),mutualinfo(rfreqs0))
    }

    maxmi <- 1 #max(c(mcsamples))
    lims <- c(0,1)
    limm <- c(1,10)

#    pdff(paste0('scatter_',filename))
#    par(mar=c(0,0,0,0))
    plot3d( 
  x=c(mcsamples[,1]),  y=c(mcsamples[,2]),  z=c(mcsamples[,3]),
  col = myblue,
#  type='p',size=0.5,
  type='s',size=0.2,
  xlim=limm, ylim=limm,
  zlim=lims,  xlab="mean f1", ylab="mean f2", zlab="MI/bit",aspect = c(1, 1, 1))
    
#    rglwidget()
#dev.off()
  writeWebGL( filename=paste0('scatter3d_',filename,'.htm') ,  width=800, height=800)
    ## pdff(paste0('scatter_',filename))
    ## par(pty = "s")
    ## matplot(x=mcsamples[,1],y=mcsamples[,2],type='p',lty=1,lwd=3,pch=16,cex=0.2,col=myblue,xlim=c(0,maxmi),ylim=c(0,maxmi),xlab=paste0('long-run MI/bit'),ylab=paste0('sample MI/bit'),main=tit0)
    ## matlines(x=c(0,maxmi),y=c(0,maxmi),type='l',lty=2,lwd=2,pch='.',col=myyellow)
    ## dev.off()
}

plotmulti(rep(5,10),filename='peaked',tit0='',nmcsamples=1000)





plotmulti(dcoe(0)*5,filename='test',tit0='',nmcsamples=5000)

plotmulti(rep(10,10),filename='centrepeak',tit0='')


plotmulti(rep(0.1,10),filename='jeffr',tit0='')

plotmulti(rep(1,10),filename='test',tit0='',nmcsamples=5000)

plotmulti(rep(0.1,10),filename='test',tit0='',nmcsamples=10000)

plotmulti(10*rev(dcoe(0)),filename='test',tit0='',nmcsamples=10000)



f1 <- dcoe(0)*1
plotmulti(cbind(f1,rev(f1)),filename='test',tit0='')

plotmulti(rep(1,10),filename='unif',tit0='')

plotmulti(rep(0.1,10),filename='jeffr',tit0='')



plotmultimean <- function(afreqs,filename,tit0,nmcsamples=10,nsubsamples=500,base=2){
    nstim <- 2
    if(is.null(dim(afreqs))){afreqs <- cbind(afreqs,afreqs)}

    misamples <- foreach(i=1:nmcsamples,.combine=rbind)%do%{
        rfreqs0 <- cbind(c(rdirichlet(n=1,alpha=afreqs[,1])),
                         c(rdirichlet(n=1,alpha=afreqs[,2])))

        meanmi <- mean(foreach(i=1:nsubsamples,.combine=c)%do%{
            fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
                tabulate(sample(x=1:nresp,size=20,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/20
            }
            mutualinfo(fsample)
        })
        c(mutualinfo(rfreqs0), meanmi)
    }

    maxmi <- max(c(misamples))
    pdff(paste0('scatter_',filename))
    par(pty = "s")
    matplot(x=misamples[,1],y=misamples[,2],type='p',lty=1,lwd=3,pch='.',cex=4,col=myblue,xlim=c(0,maxmi),ylim=c(0,maxmi),xlab=paste0('long-run MI/bit'),ylab=paste0('sampled MI/bit'),main=tit0)
    matlines(x=c(0,maxmi),y=c(0,maxmi),type='l',lty=2,lwd=2,pch='.',col=myyellow)
    dev.off()
}



plotmulti(rep(10,10),filename='centrepeak',tit0='')

plotmulti(rep(1,10),filename='unif',tit0='')

plotmulti(rep(0.1,10),filename='jeffr',tit0='')

plotmultimean(rep(0.1,10),filename='test',tit0='',nmcsamples=30,nsubsamples=500)


plotmulti(dcoe(0)*5,filename='test',tit0='')

f1 <- dcoe(0)*1
plotmulti(cbind(f1,rev(f1)),filename='test',tit0='')

plotmulti(rep(1,10),filename='unif',tit0='')

plotmulti(rep(0.1,10),filename='jeffr',tit0='')




plotmultih <- function(afreqs0,stre,filename,tit0,nmcsamples=1000,base=2,nresp=2){
    nstim <- 2

    mcsamples <- foreach(i=1:nmcsamples,.combine=rbind)%do%{
        afreqs <- stre*t(rdirichlet(n=nresp,alpha=afreqs0))
        
        rfreqs0 <- cbind(c(rdirichlet(n=1,alpha=afreqs[,1])),
                         c(rdirichlet(n=1,alpha=afreqs[,2])))
        
        fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
            tabulate(sample(x=1:nresp,size=5,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/20
        }
        c(fsample, mutualinfo(rfreqs0))
    }

    maxmi <- 1 #max(c(mcsamples))

par(mar=c(0,0,0,0))
plot3d( 
  x=c(mcsamples[,1]),  y=c(mcsamples[,2]),  z=c(mcsamples[,3]),
  col = data$color, 
  type = 's', 
  radius = .1,
  xlab="f1", ylab="f2", zlab="MI/bit")

  writeWebGL( filename=paste0('scatter3d_',filename) ,  width=600, height=600)
    
    ## pdff(paste0('scatter_',filename))
    ## par(pty = "s")
    ## matplot(x=mcsamples[,1],y=mcsamples[,2],type='p',lty=1,lwd=3,pch=16,cex=0.2,col=myblue,xlim=c(0,maxmi),ylim=c(0,maxmi),xlab=paste0('long-run MI/bit'),ylab=paste0('sample MI/bit'),main=tit0)
    ## matlines(x=c(0,maxmi),y=c(0,maxmi),type='l',lty=2,lwd=2,pch='.',col=myyellow)
    ## dev.off()
}

plotmultih(rep(1,2),stre=10,filename='test',tit0='',nmcsamples=100)

plotmultih(rep(1,10),stre=1,filename='test',tit0='',nmcsamples=2000)

plotmultih(rep(1,10),stre=1,filename='test',tit0='',nmcsamples=2000)


plotmulti(dcoe(0)*5,filename='test',tit0='')

f1 <- dcoe(0)*1
plotmulti(cbind(f1,rev(f1)),filename='test',tit0='')



backmultih <- function(afreqs0,stre,samplevalue,nmcsamples=1000,base=2){
    nstim <- 2
    v1 <- samplevalue[1]
    v2 <- samplevalue[2]

    misamples <- foreach(i=1:nmcsamples,.combine=c)%dopar%{
        afreqs <- stre*t(rdirichlet(n=2,alpha=afreqs0))
        
        rfreqs0 <- cbind(c(rdirichlet(n=1,alpha=afreqs[,1])),
                         c(rdirichlet(n=1,alpha=afreqs[,2])))
        
        fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
            tabulate(sample(x=1:nresp,size=20,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/20
        }
        smi <- mutualinfo(fsample)
        if(smi<v1 || smi>v2) return(NULL)
        mutualinfo(rfreqs0)
    }
    misamples
}


testsa <- backmultih(rep(1,10),stre=1,c(0.19,0.21),nmcsamples=100000)

saveRDS(testsa,file='example_backmi.rds')



plotmultihlines <- function(afreqs0,stre,filename,vsample,vlr,tit0,nmcsamples=1000,base=2){
    nstim <- 2

    misamples <- foreach(i=1:nmcsamples,.combine=rbind)%do%{
        afreqs <- stre*t(rdirichlet(n=2,alpha=afreqs0))
        
        rfreqs0 <- cbind(c(rdirichlet(n=1,alpha=afreqs[,1])),
                         c(rdirichlet(n=1,alpha=afreqs[,2])))
        
        fsample <- foreach(s=1:nstim,.combine=cbind)%do%{
            tabulate(sample(x=1:nresp,size=20,replace=TRUE,prob=rfreqs0[,s]),nbins=nresp)/20
        }
        c(mutualinfo(rfreqs0), mutualinfo(fsample))
    }

    maxmi <- 1 #max(c(misamples))
    pdff(paste0('scatter_',filename))
    par(pty = "s")
    matplot(x=misamples[,1],y=misamples[,2],type='p',lty=1,lwd=3,pch=16,cex=0.2,col=myblue,xlim=c(0,maxmi),ylim=c(0,maxmi),xlab=paste0('long-run MI/bit'),ylab=paste0('sample MI/bit'),main=tit0)
    matlines(x=c(-0.1,vlr[2]),y=c(vsample,vsample),type='l',lty=2,lwd=2,pch='.',col=mygreen)
    matlines(x=rep(vlr[1],2),y=c(vsample,-0.1),type='l',lty=2,lwd=2,pch='.',col=mygreen)
    matlines(x=rep(vlr[2],2),y=c(vsample,-0.1),type='l',lty=2,lwd=2,pch='.',col=mygreen)
    dev.off()
}

plotmultihlines(rep(1,10),stre=1,vsample=0.2,vlr=quantile(testsa,probs=c(0.16,0.84)),filename='test',tit0='',nmcsamples=10000)

######################################################################
### inference_headdir_data.R ends here
