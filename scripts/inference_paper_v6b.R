## Author: Battistin, Gonzalo Cogno, Porta Mana
## Last-Updated: 2021-07-27T19:14:51+0200
################
## Script for:
## - outputting samples of prior & posterior distributions
## - calculating posteriors
## Uses Dirichlet prior
################

#### Custom setup ####
## Colour-blind friendly palettes, from https://personal.sron.nl/~pault/
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
library('data.table')
library('khroma')
library('ggplot2')
library('ggthemes')
theme_set(theme_bw(base_size=18))
scale_colour_discrete <- scale_colour_bright
#library('cowplot')
library('png')
library('foreach')
library('doFuture')
registerDoFuture()
library('doRNG')
library('ash')
library('LaplacesDemon') # used for Dirichlet generator
library('extraDistr')
options(bitmapType='cairo')
pdff <- function(filename){pdf(file=paste0(filename,'.pdf'),paper='a4r',height=11.7,width=16.5)} # to output in pdf format
pngf <- function(filename,res=300){png(file=paste0(filename,'.png'),height=11.7*1.2,width=16.5,units='in',res=res,pointsize=36)} # to output in png format
#### End custom setup ####

#######################################
#### FUNCTION TO CALCULATE MUTUAL INFO FROM JOINT DISTRIBUTION
## freqs[S,B] = freq spike count B and stimulus S (one ROW per stimulus)
## The function calculates the conditional frequencies of B|S
## and constructs a new joint distribution with equal marginals for S
## Note: don't need to normalize input to mutualinfo
mutualinfo <- function(jointFreqs,base=2){##in bits by default
    stimulusFreqs <- 1/nrow(jointFreqs)
    ## (conditional freqs B|S) * (new freq S)
    jointFreqs <- (jointFreqs/rowSums(jointFreqs)) * stimulusFreqs
    sum(jointFreqs *
        log2(jointFreqs/outer(rowSums(jointFreqs), colSums(jointFreqs))),
        na.rm=TRUE)/log2(base)
}
## function to normalize absolute frequencies
normalize <- function(freqs){freqs/sum(freqs)}
normalizerows <- function(freqs){freqs/rowSums(freqs)}
normalizecols <- function(freqs){t(t(freqs)/colSums(freqs))}

longrunDataFile  <- 'SpikeCounts_and_direction.csv'
sampleIndexFile  <- 'index_mat_160.csv'
plan(sequential)
maxSpikes <- 12
maxSpikes1 <- maxSpikes + 1
maxSpikes2 <- 2 * maxSpikes1
T <- 10 ## prior weight
priorMeanSpikes <- 0.4 # 0.2 = 5Hz * (40Hz/1000s)
priorSdSpikes <- 0.2 # 0.2 = 5Hz * (40Hz/1000s)
shapegamma <- (priorMeanSpikes/priorSdSpikes)^2
rategamma <- priorMeanSpikes/priorSdSpikes^2
#priorBaseDistr <- normalize(dpois(x=0:maxSpikes, lambda=priorMeanSpikes, log=FALSE))
#priorBaseDistr <- normalize(dgeom(x=0:maxSpikes, prob=1/(priorMeanSpikes+1), log=FALSE))
## priorBaseDistr <- normalize(rep(1,maxSpikes1))
nDraws <- 2000
nPlotSamples <- 100
maxX <- 8
##
## load full recording
longrunData  <- as.data.table(t(read.csv(longrunDataFile,header=FALSE,sep=',')))
colnames(longrunData) <- c('nspikes', 'stimulus')
stimulusVals <- unique(longrunData[,stimulus])
nStimuli <- length(stimulusVals)
nspikesVals <- 0:maxSpikes
## longrunData <- longrunData[nspikes<=maxSpikes] # for debug, REMEMBER TO REMOVE
## frequencies of full recording
longrunFreqs <- foreach(stim=stimulusVals, .combine=rbind)%do%{
    tabulate(longrunData[stimulus==stim,nspikes]+1, nbins=maxSpikes1)
}
rownames(longrunFreqs) <- nameStimulus <- paste0('stimulus',stimulusVals)
colnames(longrunFreqs) <- nameNspikes <- paste0('nspikes',nspikesVals)
longrunMI <- c(bit=mutualinfo(longrunFreqs))
## frequencies of sample
gc()
plan(sequential)
#plan(multisession, workers = 6L)
allmcoutput <- foreach(chunk=0:0, .inorder=F, .packages=c('data.table','LaplacesDemon','extraDistr'))%do%{
    pflag <- 0
    if(chunk==0){chunk <- 1
        pflag <- 1}
    chunkIndices <- as.matrix(read.csv(sampleIndexFile,header=FALSE,sep=','))[chunk,]
    sampleData <- longrunData[chunkIndices,]
    ##print(str(sampleData))
    sampleFreqs <- foreach(stim=stimulusVals, .combine=rbind)%do%{
        tabulate(sampleData[stimulus==stim,nspikes]+1, nbins=maxSpikes1)
    } 
    dimnames(sampleFreqs) <- dimnames(longrunFreqs)
    nSamples <- sum(sampleFreqs)
    if(pflag==0){
        sampleMI <- c(bit=mutualinfo(sampleFreqs))
    } else {
        sampleMI <- c(bit=-2)
        chunk <- 0}
    ##
    ##
    ## Alphas for Dirichlet distribution
    ##
    dataAlphas <- sampleFreqs * (pflag==0)
    ## Generate samples
    set.seed(147+chunk)
    smoothness <- 100
    smoothm <- sqrt(smoothness)*diff(diag(maxSpikes1),differences=4)
    shapegamma <- (priorMeanSpikes/priorSdSpikes)^2
    rategamma <- priorMeanSpikes/priorSdSpikes^2
    ##
    outfile <- paste0('_LDoutput',chunk)
    thinning <- 10 #10
    mcadapt <- 2600 #10e3
    mcburnin <- mcadapt
    mciterations <- mcburnin + 10000
    mcstatus <- 200 #1e3
    Fnames <- paste0('F',rep(nspikesVals,each=nStimuli),'_',rep(stimulusVals,times=maxSpikes1))
    Mnames <- paste0('mean',stimulusVals)
    stepwidth <- 1 #c(rep(nn/100,length(inu)),rep(nnyR/100,length(iR)))
    nsteps <- 1000 #c(rep(nn/100,length(inu)),rep(nnyR/100,length(iR)))
    nprev <- 0
    meansInd <- 1:2
    dimjointfreq <- c(nStimuli, maxSpikes1)
    ## B <- c(list(meansInd), foreach(i=1:nStimuli, .combine=list)%do%{
    ##     indices <- 2+(1:(maxSpikes1*nStimuli))
    ##     dim(indices) <- dimjointfreq
    ##     indices[i,]})
    indices <- matrix(1:(nStimuli+maxSpikes1*nStimuli),nrow=2)
    B <- c(list(meansInd), foreach(i=1:nStimuli, .combine=list)%do%{
        indices[i,-1]
    })
    ## B <- foreach(i=1:nStimuli, .combine=list)%do%{indices[i,]}
    covm <- lapply(B,function(x){diag(length(x))})
    ## B <- list(meansInd, 2+(1:(maxSpikes1*nStimuli)))
    ## covm <- lapply(B,function(x){diag(length(x))})
     ## B <- NULL
     ## covm <- NULL
    nspikesVals2 <- rep(nspikesVals,each=nStimuli)
    ##
    parm2FF <- function(parm){
        if(length(parm)>nStimuli*maxSpikes1){parm <- parm[-meansInd]}
        FF <- parm
        dim(FF) <- dimjointfreq
        sFF <- rowSums(FF)
        FF/sFF
    }
        prob <- 1/(priorMeanSpikes+1)
        dgeo <- ((1-prob)^nspikesVals2) * prob
        ## dgeom(nspikesVals2, prob=1/(means+1), log=FALSE)
        dim(dgeo) <- dimjointfreq
        dgeo <- T * dgeo/rowSums(dgeo)
    PGF <- function(data){
        c(1 * rdirichlet(n=2, alpha=1/(maxSpikes1*100)+T*dgeo))
    }
    ##
    mydata <- list(y=1, PGF=PGF,
                   parm.names=c(Mnames,Fnames),
                   mon.names=c('lpf',paste0('G',0:maxSpikes)) #c('lpf','MI')
                   ##nn=nn,
                   ##L=L,
                   ##T=T,
                   ##hh=hh,
                   ##ft=ft,
                   ##rpos=rpos,
                   ##inu=inu,
                   ##iR=iR,
                   ##smoothm=smoothm,
                   ##nnyR=***
                   )
    ##
    logprob <- function(parm,data){
        parm <- interval(parm,0,Inf)
        means <- parm[meansInd]
        FF <- parm[-meansInd]
        dim(FF) <- dimjointfreq
        sFF <- rowSums(FF)
        FF <- FF/sFF
        ## mi <- mutualinfo(FF)
        ##
        ##
        lpf <- sum((dgeo+dataAlphas-1+1/(maxSpikes1*100))*log(FF), na.rm=F) -
            sum(lgamma(dgeo)) +
            ## sum(ddirichlet(x=FF, alpha = T * dgeo, log=TRUE) + 
            sum((shapegamma-1)*log(means),na.rm=TRUE) - sum(rategamma*means) 
        ## dgamma(means, shape=shapegamma, rate=rategamma, log=TRUE)) # -
           ## sum(tcrossprod(FF, smoothm)^2)
        ##
        LP <- lpf - 1e3*sum((sFF-1)^2)
        ##
        list(LP=LP, Dev=-2*LP, Monitor=c(lpf,dgeo[1,]), yhat=1, parm=parm)
    }
    ##
    Initial.Values <- PGF(mydata)
    ## print('running Monte Carlo...')
    mcoutput <- LaplacesDemon(logprob, mydata, Initial.Values,
                              #Covar=NULL,
                              Covar=covm,
                              Thinning=thinning,
                              Iterations=mciterations, Status=mcstatus,
                              Debug=list(DB.chol=T, DB.eigen=T,
                                         DB.MCSE=T, DB.Model=T),
                              LogFile=paste0('_LDlog',outfile), #Type="MPI", #Packages=c('MASS'),
                              ##Algorithm="RDMH"#, Specs=list(B=list(1:d,d1:d2,d3:dnp))
                              ##Algorithm="Slice", Specs=list(B=NULL, Bounds=c(0,1), m=Inf, Type="Continuous", w=0.001)
                              ##Algorithm="MALA", Specs=list(A=1e7, alpha.star=0.574, gamma=mcadapt, delta=1, epsilon=c(1e-6,1e-7))
                              ##Algorithm="pCN", Specs=list(beta=0.001)
                              Algorithm="AFSS", Specs=list(A=mcadapt, B=B, m=nsteps, n=nprev, w=stepwidth)
                              ##Algorithm="AIES", Specs=list(Nc=4*nparm, Z=NULL, beta=2, CPUs=1, Packages=NULL, Dyn.libs=NULL)                      
                              ##Algorithm="DRM", Specs=NULL
                              )
    ##
    ##
#    remsummary <- -1e10 # -(1:10)
    remsummary <- -round((1:mcburnin)/thinning)
    mcmcrun <- mcoutput$Posterior1[remsummary## -round((1:mcburnin)/thinning)
                                  ,-meansInd]
    nDraws <- nrow(mcmcrun)
    dim(mcmcrun) <- c(nDraws,nStimuli,maxSpikes1)
    dimnames(mcmcrun) <- list(NULL, nameStimulus, nameNspikes)
    postMISamples <- apply(mcmcrun,1,mutualinfo)
    postMIDistr <- hist(postMISamples, breaks=seq(0,1,by=0.02), plot=F)
    postMIQuantiles <- quantile(x=postMISamples, probs=c(0.025,0.5,0.975))
    condfreqSamples <- t(apply(mcmcrun,1,normalizerows))
    dim(condfreqSamples) <- c(nDraws, nStimuli, maxSpikes1)
    dimnames(condfreqSamples) <- dimnames(mcmcrun)
    ##
    ##
    ## Plot draws
    pdff(paste0('LDplots_samples',nSamples,'_chunk',chunk))
    ##
    matplot(x=nspikesVals, y=t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),1,]),
            type='l', lty=1, lwd=2, col=paste0(mypurpleblue,'22'), ylim=c(-1,1),  xlim=c(0,maxX),
            xlab='spikes/bin', ylab='freq', cex.lab=2, cex.axis=2)
    for(i in 2:nStimuli){
        matplot(x=nspikesVals, y=-t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),i,]),
                type='l', lty=1, lwd=1, col=paste0(myredpurple,'22'),
                add=TRUE)
    }
    matplot(x=nspikesVals, y=normalize(longrunFreqs[1,]),
            type='l', lty=1, lwd=2, col='black',
            add=TRUE)
    matplot(x=nspikesVals, y=-normalize(longrunFreqs[2,]),
            type='l', lty=1, lwd=2, col='black',
            add=TRUE)
    if(pflag==0){matplot(x=nspikesVals, y=normalize(sampleFreqs[1,]),
                         type='l', lty=2, lwd=5, col=myyellow,
                         add=TRUE)
                         matplot(x=nspikesVals, y=-normalize(sampleFreqs[2,]),
                                 type='l', lty=2, lwd=5, col=myyellow,
                                 add=TRUE)}
    title(paste0('(',nSamples,' data samples,',
                 ' chunk ', chunk,
                 ', prior weight = ', T, ')',
                 '\n superdistr ',chunk), cex.main=2)
    legend('topright',c('long-run freqs','sample freqs'),lty=c(1,2),lwd=c(2,5),col=c('black',myyellow),cex=1.5)
    ## Posterior MI
    matplot(x=postMIDistr$mids, y=postMIDistr$density,
            type='h', lty=1, lwd=15, col=paste0(mypurpleblue,'88'), xlim=c(0,1),
            xlab='MI/bit', ylab='prob dens', cex.lab=2, cex.axis=2)
    for(q in postMIQuantiles){
        matlines(x=rep(q,2),y=c(-1,1/2)*max(postMIDistr$density), lty=2, lwd=6, col=mygreen)
    }
    matlines(x=rep(sampleMI,2),y=c(-1,2/3)*max(postMIDistr$density), lty=4, lwd=6, col=myyellow)
    matlines(x=rep(longrunMI,2),y=c(-1,2/3)*max(postMIDistr$density), lty=1, lwd=6, col=myredpurple)
    title('posterior MI distr', cex.main=2)
    legend('topright',c('sample MI', 'long-run MI'),lty=1,col=c(myyellow,myredpurple),lwd=4,cex=1.5)
    dev.off()
    ##
    ## Plot MCMC diagnostics
    testsamples <- mcoutput$Posterior1[remsummary,-meansInd]
    dim(testsamples) <- c(nrow(testsamples),nStimuli,maxSpikes1)
    pdff(paste0('LD_MCsummary',chunk))
    matplot(mcoutput$Monitor[remsummary,1],type='l',ylab='log-likelihood')
    matplot(t(mcoutput$Monitor[remsummary,-1]),type='l',ylab='geom distr')
    matplot(postMISamples,type='l',ylab='MI')
    matplot(mcoutput$Posterior1[remsummary,meansInd],type='l',ylab='means of geom. distr.')
    matplot(normal <- rowSums(testsamples[,1,]),type='l',ylab='normalization 0')
    ## matplot(testsamples[,1,]/normal,type='l',ylab='freq. stimulus 0')
    matplot(-mcoutput$Deviance[remsummary]/2,type='l',ylab='full log-likelihood')
    dev.off()
    ##
    mcoutput
}
##
testplots <- function(){
    testoutput <- foreach(i=1:2000, .combine=rbind)%do%{
        means <- rgamma(n=2,shape=shapegamma,rate=rategamma)
        ## dgeo <- dgeom(nspikesVals2, prob=1/(means+1), log=FALSE)
        ## dim(dgeo) <- dimjointfreq
        ## dgeo <- T * dgeo/rowSums(dgeo)
        FF <- rdirichlet(n=2,alpha=dgeo+dataAlphas+1/maxSpikes1)
        c(means,FF)
    }
    mcmcrun <- testoutput[,-meansInd]
        ## means <- parm[meansInd]
        ## FF <- parm[-meansInd]
        ## dim(FF) <- c(nStimuli, maxSpikes1)
        ## sFF <- rowSums(FF)
        ## tFF <- sum(sFF)
        ## ## mi <- mutualinfo(FF)
        ## ##
        ## ##
        ## lpf <- sum(dataAlphas*log(FF/tFF), na.rm=TRUE) +
        ##     ddirichlet(x=c(FF)/tFF,
        ##                alpha = T * dgeom(nspikesVals2, prob=1/(means+1), log=FALSE),
        ##                log=TRUE) + 
        ##     sum(dgamma(means, shape=shapegamma, rate=rategamma, log=TRUE)) # -
    nDraws <- nrow(mcmcrun)
    dim(mcmcrun) <- c(nDraws,nStimuli,maxSpikes1)
    dimnames(mcmcrun) <- list(NULL, nameStimulus, nameNspikes)
    postMISamples <- apply(mcmcrun,1,mutualinfo)
    postMIDistr <- hist(postMISamples, breaks=seq(0,1,by=0.02), plot=F)
    postMIQuantiles <- quantile(x=postMISamples, probs=c(0.025,0.5,0.975))
    condfreqSamples <- t(apply(mcmcrun,1,normalizerows))
    dim(condfreqSamples) <- c(nDraws, nStimuli, maxSpikes1)
    dimnames(condfreqSamples) <- dimnames(mcmcrun)
    ##
    ##
    ## Plot draws
    pdff(paste0('LDplots_samples',nSamples,'_chunk','test'))
    ##
    matplot(x=nspikesVals, y=t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),1,]),
            type='l', lty=1, lwd=2, col=paste0(mypurpleblue,'22'), ylim=c(-1,1),  xlim=c(0,maxX),
            xlab='spikes/bin', ylab='freq', cex.lab=2, cex.axis=2)
    for(i in 2:nStimuli){
        matplot(x=nspikesVals, y=-t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),i,]),
                type='l', lty=1, lwd=1, col=paste0(myredpurple,'22'),
                add=TRUE)
    }
    matplot(x=nspikesVals, y=normalize(longrunFreqs[1,]),
            type='l', lty=1, lwd=2, col='black',
            add=TRUE)
    matplot(x=nspikesVals, y=-normalize(longrunFreqs[2,]),
            type='l', lty=1, lwd=2, col='black',
            add=TRUE)
    if(pflag==0){matplot(x=nspikesVals, y=normalize(sampleFreqs[1,]),
                         type='l', lty=2, lwd=5, col=myyellow,
                         add=TRUE)
                         matplot(x=nspikesVals, y=-normalize(sampleFreqs[2,]),
                                 type='l', lty=2, lwd=5, col=myyellow,
                                 add=TRUE)}
    title(paste0('(',nSamples,' data samples,',
                 ' chunk ', chunk,
                 ', prior weight = ', T, ')',
                 '\n superdistr ',chunk), cex.main=2)
    legend('topright',c('long-run freqs','sample freqs'),lty=c(1,2),lwd=c(2,5),col=c('black',myyellow),cex=1.5)
    ## Posterior MI
    matplot(x=postMIDistr$mids, y=postMIDistr$density,
            type='h', lty=1, lwd=15, col=paste0(mypurpleblue,'88'), xlim=c(0,1),
            xlab='MI/bit', ylab='prob dens', cex.lab=2, cex.axis=2)
    for(q in postMIQuantiles){
        matlines(x=rep(q,2),y=c(-1,1/2)*max(postMIDistr$density), lty=2, lwd=6, col=mygreen)
    }
    matlines(x=rep(sampleMI,2),y=c(-1,2/3)*max(postMIDistr$density), lty=4, lwd=6, col=myyellow)
    matlines(x=rep(longrunMI,2),y=c(-1,2/3)*max(postMIDistr$density), lty=1, lwd=6, col=myredpurple)
    title('posterior MI distr', cex.main=2)
    legend('topright',c('sample MI', 'long-run MI'),lty=1,col=c(myyellow,myredpurple),lwd=4,cex=1.5)
    dev.off()
}
testplots()


    ## logprob <- function(parm,data){
    ##     parm <- interval(parm,0,Inf)
    ##     LP <- sum(sapply(1:nStimuli,function(ii){
    ##         parm0 <- parm[indices[ii,]]
    ##         means <- parm0[1]
    ##         FF <- parm0[-1]
    ##         tFF <- sum(FF)
    ##         FF <- FF/tFF
    ##         dgeo <- dgeom(nspikesVals, prob=1/(means+1), log=FALSE)
    ##         ##
    ##         sum(dataAlphas[ii,]*log(FF), na.rm=TRUE) +
    ##         ddirichlet(x=FF, alpha = T * dgeo, log=TRUE) + 
    ##         dgamma(means, shape=shapegamma, rate=rategamma, log=TRUE) -
    ##         ##sum(tcrossprod(FF, smoothm)^2) -
    ##         1e3*(tFF-maxSpikes1)^2
    ##     }))
    ##     ##
    ##     list(LP=LP, Dev=-2*LP, Monitor=LP, yhat=1, parm=parm)
    ## }
