%% Clear variables
clear all
close all
%% File Paths

resultDir = 'W:\scratch\gfriedri\montruth\2P_RawData\2022-04-26\f3\results';
expName = '20220426_RM0008_130hpf_fP1_f3';
expFilePath = fullfile(resultDir,sprintf('experimentConfig_%s.mat',expName));
foo = load(expFilePath);
myexp = foo.myexp;
disp(myexp.expInfo)
fileNameArray = myexp.rawFileList;
% Sort file names by odor
nTrialPerOdor = 3;
odorList = myexp.expInfo.odorList;
fileNameArraySorted = shortcut.sortFileNameArray(fileNameArray,'odor',odorList);


%% Load time trace matrices and calculate df/fs
for planeNum = 1:4
planeString = NrModel.getPlaneString(planeNum);
traceResultDir = fullfile(resultDir,'time_trace', ...
                         planeString);



traceResultArray = struct('timeTraceMat',{},'roiArray',{},...
                          'roiFilePath',{},'rawFilePath',{});
appendix = sprintf('_frame%dtoInfby4',planeNum);
for k=1:length(fileNameArraySorted)
    fileName = fileNameArraySorted{k};
    timeTraceFilePath = shortcut.getTimeTraceFilePath(traceResultDir,fileName,appendix);
    foo = load(timeTraceFilePath);
    traceResultArray(k) = foo.traceResult;
end

timeTraceMatList = {};
for k=1:length(traceResultArray)
    timeTraceMatList{k} = traceResultArray(k).timeTraceMat;
end
% Calculate dF/F from raw traces

dfOption1 = struct('intensityOffset',-10,...
                  'fZeroWindow',100:130,...
                  'fZeroPercent',0.5,...
                  'gaussN',3,...
                  'gaussAlpha',2.5);
dfOption2 = struct('intensityOffset',-10,...
                  'fZeroWindow',50:80,...
                  'fZeroPercent',0.5,...
                  'gaussN',3,...
                  'gaussAlpha',2.5);
              
for k= 1:24
    timeTraceDfMatList{k} = ...
        analysis.getTimeTraceDf(timeTraceMatList{k},dfOption1);
    nNeuron = size(timeTraceDfMatList{k},1);
    timeTraceDfMatList{k} = [repmat(0,nNeuron,15),timeTraceDfMatList{k}(:,1:end-15)];
end 
              
% Save time trace
timeTraceDataFilePath = fullfile(traceResultDir, ...
                           'timetrace.mat');
save(timeTraceDataFilePath,'timeTraceMatList','timeTraceDfMatList','odorList')

end
% %% Plot heat map
% zlim = [0 20];
% nCol = length(odorList)+1;
% nRow = nTrialPerOdor;
% nSubplot = length(timeTraceDfMatList);
% indMat = reshape(1:nRow*nCol,nCol,nRow).';
% 
% figWidth = 1800;
% figHeight = 300*nRow;
% fig = figure('InnerPosition',[200 500 figWidth figHeight]);
% for k=1:nSubplot
%     subplot(nRow,nCol,indMat(k))
%     imagesc(timeTraceDfMatList{k})
%     % imagesc(timeTraceMatList{k})
%     % imagesc(traceResultArray(k).timeTraceMat)
%     % ax.Visible = 'off';
%     if mod(k,nRow) == 1
%         ax = gca;
%         odor = shortcut.getOdorFromFileName(fileNameArraySorted{k});
%         title(odor);
%         set(get(ax,'Title'),'Visible','on');
%     end
%     %caxis(zlim)
% end
% subplot(nRow,nCol,indMat(nSubplot+1))
% %caxis(zlim)
% colorbar('Location','west')
% axis off
% 
% 
% %% Calculate average time trace for each odor
% [timeTraceAvgArray,timeTraceSemArray] = shortcut.calcTimeTraceAvg(timeTraceDfMatList,nTrialPerOdor);
% timeTraceAvgDataFilePath = fullfile(traceResultDir, ...
%                            'timetraceAvg.mat');
% save(timeTraceAvgDataFilePath,'timeTraceAvgArray','timeTraceSemArray','odorList')
% 
% %% Plot average time trace
% frameRate = 7.5;
% tvec = (1:size(timeTraceAvgArray{1},2))/frameRate;
% nOdor = length(timeTraceAvgArray);
% fig = figure;
% axArray = gobjects(1,nOdor);
% yLimit = [-0.1 0.7];
% for k=1:nOdor
%     subplot(nOdor,1,k)
%     axArray(k) = gca;
%     plot(timeTraceAvgArray{k})
%     %boundedline(tvec,timeTraceAvgArray{k},timeTraceSemArray{k})
%     % errorbar(tvec,timeTraceAvgArray{k},timeTraceSemArray{k})
%     ylim(yLimit)
%     if k<nOdor
%         set(gca,'XTick',[]);
%     end
%     odor = odorList(k);
%     ylabel(odor)
% end
% linkaxes(axArray,'xy')
% xlabel('Frames')
% Get all the timetrace.mat files 
%% Concatanate all the planes
obAvg=[];
dayNum = length(resultDir);
obAvg = struct('timeTraceDfMatList',{},'timeTraceMatList',{},'odorList',{});
    
for planeNum = 1:4
    planeString = NrModel.getPlaneString(planeNum);
    traceResultDir = fullfile(resultDir,'time_trace', ...
                              planeString);     
        if exist(traceResultDir,'dir')                    
       obAvg = [obAvg; load(fullfile(traceResultDir,'timetrace.mat'))];  
        end 
end


% Concatanate and save all the time traces from all experiment 
 
 for tt=1:24
     trial=[];
     for aa= 1:length(obAvg)
         exp= obAvg(aa).timeTraceDfMatList;
         if tt==1 && aa==1
            trial= exp{tt};
         else
            trial= [trial; exp{tt}];
         end
     end
     timeTraceDfMatListFinal{tt}=trial;
 end
%% Cut and shift time traces so that start points of odor stimuli
%% are aligned

cutWindow = 106:375;
cutTimeTraceMatArray = {};
for k=1:length(timeTraceDfMatListFinal)
    odorInd = ceil(k/nTrialPerOdor);
    timeTraceMat = timeTraceDfMatListFinal{k};
    cutTimeTraceMatArray{k} = timeTraceMat(:,cutWindow);
end
% 
%% Plot cutted time trace
frameRate = 7.5;
zlim = [0 1];
nOdor = length(odorList);
shortcut.plotTimeTraceHeatmap(cutTimeTraceMatArray,fileNameArraySorted, ...
                              nOdor,nTrialPerOdor,frameRate,zlim)

% 
%% Calculate and plot mean time traces

clear meanTimeTrace trialMeanTimeTrace
for n=1:length(cutTimeTraceMatArray)
    cutMeanTimeTraceMat=cutTimeTraceMatArray{n};   
    trialMeanTimeTrace(n,:)=mean(cutMeanTimeTraceMat);
end

for m=1:length(myexp.expInfo.odorList)
    odorTimeTrace= trialMeanTimeTrace(myexp.expInfo.nTrial*m-(myexp.expInfo.nTrial-1):myexp.expInfo.nTrial*m,:);
    meanTimeTrace(m,:) = mean (odorTimeTrace);
end

fig = figure;
hold on
for ii = 1:length(myexp.expInfo.odorList)
 plot(meanTimeTrace(ii,:))
end
ticks=[7.5:7.5:300];
for qqq=1:length(ticks)
    xLabels{qqq}=num2str(ticks(qqq)/7.5);
end    
set(gca,'XTick',ticks,'XTickLabel',xLabels)
xlabel('Time (sec)')
legend(myexp.expInfo.odorList)



%% Plot the cut mean time traces in separate graphs
nOdor = size(meanTimeTrace,1);
fig = figure;
axArray = gobjects(1,nOdor);
yLimit = [-0.05 0.5];
for k=1:nOdor
    subplot(nOdor,1,k)
    axArray(k) = gca;
    plot(meanTimeTrace(k,:))
    ylim(yLimit)
    odor = odorList(k);
    ylabel(odor)
    
    if k<nOdor
        set(gca,'XTick',[]);
    else
    ticks=[7.5:7.5:810];
    
    for qqq=1:length(ticks)
        xLabels{qqq}=num2str(ticks(qqq)/7.5);
    end    
    set(gca,'XTick',ticks,'XTickLabel',xLabels)
    end
end
linkaxes(axArray,'xy')
xlim([0 size(meanTimeTrace,2)])
xlabel('Time (sec)')
%% Calculate correlation matrix for average response pattern
nOdor = length(odorList);
nTrial = length(cutTimeTraceMatArray);
responseWindow = floor([5.4 11] * 7.5); %[5.4 11] is the window to select in seconds
responseInd = responseWindow(1):responseWindow(2);
patternArray = cellfun(@(x) mean(x(:,responseInd),2),...
                       cutTimeTraceMatArray,'UniformOutput',false);


%%%%
corrMat = zeros(nTrial,nTrial);
sm=0;
for ind=1:nTrial
    for jnd=ind:nTrial
        corrVec = analysis.calcPatternCorrelation(...
            patternArray{ind},...
            patternArray{jnd},sm);
        corrMat(ind,jnd) = corrVec;
    end
end

% plot
fig = figure;
imagesc(helper.makeSymmetricMat(corrMat))
% caxis([0 1])
trialNumVec = linspace(ceil(nTrialPerOdor/2),nTrial-floor(nTrialPerOdor/2),nOdor);
xticks(trialNumVec)
xticklabels(odorList)
set(gca,'xaxisLocation','top')
set(gca,'XTick',[])
yticks(trialNumVec)
yticklabels(odorList)
colorbar
set(gca, 'FontSize', 10)
%colormap jet
caxis([0 1])

%% Calculate lifetime sparseness   

responseWindowLts = floor([5.4 7.6] * 7.5);   
ltSparseness= ltSparse(odorList,nTrialPerOdor,responseWindowLts,cutTimeTraceMatArray);
meanLtSparse=nanmean(ltSparseness);
semltSparse=nanstd(ltSparseness)./sqrt(length(ltSparseness));

 
%% Choose neurons from ltsparseness
neuronsSelected=[];
neuronsSelected=find(ltSparseness>0.1);
currentOdorON=[];       
   for n=1:length(cutTimeTraceMatArray)
        currentOdor=cutTimeTraceMatArray{n};
        currentOdorON=[];
        for m=1:length(neuronsSelected)
            currentOdorON=[currentOdorON;currentOdor(neuronsSelected(m),:)];
        end   
       timeTraceDfMatListChosen{n}=currentOdorON;
   end   
   
   %% Calculate correlation matrix for average response pattern
nOdor = length(odorList);
nTrial = length(timeTraceDfMatListChosen);
responseWindow = floor([5.4 11] * 7.5); %[5.4 11] is the window to select in seconds
responseInd = responseWindow(1):responseWindow(2);
patternArray = cellfun(@(x) mean(x(:,responseInd),2),...
                       timeTraceDfMatListChosen,'UniformOutput',false);


%%%%
corrMat = zeros(nTrial,nTrial);
sm=0;
for ind=1:nTrial
    for jnd=ind:nTrial
        corrVec = analysis.calcPatternCorrelation(...
            patternArray{ind},...
            patternArray{jnd},sm);
        corrMat(ind,jnd) = corrVec;
    end
end

% plot
fig = figure;
imagesc(helper.makeSymmetricMat(corrMat))
% caxis([0 1])
trialNumVec = linspace(ceil(nTrialPerOdor/2),nTrial-floor(nTrialPerOdor/2),nOdor);
xticks(trialNumVec)
xticklabels(odorList)
set(gca,'xaxisLocation','top')
set(gca,'XTick',[])
yticks(trialNumVec)
yticklabels(odorList)
colorbar
set(gca, 'FontSize', 10)
%colormap jet
caxis([0 1])