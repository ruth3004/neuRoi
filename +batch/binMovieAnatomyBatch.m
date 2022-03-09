 function binMovieAnatomyBatch(param,outDir,planeNum,nPlane,anatomyDataPath,anatomyDataFile)
 
            if ~exist(outDir,'dir')
                mkdir(outDir)
            end
            
            trialOption = param.trialOption;

                if exist('planeNum','var')
                    planeString = NrModel.getPlaneString(planeNum);
                    outSubDir = fullfile(outDir,planeString);
                    if ~exist(outSubDir,'dir')
                        mkdir(outSubDir)
                    end
                    trialOption.nFramePerStep = nPlane;
                    trialOption.zrange = [planeNum,inf]; 
                else
                    error(['Please specify plane number for' ...
                           ' multiplane data!']);
                end
 
                rawFileList = anatomyDataFile;
            
            
            binConfig = batch.binMovieFromFile(anatomyDataPath, ...
                                               rawFileList, ...
                                               outSubDir,...
                                               param.shrinkFactors,...
                                               param.depth,...
                                               trialOption);
            binConfig.outDir = outDir;
            binConfig.trialOption = param.trialOption;
            %self.binConfig = binConfig;
            % timeStamp = helper.getTimeStamp();
            % configFileName = ['binConfig-' timeStamp '.json'];
            configFileName = 'binConfig.json';
            configFilePath = fullfile(outDir,configFileName);
            helper.saveStructAsJson(binConfig,configFilePath);
end