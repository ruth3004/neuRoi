function handles = trialStackGui(mapSize)
% TRIALSTACKGUI create a GUI for sliding over stack of images from all trials
    handles.mainFig = figure('Position',[600,300,750,650]);
    handles.mapAxes = axes('Position',[0.15 0.1 0.8 0.72]);
    handles.mapImage  = imagesc(zeros(mapSize),'Parent',handles.mapAxes);

    % Sliders for contrast adjustment
    handles.contrastSliderGroup = uibuttongroup('Position',[0.7,0.9,0.25,0.1]);
    handles.contrastMinSlider = uicontrol(handles.contrastSliderGroup,...
                                          'Style','slider', ...
                                          'Tag','contrastSlider_1',...
                                          'Units','normal',...
                                          'Position',[0 0.5 1 0.4]);
    
    handles.contrastMaxSlider = uicontrol(handles.contrastSliderGroup,...
                                          'Style','slider', ...
                                          'Tag','contrastSlider_2',...
                                          'Units','normal',...
                                          'Position',[0 0 1 0.4]);

    handles.metaText = uicontrol('Style','text',...
                                 'String','meta data',...
                                 'Units','normal',...
                                 'Position',[0.02 0.85 0.12 0.15],...
                                 'BackgroundColor',[255,250,250]/255);
    
end
