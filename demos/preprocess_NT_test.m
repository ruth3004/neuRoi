%% Need Curve fitting, statistics, image processing and   signal processing toolboxes
%% Clear variables
clear all
%% Step01 Configure experiment and image processing parameters
% Load 
% Experiment parameters
expInfo.name = 'Nesibe-test-f1';
expInfo.frameRate = 30;
expInfo.odorList = {'Ala','Trp','Ser'};
expInfo.nTrial = 1;
expInfo.nPlane = 4;
expSubDir = expInfo.name;

% Raw data
rawDataDir = '\\tungsten-nas.fmi.ch\tungsten\scratch\gfriedri\teminesi\neuRoi_versions\neuRoi_NT\demos\test_data';
rawFileList = {'NT0012_49dpf_f1_o1Ala_001_.tif';...
               'NT0012_49dpf_f1_o2Trp_001_.tif';...
               'NT0012_49dpf_f1_o3Ser_001_.tif'};

% Data processing configuration
% Directory for saving processing results
resultDir = '\\tungsten-nas.fmi.ch\tungsten\scratch\gfriedri\teminesi\neuRoi_versions\neuRoi_NT\demos\test_data\results';

% Directory for saving binned movies
binDir = '\\tungsten-nas.fmi.ch\tungsten\scratch\gfriedri\teminesi\neuRoi_versions\neuRoi_NT\demos\test_data\results\binned';

%% Step02 Initialize NrModel with experiment confiuration
myexp = NrModel(rawDataDir,rawFileList,resultDir,...
                expInfo);
%% Step03a (optional) Bin movies
% Bin movie parameters
binParam.shrinkFactors = [1, 1, 2];
binParam.trialOption = struct('process',true,'noSignalWindow',[1 4]);
binParam.depth = 8;
for planeNum=1:myexp.expInfo.nPlane
myexp.binMovieBatch(binParam,binDir,planeNum);
end
%% Step03b (optional) If binning has been done, load binning
%% parameters to experiment
%read from the binConfig file to get the binning parameters
binConfigFileName = 'binConfig.json';
binConfigFilePath = fullfile(binDir,binConfigFileName);
myexp.readBinConfig(binConfigFilePath);
%% Step04 Calculate anatomy maps
% anatomyParam.inFileType = 'raw';
%anatomyParam.trialOption = {'process',true,'noSignalWindow',[1 24]};
anatomyParam.inFileType = 'binned';
anatomyParam.trialOption = [];
for planeNum=1:myexp.expInfo.nPlane
    myexp.calcAnatomyBatch(anatomyParam,planeNum);
end
%% Step04b If anatomy map has been calculated, load anatomy
%% parameters to experiment
anatomyDir = myexp.getDefaultDir('anatomy');
anatomyConfigFileName = 'anatomyConfig.json';
anatomyConfigFilePath = fullfile(anatomyDir,anatomyConfigFileName);
myexp.readAnatomyConfig(anatomyConfigFilePath);
%% Step05 Align trial to template
templateRawName = myexp.rawFileList{1};
tempDir=[];
% plotFig = false;
% climit = [0 0.5];
for planeNum=1:myexp.expInfo.nPlane
    myexp.alignTrialBatch(templateRawName,...
                          tempDir,...
                          'planeNum',planeNum,...
                          'alignOption',{'plotFig',false});
end
%% Save experiment configuration
expFileName = strcat('experimentConfig_',expInfo.name,'.mat');
expFilePath = fullfile(resultDir,expFileName);
save(expFilePath,'myexp')
