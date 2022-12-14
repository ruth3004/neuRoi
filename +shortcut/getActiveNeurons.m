function [timeTraceDfMatListChosen] = getActiveNeurons(timeTraceDfMatListFinal,neuronsON)
    for n=1:length(timeTraceDfMatListFinal)
        currentOdor=timeTraceDfMatListFinal{n};
        currentOdorON=[];
        for m=1:length(neuronsON)
            currentOdorON=[currentOdorON;currentOdor(neuronsON(m),:)];
        end   
        timeTraceDfMatListChosen{n}=currentOdorON;
    end       
end

