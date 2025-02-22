## Author: PGL Porta Mana
## Last-Updated: 2021-08-03T10:05:39+0200
################
## Script to test Nimble

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
options(bitmapType='cairo')
pdff <- function(filename){pdf(file=paste0(filename,'.pdf'),paper='a4r',height=11.7,width=16.5)} # to output in pdf format
pngf <- function(filename,res=300){png(file=paste0(filename,'.png'),height=11.7*1.2,width=16.5,units='in',res=res,pointsize=36)} # to output in png format
library('nimble')

deregisterDistributions(c('dmynorm','rmynorm'))
dmynorm <- nimbleFunction(
    run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
        if(log) return(lp)
        else return(exp(lp))
        returnType(double(0))
    })
assign('dmynorm',dmynorm,envir=.GlobalEnv)
#assign('dlogsmoothmean', dlogsmoothmean, envir = .GlobalEnv)
#Cdlogsmoothmean <- compileNimble(dlogsmoothmean)
##
code <- nimbleCode({
    mean ~ dnorm(mean=0, sd=0.1)
    sd ~ dgamma(shape=2, rate=1)
    means[1:2] <- c(mean,mean)
    prec[1:2,1:2] <- diag(c(1/sd^2,1/(sd/100)^2))
    
    x[1:2] ~ dmnorm(mean=means[1:2], prec=prec[1:2,1:2])
    y[1:2] ~ dmynorm(mean=means[1:2], prec=prec[1:2,1:2])
})
##
constants <- list()
##
inits <- list(mean=0, sd=1)
##
modeldata <- list()
##
model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata)
Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
##
confmodel <- configureMCMC(Cmodel,nodes=NULL)
confmodel$addSampler(target=c('mean'), type='posterior_predictive')
confmodel$addSampler(target=c('sd'), type='posterior_predictive')
confmodel$addSampler(target=c('x[1:2]','y[1:2]'), type='AF_slice', control=list(sliceAdaptFactorMaxIter=1000, sliceAdaptFactorInterval=100, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
confmodel$setMonitors(c('x', 'y'))
##confmodel$setMonitors(c('x'))
confmodel
##
mcmc <- buildMCMC(confmodel)
Cmcmc <- compileNimble(mcmc, project= model, resetFunctions = TRUE)
test <- runMCMC(mcmc=Cmcmc,niter=2000,nburnin=1000)


##################################################
library('foreach')
library('doFuture')
##
parallelSamplesFun <- function(mymeansd){
    library('nimble')
    ##
##    deregisterDistributions('dmymnorm')
    dmymnorm <- nimbleFunction(
        run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
            if(log) return(lp)
            else return(exp(lp))
            returnType(double(0))
        })
    assign('dmymnorm',dmymnorm,envir=.GlobalEnv)
    ##
    code <- nimbleCode({
        mu ~ dnorm(mean=2, sd=meansd)
        means[1:2] <- c(mu, mu)
        prec[1:2,1:2] <- diag(c(1/1^2, 1/0.1^2))
        ##    
        x[1:2] ~ dmymnorm(mean=means[1:2], prec=prec[1:2,1:2])
    })
    ##
    constants <- list(meansd=mymeansd)
    inits <- list(mu=1, x=1:2)
    modeldata <- list()
    ##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata, dimensions=list(x=2, means=2, prec=c(2,2)), calculate=F)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    ##
    confmodel <- configureMCMC(Cmodel, nodes=NULL)
    confmodel$addSampler(target=c('mu'), type='posterior_predictive')
    confmodel$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    confmodel$setMonitors(c('mu','x','logProb_x'))
    confmodel
    ##
    confmodel$printSamplers(executionOrder=T)
    mcmc <- buildMCMC(confmodel)
    Cmcmc <- compileNimble(mcmc)
    samples <- runMCMC(mcmc=Cmcmc, niter=10000, nburnin=5000, thin=5)
    samples
}
##
plan(sequential)
plan(multisession, workers = 3)
results <- foreach(ii=c(1,10), .packages='nimble')%dopar%{parallelSamplesFun(ii)}




#### With dummy r-generator
##################################################
library('foreach')
library('doFuture')
registerDoFuture()
## library('parallel')
## mycluster <- makeCluster(3)
##
parallelSamplesFun <- function(XX){
    library('nimble')
    ##
    ##    deregisterDistributions('dmymnorm')
    dmymnorm <- nimbleFunction(
        run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
            if(log) return(lp)
            else return(exp(lp))
            returnType(double(0))
        })
    rmymnorm <- nimbleFunction(
        run = function(n=integer(0), mean=double(1), prec=double(2)){
            print('This function does not exist')
            return(Inf)
            returnType(double(1))
        })
    ## registerDistributions(list(
    ## dmymnorm = list(
    ##           BUGSdist = "dmymnorm(mean, prec)",
    ##           Rdist = "dmymnorm(mean, prec)",
    ##     pqAvail = FALSE,
    ##     types = c("value = double(1)", "mean = double(1)", "prec = double(2)")
    ##     )))
    assign('dmymnorm', dmymnorm, envir=.GlobalEnv)
    assign('rmymnorm', rmymnorm, envir=.GlobalEnv)
    ##
    code <- nimbleCode({
        x[1:2] ~ dmymnorm(mean=means[1:2], prec=prec[1:2,1:2])
    })
    ##
    constants <- list(means=rep(XX,2), prec=diag(c(1/1^2, 1/0.1^2)))
    inits <- list(x=1:2)
    modeldata <- list()
    ##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata, dimensions=list(x=2, means=2, prec=c(2,2)), calculate=F)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    ##
    confmodel <- configureMCMC(Cmodel, nodes=NULL)
    confmodel$addSampler(target='x', type='AF_slice')#, control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    confmodel$setMonitors(c('x','logProb_x'))
    confmodel
    ##
    confmodel$printSamplers(executionOrder=T)
    mcmc <- buildMCMC(confmodel)
    Cmcmc <- compileNimble(mcmc)
    samples <- runMCMC(mcmc=Cmcmc, niter=10, nburnin=5, inits=list(x=1:2), setSeed=147)
    samples
}
plan(sequential)
plan(multisession, workers = 3)
results3 <- foreach(XX=c(1,10), .packages='nimble')%dopar%{parallelSamplesFun(XX)}

##
results <- parLapply(cl = mycluster, X = c(1,10), parallelSamplesFun)

## Error in checkForRemoteErrors(val) : 
##   2 nodes produced errors; first error: In sizeAssignAfterRecursing: 'rmymnorm' is not available or its output type is unknown.
##  This occurred for: eigenBlock(model_x,1:2) <<- rmymnorm(=1,mean=model_means[1:2],prec=model_prec[1:2, 1:2])
##  This was part of the call:  {
##   eigenBlock(model_x,1:2) <<- rmymnorm(=1,mean=model_means[1:2],prec=model_prec[1:2, 1:2])
## }



    library('nimble')
    ##
    ##    deregisterDistributions('dmymnorm')
    ## dmymnorm <- nimbleFunction(
    ##     run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
    ##         if(log) return(lp)
    ##         else return(exp(lp))
    ##         returnType(double(0))
    ##     })
    ## rmymnorm <- nimbleFunction(
    ##     run = function(n=integer(0), mean=double(1), prec=double(2)){
    ##         print('This function does not exist')
    ##         return(Inf)
    ##         returnType(double(1))
    ##     })
    ## registerDistributions(list(
    ## dmymnorm = list(
    ##           BUGSdist = "dmymnorm(mean, prec)",
    ##           Rdist = "dmymnorm(mean, prec)",
    ##     pqAvail = FALSE,
    ##     types = c("value = double(1)", "mean = double(1)", "prec = double(2)")
    ##     )))
    ## assign('dmymnorm', dmymnorm, envir=.GlobalEnv)
    ## assign('rmymnorm', rmymnorm, envir=.GlobalEnv)
    ##
code <- nimbleCode({
    mu ~ dnorm(mean=0, sd=10)
    x ~ dnorm(mean=mu, sd=1)
    })
    ##
    constants <- list()
    inits <- list(mu=1)
    modeldata <- list(x=10)
    ##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata, calculate=F)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    ##
    confmcmc <- configureMCMC(Cmodel)
#    confmcmc$addSampler(target='x', type='AF_slice')#, control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    confmcmc$setMonitors(c('mu','x','logProb_x','logLik'))
    confmcmc
    ##
    confmcmc$printSamplers(executionOrder=T)
    mcmc <- buildMCMC(confmcmc)
Cmcmc <- compileNimble(mcmc)
Cmcmc$run(niter=10)
samples <- as.matrix(Cmcmc$mvSamples)

    samples <- runMCMC(mcmc=Cmcmc, niter=1000, nburnin=1000, inits=list(x=1:2), setSeed=147)
    samples
}
plan(sequential)
plan(multisession, workers = 3)
results3 <- foreach(XX=c(1,10), .packages='nimble')%dopar%{parallelSamplesFun(XX)}




##################################################
library('foreach')
library('doFuture')
registerDoFuture()
##
parallelSamplesFun <- function(XX){
    library('nimble')
    ##
##    deregisterDistributions('dmymnorm')
    dmymnorm <- nimbleFunction(
        run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
            if(log) return(lp)
            else return(exp(lp))
            returnType(double(0))
        })
    registerDistributions(list(
    dmymnorm = list(
              BUGSdist = "dmymnorm(mean, prec)",
              Rdist = "dmymnorm(mean, prec)",
        pqAvail = FALSE,
        types = c("value = double(1)", "mean = double(1)", "prec = double(2)")
        )))
    assign('dmymnorm', dmymnorm, envir=.GlobalEnv)
    ##
    code <- nimbleCode({
        mu ~ dnorm(mean=2, sd=meansd)
        means[1:2] <- c(mu, mu)
        ##    
        x[1:2] ~ dmymnorm(mean=means[1:2], prec=prec[1:2,1:2])
    })
    ##
    constants <- list(meansd=XX, prec=diag(c(1/1^2, 1/0.1^2)))
    inits <- list(mu=1, x=1:2)
    modeldata <- list()
    ##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata, dimensions=list(x=2, means=2, prec=c(2,2)), calculate=F)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    ##
    confmodel <- configureMCMC(Cmodel, nodes=NULL)
    confmodel$addSampler(target=c('mu'), type='posterior_predictive')
    confmodel$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    confmodel$setMonitors(c('mu','x','logProb_x'))
    confmodel
    ##
    confmodel$printSamplers(executionOrder=T)
    mcmc <- buildMCMC(confmodel)
    Cmcmc <- compileNimble(mcmc)
    samples <- runMCMC(mcmc=Cmcmc, niter=10000, nburnin=5000, thin=5, inits=list(mu=1, x=1:2))
    samples
}
##
plan(multisession, workers = 3)
results <- foreach(ii=c(1,10))%dopar%{parallelSamplesFun(ii)}



##################################################
library('foreach')
library('doFuture')
registerDoFuture()
##
##
plan(multisession, workers = 3)

results <- foreach(XX=c(1,10))%dopar%{
    library('nimble')
    ##
##    deregisterDistributions('dmymnorm')
    dmymnorm <- nimbleFunction(
        run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
            if(log) return(lp)
            else return(exp(lp))
            returnType(double(0))
        })
    registerDistributions(list(
    dmymnorm = list(
              BUGSdist = "dmymnorm(mean, prec)",
              Rdist = "dmymnorm(mean, prec)",
        pqAvail = FALSE,
        types = c("value = double(1)", "mean = double(1)", "prec = double(2)")
        )))
    assign('dmymnorm', dmymnorm, envir=.GlobalEnv)
    ##
    code <- nimbleCode({
        mu ~ dnorm(mean=2, sd=meansd)
        means[1:2] <- c(mu, mu)
        ##    
        x[1:2] ~ dmymnorm(mean=means[1:2], prec=prec[1:2,1:2])
    })
    ##
    constants <- list(meansd=XX, prec=diag(c(1/1^2, 1/0.1^2)))
    inits <- list(mu=1, x=1:2)
    modeldata <- list()
    ##
    model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata, dimensions=list(x=2, means=2, prec=c(2,2)), calculate=F)
    Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
    ##
    confmodel <- configureMCMC(Cmodel, nodes=NULL)
    confmodel$addSampler(target=c('mu'), type='posterior_predictive')
    confmodel$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    confmodel$setMonitors(c('mu','x','logProb_x'))
    confmodel
    ##
    confmodel$printSamplers(executionOrder=T)
    mcmc <- buildMCMC(confmodel)
    Cmcmc <- compileNimble(mcmc)
    samples <- runMCMC(mcmc=Cmcmc, niter=10000, nburnin=5000, thin=5, inits=list(mu=1, x=1:2))
    samples
}





plan(multisession, workers = 3)
results <- foreach(ii=c(1,10), .packages='nimble')%dopar%{parallelSamplesFun(ii)}
stopCluster(mycluster)



##
code2 <- nimbleCode({
    means[1:2] <- c(0, 1)
    prec[1:2,1:2] <- diag(c(1, 0.1))
    ##    
    x[1:2] ~ dmymnorm(mean=means[1:2], prec=prec[1:2,1:2])
})
##
constants <- list()
inits <- list(x=0:1)
modeldata <- list()
##
model2 <- nimbleModel(code=code2, name='model2', constants=constants, inits=inits, data=modeldata)
Cmodel2 <- compileNimble(model2, showCompilerOutput = TRUE, resetFunctions = TRUE)
##
confmodel2 <- configureMCMC(Cmodel2, nodes=NULL)
confmodel2$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=1000, sliceAdaptFactorInterval=100, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
confmodel2$addMonitors('x')
confmodel2
## ===== Monitors =====
## thin = 1: x
## ===== Samplers =====
## AF_slice sampler (1)
##   - x
##
mcmc2 <- buildMCMC(confmodel2)
samples <- runMCMC(mcmc=mcmc2,niter=2000,nburnin=1000,inits=list(x=0:1))
## Warning: running an uncompiled MCMC algorithm, use compileNimble() for faster execution.
## running chain 1...
## |-------------|-------------|-------------|-------------|
## |Error: user-defined distribution dmymnorm provided without random generation function.



## Check what the logProb actually are
##################################################
library('nimble')
##
dmymnorm <- nimbleFunction(
    run = function(x=double(1), mean=double(1), prec=double(2), log=integer(0, default=0)){ lp <- -sum(asRow(x-mean) %*% prec %*% asCol(x-mean))/2
        if(log) return(lp)
        else return(exp(lp))
        returnType(double(0))
    })
assign('dmymnorm',dmymnorm,envir=.GlobalEnv)
##
code <- nimbleCode({
    mean ~ dnorm(mean=0, sd=1)
    x ~ dnorm(mean=mean, sd=0.1)
})
##
constants <- list()
inits <- list()
modeldata <- list(x=-100)
##
model <- nimbleModel(code=code, name='model', constants=constants, inits=inits, data=modeldata)
Cmodel <- compileNimble(model, showCompilerOutput = TRUE, resetFunctions = TRUE)
##
confmodel <- configureMCMC(Cmodel,nodes=NULL)
confmodel$addSampler(target=c('mean','lsd'), type='posterior_predictive', control=list())
confmodel$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
confmodel$addSampler(target='y', type='posterior_predictive', control=list())
## confmodel$addSampler(target=c('mean','lsd'), type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
## confmodel$addSampler(target='x', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
## confmodel$addSampler(target='y', type='AF_slice', control=list(sliceAdaptFactorMaxIter=5000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
confmodel$setMonitors(c('mean','x','y','logProb_x','logProb_y'))
confmodel
confmodel$printSamplers(executionOrder=T)
## ===== Monitors =====
## thin = 1: mean, sd, x
## ===== Samplers =====
## posterior_predictive_branch sampler (2)
##   - mean
##   - sd
## AF_slice sampler (1)
##   - x
##
mcmc <- buildMCMC(confmodel)
#samples0 <- runMCMC(mcmc=mcmc,niter=20,nburnin=10,inits=list(mean=0, sd=1,x=0:1,y=0:1))
Cmcmc <- compileNimble(mcmc)
samplesS <- runMCMC(mcmc=Cmcmc,niter=10000,nburnin=5000,thin=5,inits=list(mean=0, lsd=0,x=0:1,y=0:1))
## Warning: running an uncompiled MCMC algorithm, use compileNimble() for faster execution.
## running chain 1...
## |-------------|-------------|-------------|-------------|
## |Error: user-defined distribution dmymnorm provided without random generation function.





debug(dmymnorm)
mcmc$run(100)

confmodel$setMonitors(c('X','logProb_X'))
    confmodel


confmodel <- configureMCMC(Cmodel)
    ## confmodel$addSampler(target='X', type='AF_slice', control=list(sliceAdaptFactorMaxIter=20000, sliceAdaptFactorInterval=1000, sliceAdaptWidthMaxIter=1000, sliceMaxSteps=100, maxContractions=100))
    ## for(i in 1:nStimuli){
    ##     confmodel$addSampler(target=paste0('X[',i,',]'), type='RW_', control=list(sliceAdaptFactorMaxIter=10000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
        ## confmodel$addSampler(target=paste0('X[',i,',]'), type='AF_slice', control=list(sliceAdaptFactorMaxIter=10000, sliceAdaptFactorInterval=500, sliceAdaptWidthMaxIter=500, sliceMaxSteps=100, maxContractions=100))
    ## }
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
    pdff(paste0('testsummaryNv2random_',chunk))
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
NULL
##
##
## plan(sequential)
## plan(multisession, workers = 3L)
## clusterExport(cl=mycluster, c('runcode'))
## alloutput <- parLapply(cl = mycluster, X = 0:2, fun = function(chunk){runcode(chunk)})
## stopCluster(mycluster)

