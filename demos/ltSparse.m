function [ltSparseness] = ltSparse(odorList,nTrialPerOdor,responseWindowLts,TimeTraceMatArray)
%To calculate the lifetimesparseness of a time trace array at a certain
%time window
 nOdor=length(odorList);
 responseInd = responseWindowLts(1):responseWindowLts(2);                
 patternArray = cellfun(@(x) max(x(:,responseInd),[],2),...
                   TimeTraceMatArray,'UniformOutput',false); 
               
for n=1:length(patternArray)
    trialMeanTimeTraceLts(n,:)=patternArray{n}; 
end
%Getting mean response for all odors by avergaging the trials
for m=1:length(odorList)
    odorTimeTrace= trialMeanTimeTraceLts(nTrialPerOdor*m-(nTrialPerOdor-1):nTrialPerOdor*m,:);
    meanLts(m,:) = mean (odorTimeTrace);
end   
meanLts=meanLts';     
ltSparseness=(1-(sum(meanLts(:,1:6),2)/(nOdor-2)).^2 ./sum(((meanLts(:,1:(nOdor-2))).^2)/(nOdor-2),2))/(1-1/(nOdor-2));        
end