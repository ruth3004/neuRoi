classdef TrialStackModel < handle
    properties
        rawFileList
        anatomyArray
        responseArray
        mapSize
        nTrial
        
        contrastLimArray
        contrastForAllTrial
        mapTypeList
		roiProvided
        roiArrays
        roiArray
        SingleRoi
    end
    
    properties (SetObservable)
        currentTrialIdx
        mapType
        roiVisible
        selectedRoiTagArray
    end

    events
        loadNewRois
        roiAdded
        roiDeleted
        roiUpdated
        roiArrayReplaced
        roiTagChanged
        
        roiSelected
        roiUnSelected
        roiSelectionCleared

        roiNewAlpha
        roiNewAlphaAll
    end
    
    methods
        function self = TrialStackModel(rawFileList, anatomyArray,...
                                        responseArray,roiArrays)
            % TODO check sizes of all arrays
            self.rawFileList = rawFileList;
            self.anatomyArray = anatomyArray;
            self.responseArray = responseArray;
            self.mapSize = size(anatomyArray(:,:,1));
            self.mapType = 'anatomy';
            self.nTrial = length(rawFileList)
            self.currentTrialIdx = 1;
            self.mapTypeList = {'anatomy','response'};
            self.contrastLimArray = cell(length(self.mapTypeList),...
                                         self.nTrial);
            self.contrastForAllTrial = false
			if ~exist('roiArrays','var')
                self.roiProvided= false;
            else
                self.roiArrays=roiArrays;
                self.roiProvided=true;
                roiSize=size(roiArrays);
                if roiSize(1)==1
                    self.SingleRoi=true;
                    self.roiArray=roiArrays;
                else
                    self.SingleRoi=false;
                    if roiSize(1)~=self.nTrial
                        self.roiArrays= [];
                        self.roiProvided=false;
                    else
                        self.roiArray=roiArrays(1,:);
                    end
                end

            end
        end
        
        function data = getMapData(self,mapType,trialIdx)
            switch mapType
              case 'anatomy'
                mapArray = self.anatomyArray;
              case 'response'
                mapArray = self.responseArray;
            end
            data = mapArray(:,:,trialIdx);
        end
        
        function map = getCurrentMap(self)
            map.data = self.getMapData(self.mapType,self.currentTrialIdx);
            map.type = self.mapType;
            map.meta.trialIdx = self.currentTrialIdx;
            
            map.meta.fileName = self.rawFileList{self.currentTrialIdx};
            contrastLim = self.getContrastLimForCurrentMap();
            if isempty(contrastLim)
                contrastLim = helper.minMax(map.data);
                self.saveContrastLim(contrastLim);
            end
            map.contrastLim = contrastLim;
        end
        
        function saveContrastLim(self,contrastLim)
            mapTypeIdx = self.findMapTypeIdx(self.mapType);
            if self.contrastForAllTrial
                [self.contrastLimArray{mapTypeIdx,:}] = deal(contrastLim);
            else
                self.contrastLimArray{mapTypeIdx,self.currentTrialIdx} = contrastLim;
            end
        end
        
        function climit = getContrastLimForCurrentMap(self)
            mapTypeIdx = self.findMapTypeIdx(self.mapType);
            climit = self.contrastLimArray{mapTypeIdx,self.currentTrialIdx};
        end
        
        function MaxTrialnumber = getMaxTrialnumber(self)
            MaxTrialnumber = length(self.anatomyArray(1,1,:));
        end

        
        function idx = findMapTypeIdx(self, mapType)
            idx = find(strcmp(self.mapTypeList, self.mapType));
        end
        
        function set.currentTrialIdx(self,idx)
            newIdx = min(max(idx,1),length(self.rawFileList));
            self.currentTrialIdx = newIdx;
            self.roiArray= self.getCurrentRoiArray();
        end
        
        function selectMapType(self,idx)
           self.mapType = self.mapTypeList{idx};
        end
		function roiArray = getCurrentRoiArray(self)
            if self.roiProvided== true
                if self.SingleRoi
                      roiArray =self.roiArrays;
                else
                    roiArray =self.roiArrays(self.currentTrialIdx,:);
                end
            else
                roiArray=[];
            end
        end
     % Methods for ROI-based processing
        % TODO set roiArray to private
        function addRoi(self,varargin)
        % ADDROI add ROI to ROI array
        % input arguments can be a RoiFreehand object
        % or a structure containing position and imageSize
            
            if nargin == 2
                if isa(varargin{1},'RoiFreehand')
                    roi = varargin{1};
                else
                    % TODO add ROI from mask
                    error('Wrong usage!')
                    help TrialModel.addRoi
                end
            else
                error('Wrong usage!')
                help TrialModel.addRoi
            end
            
            nRoi = length(self.roiArray);
            if nRoi >= self.MAX_N_ROI
                error('Maximum number of ROIs exceeded!')
            end
            
            % TODO validate ROI position (should not go outside of image)
            if isempty(self.roiArray)
                roi.tag = 1;
            else
                roi.tag = self.roiTagMax+1;
            end
            self.roiTagMax = roi.tag;
            self.roiArray(end+1) = roi;
            
            notify(self,'roiAdded')
        end
        
        function selectSingleRoi(self,varargin)
            if nargin == 2
                if strcmp(varargin{1},'last')
                    ind = length(self.roiArray);
                    tag = self.roiArray(ind).tag;
                else
                    tag = varargin{1};
                    ind = self.findRoiByTag(tag);
                end
            else
                error('Too Many/few input args!')
            end
            
            if ~isequal(self.selectedRoiTagArray,[tag])
                self.unselectAllRoi();
                self.selectRoi(tag);
            end
        end
        
        function selectRoi(self,tag)
            if ~ismember(tag,self.selectedRoiTagArray)
                ind = self.findRoiByTag(tag);
                self.selectedRoiTagArray(end+1)  = tag;
                notify(self,'roiSelected',NrEvent.RoiEvent(tag));
                disp(sprintf('ROI #%d selected',tag))
            end
        end
        
        function unselectRoi(self,tag)
            tagArray = self.selectedRoiTagArray;
            tagInd = find(tagArray == tag);
            if tagInd
                self.selectedRoiTagArray(tagInd) = [];
                notify(self,'roiUnSelected',NrEvent.RoiEvent(tag));
            end
        end
        
        function tagArray = getAllRoiTag(self)
        % TODO remove uniform false
        % Debug tag data type (uint16 or double)
            tagArray = arrayfun(@(x) x.tag, self.roiArray);
        end
        
        function selectAllRoi(self)
            tagArray = self.getAllRoiTag();
            self.unselectAllRoi();
            self.selectedRoiTagArray = tagArray;
            for k=1:length(tagArray)
                tag = tagArray(k);
                notify(self,'roiSelected',NrEvent.RoiEvent(tag));
            end
            disp('All Rois selected')
        end
        
        function unselectAllRoi(self)
            self.selectedRoiTagArray = [];
            notify(self,'roiSelectionCleared');
        end


        function NewAlphaAllRois(self, NewAlpha)
            arguments
                self
                NewAlpha {mustBeInRange(NewAlpha,0,1)}
            end
            for  i=1:length(self.roiArray)
                self.roiArray(i).AlphaValue=NewAlpha;
            end
            notify(self,'roiNewAlphaAll', ...
                   NrEvent.RoiNewAlphaEvent({},true,NewAlpha));
           % self.NewAlphaRois(self.roiArray,NewAlpha);
        end

        function NewAlphaRois(self,selectedRois,NewAlpha)
            arguments
                self 
                selectedRois (1,:) RoiFreehand
                NewAlpha {mustBeInRange(NewAlpha,0,1)}
            end
            for  i=1:length(selectedRois)
                selectedRois(i).AlphaValue=NewAlpha;
            end
            notify(self,'roiNewAlpha', ...
                   NrEvent.RoiNewAlphaEvent(selectedRois));
        end
        
        function updateRoi(self,tag,varargin)
            ind = self.findRoiByTag(tag);
            oldRoi = self.roiArray(ind);
            freshRoi = RoiFreehand(varargin{:});
            freshRoi.tag = tag;
            % TODO validate ROI position (should not go outside of image)
            self.roiArray(ind) = freshRoi;

            notify(self,'roiUpdated', ...
                   NrEvent.RoiUpdatedEvent([self.roiArray(ind)]));
            disp(sprintf('Roi #%d updated',tag))
        end
        
        function changeRoiTag(self,oldTag,newTag)
            ind = self.findRoiByTag(oldTag);
            oldRoi = self.roiArray(ind);
            tagArray = self.getAllRoiTag();
            if ismember(newTag,tagArray)
                error(['New tag cannot be assigned! The tag is ' ...
                       'already used by another ROI.'])
            else
                oldRoi.tag = newTag;
                self.roiArray(ind) = oldRoi;
                notify(self,'roiTagChanged', ...
                NrEvent.RoiTagChangedEvent(oldTag,newTag));
                disp(sprintf('Roi #%d changed to #%d',oldTag,newTag))
                if ismember(oldTag,self.selectedRoiTagArray)
                    idx = find(self.selectedRoiTagArray,oldTag);
                    self.selectedRoiTagArray(idx) = newTag;
                end
            end
        end
        
        function deleteSelectedRoi(self)
            tagArray = self.selectedRoiTagArray;
            self.unselectAllRoi();
            indArray = self.findRoiByTagArray(tagArray);
            self.roiArray(indArray) = [];
            notify(self,'roiDeleted',NrEvent.RoiDeletedEvent(tagArray));
        end
        
        function deleteRoi(self,tag)
            ind = self.findRoiByTag(tag);
            self.unselectRoi(tag);
            self.roiArray(ind) = [];
            notify(self,'roiDeleted',NrEvent.RoiDeletedEvent([tag]));loadRoiArray
        end
        
        function roiArray = getRoiArray(self)
            roiArray = self.roiArray;
        end
        
        function roi = getRoiByTag(self,tag)
            if strcmp(tag,'end')
                roi = self.roiArray(end);
            else
                ind = self.findRoiByTag(tag);
                roi = self.roiArray(ind);
            end
        end
        
        function saveRoiArray(self,filePath)
            roiArray = self.roiArray;
            ind = self.findMapByType('anatomy');
            templateAnatomy = self.mapArray{ind}.data;
            save(filePath,'roiArray');
        end
        
        function loadRoiArray(self,filePath,option)
            foo = load(filePath);
            roiArray = foo.roiArray;
            nRoi = length(roiArray);
                if nRoi >= self.MAX_N_ROI
                    error('Maximum number of ROIs exceeded!')
                end
            self.insertRoiArray(roiArray,option)
            if isfield(foo,'templateAnatomy')
                self.templateAnatomy = foo.templateAnatomy;
            end
        end

        function insertRoiArray(self,roiArray,option)
            if strcmp(option,'merge')
                arrayfun(@(x) self.addRoi(x),roiArray);
            elseif strcmp(option,'replace')
                self.roiArray = roiArray;
                tagArray = self.getAllRoiTag();
                self.roiTagMax = max(tagArray);
                notify(self,'roiArrayReplaced');
            end
        end

        
        function importRoisFromMask(self,filePath)
            maskImg = movieFunc.readTiff(filePath);
            if ~isequal(size(maskImg),self.getMapSize())
                error(['Image size of mask does not match the map size ' ...
                       '(pixel size in x and y)!'])
            end
            tagArray = unique(maskImg);
            roiArray = RoiFreehand.empty();
            for k=1:length(tagArray)
                tag = tagArray(k);
                if tag ~= 0
                    mask = maskImg == tag;
                    poly = roiFunc.mask2poly(mask);
                    if length(poly) > 1
                        % TODO If the mask corresponds multiple polygon,
                        % for simplicity,
                        % take the largest polygon
                        warning(sprintf('ROI %d has multiple components, only taking the largest one.',tag))
                        pidx = find([poly.Length] == max([poly.Length]));
                        poly = poly(pidx);
                    end
                    position = [poly.X',poly.Y'];
                    roi = RoiFreehand(position);
                    roi.tag = double(tag);
                    roiArray(end+1) = roi;
                end
            end
            self.insertRoiArray(roiArray,'replace')
        end
        
        function importRoisFromImageJ(self,filePath)
            [jroiArray] = roiFunc.ReadImageJROI(filePath);
            roiArray = roiFunc.convertFromImageJRoi(jroiArray);
            self.insertRoiArray(roiArray,'replace');
        end
        
        
        function matchRoiPos(self,roiTagArray,windowSize)
            fitGauss = 1;
            normFlag = 1;
            roiIndArray = self.findRoiByTagArray(roiTagArray);
            mapInd = self.findMapByType('anatomy');
            inputMap = self.mapArray{mapInd}.data;
            for ind = roiIndArray
                self.roiArray(ind).matchPos(inputMap, ...
                                            self.templateAnatomy,...
                                            windowSize,...
                                            fitGauss,...
                                            normFlag)
            end
            notify(self,'roiUpdated', ...
                   NrEvent.RoiUpdatedEvent(self.roiArray(roiIndArray)));
        end
        
        % function checkRoiImageSize(self,roi)
        %     mapSize = self.getMapSize();
        %     if ~isequal(roi.imageSize,mapSize)
        %         error(['Image size of ROI does not match the map size ' ...
        %                '(pixel size in x and y)!'])
        %     end
        % end
        
        function ind = findRoiByTag(self,tag)
            ind = find(arrayfun(@(x) isequal(x.tag,tag), ...
                                self.roiArray),1);
            if ~isempty(ind)
                ind = ind(1);
            else
                error(sprintf('Cannot find ROI with tag %d!',tag))
            end
        end
        
        function roiIndArray = findRoiByTagArray(self,tagArray)
            roiIndArray = arrayfun(@(x) self.findRoiByTag(x), ...
                                   tagArray);
        end



    end

end

