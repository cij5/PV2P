function [notes] = parsePrairieXML(currentDir)
%----------------------------------------------------------------------------------------------
% Written by Kevin L. Turner
% Brown University, Department of Neuroscience
% https://github.com/KL-Turner
%
% Read PrairieView (Bruker) acquisition parameters from XML file, return Notes struct
%
%----------------------------------------------------------------------------------------------
[parent1,~] = fileparts(currentDir);
[~,animalFolder] = fileparts(parent1);
notes.animalID = animalFolder(1:4);
dataDir = fullfile(currentDir,'Raw Data');
xmlList = dir(fullfile(dataDir,'*.xml'));
xmlPath = fullfile(dataDir,xmlList.name);
dateCell = extractBetween(xmlPath,'FileInfo-','.xml');
notes.dateString = char(dateCell{1});
[~,xmlName,xmlExt] = fileparts(xmlPath); % xmlPath is the full path
fprintf('Reading %s%s\n\n',xmlName,xmlExt);
xmlDoc = xmlread(xmlPath);
allPVStateValues = xmlDoc.getElementsByTagName('PVStateValue');
notes.laserWavelength = '920 nm'; 
notes.SWGBEparams = '<0,0,25,2048,25,5,100>';
for aa = 0:allPVStateValues.getLength - 1
    node = allPVStateValues.item(aa);
    if node.hasAttributes
        key = char(node.getAttribute('key'));
        switch key
            case 'activeMode'
               notes.activeMode = char(node.getAttribute('value'));
            case 'bitDepth'
               notes.bitDepth = str2double(node.getAttribute('value'));
            case 'dwellTime'
               notes.dwellTime = str2double(node.getAttribute('value'));
            case 'framePeriod'
               notes.framePeriod = str2double(node.getAttribute('value'));
               notes.frameRateHz = 1 / notes.framePeriod;
            case 'laserPower'
                indexedValues = node.getElementsByTagName('IndexedValue');
                if indexedValues.getLength > 0
                    value = indexedValues.item(0);
                   notes.laserPockels = str2double(value.getAttribute('value'));
                end
            case 'pixelsPerLine'
                notes.imageWidth = str2double(node.getAttribute('value'));
            case 'linesPerFrame'
               notes.imageHeight  = str2double(node.getAttribute('value'));
            case 'micronsPerPixel'
                indexedValues = node.getElementsByTagName('IndexedValue');
                for bb = 0:indexedValues.getLength - 1
                    value = indexedValues.item(bb);
                    frameIndex = char(value.getAttribute('index'));
                    value = str2double(value.getAttribute('value'));
                    switch frameIndex
                        case 'XAxis'
                           notes.micronsPerPixelX = value;
                        case 'YAxis'
                            notes.micronsPerPixelY = value;
                        case 'ZAxis'
                           notes.micronsPerPixelZ = value;
                    end
                end
            case 'objectiveLens'
               notes.objectiveLens = char(node.getAttribute('value'));
            case 'objectiveLensMag'
               notes.objectiveLensMag = str2double(node.getAttribute('value'));
            case 'objectiveLensNA'
               notes.objectiveLensNA = str2double(node.getAttribute('value'));
            case 'opticalZoom'
               notes.opticalZoom = str2double(node.getAttribute('value'));
               notes.xFactor = notes.micronsPerPixelX / notes.opticalZoom;
               notes.yFactor = notes.micronsPerPixelY / notes.opticalZoom;
               notes.zFactor = notes.micronsPerPixelZ / notes.opticalZoom;
            case 'pmtGain'
                indexedValues = node.getElementsByTagName('IndexedValue');
                pmtGain = zeros(1,indexedValues.getLength);
                for bb = 0:indexedValues.getLength - 1
                    value = indexedValues.item(bb);
                    index = str2double(value.getAttribute('index')) + 1;
                    pmtGain(index) = str2double(value.getAttribute('value'));
                end
               notes.pmtCh1 = pmtGain(1);
               notes.pmtCh2 = pmtGain(2);
            case 'scanLinePeriod'
               notes.scanLinePeriod = str2double(node.getAttribute('value'));
        end
    end
end