classdef NrModel < handle
    properties (SetObservable)
        expInfo
        
        rawDataDir
        rawFileList
        resultDir
        
        trialTable

        trialArray
        currentTrialIdx
        
        motionCorrConfig
        
        alignFilePath
        alignResult

        responseOption
        responseMaxOption
        localCorrelationOption
        
        roiDir
        jroiDir
        maskDir
        
        loadFileType
        planeNum
        
        trialOptionRaw
        trialOptionBinned
        alignToTemplate
        mapsAfterLoading
        loadTemplateRoi
        roiTemplateFilePath
        
        binConfig
    end 
    
    properties (SetAccess = private, SetObservable = true)
        anatomyDir
        anatomyConfig
        alignDir
        alignConfig
    end
    
    methods
        function self = NrModel(varargin)
            pa = inputParser;
            addParameter(pa,'rawDataDir','',@ischar);
            addParameter(pa,'rawFileList','',@iscell);
            addParameter(pa,'resultDir','',@ischar);
            defaultExpInfo.frameRate = 1;
            defaultExpInfo.nPlane = 1;
            addParameter(pa,'expInfo',defaultExpInfo,@isstruct);
            % addParameter(pa,'alignFilePath','',@ischar)
            addParameter(pa,'roiDir','',@ischar);
            addParameter(pa,'loadFileType','raw',@ischar);
            defaultTrialOptionRaw = struct('process',true,...
                                'noSignalWindow',[1 12], ...
                                'intensityOffset',-30);
            defaultTrialOptionBinned = struct('process',false,...
                                'noSignalWindow',[], ...
                                'intensityOffset',100);
            addParameter(pa,'trialOptionRaw',defaultTrialOptionRaw, ...
                         @isstruct);
            addParameter(pa,'trialOptionBinned', ...
                         defaultTrialOptionBinned,@isstruct);
            
            
            defaultResponseOption = struct('offset',0,...
                                           'fZeroWindow',[1 5],...
                                           'responseWindow',[10 15]);
            defaultResponseMaxOption = struct('offset',0,...
                                              'fZeroWindow',[1 5],...
                                              'slidingWindowSize',3);

            addParameter(pa,'responseOption',defaultResponseOption, ...
                         @isstruct);
            addParameter(pa,'responseMaxOption', ...
                         defaultResponseMaxOption,@isstruct);
            

            parse(pa,varargin{:})
            pr = pa.Results;

            self.trialArray = TrialModel.empty;
            
            self.expInfo = pr.expInfo; % expInfo.nPlane is the total
                                    % number of planes in the data
            self.rawDataDir = pr.rawDataDir;
            self.rawFileList = pr.rawFileList;
            self.resultDir = pr.resultDir;
            
            self.anatomyDir = 'anatomy';
            
            self.alignDir = 'alignment';
            self.alignResult = cell(1,pr.expInfo.nPlane);
            
            if ~isempty(pr.roiDir)
                self.roiDir = pr.roiDir;
            else
                self.roiDir = self.getDefaultDir('roi');
            end
            
            self.maskDir = self.getDefaultDir('stardist_mask');

            
            self.loadFileType = pr.loadFileType;
            self.trialOptionRaw = pr.trialOptionRaw;
            self.trialOptionBinned = pr.trialOptionBinned;
            self.responseOption = pr.responseOption;
            self.responseMaxOption = pr.responseMaxOption;
            self.mapsAfterLoading = {};
            self.loadTemplateRoi = false;
            self.roiTemplateFilePath = '';
            
            self.planeNum = 1; % The plane number for loading file
        end
        
        function importRawData(self,expInfo,rawDataDir,rawFileList,resultDir)
            self.expInfo = expInfo;
            self.rawDataDir = rawDataDir;
            self.rawFileList = rawFileList;
            self.resultDir = resultDir;
        end
        
        function processRawData(self,varargin)
            pa = inputParser;
            addParameter(pa,'subtractScan',false);
            addParameter(pa,'noSignalWindow',1);
            addParameter(pa,'mcWithinTrial',false);
            addParameter(pa,'mcBetweenTrial',true);
            addParameter(pa,'mcBTTemplateIdx',1);
            addParameter(pa,'binning',false);
            addParameter(pa,'binDir','');
            addParameter(pa,'binParam',[]);
            parse(pa,varargin{:})
            pr = pa.Results;

            if pr.subtractScan
                trialOption = struct('process',true,'noSignalWindow',[1 10]);
            else
                trialOption = {}; %
            end
            
            % Motion correction within trial
            if pr.mcWithinTrial
                % For now motion correction within trial only
                % support single plane data
                % TODO add multiplane support
                motionCorrDir = self.getDefaultDir('motion_corr');
                self.motionCorrBatch(trialOption,motionCorrDir)
            end
            
            % Subsampling
            if pr.binning
                binParam = pr.binParam;
                binParam.trialOption = trialOption;
                for planeNum=1:self.expInfo.nPlane
                    self.binMovieBatch(binParam,pr.binDir,planeNum);
                end
            end
            
            % Motion correction between trials
            if pr.mcBetweenTrial
                if pr.binning
                    anatomyParam.inFileType = 'binned';
                    anatomyParam.trialOption = [];
                else
                    anatomyParam.inFileType = 'raw';
                    anatomyParam.trialOption = trialOption;
                end
                
                for planeNum=1:self.expInfo.nPlane
                    self.calcAnatomyBatch(anatomyParam,planeNum);
                end

                templateRawName = self.rawFileList{pr.mcBTTemplateIdx};
                for planeNum=1:self.expInfo.nPlane
                    self.alignTrialBatch(templateRawName,...
                                         'planeNum',planeNum,...
                                         'alignOption',{'plotFig',false});
                end
            end
        end
        
        function tagArray = getTagArray(self)
            tagArray = arrayfun(@(x) x.tag,self.trialArray, ...
                                'Uniformoutput',false);
        end
        
        function idx = getTrialIdx(self,tag)
            tagArray = self.getTagArray();
            idx = find(strcmp(tagArray,tag));
        end
        
        function trial = getTrialByTag(self,tag)
            idx = self.getTrialIdx(tag);
            trial = self.trialArray(idx);
        end

        function trial = loadTrialFromList(self,fileIdx,fileType, ...
                                           planeNum)
            if ~exist('planeNum','var')
                planeNum = 1;
            end
            
            rawFileName = self.rawFileList{fileIdx};
            fprintf('Loading %s\n planeNum: %d\n',rawFileName, ...
                    planeNum)
            
            multiPlane = checkMultiPlane(self,planeNum);
            
            switch fileType
              case 'raw'
                fileName = rawFileName;
                filePath = fullfile(self.rawDataDir, ...
                                    fileName);
                trialOption = self.trialOptionRaw;
                if multiPlane
                    trialOption.zrange = [planeNum inf];
                    trialOption.nFramePerStep = ...
                        self.expInfo.nPlane;
                    frameRate = self.expInfo.frameRate /self.expInfo.nPlane;
                else
                    frameRate = self.expInfo.frameRate;
                end
              case 'binned'
                shrinkFactors = self.binConfig.param.shrinkFactors;
                fileName = iopath.getBinnedFileName(rawFileName, ...
                                                    shrinkFactors);
                if multiPlane
                    planeString = NrModel.getPlaneString(planeNum);
                    filePath = fullfile(self.binConfig.outDir, ...
                                        planeString,fileName);
                    frameRate = self.expInfo.frameRate / ...
                        shrinkFactors(3) / self.expInfo.nPlane;
                else
                    filePath = fullfile(self.binConfig.outDir, ...
                                        fileName);
                    frameRate = self.expInfo.frameRate / ...
                        shrinkFactors(3);
                end
                
                trialOption = self.trialOptionBinned;
            end
            

            if self.alignToTemplate
                offsetYx = self.getTrialOffsetYx(fileIdx,planeNum);
            else
                warning('The trial might not be aligned in X and Y!')
                offsetYx = [0,0];
            end
            
            if multiPlane
                planeString = NrModel.getPlaneString(planeNum);
                roiDir = fullfile(self.roiDir,planeString);
            else
                roiDir = self.roiDir;
            end
            
            if ~exist(roiDir)
                mkdir(roiDir)
            end

            if multiPlane
                planeString = NrModel.getPlaneString(planeNum);
                maskDir = fullfile(self.maskDir,planeString);
            else
                maskDir = self.maskDir;
            end
            
            if ~exist(maskDir)
                mkdir(maskDir)
            end

            trialOption.yxShift = offsetYx;
            trialOption.roiDir = roiDir;
            trialOption.maskDir = maskDir;
            trialOption.frameRate = frameRate;
            trial = self.loadTrial(filePath,trialOption);
            trial.sourceFileIdx = fileIdx;
        end
        
        function trial = loadAdditionalTrial(self,filePath,varargin)
        % TODO save trial path into a property
            trial = self.loadTrial(filePath,varargin{:});
        end
        
        function trial = loadTrial(self,filePath,trialOption)
            tagArray = self.getTagArray();
            tag = helper.generateRandomTag(6);
            nstep = 1;
            while ismember(tag,tagArray) && nstep < 100
                tag = helper.generateRandomTag(5);
                nstep = nstep+1;
            end
            
            if ismember(tag,tagArray)
                error('Cannot get unused trial tag!')
            end
            
            trialOptionCell = helper.structToNameValPair(trialOption);
            trial = TrialModel(filePath,trialOptionCell{:});
            trial.tag = tag;
            self.trialArray(end+1) = trial;
        end
        
        function selectTrial(self,tag)
            if isempty(tag)
                self.currentTrialIdx = [];
                disp('No trial is selected..')
            else
                idx = self.getTrialIdx(tag);
                if isempty(idx)
                    disp('No trial is selected')
                else
                    if ~isequal(idx,self.currentTrialIdx)
                        self.currentTrialIdx = idx;
                        disp(sprintf('trial_%s # %d selected', tag, ...
                                     self.currentTrialIdx))
                    end
                end
            end
        end
        
        function deleteTrial(self,idx)
            self.trialArray(idx) = [];
        end
        
        function trial = getCurrentTrial(self)
            trial = self.trialArray(self.currentTrialIdx);
        end
        
        function mapOption = getMapOption(self,mapType)
            switch mapType
              case 'response'
                mapOption = self.responseOption;
              case 'responseMax'
                mapOption = self.responseMaxOption;
              case 'localCorrelation'
                mapOption = self.localCorrelationOption;
              otherwise
                error('NrModel:mapTypeTagError',['Map type of ' ...
                                    'the button is wrong!'])
            end
        end
        
        function addMapCurrTrial(self,mapType)
            mapOption = self.getMapOption(mapType);
            trial = self.getCurrentTrial();
            
            try
                trial.calculateAndAddNewMap(mapType,mapOption);
            catch ME
                if strcmp(ME.identifier,['TrialModel:' ...
                                        'windowValueError'])
                    self.view.displayError(ME);
                    return
                end
                rethrow(ME)
            end
        end
        
        function updateMapCurrTrial(self,mapType)
            mapOption = self.getMapOption(mapType);
            trial = self.getCurrentTrial();
            try
                trial.findAndUpdateMap(mapType,mapOption);
            catch ME
                switch ME.identifier
                  case 'TrialModel:mapTypeError','TrialModel:windowValueError'
                    self.view.displayError(ME);
                    return
                end
                rethrow(ME)
            end
                
        end
        
        function motionCorrBatch(self,trialOption,outDir,fileIdx)
        % MOTIONCORRBATCH motion correction within trial
        %      multiplane not yet implemented
            self.motionCorrConfig.outDir = outDir;
            if exist('fileIdx','var')
                rawFileList = self.rawFileList(fileIdx);
            else
                rawFileList = self.rawFileList;
            end
            batch.motionCorrFromFile(self.rawDataDir,rawFileList,trialOption,outDir)
        end

        function binMovieBatch(self,param,outDir,planeNum,fileIdx)
            if ~exist('outDir','var')
                if length(self.binConfig.outDir)
                    outDir = self.binConfig.outDir;
                else
                    error('Please specify output directory!')
                end
            end
            if ~exist(outDir,'dir')
                mkdir(outDir)
            end
            
            trialOption = param.trialOption;
            if self.expInfo.nPlane > 1
                if exist('planeNum','var')
                    planeString = NrModel.getPlaneString(planeNum);
                    outSubDir = fullfile(outDir,planeString);
                    if ~exist(outSubDir,'dir')
                        mkdir(outSubDir)
                    end
                    trialOption.nFramePerStep = self.expInfo.nPlane;
                    trialOption.zrange = [planeNum,inf];
                else
                    error(['Please specify plane number for' ...
                           ' multiplane data!']);
                end
            else
                outSubDir = outDir;
            end

            
            if exist('fileIdx','var')
                rawFileList = self.rawFileList(fileIdx);
            else
                rawFileList = self.rawFileList;
            end
            
            binConfig = batch.binMovieFromFile(self.rawDataDir, ...
                                               rawFileList, ...
                                               outSubDir,...
                                               param.shrinkFactors,...
                                               param.depth,...
                                               trialOption);
            binConfig.outDir = outDir;
            binConfig.trialOption = param.trialOption;
            self.binConfig = binConfig;
            % timeStamp = helper.getTimeStamp();
            % configFileName = ['binConfig-' timeStamp '.json'];
            configFileName = 'binConfig.json';
            configFilePath = fullfile(outDir,configFileName);
            helper.saveStructAsJson(binConfig,configFilePath);
        end
        
        function readBinConfig(self,metaFilePath)
            self.binConfig = jsondecode(fileread(metaFilePath));
        end
        
        function calcAnatomyBatch(self,param,planeNum,fileIdx)
            outDir = fullfile(self.resultDir,self.anatomyDir);
            if ~exist(outDir,'dir')
                mkdir(outDir)
            end

            if ~isfield(param,'trialOption')
                param.trialOption = {};
            end
            
            if exist('fileIdx','var')
                rawFileList = self.rawFileList(fileIdx);
            else
                rawFileList = self.rawFileList;
            end

            if self.expInfo.nPlane > 1
                if exist('planeNum','var')
                    planeString = NrModel.getPlaneString(planeNum);
                    outSubDir = fullfile(outDir,planeString);
                    if ~exist(outSubDir,'dir')
                        mkdir(outSubDir)
                    end
                else
                    error(['Please specify plane number for' ...
                           ' multiplane data!']);
                end
            else
                outSubDir = outDir;
            end
            

            if strcmp(param.inFileType,'raw')
                trialOption = param.trialOption;
                if self.expInfo.nPlane > 1
                    trialOption.nFramePerStep = self.expInfo.nPlane;
                    trialOption.zrange = [planeNum,inf];
                end
                [~,filePrefix] = batch.calcAnatomyFromFile(self.rawDataDir, ...
                                                       rawFileList,...
                                                       outSubDir, ...
                                                       trialOption);
            elseif strcmp(param.inFileType,'binned')
                binDir = self.binConfig.outDir;
                if self.expInfo.nPlane > 1
                    binDir = fullfile(binDir,planeString);
                end
                
                if self.binConfig.filePrefix
                    binPrefix = self.binConfig.filePrefix;
                    binnedFileList = ...
                        iopath.modifyFileName(rawFileList,binPrefix,'','tif');
                end
                try
                    [~,filePrefix] = batch.calcAnatomyFromFile(binDir, ...
                                 binnedFileList,outSubDir,param.trialOption);
                catch ME
                    if strcmp(ME.identifier, ...
                              'batchCalcAnatomyFromFile:fileNotFound')
                        addMsg = ['Binned data does not exist! Please do ' ...
                               'binning first before calculating anatomy.'];
                        disp(addMsg)
                    end
                    rethrow(ME)
                end
                filePrefix = [filePrefix,binPrefix];
            end
            
            anatomyConfig.param = param;
            anatomyConfig.filePrefix = filePrefix;
            
            self.anatomyConfig = anatomyConfig;

            configFileName = ['anatomyConfig.json'];
            configFilePath = fullfile(outDir,configFileName);
            helper.saveStructAsJson(anatomyConfig,configFilePath);
        end
        
        function readAnatomyConfig(self,filePath)
            self.anatomyConfig = jsondecode(fileread(filePath));
        end

        function alignTrialBatch(self,templateRawName,varargin)
            pa = inputParser;
            addParameter(pa,'planeNum',1,@isnumeric);
            addParameter(pa,'fileIdx','all',@(x) ischar(x)|ismatrix(x));
            addParameter(pa,'alignOption',{},@iscell);
            parse(pa,varargin{:})
            pr = pa.Results;
            
            outFileName = 'alignResult.mat';
            outDir = fullfile(self.resultDir,self.alignDir);
            if ~exist(outDir,'dir')
                mkdir(outDir)
            end

            anatomyPrefix = self.anatomyConfig.filePrefix;
            templateName = iopath.modifyFileName(templateRawName, ...
                                           anatomyPrefix,'','tif');
            

            if ischar(pr.fileIdx)
                rawFileList = self.rawFileList;
            else
                rawFileList = self.rawFileList(pr.fileIdx);
            end

            % TODO deal with error that no anatomy files found
            % TODO deal with no anatomyConfig loaded

            if self.expInfo.nPlane > 1
                if pr.planeNum
                    planeString = NrModel.getPlaneString(pr.planeNum);
                    inDir = fullfile(self.resultDir,self.anatomyDir, ...
                                     planeString);
                    
                    outSubDir = fullfile(outDir,planeString);
                    if ~exist(outSubDir,'dir')
                        mkdir(outSubDir)
                    end
                    multiPlane = true;
                else
                    error(['Please specify plane number for' ...
                           ' multiplane data!']);
                end
            else
                inDir = fullfile(self.resultDir,self.anatomyDir);
                outSubDir = outDir;
            end
            anatomyFileList = iopath.modifyFileName(rawFileList, ...
                                                    anatomyPrefix, ...
                                                    '','tif');
            stackFileName = iopath.modifyFileName(outFileName, ...
                                                  'stack_','','tif');
            stackFilePath = fullfile(outSubDir,stackFileName);
            alignResult = batch.alignTrials(inDir,...
                                            anatomyFileList, ...
                                            templateName,...
                                            'stackFilePath',...
                                            stackFilePath,...
                                            pr.alignOption{:});
            
            alignResult.anatomyPrefix = anatomyPrefix;
            alignResult.templateRawName = templateRawName;

            self.alignResult{pr.planeNum} = alignResult;
            
            outFilePath = fullfile(outSubDir,outFileName);
            save(outFilePath,'alignResult')
        end

        function loadAlignResult(self,planeNum)
            fileName = 'alignResult.mat';
            multiPlane = self.checkMultiPlane(planeNum);
            if multiPlane
                planeString = NrModel.getPlaneString(planeNum);
                filePath = fullfile(self.resultDir,self.alignDir,planeString,...
                                    fileName);
            else
                filePath = fullfile(self.resultDir,self.alignDir,fileName);
            end
            foo = load(filePath);
            self.alignResult{planeNum} = foo.alignResult;
        end
        
        function arrangeTrialTable(self)
            trialTable = batch.getTrialTable(self.rawFileList,self.expInfo.odorList);
            trialTable = batch.addTrialNum(trialTable);
            self.trialTable = trialTable;
        end
        
        function removeTrialFromTable(self, fileIdxList)
            rowLogic = ismember(self.trialTable.fileIdx, fileIdxList);
            self.trialTable(rowLogic,:) = [];
        end
        
        function [mapArray,varargout] = calcMapBatch(self,...
                            inFileType,mapType,mapOption,varargin)
            pa = inputParser;
            addParameter(pa,'trialOption',[]);
            addParameter(pa,'planeNum',1,@isnumeric);
            addParameter(pa,'sortBy','none',@ischar);
            addParameter(pa,'odorDelayList',[],@ismatrix);
            addParameter(pa,'saveMap',false);
            addParameter(pa,'outFileType','mat',@ischar);
            addParameter(pa,'fileIdx',0,@ismatrix);
            parse(pa,varargin{:})
            pr = pa.Results;
            planeNum = pr.planeNum;
            multiPlane = self.checkMultiPlane(planeNum);
                
            trialOption = pr.trialOption;
            if strcmp(inFileType,'raw')
                inSubDir = self.rawDataDir;
                inFileList = self.rawFileList;
                if pr.fileIdx
                    inFileList = inFileList(pr.fileIdx);
                end
                if multiPlane
                    trialOption.frameRate = self.expInfo.frameRate/ ...
                                            self.expInfo.nPlane;
                    trialOption.zrange = [planeNum inf];
                    trialOption.nFramePerStep = self.expInfo.nPlane;
                else
                    trialOption.frameRate = self.expInfo.frameRate;
                end
            elseif strcmp(inFileType,'binned')
                inDir = self.binConfig.outDir;
                inFileList = self.getFileList('binned');
                if pr.fileIdx
                    inFileList = inFileList(pr.fileIdx);
                end
                shrinkZ = self.binConfig.param.shrinkFactors(3);
                if multiPlane
                    inSubDir = fullfile(inDir, ...
                                  NrModel.getPlaneString(planeNum));
                    trialOption.frameRate = self.expInfo.frameRate/ ...
                                         self.expInfo.nPlane/shrinkZ;
                else
                    inSubDir = inDir;
                    trialOption.frameRate = self.expInfo.frameRate/ ...
                                            shrinkZ;
                end

            else
                error('inFileType should be either raw or binned!')
            end
            
            % odorList = self.expInfo.odorList;
            % % TODO accept user provided fileOdorList
            % if ~isempty(odorList)
            %     trialTable = batch.getTrialTable(inFileList, ...
            %                                      odorList);
            % else
            %     trialTable = table(inFileList');
            % end
            
            % if strcmpi(pr.sortBy,'odor')
            %     trialTable = sortrows(trialTable,'Odor');
            % end
            
            % if ~isempty(pr.odorDelayList)
            %     trialTable = batch.getWindowDelayTable(trialTable, ...
            %                          odorList,pr.odorDelayList);
            %     delayList =  trialTable.Delay;
            % else
            %     delayList = [];
            % end
                
            % if nargout == 2
            %     varargout{1} = trialTable;
            % end

            delayList = [];
            if pr.saveMap
                outDir = myexp.getDefaultDir('response_map');
                if ~exist(outDir,'dir')
                    mkdir(outDir)
                end
                if multiPlane
                    outSubDir = fullfile(outDir, ...
                                NrModel.getPlaneString(planeNum));
                    if ~exist(outSubDir,'dir')
                        mkdir(outSubDir)
                    end
                else
                    outSubDir = outDir;
                end
            else
                outSubDir = [];
            end
                
            mapArray = batch.calcMapFromFile(inSubDir,...
                                      inFileList,...
                                      mapType,...
                                      'mapOption',mapOption,...
                                      'windowDelayList',...
                                      delayList,...
                                      'trialOption',trialOption,...
                                      'outDir',outSubDir,...
                                      'outFileType',pr.outFileType);
        end
        
        function offsetYx = getTrialOffsetYx(self,fileIdx,planeNum)
        % GETTRIALOFFSETYX get trial offset in y and x axis by
        % matching file name to the alignment result file list
            if isempty(self.alignResult{planeNum})
                try
                    self.loadAlignResult(planeNum);
                catch ME
                    display('Cannot load alignment result!')
                    rethrow ME
                end
            end
            alignResult = self.alignResult{planeNum};
            
            rawFileName = self.rawFileList{fileIdx};
            inFileList = alignResult.inFileList;
            anatomyPrefix = alignResult.anatomyPrefix;
            anatomyFileName = ...
                iopath.modifyFileName(rawFileName, ...
                                      anatomyPrefix,'','tif');
            
            idx = find(strcmp(inFileList,anatomyFileName));
            if isempty(idx)
                msg = ['Cannot find offset value in the aligment ' ...
                       'result for file: ' anatomyFileName];
                error(msg);
            else
                offsetYx = alignResult.offsetYxMat(idx,:);
            end
        end
        
        
        function [timeTraceMat,roiArray] = ...
                extractTimeTrace(self,fileIdx,roiFilePath,planeNum)
            if ~exist('planeNum','var')
                planeNum = 1;
            end
            
            multiPlane = self.checkMultiPlane(planeNum);
            
            traceDir = fullfile(self.resultDir,'time_trace');
            
            if multiPlane
                planeString = NrModel.getPlaneString(planeNum);
                traceDir = fullfile(traceDir,planeString);
            end
            
            if ~exist(traceDir,'dir')
                mkdir(traceDir)
            end
            
            if ~exist(roiFilePath,'file')
                error(sprintf('ROI file %s does not exists!',roiFilePath))
            end
            
            disp(sprintf('Extract time trace ...'))
            disp(sprintf('Data file: #%d, %s', fileIdx, self.rawFileList{fileIdx}))
            disp(sprintf('ROI file: %s', roiFilePath))
            trial = self.loadTrialFromList(fileIdx,'raw',planeNum);
            
            trial.loadRoiArray(roiFilePath,'replace');
            [timeTraceMat,roiArray] = trial.extractTimeTraceMat();
            % TODO extract only raw trace
            
            dataFileBaseName = trial.name;
            resFileName = [dataFileBaseName '_traceResult.mat'];
            resFilePath = fullfile(traceDir,resFileName);
            traceResult.timeTraceMat = timeTraceMat;
            traceResult.roiArray = roiArray;
            traceResult.roiFilePath = roiFilePath;
            traceResult.rawFilePath = trial.filePath;
            save(resFilePath,'traceResult')
        end
        
        function extractTimeTraceBatch(self,fileIdxList, ...
                                       roiFileList,planeNum, ...
                                       plotTrace)
            if ~exist('plotTrace','var')
                plotTrace = false;
            end
            
            if plotTrace
                timeTraceFig = figure();
                nrow = 4;
                ncol = ceil(length(fileIdxList)/4);
            end

            for k=1:length(fileIdxList)
                fileIdx = fileIdxList(k);
                roiFilePath = roiFileList{k};
                [timeTraceMat,roiArray] = ...
                    self.extractTimeTrace(fileIdx,roiFilePath,planeNum);
                if plotTrace
                    figure(timeTraceFig)
                    subplot(nrow,ncol,k)
                    imagesc(timeTraceMat)
                end
            end
        end
        
        function multiPlane = checkMultiPlane(self,planeNum)
            multiPlane = false;
            if isfield(self.expInfo,'nPlane')
                nPlane = self.expInfo.nPlane;
                if nPlane >1
                    if planeNum >= 1 && planeNum <= nPlane
                        multiPlane = true;
                    else
                        msg = sprintf(['Please specify the plane'...
                                       'numberbetween 1 and %d!'], ...
                                      nPlane);
                        error(msg);
                    end
                else
                    if planeNum > 1
                        msg = sprintf(['No multi-plane data for'...
                                      ' plane %d'],planeNum);
                        error(msg);
                    end
                end
            end
        end
        
        function dd = getDefaultDir(self,dirName)
            dirNameList = {'binned','anatomy','alignment',...
                           'response_map','roi','motion_corr','df_rgb',...
                          'stardist_mask'};
            if ismember(dirName, dirNameList)
                dd = fullfile(self.resultDir,dirName);
            else
                error('Directory name not in list!')
            end
        end
        
        function fp = getDefaultFile(self,fileName)
            switch fileName
              case 'experiment'
                fileName = sprintf('experiment_%s.mat',self.expInfo.name);
                fp = fullfile(self.resultDir,fileName);
            end
        end
        
        function fileList = getFileList(self,resultType,fileIdx)
            if exist('fileIdx','var')
                rawFileList = self.rawFileList(fileIdx);
            else
                rawFileList = self.rawFileList;
            end
            
            switch resultType
              case 'binned'
                    binPrefix = self.binConfig.filePrefix;
                    fileList = iopath.modifyFileName(rawFileList, ...
                                                     binPrefix,'','tif');
            end
        end
        
        function saveExperiment(self,filePath)
            save(filePath,'self')
        end
        
        function s = saveobj(self)
            for fn = fieldnames(self)'
                s.(fn{1}) = self.(fn{1});
            end
        end
    end

    methods (Static)
        function obj = loadobj(s)
            if isstruct(s)
                obj = NrModel();
                
                for fn = fieldnames(s)'
                    obj.(fn{1}) = s.(fn{1});
                end
                
                if isstruct(obj.alignResult)
                    obj.alignToTemplate = true;
                end
            else
                obj = s;
            end
        end
    
        function planeString = getPlaneString(planeNum)
            planeString = sprintf('plane%02d',planeNum);
        end
    end
    
end
