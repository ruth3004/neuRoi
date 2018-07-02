classdef NrController < handle
    properties
        model
        view
    end
       
    properties (SetObservable)
        timeTraceState
        roiDisplayState
    end
    
    methods
        function self = NrController(mymodel)
            self.timeTraceState = 'dfOverF';
            self.roiDisplayState = true;

            self.model = mymodel;
            self.model.calcResponse();
            self.model.calcAnatomy()
            self.view = NrView(self);
        end
        
        % Change display states
        function toggleRoiDisplayState(self)
            self.roiDisplayState = ~self.roiDisplayState;
        end
        
        % ROI funcitons
        function addRoiInteract(self)
            if ~self.roiDisplayState
                self.roiDisplayState = true;
            end
            rawRoi = imfreehand;
            %TODO important, deal with roi cancelled by Esc!!
            if ~isempty(rawRoi)
                position = rawRoi.getPosition();
                delete(rawRoi)
                imageInfo = getImageSizeInfo(self.view.guiHandles.mapImage);
                if ~isempty(position)
                    freshRoi = RoiFreehand(0,position,imageInfo);
                    roiPatch = self.addRoi(freshRoi);
                    % Set the new ROI as the selected ROI
                    self.selectSingleRoi(roiPatch);
                end
            end
        end

        function roiPatch = addRoi(self,roi)
            if isvalid(roi) && isa(roi,'RoiFreehand')
                % TODO check if image info matches
                self.model.addRoi(roi);
                roiPatch = self.view.addRoiPatch(roi);
            else
                warning('Invalid ROI!')
            end
        end

        % function selectRoi(self)
        %     selectedObj = gco; % get(gco,'Parent');
        %     tag = get(selectedObj,'Tag');
        %     if and(~isempty(selectedObj),strfind(tag,'roi_'))
        %         slRoi = getappdata(selectedObj,'roiHandle');
        %         self.model.currentRoi = slRoi;
        %     else
        %         self.model.currentRoi = [];
        %     end 
        % end
        
        function selectSingleRoi(self,varargin)
            if nargin == 1
                selectedObj = gco; % get(gco,'Parent');
            elseif nargin == 2
                selectedObj = varargin{1};
            else
                error('Wrong usage!')
            end
            
            tag = get(selectedObj,'Tag');
            if and(~isempty(selectedObj),strfind(tag,'roi_'))
                self.view.selectSingleRoiPatch(selectedObj);
                slRoi = getappdata(selectedObj,'roiHandle');
                self.model.selectSingleRoi(slRoi);
                
                trace = self.model.selectedTraceArray{end};
                self.view.holdTraceAxes('off');
                self.view.plotTimeTrace(trace,slRoi.id);
            else
                cla(self.view.guiHandles.traceAxes);
                self.view.holdTraceAxes('off');
                self.view.unselectAllRoiPatch();
                self.model.unselectAllRoi();
            end
        end
        
        function selectMultRoi(self)
            selectedObj = gco; % get(gco,'Parent');
            tag = get(selectedObj,'Tag');
            if and(~isempty(selectedObj),strfind(tag,'roi_'))
                if strcmp(selectedObj.Selected,'off')
                    self.view.selectRoiPatch(selectedObj);
                    slRoi = getappdata(selectedObj,'roiHandle');
                    self.model.selectRoi(slRoi);
                    
                    self.view.holdTraceAxes('on');
                    trace = self.model.selectedTraceArray{end};
                    self.view.plotTimeTrace(trace,slRoi.id);
                else
                    roiId = regexp(tag,'\d{4}','match');
                    roiId = str2num(roiId{:})
                    self.view.deleteTraceLine(roiId);

                    self.view.unselectRoiPatch(selectedObj);
                    slRoi = getappdata(selectedObj,'roiHandle');
                    self.model.unselectRoi(slRoi);
                end
            end
        end
        
        function deleteRoi(self)
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
