function [Data] = processBehaviorCamera(Data)
%----------------------------------------------------------------------------------------------
% Written by Kevin L. Turner
% Brown University, Department of Neuroscience
% https://github.com/KL-Turner
%
% Read behavior video, choose crop, stamp timestamps, return uint8 stack
%
%----------------------------------------------------------------------------------------------
currentDir = pwd;
figPath = [currentDir '/Figures/'];
dataDir = fullfile(currentDir,'Raw Data');
behavCamPath = fullfile(dataDir,['BehaviorCam-' Data.notes.dateString '.avi']);
[~,behavCamName,behavCamExt] = fileparts(behavCamPath); % behavCamPath is the full path
fprintf('Reading %s%s\n\n',behavCamName,behavCamExt);
behaviorCam = VideoReader(behavCamPath);
nominalFrameRate = behaviorCam.FrameRate;
Data.behaviorCam.numFrames = floor(behaviorCam.Duration*nominalFrameRate);
Data.behaviorCam.videoHeight = behaviorCam.Height;
Data.behaviorCam.videoWidth = behaviorCam.Width;
Data.notes.behaviorCamHz = Data.behaviorCam.numFrames / Data.notes.trialDurationSeconds;
frames = zeros(behaviorCam.Height,behaviorCam.Width,floor(behaviorCam.Duration*behaviorCam.FrameRate),'uint8');
aa = 1;
while hasFrame(behaviorCam)
    frames(:,:,aa) = rgb2gray(readFrame(behaviorCam));
    aa = aa + 1;
end
% reposition rectangle to crop image
fixedWidth  = 400;
fixedHeight = 300;
sampleFrame = frames(:,:,100);
newROI = [1,1,fixedWidth,fixedHeight];
newROIFig = figure;
ax = axes('Parent',newROIFig);
imshow(sampleFrame,'Parent',ax);
axis(ax,'image');
axis(ax,'off');
colormap(ax,'gray');
title(ax,'Reposition cropping window and double-click to confirm');
% reposition rectangle ROI
fprintf('Reposition cropping window and double click to confirm\n\n');
h = drawrectangle(ax,'Position',newROI,'Rotatable',false,'FaceAlpha',0.05,'Color','y','LineWidth',1.25);
addlistener(h,'MovingROI',@(~,evt) title(ax,mat2str(evt.CurrentPosition,3)));
addlistener(h,'ROIMoved', @(~,evt) title(ax,mat2str(evt.CurrentPosition,3)));
wait(h); % finalize on double-click; then read Position
resizePosition = h.Position; % [x y w h]
newImage = imcrop(sampleFrame,resizePosition); % crop image
close(newROIFig)
% Show final result
newImageFig = figure;
imagesc(newImage)
axis image off
colormap gray
savefig(newImageFig,[figPath Data.notes.animalID '_' Data.notes.dateString '_behaviorCam']);
close(newImageFig)
% assign timestamp to each frame
finalFrames = zeros(fixedHeight + 1,fixedWidth + 1,Data.behaviorCam.numFrames,'uint8'); % pre-allocate
for bb = 1:Data.behaviorCam.numFrames
    thisFrame = imcrop(frames(:,:,bb),resizePosition);
    thisRGB = repmat(thisFrame,[1,1,3]);
    timestamp = sprintf('%.2f s',bb / Data.notes.behaviorCamHz);
    timeStampPosition = [10,10]; % [x,y]
    thisRGB = insertText(thisRGB,timeStampPosition,timestamp,'FontSize',16,'TextColor','white','BoxColor','black','BoxOpacity',0.5);
    finalFrames(:,:,bb) = rgb2gray(thisRGB);
end
Data.behaviorCam.frames = finalFrames;
figure; % review webcam stack & behavior
sliceViewer(Data.behaviorCam.frames);