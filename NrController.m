classdef NrController < handle
    properties
        model
        view
    end
    
    methods
        function self = NrController(mymodel)
            self.model = mymodel;
            self.view = NrView(self);
        end
        
        function setDisplayState(self,displayState)
            if ismember(displayState, self.model.stateArray)
                if strcmp(displayState,'localCorr') & ~self.model.localCorrMap
                        self.model.calcLocalCorrelation();
                end
                self.model.displayState = displayState;
            else
                error('The state should be in array of states')
            end
        end
        
        % ROI funcitons
        function addRoiInteract(self)
            rawRoi = imfreehand;
            %TODO important, deal with roi cancelled by Esc!!
            position = rawRoi.getPosition();
            delete(rawRoi)
            imageInfo = getImageSizeInfo(self.view.guiHandles.mapImage);
            if ~isempty(position)
                freshRoi = RoiFreehand(0,position,imageInfo);
                self.addRoi(freshRoi);
                self.model.currentRoi = freshRoi;
            end
        end

        function addRoi(self,roi)
            if isvalid(roi) && isa(roi,'RoiFreehand')
                % TODO check if image info matches
                self.model.addRoi(roi);
                self.view.addRoiPatch(roi);
            else
                warning('Invalid ROI!')
            end
        end

        function selectRoi(self)
            selectedObj = gco; % get(gco,'Parent');
            tag = get(selectedObj,'Tag');
            if and(~isempty(selectedObj),strfind(tag,'roi_'))
                slRoi = getappdata(selectedObj,'roiHandle');
                self.model.currentRoi = slRoi;
            end 
        end
        
        function deleteRoi(self)
            display('Control:delete')
            selectedObj = gco;
            tag = get(selectedObj,'Tag');
            if and(~isempty(selectedObj),strfind(tag,'roi_'))
                slRoi = getappdata(selectedObj,'roiHandle');
                self.model.deleteRoi(slRoi);
                self.view.deleteRoiPatch(selectedObj);
            end 
        end
        
        function roi = copyRoi(self)
            currentRoi = self.model.currentRoi;
            roi = copy(currentRoi)
        end
                
        function addRoiArray(self,roiArray)
            cellfun(@(x) self.addRoi(x), roiArray);
        end

        function freshRoiArray = copyRoiArray(self)
            roiArray = self.model.getRoiArray();
            freshRoiArray = cellfun(@copy,roiArray, ...
                                    'UniformOutput',false);
            
        end
        
        function saveRoiArray(self,filePath)
            NrModel.saveRoiArray(self.model,filePath)
        end
        
        function loadRoiArray(self,filePath)
            foo = load(filePath);
            roiArray = foo.roiArray;
            self.addRoiArray(roiArray);
        end
        
        
    end
    
    methods
        function closeGUI(self,src,event)
            selection = questdlg('Close MyGUI?', ...
                                 'Warning', ...
                                 'Yes','No','Yes');
            switch selection
              case 'Yes'
                delete(src)
              case 'No'
                return
            end
        end
    end

end
