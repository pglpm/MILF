## Author: Battistin, Gonzalo Cogno, Porta Mana
<<<<<<< HEAD
## Last-Updated: 2021-09-09T10:12:53+0200
=======
## Last-Updated: 2021-08-03T19:30:11+0200
>>>>>>> 7f136e19af6d747aa66142a4deb2de6042270316
################
## Script for:
## - outputting samples of prior & posterior distributions
## - calculating posteriors
## Uses Dirichlet prior
################
## library('parallel')
## mycluster <- makeCluster(3)
#### Custom setup ####
## Colour-blind friendly palettes, from https://personal.sron.nl/~pault/
## (consider using khroma package instead)
## library('RColorBrewer')
## mypurpleblue <- '#4477AA'
## myblue <- '#66CCEE'
## mygreen <- '#228833'
## myyellow <- '#CCBB44'
## myred <- '#EE6677'
## myredpurple <- '#AA3377'
## mygrey <- '#BBBBBB'
## mypalette <- c(myblue, myred, mygreen, myyellow, myredpurple, mypurpleblue, mygrey, 'black')
## palette(mypalette)
## barpalette <- colorRampPalette(c(mypurpleblue,'white',myredpurple),space='Lab')
## barpalettepos <- colorRampPalette(c('white','black'),space='Lab')
library('data.table')
library('khroma')
palette(colour('bright')())
## palette(colour('muted')())
library('ggplot2')
library('ggthemes')
theme_set(theme_bw(base_size=18))
scale_colour_discrete <- scale_colour_bright
#library('cowplot')
library('png')
library('foreach')
##library('ash')
#library('extraDistr')
options(bitmapType='cairo')
pdff <- function(filename){pdf(file=paste0(filename,'.pdf'),paper='a4r',height=11.7,width=16.5)} # to output in pdf format
pngf <- function(filename,res=300){png(file=paste0(filename,'.png'),height=11.7*1.2,width=16.5)} # to output in png format
##
library('foreach')
library('doFuture')
registerDoFuture()
library('doRNG')

source('funcmodel3randomized.R')
##
plan(sequential)
plan(multisession, workers = 3L)
resu <- foreach(chunk=0:2, .inorder=F, .packages=c('data.table','foreach'))%dorng%{ postsamples(chunk)}







tsamples <- mcsamples
dim(tsamples) <- c(nrow(mcsamples),2,(maxS1+1))
matplot(x=0:maxS,y=t(tsamples[1:10,1,1:maxS1]),type='l',lty=1,col=paste0(mygrey,'88'))

tmeansamples <- c(apply(tsamples[,1,1:maxS],1,function(x){sum(x * (0:maxS))}))
hist(tmeansamples)

hist(tsamples[,1,-(1:(maxS1+1))])

tmeansamples2 <- mcsamples[,]
dim(tsamples) <- c(nrow(mcsamples),2,(maxS1+2))
matplot(x=0:maxS,y=t(tsamples[1:10,1,1:maxS1]),type='l',lty=1,col=paste0(mygrey,'88'))



gfactor <- function(mean,pstrength,sfreq){
    tgeo <- pstrength*geomd(x=mean,y=0:maxS)
    exp(sum(lgamma(tgeo+sfreq)-lgamma(tgeo))+lgamma(sum(tgeo))-lgamma(sum(tgeo+sfreq)))
}

postggamma <- function(mean,pstrength,sfreq,pmean,psd){
    sgamma <- (pmean/psd)^2
    rgamma <- sqrt(sgamma)/psd
    gfactor(mean,pstrength,sfreq)*dgamma(x=mean,shape=sgamma,rate=rgamma)
}

normalizerows(sampleFreqs) %*% (0:maxS)

matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){gfactor(x,100,sampleFreqs[2,])}),type='l')

matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,]*0,0.6,0.5)}),type='l',add=F)
matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,]/80,0.6,0.5)}),type='l',add=F)
matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,],0.6,0.5)}),type='l',add=F)



## test with poisson instead of geometric
gfactor <- function(mean,pstrength,sfreq){
    rt <- 2
    tgeo <- pstrength*normalize(dgamma(x=0:maxS,shape=rt,rate=rt/mean))
    exp(sum(lgamma(tgeo+sfreq)-lgamma(tgeo))+lgamma(sum(tgeo))-lgamma(sum(tgeo+sfreq)))
}
postggamma <- function(mean,pstrength,sfreq,pmean,psd){
    sgamma <- (pmean/psd)^2
    rgamma <- sqrt(sgamma)/psd
    gfactor(mean,pstrength,sfreq)*dgamma(x=mean,shape=sgamma,rate=rgamma)
}
matplot(xgrid <- seq(0.001,3,length.out=100),sapply(xgrid,function(x){gfactor(x,100,sampleFreqs[2,])}),type='l')

normalizerows(sampleFreqs) %*% (0:maxS)


matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,]*0,0.6,0.5)}),type='l',add=F)
matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,]/80,0.6,0.5)}),type='l',add=F)
matplot(xgrid <- seq(0,3,length.out=100),sapply(xgrid,function(x){postggamma(x,100,sampleFreqs[1,],0.6,0.5)}),type='l',add=F)





plan(sequential)
plan(multisession, workers = 3L)
tme <- 0.6
tsd <- 0.5
tshape <- (tme/tsd)^2
trate <- sqrt(tshape)/tsd
tmeans <- rgamma(n=1000, shape=tshape, rate=trate)
hist(tmeans)
tsamples <- foreach(i=1:1000, .inorder=F, .combine=rbind)%dorng%{
    rdirch(n=1,alpha=100*geomd(x=tmeans[i], y=0:maxS))
}
matplot(x=0:maxS,y=t(mcsamples[1:10,]),type='l',lty=1,col=paste0(mygrey,'88'))

tmeansamples <- c(apply(tsamples,1,function(x){sum(x * (0:maxS))}))
hist(tmeansamples)

hist(tmeans)

matplot(x=0:maxS,y=t(tsamples[1:5,]),type='l',lty=1)

## library('parallel')
## mycluster <- makeCluster(3)
library('nimble')
    dlogsmoothmean <- nimbleFunction(
        run = function(x=double(1), alphas=double(1), powerexp=double(0), shapegamma=double(0), rategamma=double(0), smatrix=double(2), normstrength=double(0, default=1000), log=integer(0, default=0)){
            returnType(double(0))
            tx <- sum(x)
            f <- exp(x)/sum(exp(x))
            dmean <- inprod(f,0:(length(f)-1))
            logp <- sum((alphas+1) * log(f)) + (shapegamma-1)*log(dmean) - (rategamma*dmean)^powerexp - sum((log(f) %*% smatrix)^2) - normstrength  * tx^2 
            if(log) return(logp)
            else return(exp(logp))
        })
    assign('dlogsmoothmean', dlogsmoothmean, envir = .GlobalEnv)
##
runcode <- function(chunk,seed=147){
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
## library('doFuture')
## registerDoFuture()
## library('doRNG')
library('ash')
#library('nimble')
#library('extraDistr')
options(bitmapType='cairo')
pdff <- function(filename){pdf(file=paste0(filename,'.pdf'),paper='a4r',height=11.7,width=16.5)} # to output in pdf format
pngf <- function(filename,res=300){png(file=paste0(filename,'.png'),height=11.7*1.2,width=16.5,units='in',res=res,pointsize=36)} # to output in png format
#### End custom setup ####
##
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
##
t2f <- function(t){exp(t)/sum(exp(t))}
    library('nimble')
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
#chunk <- 1
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
<<<<<<< HEAD
    ## print('HEY')
=======
    print('HEY')
>>>>>>> 7f136e19af6d747aa66142a4deb2de6042270316
    priorMeanSpikes <- 1.6 # 0.2 = 5Hz * (40Hz/1000s)
    priorSdSpikes <- 0.15 # 0.2 = 5Hz * (40Hz/1000s)
    shapegamma <- (priorMeanSpikes/priorSdSpikes)^2
    rategamma <- sqrt(shapegamma)/priorSdSpikes
    ## shapegamma <- 1
    ## rategamma <- 1
    powergamma <- 1
    print('data')
    print(c(chunk,shapegamma, rategamma, powergamma))
    prioralphas <- rep(0,maxS1)
    smoothness <- 2
    smoothm <- t(diff(diag(maxS1),differences=2))
    ##
    chunkIndices <- as.matrix(read.csv(sampleIndexFile,header=FALSE,sep=','))[chunk+(chunk==0),]
    sampleData <- longrunData[chunkIndices,]
    ##print(str(sampleData))
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
    dlogsmoothmean <- nimbleFunction(
        run = function(x=double(1), alphas=double(1), powerexp=double(0), shapegamma=double(0), rategamma=double(0), smatrix=double(2), normstrength=double(0, default=1000), log=integer(0, default=0)){
            returnType(double(0))
            tx <- sum(x)
            f <- exp(x)/sum(exp(x))
            dmean <- inprod(f,0:(length(f)-1))
            logp <- sum((alphas+1) * log(f)) + (shapegamma-1)*log(dmean) - (rategamma*dmean)^powerexp - sum((log(f) %*% smatrix)^2) - normstrength  * tx^2 
            if(log) return(logp)
            else return(exp(logp))
        })
    assign('dlogsmoothmean', dlogsmoothmean, envir = .GlobalEnv)
    #Cdlogsmoothmean <- compileNimble(dlogsmoothmean)
    lnprob <- nimbleCode({
        for(i in 1:nStimuli){
            X[i,1:maxS1] ~ dlogsmoothmean(alphas=postalphas[i,1:maxS1], powerexp=powergammac, shapegamma=shapegammac, rategamma=rategammac, smatrix=smatrixc[1:maxS1,1:smoothdim], normstrength=1000)
        }
    })
    ##
    constants <- list(postalphas=sampleFreqs+prioralphas, powergammac=powergamma, shapegammac=shapegamma, rategammac=rategamma, smoothdim=ncol(smoothm), smatrixc=smoothness*smoothm, nStimuli=nStimuli, maxS1=maxS1, maxS=maxS)
    ##
    initX <- normalizerows(sampleFreqs+prioralphas+1)
    initX <- log(initX) - rowSums(log(initX))/maxS1
    inits <- list(X=initX+rnorm(length(initX)))
    ##
    ##
    model2 <- nimbleModel(code=lnprob, name='model2', constants=constants, inits=inits, data=list())
    Cmodel2 <- compileNimble(model2, showCompilerOutput = TRUE, resetFunctions = TRUE)
    confmodel2 <- configureMCMC(Cmodel2, nodes=NULL)
    ## confmodel2$addSampler(target='X', type='AF_slice', control=list(sliceAdaptFactorMaxIter=20000, sliceAdaptFactorInterval=1000, sliceAdaptWidthMaxIter=1000, sliceMaxSteps=100, maxContractions=100))
    for(i in 1:nStimuli){
        confmodel2$addSampler(target=paste0('X[',i,',]'), type='AF_slice', control=list(sliceAdaptFactorMaxIter=10000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    }
    confmodel2$addMonitors('logProb_X')
    confmodel2
    mcmcsampler <- buildMCMC(confmodel2)
    Cmcmcsampler <- compileNimble(mcmcsampler, resetFunctions = TRUE)
    mcsamples <- runMCMC(Cmcmcsampler, nburnin=10000, niter=20000, thin=10, setSeed=seed)
    nDraws <- nrow(mcsamples)
    llsamples <- mcsamples[,-(1:(maxS1*2)),drop=F]
    ##
    condfreqSamples <- t(apply(mcsamples[,1:(maxS1*2)],1,function(x){
        dim(x) <- c(2,maxS1)
        Nx2f(x)}))
    dim(condfreqSamples) <- c(nrow(mcsamples),nStimuli,maxS1)
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
    maxX <- 8
    if(chunk==0){psign <- 1}else{psign <- -1}
    pdff(paste0('testsummaryN',chunk))
    matplot(x=nspikesVals, y=t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),1,]),
            type='l', lty=1, lwd=2, col=paste0(mygrey,'66'), ylim=c(min(0,psign),1),  xlim=c(0,maxX), xlab='spikes/bin', ylab='freq', cex.lab=2, cex.axis=2)
        matplot(x=nspikesVals, y=psign*t(condfreqSamples[round(seq(1,nDraws,length.out=nPlotSamples)),2,]),
                type='l', lty=1, lwd=1, col=paste0(mygrey,'66'), add=TRUE)
    ##
    if(pflag==0){matplot(x=nspikesVals, y=t(normalizerows(sampleFreqs)*c(1,psign)),
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
    hist(meanSsamples[,1], xlim=c(0,3),ylab='mean spikecounts')
    hist(meanSsamples[,2], xlim=c(0,3),ylab='mean spikecounts')
    matplot((MIsamples),type='l', lty=1,ylab='MI samples')
    matplot((llsamples[,]),type='l', lty=1,ylab='log-posterior')
    matplot((mcsamples[,1]),type='l', lty=1,ylab='samples of first freq')
    dev.off()
    NULL
}
##
##
## plan(sequential)
## plan(multisession, workers = 3L)
## clusterExport(cl=mycluster, c('runcode'))
## alloutput <- parLapply(cl = mycluster, X = 0:2, fun = function(chunk){runcode(chunk)})
## stopCluster(mycluster)

corrp <- matrix(0,11,4)
dimnames(corrp) <- list(paste0('count',0:10), paste0('stimulus_',0:1,'_then_',rep(0:1,each=2)))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
for(i in 2:nrow(longrunData)){
    batch <- as.matrix(longrunData[(i-1):i])
    group <- 1+sum((1:2)*batch[,2])
    corrp[batch[2,1]+1,group] <- corrp[batch[2,1]+1,group] + 1
}
corrf <- t(t(corrp)/colSums(corrp))
##
matplot(0:10,corrf,type='l',lty=c(1,2), lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency')
legend('topright',colnames(corrf),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
##
##
rcorrp <- matrix(0,11,4)
dimnames(rcorrp) <- list(paste0('count',0:10), paste0('stimulus_',0:1,'_then_',rep(0:1,each=2)))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
##
randomlrd <- longrunData
for(i in 0:1){
whichstim <- which(longrunData$stimulus==i)
randomlrd[whichstim] <- longrunData[sample(whichstim)]
}
for(i in 2:nrow(longrunData)){
    batch <- as.matrix(randomlrd[(i-1):i])
    group <- 1+sum((1:2)*batch[,2])
    rcorrp[batch[2,1]+1,group] <- rcorrp[batch[2,1]+1,group] + 1
}
rcorrp <- rcorrp
rcorrf <- t(t(rcorrp)/colSums(rcorrp))
##
pdff('2step_condfreqs')
matplot(0:10,corrf,type='l',lty=c(1,2), lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='data')
legend('topright',paste0(colnames(corrf),': ',colSums(corrp)),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
matplot(0:10,rcorrf,type='l',lty=c(1,2), lwd=1,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus')
for(sample in 1:10){
    rcorrp <- matrix(0,11,4)
    dimnames(rcorrp) <- list(paste0('count',0:10), paste0('stimulus_',0:1,'_then_',rep(0:1,each=2)))
    batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
    for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
    ##
    randomlrd <- longrunData
    for(i in 0:1){
        whichstim <- which(longrunData$stimulus==i)
        randomlrd[whichstim] <- longrunData[sample(whichstim)]
    }
    for(i in 2:nrow(longrunData)){
        batch <- as.matrix(randomlrd[(i-1):i])
        group <- 1+sum((1:2)*batch[,2])
        rcorrp[batch[2,1]+1,group] <- rcorrp[batch[2,1]+1,group] + 1
    }
    rcorrp <- rcorrp
    rcorrf <- t(t(rcorrp)/colSums(rcorrp))
    matplot(0:10,rcorrf,type='l',lty=c(1,2), lwd=1,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus',add=T)
}
legend('topright',colnames(rcorrf),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
dev.off()



#### corr now & future
fcorrp <- matrix(0,11,4)
dimnames(fcorrp) <- list(paste0('count',0:10), paste0('stimulus_now',0:1,'_then_',rep(0:1,each=2)))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
for(i in 1:ncol(batches)){colnames(fcorrp)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
for(i in 1:(nrow(longrunData)-1)){
    batch <- as.matrix(longrunData[i:(i+1)])
    group <- 1+sum((1:2)*batch[,2])
    fcorrp[batch[1,1]+1,group] <- fcorrp[batch[1,1]+1,group] + 1
}
fcorrf <- t(t(fcorrp)/colSums(fcorrp))
##
matplot(0:10,fcorrf,type='l',lty=c(1,2), lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency')
legend('topright',colnames(fcorrf),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
##
##
rfcorrp <- matrix(0,11,4)
dimnames(rfcorrp) <- list(paste0('count',0:10), paste0('stimulus_',0:1,'_then_',rep(0:1,each=2)))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
for(i in 1:ncol(batches)){colnames(fcorrp)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
##
randomlrd <- longrunData
for(i in 0:1){
whichstim <- which(longrunData$stimulus==i)
randomlrd[whichstim] <- longrunData[sample(whichstim)]
}
for(i in 1:(nrow(longrunData)-1)){
    batch <- as.matrix(randomlrd[i:(i+1)])
    group <- 1+sum((1:2)*batch[,2])
    rfcorrp[batch[1,1]+1,group] <- rfcorrp[batch[1,1]+1,group] + 1
}
rfcorrp <- rfcorrp
rfcorrf <- t(t(rfcorrp)/colSums(rfcorrp))
##
pdff('2step_condfreqs_future')
matplot(0:10,fcorrf,type='l',lty=c(1,2), lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='data')
legend('topright',paste0(colnames(fcorrf),': ',colSums(fcorrp)),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
matplot(0:10,rfcorrf,type='l',lty=c(1,2), lwd=1,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus')
for(sample in 1:10){
    rfcorrp <- matrix(0,11,4)
    dimnames(rfcorrp) <- list(paste0('count',0:10), paste0('stimulus_',0:1,'_then_',rep(0:1,each=2)))
    batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%do%{c(i1,i2)},2)
    for(i in 1:ncol(batches)){colnames(fcorrp)[1+sum(c(1,2)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
    ##
    randomlrd <- longrunData
    for(i in 0:1){
        whichstim <- which(longrunData$stimulus==i)
        randomlrd[whichstim] <- longrunData[sample(whichstim)]
    }
    for(i in 1:(nrow(longrunData)-1)){
        batch <- as.matrix(randomlrd[i:(i+1)])
        group <- 1+sum((1:2)*batch[,2])
        rfcorrp[batch[1,1]+1,group] <- rfcorrp[batch[1,1]+1,group] + 1
    }
    rfcorrp <- rfcorrp
    rfcorrf <- t(t(rfcorrp)/colSums(rfcorrp))
    matplot(0:10,rfcorrf,type='l',lty=c(1,2), lwd=1,col=c(myred,myredpurple,myblue,mypurpleblue),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus',add=T)
}
legend('topright',colnames(rfcorrf),lty=c(1,2),lwd=3,col=c(myred,myredpurple,myblue,mypurpleblue))
dev.off()







corr3p <- matrix(0,11,8)
dimnames(corr3p) <- list(paste0('count',0:10), paste0('stimulus_',1:8))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%:%foreach(i3=0:1,.combine=c)%do%{c(i1,i2,i3)},3)
for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2,4)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
for(i in 3:nrow(longrunData)){
    batch <- as.matrix(longrunData[(i-2):i])
    group <- 1+sum(c(1,2,4)*batch[,2])
    corr3p[batch[3,1]+1,group] <- corr3p[batch[3,1]+1,group] + 1
}
corr3f <- t(t(corr3p)/colSums(corr3p))
##
matplot(0:10,corr3f,type='l',lty=c(1,2,3,4), lwd=3,col=c(myredpurple,mypurpleblue),xlab='spike count',ylab='long-run relative frequency')
legend('topright',colnames(corr3f),lty=c(1,2,3,4),lwd=3,col=c(myredpurple,mypurpleblue))
##
##
rcorr3p <- matrix(0,11,8)
dimnames(rcorr3p) <- list(paste0('count',0:10), paste0('stimulus_',1:8))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%:%foreach(i3=0:1,.combine=c)%do%{c(i1,i2,i3)},3)
for(i in 1:ncol(batches)){colnames(rcorr3p)[1+sum(c(1,2,4)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
##
randomlrd <- longrunData
for(i in 0:1){
whichstim <- which(longrunData$stimulus==i)
randomlrd[whichstim] <- longrunData[sample(whichstim)]
}
for(i in 3:nrow(longrunData)){
    batch <- as.matrix(randomlrd[(i-2):i])
    group <- 1+sum(c(1,2,4)*batch[,2])
    rcorr3p[batch[3,1]+1,group] <- rcorr3p[batch[3,1]+1,group] + 1
}
rcorr3p <- rcorr3p
rcorr3f <- t(t(rcorr3p)/colSums(rcorr3p))
##
pdff('3step_condfreqs')
matplot(0:10,corr3f,type='l',lty=c(1,2,3,4), lwd=3,col=rep(c(myredpurple,mypurpleblue),each=4),xlab='spike count',ylab='long-run relative frequency',main='data')
legend('topright',paste0(colnames(corr3f),': ',colSums(corr3p)),lty=c(1,2,3,4),lwd=3,col=rep(c(myredpurple,mypurpleblue),each=4))
matplot(0:10,rcorr3f,type='l',lty=c(1,2,3,4), lwd=1,col=rep(c(myredpurple,mypurpleblue),each=4),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus')
for(sample in 1:10){
    rcorr3p <- matrix(0,11,8)
    ## dimnames(rcorr3p) <- list(paste0('count',0:10), paste0('stimulus_',1:8))
    ## batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%:%foreach(i3=0:1,.combine=c)%do%{c(i1,i2,i3)},3)
    ## for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2,4)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
    ##
    randomlrd <- longrunData
    for(i in 0:1){
        whichstim <- which(longrunData$stimulus==i)
        randomlrd[whichstim] <- longrunData[sample(whichstim)]
    }
    for(i in 3:nrow(longrunData)){
        batch <- as.matrix(randomlrd[(i-2):i])
        group <- 1+sum(c(1,2,4)*batch[,2])
        rcorr3p[batch[3,1]+1,group] <- rcorr3p[batch[3,1]+1,group] + 1
    }
    rcorr3p <- rcorr3p
    rcorr3f <- t(t(rcorr3p)/colSums(rcorr3p))
    matplot(0:10,rcorr3f,type='l',lty=c(1,2,3,4), lwd=1,col=rep(c(myredpurple,mypurpleblue),each=4),xlab='spike count',ylab='long-run relative frequency',main='randomized within each stimulus',add=T)
}
legend('topright',colnames(corr3f),lty=c(1,2,3,4),lwd=3,col=rep(c(myredpurple,mypurpleblue),each=4))
dev.off()






















paste0('stimulusseq_',0:1,rep(0:1,each=2),rep(0:1,each=4))

corr3p <- matrix(0,11,8)
dimnames(corr3p) <- list(paste0('count',0:10), paste0('stimulusseq_',0:1,rep(0:1,each=2),rep(0:1,each=4)))
batches <- matrix(foreach(i1=0:1,.combine=c)%:%foreach(i2=0:1,.combine=c)%:%foreach(i3=0:1,.combine=c)%do%{c(i1,i2,i3)},3)
for(i in 1:ncol(batches)){colnames(corr3p)[1+sum(c(1,2,4)*batches[,i])] <- paste0('seq_',paste0(batches[,i],collapse="_"))}
for(i in 3:nrow(longrunData)){
    batch <- as.matrix(longrunData[(i-2):i])
    group <- 1+sum(c(1,2,4)*batch[,2])
    corr3p[batch[3,1]+1,group] <- corr3p[batch[3,1]+1,group] + 1
}

corr3f <- t(t(corr3p)/colSums(corr3p))

matplot(0:10,corr3f,type='l',lty=c(1,2,3,4), lwd=2,col=coluse <- rep(c(myred,myblue),each=4),xlab='spike count',ylab='long-run relative frequency')
legend('topright',colnames(corr3f),lty=c(1,2,3,4),lwd=3,col=coluse)
