function [neuronsON] = findActiveNeurons(timeTraceMatArray,thresh)
 neuronList=[];
% neuronList=zeros(length(timeTraceMatArray{1}),length(timeTraceMatArray));
    for n=1:length(timeTraceMatArray)         
        currentOdorTimeTrace= timeTraceMatArray{n};        
        for m=1:size(currentOdorTimeTrace,1)
            responseOn=[];
            responseOn= find(currentOdorTimeTrace(m,1:220)>thresh);
            if  ~isempty(responseOn)
                neuronList=[neuronList;m];
            end
        end 
    end
neuronsON=unique(neuronList);
end

