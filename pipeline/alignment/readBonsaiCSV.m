function [Data] = readBonsaiCSV(Data)
%----------------------------------------------------------------------------------------------
% Written by Kevin L. Turner
% Brown University, Department of Neuroscience
% https://github.com/KL-Turner
%
% Read CSV data from Bonsai files, interpolate to 1 kHz, and apply correction for time delay
%
%----------------------------------------------------------------------------------------------
currentDir = pwd;
figPath = [currentDir '/Figures/'];
dataDir = fullfile(currentDir,'Raw Data');
csvFiles.frameCounter = ['FrameCounter-' Data.notes.dateString '.csv'];
csvFiles.rotaryEncoder = ['RotaryEncoder-' Data.notes.dateString '.csv'];
csvFiles.vibrissaePiezo = ['VibrissaePiezo-' Data.notes.dateString '.csv'];
csvFiles.capacitiveSensor = ['CapacitiveSensor-' Data.notes.dateString '.csv'];
csvFiles.rewardSolenoid = ['RewardSolenoid-' Data.notes.dateString '.csv'];
csvFiles.failureSolenoid = ['FailureSolenoid-' Data.notes.dateString '.csv'];
csvFiles.optoLED = ['OptoLED-' Data.notes.dateString '.csv'];
csvFields = fieldnames(csvFiles);
for aa = 1:length(csvFields)
    csvField = csvFields{aa,1};
    csvFilePath = fullfile(dataDir,csvFiles.(csvFields{aa,1}));
    if exist(csvFilePath,'file') == 2
        Data.(csvField) = [];
        % --- CSV import (robust across MATLAB versions) ---
        opts = delimitedTextImportOptions("NumVariables", 2);
        opts.VariableNames = {'Signal','Timestamp'};
        opts.VariableTypes = {'double','string'};   % read Timestamp as text
        [~,csvFileName,csvFileExt] = fileparts(csvFilePath);
        fprintf('Reading %s%s\n\n', csvFileName, csvFileExt);
        csvData = readtable(csvFilePath, opts);
        % Parse timestamps that include zone offsets, e.g. 2025-05-27T16:24:41.1234567-04:00
        fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSXXX";
        ts = datetime(csvData.Timestamp, 'InputFormat', fmt, 'TimeZone', 'UTC');
        ts.TimeZone = ''; % retains absolute times, drops zone metadata
        csvData.Timestamp = ts;
        % csvData = readtable(csvFilePath,opts); % read CSV file
        samplingRate = 1000;
        t_raw = seconds(csvData.Timestamp - csvData.Timestamp(1)); % convert timestamp to seconds relative to start
        signal_raw = csvData.Signal;
        [t_unique,ia] = unique(t_raw); % remove duplicates from time vector
        signal_unique = csvData.Signal(ia); % matching signal values
        t_uniform = (0:1/samplingRate:t_unique(end))'; % uniformly spaced time base (1 kHz)
        signal_interp = interp1(t_unique,signal_unique,t_uniform,'linear'); % interpolate to uniform time base
        % correct time shift
        if strcmp(csvField,'frameCounter') == true
            % generate figure
            if ~isfield(Data.notes,'firstFrameDurationSeconds')
                frameCountFig = figure;
                plot(t_raw,signal_raw,'color',colors('dark midnight blue'),'LineWidth',0.25)
                xlabel('Time (s)')
                ylabel('Frame Counter (a.u.)')
                set(gca,'box','off')
                xlim([0,2])
                ylim([0,1200])
                fprintf('Full frame length (s): %s\n',num2str(Data.notes.framePeriod));
                Data.notes.firstFrameDurationSeconds = round(input('Input first frame length (s): '),3); disp(' ')
                close(frameCountFig)
            end
            Data.notes.bonsaiDelaySeconds = Data.notes.framePeriod - Data.notes.firstFrameDurationSeconds;
            Data.notes.estimatedNumberOfFrames = ceil(1/Data.notes.framePeriod*2400);
            fprintf('Estimated Number of frames: %s\n\n',num2str(Data.notes.estimatedNumberOfFrames));
            frameIndex = (round(t_uniform,3) == Data.notes.firstFrameDurationSeconds);
            Data.notes.secondFrameCSVIndex = find(frameIndex,1,'first');
            frontTrim = t_uniform(Data.notes.secondFrameCSVIndex:end) - t_uniform(Data.notes.secondFrameCSVIndex);
            Data.notes.trialDurationSeconds = round(Data.notes.framePeriod*(Data.notes.estimatedNumberOfFrames - 1),2);
            frameIndex = (round(frontTrim,3) ==  Data.notes.trialDurationSeconds);
            Data.notes.lastFrameCSVIndex = find(frameIndex,1,'first') + Data.notes.secondFrameCSVIndex;
            Data.(csvField).timeVec = t_uniform(Data.notes.secondFrameCSVIndex:Data.notes.lastFrameCSVIndex) - t_uniform(Data.notes.secondFrameCSVIndex);
            Data.(csvField).signal = signal_interp(Data.notes.secondFrameCSVIndex:Data.notes.lastFrameCSVIndex);
            fprintf('Time corrected image sequence: %s seconds\n',num2str(Data.notes.trialDurationSeconds));
            fprintf('Time corrected bonsai sequence: %s seconds\n\n',num2str(Data.(csvField).timeVec(end)));
        else % frame counter is always first, so assume we can apply time correction to every other field
            Data.(csvField).timeVec = t_uniform(Data.notes.secondFrameCSVIndex:Data.notes.lastFrameCSVIndex) - t_uniform(Data.notes.secondFrameCSVIndex);
            Data.(csvField).signal = signal_interp(Data.notes.secondFrameCSVIndex:Data.notes.lastFrameCSVIndex);
        end
        % temporary for T450, T451, T461, T462
        if strcmp(csvField,'vibrissaePiezo') == true && any(strcmp(Data.notes.animalID,{'T450','T451','T461','T462'}))
            padArray = zeros(100,1);
            figHandle = figure;
            p1 = plot(Data.(csvField).timeVec,Data.(csvField).signal);
            tempSignal = cat(1,padArray,Data.(csvField).signal);
            Data.(csvField).signal = tempSignal(1:end - 100);
            hold on;
            p2 = plot(Data.(csvField).timeVec,Data.(csvField).signal);
            title(csvField)
            xlabel('Time (s)')
            ylabel('Signal (a.u.)')
            legend([p1,p2],'Original','100 ms delay corrected')
            set(gca,'box','off')
            xlim([0,Data.notes.trialDurationSeconds])
            ylim([0,1200])
            % save the file to directory.
            savefig(figHandle,[figPath Data.notes.animalID '_' Data.notes.dateString '_' (csvField) '_delayCorrection']);
        else
            % generate figure - time corrected data
            figHandle = figure;
            plot(Data.(csvField).timeVec,Data.(csvField).signal,'color',colors('dark midnight blue'),'LineWidth',0.25)
            title(csvField)
            xlabel('Time (s)')
            ylabel('Signal (a.u.)')
            set(gca,'box','off')
            xlim([0,Data.notes.trialDurationSeconds])
            ylim([0,1200])
            % save the file to directory.
            savefig(figHandle,[figPath Data.notes.animalID '_' Data.notes.dateString '_' (csvField)]);
        end
    end
end
csvFields = {'vibrissaePiezo';'capacitiveSensor';'rewardSolenoid';'failureSolenoid';'optoLED'};
for aa = 1:length(csvFields)
    csvField = csvFields{aa,1};
    if isfield(Data,csvField) == true
        signal = Data.(csvField).signal;
        t = Data.(csvField).timeVec;
        binSignal = signal >= 10;
        if strcmp(csvField,'capacitiveSensor') == false
            samplingRate = 1000;
            deadSamp = round(1.0*samplingRate);
            onsets = find(binSignal & ~[false; binSignal(1:end - 1)]); % rising edges
            if ~isempty(onsets)
                keep = [true; diff(onsets) >= deadSamp];
                onsets = onsets(keep);
            end
            onsetTimes = t(onsets); % timestamps at event starts (in seconds)
        else
            onsets = find(binSignal);
            onsetTimes = t(onsets);
        end
        % save
        Data.(csvField).eventOnsetTimes = onsetTimes;
        eventOnsetBinary = false(size(binSignal));
        eventOnsetBinary(onsets) = true;
        if strcmp(csvField,'failureSolenoid') == true
            tolSec = 1.0; % window: ±1 s
            rTimes = Data.rewardSolenoid.eventOnsetTimes; % Onset TIMES (seconds)
            fTimes = Data.failureSolenoid.eventOnsetTimes;
            tF = Data.failureSolenoid.timeVec;
            % Identify failure onsets within tolSec of ANY reward onset
            if ~isempty(fTimes) && ~isempty(rTimes)
                isNearReward = ismembertol(fTimes,rTimes,tolSec,'DataScale',1);
            else
                isNearReward = false(size(fTimes));
            end
            fTimes_new = fTimes(~isNearReward);  % Keep only failure onsets NOT near rewards
            % Rebuild the 0/1 stem vector for failure onsets (snap to nearest sample)
            onsetBinaryF = false(size(Data.failureSolenoid.signal));
            if ~isempty(fTimes_new)
                idxF_new = interp1(tF,1:numel(tF),fTimes_new,'nearest','extrap');
                idxF_new = max(1,min(numel(tF),round(idxF_new))); % clamp to range
                onsetBinaryF(idxF_new) = true;
            end
            % Save back (times only)
            eventOnsetBinary = onsetBinaryF;
            Data.failureSolenoid.eventOnsetTimes  = fTimes_new;
        end
        fs = 1000; % Hz (original sampling rate)
        targetFs = 10; % Hz (downsample target)
        binSamp  = fs / targetFs; % 100 for 1 kHz -> 10 Hz
        x = eventOnsetBinary(:);  % original vector (any type)
        N = numel(x);
        nBins = ceil(N / binSamp);
        padN  = nBins*binSamp - N;
        % --- preallocate and fill b (logical) ---
        b = false(N + padN, 1);
        b(1:N) = x ~= 0;          % copy as logicals; padded tail stays false
        B  = reshape(b, binSamp, nBins);   % 0.1 s windows by columns
        ds = any(B, 1).';                  % windowed OR -> 10 Hz logical
        t10 = ((0:nBins-1).' + 0.5) / targetFs;  % bin centers in seconds
        Data.(csvField).dsTimeVec = t10;
        Data.(csvField).dsBinarySignal = ds;
    end
end