## Author: Battistin, Gonzalo Cogno, Porta Mana
## Last-Updated: 2021-08-03T10:59:00+0200
################
## Script for:
## - outputting samples of prior & posterior distributions
## - calculating posteriors
## Uses Dirichlet prior
################
postsamples <- function(chunk){ # <- as.numeric(commandArgs(trailingOnly = TRUE))
print(paste0('chunk ',chunk))
##
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
##
t2f <- function(t){exp(t)/sum(exp(t))}
longrunDataFile  <- 'SpikeCounts_and_direction.csv'
sampleIndexFile  <- 'index_mat_160.csv'
#plan(sequential)
maxS <- 12
maxS1 <- maxS + 1
maxS2 <- 2 * maxS1
##
## load full recording
longrunData  <- as.data.table(t(read.csv(longrunDataFile,header=FALSE,sep=',')))
colnames(longrunData) <- c('nspikes', 'stimulus')
stimulusVals <- unique(longrunData[,stimulus])
nStimuli <- length(stimulusVals)
nspikesVals <- 0:maxS
## longrunData <- longrunData[nspikes<=maxS] # for debug, REMEMBER TO REMOVE
## frequencies of full recording
longrunFreqs <- foreach(stim=stimulusVals, .combine=rbind)%do%{
    tabulate(longrunData[stimulus==stim,nspikes]+1, nbins=maxS1)
}
rownames(longrunFreqs) <- nameStimulus <- paste0('stimulus',stimulusVals)
colnames(longrunFreqs) <- nameNspikes <- paste0('nspikes',nspikesVals)
longrunMI <- c(bit=mutualinfo(longrunFreqs))
##
    ##
    ##
    ## stimulus0 0.08165385
    ## stimulus1 1.23955008
    ## > summary(lmf)
    ##        V1         
    ##  Min.   :0.08165  
    ##  1st Qu.:0.37113  
    ##  Median :0.66060  
    ##  Mean   :0.66060  
    ##  3rd Qu.:0.95008  
    ##  Max.   :1.23955
    priorMeanSpikes <- 0.7 # 0.2 = 5Hz * (40Hz/1000s)
    priorSdSpikes <- 0.7 # 0.2 = 5Hz * (40Hz/1000s)
    shapegamma <- (priorMeanSpikes/priorSdSpikes)^2
    rategamma <- sqrt(shapegamma)/priorSdSpikes
    priorstrength <- 100
prioralphas <- rep(0,maxS1)
    smoothness <- 2
    smoothm <- t(diff(diag(maxS1),differences=2))
##
library('nimble')
#### End custom setup ####
##
#######################################
#### FUNCTION TO CALCULATE MUTUAL INFO FROM JOINT DISTRIBUTION
## freqs[S,B] = freq spike count B and stimulus S (one ROW per stimulus)
## The function calculates the conditional frequencies of B|S
## and constructs a new joint distribution with equal marginals for S
## Note: don't need to normalize input to mutualinfo
##
## Functions definitions
##
## Normalize rows
Nnormrows <- nimbleFunction(
    run = function(x=double(2)){
        newx <- matrix(value=0,init=FALSE,nrow=dim(x)[1],ncol=dim(x)[2])
        for(i in 1:(dim(x)[1])){ newx[i,] <- x[i,]/sum(x[i,]) }
        return(newx)
        returnType(double(2))
    })
assign('Nnormrows', Nnormrows, envir = .GlobalEnv)
## Cross-entropy
Ncrossentropy <- nimbleFunction(
    run = function(x=double(1), y=double(1, default=x), base=double(0, default=2)){
        nzero <- which(x>0)
        return(sum(x[nzero] * log(y[nzero])/log(base)))
        returnType(double(0))
    })
assign('Ncrossentropy', Ncrossentropy, envir = .GlobalEnv)
##Ccentropy <- compileNimble(Ncentropy)    
##
## Mutual info
Nmutualinfo <- nimbleFunction(
    run = function(x=double(2), base=double(0, default=2)){
        newx <- Nnormrows(x)/(dim(x)[1])
        marg <- numeric(value=0, length=dim(x)[2])
        for(i in 1:(dim(x)[1])){marg <- marg + newx[i,]}
        return(Ncrossentropy(x=c(newx), y=c(newx), base=base) - Ncrossentropy(x=marg, y=marg, base=base) + log(dim(x)[1])/log(base))
        returnType(double(0))
    })
assign('Nmutualinfo', Nmutualinfo, envir = .GlobalEnv)
## Cmutualinfo <- compileNimble(Nmutualinfo)
## Mutual info
geomd <- nimbleFunction(
    run = function(x=double(0), y=double(1)){
        prob <- 1/(1+x)
        dist <- exp(y*log(1-prob) + log(prob))
        return(dist/sum(dist))
        returnType(double(1))
    })
assign('geomd', geomd, envir = .GlobalEnv)
##
## Transform log-frequencies to frequencies
Nx2f <- nimbleFunction(
    run = function(x=double(2)){
        return(Nnormrows(exp(x)))
        returnType(double(2))
    })
assign('Nx2f', Nx2f, envir = .GlobalEnv)
##
##
set.seed(147+chunk)
chunkIndices <- as.matrix(read.csv(sampleIndexFile,header=FALSE,sep=','))[chunk+(chunk==0),]
sampleData <- foreach(i=stimulusVals, .combine=rbind)%do%{
    chosen <- longrunData[stimulus==i]
    chosen <- chosen[sample(nrow(chosen))]
    chosen[1:(length(chunkIndices)/nStimuli)]
}    ##print(str(sampleData))
    sampleFreqs <- foreach(stim=stimulusVals, .combine=rbind)%do%{
        tabulate(sampleData[stimulus==stim,nspikes]+1, nbins=maxS1)
    } 
    dimnames(sampleFreqs) <- dimnames(longrunFreqs)
    nSamples <- sum(sampleFreqs)
    sampleMI <- c(bit=(chunk>0)*mutualinfo(sampleFreqs) - 2*(chunk==0))
    sampleFreqs <- sampleFreqs * (chunk>0)
    ##
    ##
    ## MONTE CARLO sampling for prior and posterior
    ##
    ##
    ## Probability density
    ## dlogsmoothmean <- nimbleFunction(
    ##     run = function(x=double(1), alphas=double(1), powerexp=double(0), shapegamma=double(0), rategamma=double(0), smatrix=double(2), normstrength=double(0, default=1000), log=integer(0, default=0)){
    ##         returnType(double(0))
    ##         tx <- sum(x)
    ##         f <- exp(x)/sum(exp(x))
    ##         dmean <- inprod(f,0:(length(f)-1))
    ##         logp <- sum((alphas+1) * log(f)) + (shapegamma-1)*log(dmean) - (rategamma*dmean)^powerexp - sum((log(f) %*% smatrix)^2) - normstrength  * tx^2 
    ##         if(log) return(logp)
    ##         else return(exp(logp))
    ##     })
    ## assign('dlogsmoothmean', dlogsmoothmean, envir = .GlobalEnv)
    #Cdlogsmoothmean <- compileNimble(dlogsmoothmean)
##
code <- nimbleCode({
        for(i in 1:nStimuli){
            means[i] ~ dgamma(shape=shapegammac, rate=rategammac)
            alphas[i,1:maxS1] <- priorstrengthc * geomd(x=means[i], y=0:maxS)
            X[i,1:maxS1] ~ ddirch(alpha=alphas[i,1:maxS1])
            ##if(chunk>0){
                datafreqs[i,1:maxS1] ~ dmulti(size=size[i], prob=X[i,1:maxS1])
            ##}
            }
    })
    ##
    constants <- list(priorstrengthc=priorstrength, shapegammac=shapegamma, rategammac=rategamma, nStimuli=nStimuli, maxS1=maxS1, maxS=maxS, chunk=chunk)
    ##
    initX <- normalizerows(sampleFreqs+1)
    initmeans <- rep(priorMeanSpikes,nStimuli)
    inits <- list(means=initmeans, X=initX)
##
modeldata <- if(chunk>-1){list(datafreqs=sampleFreqs, size=rowSums(sampleFreqs))}else{list()}
##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    confmcmc <- configureMCMC(Cmodel, nodes=NULL)
##confmcmc <- configureMCMC(Cmodel)
for(i in 1:nStimuli){
    confmcmc$addSampler(target=c(paste0('means[',i,']'), paste0('X[',i,', ]')), type='AF_slice', control=list(sliceAdaptFactorMaxIter=20000, sliceAdaptFactorInterval=1000, sliceAdaptWidthMaxIter=1000, sliceMaxSteps=100, maxContractions=100))
    }
    ## for(i in 1:nStimuli){
    ##     confmcmc$addSampler(target=paste0('X[',i,',]'), type='RW_', control=list(sliceAdaptFactorMaxIter=10000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
        ## confmcmc$addSampler(target=paste0('X[',i,',]'), type='AF_slice', control=list(sliceAdaptFactorMaxIter=10000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    ## }
    confmcmc$setMonitors(c('X','logProb_X'))
    confmcmc
    confmcmc$printSamplers(executionOrder=T)
    mcmcsampler <- buildMCMC(confmcmc)
    Cmcmcsampler <- compileNimble(mcmcsampler, resetFunctions = TRUE)
    mcsamples <- runMCMC(Cmcmcsampler, nburnin=20000, niter=20000+50000, thin=10, setSeed=147)
    nDraws <- nrow(mcsamples)
    llsamples <- mcsamples[,-(1:(maxS1*2)),drop=F]
##
condfreqSamples <- mcsamples[,1:(maxS1*nStimuli)]
    ## condfreqSamples <- t(apply(mcsamples[,1:(maxS1*2)],1,function(x){
    ##     dim(x) <- c(2,maxS1)
    ##     Nx2f(x)}))
    dim(condfreqSamples) <- c(nDraws,nStimuli,maxS1)
    dimnames(condfreqSamples) <- list(NULL, nameStimulus, nameNspikes)
    ##
    MIsamples <- apply(condfreqSamples,1,Nmutualinfo)
    MIDistr <- hist(MIsamples, breaks=seq(0,1,by=0.02), plot=F)
    MIQuantiles <- quantile(x=MIsamples, probs=c(0.025,0.5,0.975))
    ##
    meanSsamples <- t(apply(condfreqSamples,1,function(x){x %*% (0:maxS)}))
    ##
    ## PLOTS
    nPlotSamples <- 100
    maxX <- maxS
    if(chunk==0){psign <- 1}else{psign <- -1}
    pdff(paste0('testsummaryNv2random_checkb_',chunk))
    matplot(x=nspikesVals, y=t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),1,]),
            type='l', lty=1, lwd=2, col=paste0(mygrey,'66'), ylim=c(min(0,psign),1),  xlim=c(0,maxX), xlab='spikes/bin', ylab='freq', cex.lab=2, cex.axis=2)
        matplot(x=nspikesVals, y=psign*t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),2,]),
                type='l', lty=1, lwd=1, col=paste0(mygrey,'66'), add=TRUE)
    ##
    if(chunk>0){matplot(x=nspikesVals, y=t(normalizerows(sampleFreqs)*c(1,psign)),
                         type='l', lty=2, lwd=5, col=myyellow, add=TRUE)}
    ##
    matplot(x=nspikesVals, y=t(normalizerows(longrunFreqs)*c(1,psign)),
            type='l', lty=4, lwd=4, col='black', add=TRUE)
    ##
    title(paste0(nSamples,' data samples,',
                 ' chunk =', chunk,
                 ', prior weight = ', sum(prioralphas),
                 '\n superdistr ',chunk), cex.main=2)
    legend('topright',c('long-run freqs','sample freqs'),lty=c(1,2),lwd=c(2,5),col=c('black',myyellow),cex=1.5)
    ##
    ##
    matplot(x=MIDistr$mids, y=MIDistr$density,
            type='h', lty=1, lwd=15, col=paste0(mypurpleblue,'88'), xlim=c(0,1),
            xlab='MI/bit', ylab='prob dens', cex.lab=2, cex.axis=2)
    for(q in MIQuantiles){
        matlines(x=rep(q,2),y=c(-1,1/2)*max(MIDistr$density), lty=2, lwd=6, col=mygreen)
    }
    matlines(x=rep(sampleMI,2),y=c(-1,2/3)*max(MIDistr$density), lty=4, lwd=6, col=myyellow)
    matlines(x=rep(longrunMI,2),y=c(-1,2/3)*max(MIDistr$density), lty=1, lwd=6, col=myredpurple)
    title('predicted MI distr', cex.main=2)
    legend('topright',c('sample MI', 'long-run MI'),lty=1,col=c(myyellow,myredpurple),lwd=4,cex=1.5)
    ##
    ## Diagnostics
    hist(meanSsamples[,1], xlim=c(0,3),ylab='mean spikecountsy')
    hist(meanSsamples[,2], xlim=c(0,3),ylab='mean spikecounts')
    matplot((MIsamples),type='l', lty=1,ylab='MI samples')
    matplot((llsamples[,]),type='l', lty=1,ylab='log-posterior')
    matplot((mcsamples[,1]),type='l', lty=1,ylab='samples of first freq')
    dev.off()
print(paste0('gamma parms: ',c(shapegamma,rategamma)))
mcsamples
}
