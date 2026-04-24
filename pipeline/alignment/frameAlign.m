currentDir = pwd;
figPath = [currentDir '/Figures/'];
if ~exist(figPath,'dir')
    mkdir(figPath); % make directory folder during first initialization
end
% load data structs if present
structFileNames = "*_Data.mat";
dataFileStruct = dir(structFileNames);
dataFile = {dataFileStruct.name}';
dataFile = dataFile(~startsWith(dataFile, '._'));  % drop AppleDouble files
dataFileID = char(dataFile);
if ~isempty(dataFileID)
    fprintf('Loading %s\n\n',dataFileID);
    load(dataFileID)
else
    Data = [];
end
% read PrairieView (Bruker) acquisition parameters from XML file, return Notes struct
if any([~isfield(Data,'notes'), ~isfield(Data,'frameCounter'), ~isfield(Data,'behaviorCam')])
    if ~isfield(Data,'notes')
        [Data.notes] = parsePrairieXML(currentDir);
    end
    % read CSV data from Bonsai files
    if ~isfield(Data,'frameCounter')
        [Data] = readBonsaiCSV(Data);
    end
    % create VideoReader object for behavior camera
    if ~isfield(Data,'behaviorCam')
        [Data] = processBehaviorCamera(Data);
    end
    % display final notes for review
    disp(Data.notes);
    fprintf('Saving Data Struct: %s_%s_Data.mat\n\n',Data.notes.animalID,Data.notes.dateString);
    save([Data.notes.animalID '_' Data.notes.dateString '_Data.mat'],'Data','-v7.3')
end