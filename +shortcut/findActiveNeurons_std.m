function [neuronsON] = findActiveNeurons_std(timeTraceMatArray,thresh)
 neuronList=[];
% neuronList=zeros(length(timeTraceMatArray{1}),length(timeTraceMatArray));
    for n=1:length(timeTraceMatArray)         
        currentOdorTimeTrace= timeTraceMatArray{n};        
        for m=1:size(currentOdorTimeTrace,1)
            responseOn=[];
            if max(currentOdorTimeTrace(m,1:220))>thresh
%                 max(currentOdorTimeTrace(m,1:220))./nanstd(currentOdorTimeTrace(m,1:220))>thresh
               responseOn= 1;
                if  responseOn==1
                    neuronList=[neuronList;m];
                end
            end
        end 
    end
neuronsON=unique(neuronList);
end

