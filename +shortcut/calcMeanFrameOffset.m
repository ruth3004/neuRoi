function [frameOffsetArray,startPointList] = calcMeanFrameOffset(timeTraceMatArray,onsetThresh,nTrialPerOdor)
%Calculate frame offset from mean time trace for each odor
%   
missingOdors=2; %ACSF and Sponteneous activity is not aligned 

for n=1:length(timeTraceMatArray)-missingOdors*nTrialPerOdor %to not align ACSF and spont. activity. They`ll shift similar to last odor (TDCA)
meanTimeTrace(n,:)= mean(timeTraceMatArray{n}); 
responseOn= find(meanTimeTrace(n,:)>(onsetThresh*max(meanTimeTrace(n,:))));
onset(n)=responseOn(1);
end

x=numel(onset);
xx=reshape(onset(1:x-mod(x,nTrialPerOdor)),nTrialPerOdor, []);
y=sum(xx,1).'/nTrialPerOdor;

base=min(y);
frameOffsetArray=y-base;
startPointList=y;
fill= repelem(frameOffsetArray(end),missingOdors);
frameOffsetArray=ceil([frameOffsetArray ; fill'])';

fillStart= repelem(startPointList(end),missingOdors);
startPointList=ceil([startPointList ; fillStart'])';

end

