classdef TrialStackController < handle
    properties
        model
        view
    end
    
    methods
        function self = TrialStackController(mymodel)
            self.model = mymodel;
            self.view = trialStack.TrialStackView(self.model,self);
            
            self.view.displayCurrentMap();
        end
        
        function keyPressCallback(self, src, evnt)
            if isempty(evnt.Modifier)
                switch evnt.Key
                  case {'j','k'}
                    self.slideTrialCallback(evnt)
                end
            end
        end
        
        function slideTrialCallback(self,evnt)
            if strcmp(evnt.Key, 'k')
                self.model.currentTrialIdx = self.model.currentTrialIdx+1;
            elseif strcmp(evnt.Key, 'j')
                self.model.currentTrialIdx = self.model.currentTrialIdx-1;
            end
        end
        
        function contrastSlider_Callback(self,src,evnt)
        % Method to change contrast of map image
            contrastSliderInd = helper.convertTagToInd(src.Tag, ...
                                                       'contrastSlider');
            contrastLim = self.view.getContrastLim();
            dataLim = self.view.getContrastSliderDataLim();
            % Check whether contrastLim is valid (min < max), otherwise set the
            % other slider to a valid value based on the new value of
            % the changed slider;
            if contrastLim(1) >= contrastLim(2)
                contrastLim = ...
                    self.calcMinLessThanMax(contrastSliderInd, ...
                                              contrastLim,dataLim);
                self.view.setContrastLim(contrastLim);
            end
            self.view.changeMapContrast(contrastLim);
            self.model.saveContrastLimToCurrentMap(contrastLim);
        end

        function contrastLim = ...
                calcMinLessThanMax(self,contrastSliderInd,contrastLim,dataLim)
            sn = 10000*eps; % a small number
            switch contrastSliderInd
              case 1
                if contrastLim(1) >= dataLim(2)
                    contrastLim(1) = dataLim(2)-sn;
                end
                contrastLim(2) = contrastLim(1)+sn;
              case 2
                if contrastLim(2) <= dataLim(1)
                    contrastLim(2) = dataLim(1)+sn;
                end
                contrastLim(1) = contrastLim(2)-sn;
              otherwise
                error('contrastSliderInd should be 1 or 2 ');
            end
        end

        function updateContrastForCurrentMap(self)
        % Set limit and values of the contrast sliders
            map = self.model.getCurrentMap();
            dataLim = helper.minMax(map.data);
            sn = 10000*eps; % a small number
            dataLim(2) = dataLim(2) + sn;

            if isfield(map,'contrastLim')
                contrastLim = map.contrastLim;
                ss = helper.rangeIntersect(dataLim,contrastLim);
                if ~isempty(ss)
                    vcl = ss;
                else
                    vcl = dataLim;
                end
            else
                vcl = dataLim;
            end
            self.model.saveContrastLimToCurrentMap(vcl);
            self.view.setDataLimAndContrastLim(dataLim,vcl);
            self.view.changeMapContrast(vcl);
        end
    end
end
