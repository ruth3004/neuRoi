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
    end
    
    properties (SetObservable)
        currentTrialIdx
        mapType
    end
    
    methods
        function self = TrialStackModel(rawFileList, anatomyArray,...
                                        responseArray)
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
        
        function idx = findMapTypeIdx(self, mapType)
            idx = find(strcmp(self.mapTypeList, self.mapType));
        end
        
        function set.currentTrialIdx(self,idx)
            newIdx = min(max(idx,1),length(self.rawFileList));
            self.currentTrialIdx = newIdx;
        end
        
        function selectMapType(self,idx)
           self.mapType = self.mapTypeList{idx};
        end
    end

end
