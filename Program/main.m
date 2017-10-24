function main()
% ============================================================================ %
% EEG echo binocular transfer experiment 2

% condition and trigger type:
% 1: Bi
% 2: LR
% 3: RL
% 4: LRLR
% 5: RLRL
% 254: Rest start
% 255: Rest end

% 1.0 - Acer 2017/10/24 16:28
% ============================================================================ %



%% Parameters
presentationScreen   = 2;                  
isTriggerEnable      = 0;                  
conditionTrialNumber = [150 75 75 75 75];  
    % condition:
    % 1: Bi
    % 2: LR
    % 3: RL
    % 4: LRLR
    % 5: RLRL


%% Initialize
addpath(genpath('PsyObj'));
addpath(genpath('Functions'));
disp('PsyObj imported');


% parallele obj
% ----------------------------------------------------------------------
parallelObj = PsyParallelPort;
if isTriggerEnable
    parallelObj.enableTTL; %#ok<UNRCH>
    parallelObj.disablePrint;
end
parallelObj.send(0);

% date log in
data.date = datestr(now); 

% Change Priority
Priority(2);


%% Subject information input
subjInfo = SubjInfObj;
subjInfo.gui;
data.subjInfo = subjInfo.makeStructure();


%% Parameters

% Screen
% ----------------------------------------------------------------------------
para.screen.wNum = presentationScreen;
para.screen.resolustionSet = 0;
para.screen.refreshRate = 160;
para.screen.width = 800;
para.screen.height = 600;
para.screen.isGammaCorrection = 0;

% binocular 
% ----------------------------------------------------------------------------
[centreLeftShift, centreRightShift] = readPosition();
para.binocular.centreLeftShift = centreLeftShift;
para.binocular.centreRightShift = centreRightShift;


% trial
% ----------------------------------------------------------------------------
para.trial.restTrialNum = 50;
para.trial.restSec = 4;
para.trial.ITI = [2.5 3.5];


% disk sequence 
% ----------------------------------------------------------------------------
para.seq.duration = 5;
para.seq.size = 100;
para.seq.eccentricity = [0 -115]; 
para.seq.nFrame = para.seq.duration * para.screen.refreshRate;


% repeat sequence
% ----------------------------------------------------------------------------
% para.repSeq.nRep = 4;
para.seq.nSeqByCondition = conditionTrialNumber;
% condition:
% 1: Bi
% 2: LR
% 3: RL
% 4: LRLR
% 5: RLRL

para.trial.num = sum(para.seq.nSeqByCondition);


% save to data
% ----------------------------------------------------------------------------
data.para = para;


%% Design

% make trial condition index
iCondi = [];
for ii = 1:length(para.seq.nSeqByCondition)
    iCondi = [iCondi; repmat(ii, para.seq.nSeqByCondition(ii), 1)]; %#ok<AGROW>
end
iCondi = iCondi(randperm(length(iCondi)));


% Make sequence and assign parameters to trials
% ----------------------------------------------------------------------------
seqMat = NaN(para.trial.num, para.seq.nFrame);
for iTrial = 1:para.trial.num
    seqMat(iTrial, :) = MakeSequence(para.screen.refreshRate, para.seq.duration, 1);      
    data.trialInfo(iTrial).iTrial = iTrial;
    data.trialInfo(iTrial).ITI = unidrand2(1, para.trial.ITI);
    data.trialInfo(iTrial).sequence = seqMat(iTrial, :);
    data.trialInfo(iTrial).iCondi = iCondi(iTrial);
    data.trialInfo(iTrial).triggerCode = data.trialInfo(iTrial).iCondi;
end


% save to data
% ----------------------------------------------------------------------------
data.sequence = seqMat;


%% Initialize Psychotoolbox and objects
PsyInitialize;
commandwindow();

% Screen
% Screen('Preference', 'SkipSyncTests', 1);
w = PsyScreen(para.screen.wNum);
w.ctrl_gammaCorrection = para.screen.isGammaCorrection;
if para.screen.resolustionSet
    w.resolustion_experiment.width = para.screen.width;
    w.resolustion_experiment.height = para.screen.height;
    w.resolustion_experiment.hz = para.screen.refreshRate;
    w.resolutionSet();
end

% w.openTest([100 100 800 800]);
w.open();



% Rest Text
p = PsyText_Prompt(w);                  


% disk
d = PsyOval(w);
d.size = [para.seq.size, para.seq.size];
d.center = para.seq.eccentricity + [w.xcenter w.ycenter];
diskCentreL = [w.xcenter w.ycenter] + para.seq.eccentricity + centreLeftShift;
diskCentreR = [w.xcenter w.ycenter] + para.seq.eccentricity + centreRightShift;


% fixation
fix = PsyCross(w);
fix.color = [50, 50, 50];


% command window message
mesg = PsyCommandWindowMessage;


% record variables
frameTimingMat = NaN(size(seqMat));


% Break time counter
cBreak = 0;


% binacular
centreL = centreLeftShift + [w.xcenter w.ycenter];
centreR = centreRightShift + [w.xcenter w.ycenter];

%% Exp start
% ======================================================================

parallelObj.send(254);
p.playWelcome_and_prompt();
parallelObj.send(255);

mesg.blockMessage('Experiment starts');
for iTrial = 1:para.trial.num
    
    % Trial Initialize
    % ---------------------------------------------------------------------
    mesg.trialNum(iTrial);
        
    % Resting Screen
    % ---------------------------------------------------------------------    
    if ( floor( (iTrial-1) ./ para.trial.restTrialNum) - cBreak ) > 0 &&...
            data.trialInfo(iTrial).nRep == 1
        parallelObj.send(254);
        mesg.blockMessage('Rest block onset');
        
        [remainBlcok] = calBlockRemain(iTrial,...
            para.trial.restTrialNum,...
            para.trial.num);
        
        p.playRest_Block_pressKey(remainBlcok); 
        
        parallelObj.send(255);
        mesg.blockMessage('Rest block offset');
        WaitSecs(3);
        cBreak = cBreak + 1;                
    end
    
    % fixation
    fix.xy = centreL;
    fix.draw();
    fix.xy = centreR;  
    fix.play();
    
    WaitSecs( data.trialInfo(1, 1).ITI );

    
    % =====================================================================
    % Run sequence
    % =====================================================================
    % Send onset Trigger
    
    parallelObj.send( data.trialInfo(iTrial).triggerCode );
        
    
    % Sequence Presentation
    for iFrame = 1:length( data.trialInfo(iTrial).sequence )
        d.color = repmat( data.trialInfo(iTrial).sequence(iFrame), 1, 3);
        
        % draw fixation
        fix.xy = centreL;
        fix.draw();
        fix.xy = centreR;  
        fix.draw();
        
       % draw disk 
        switch data.trialInfo(iTrial).iCondi
            case 1               
                d.center = diskCentreL;
                d.draw();                
                d.center = diskCentreR;
                d.draw();
            case 2
                fInd = frame2ind(iFrame, para.seq.nFrame, [0, 0.5]);
                if fInd == 1 
                   d.center = diskCentreL;
                   d.draw();
                elseif fInd == 2
                   d.center = diskCentreR;
                   d.draw();
                end
            case 3
                fInd = frame2ind(iFrame, para.seq.nFrame, [0, 0.5]);
                if fInd == 1 
                   d.center = diskCentreR;
                   d.draw();
                elseif fInd == 2
                   d.center = diskCentreL;
                   d.draw();
                end              
            case 4
                fInd = frame2ind(iFrame, para.seq.nFrame, [0, 0.25, 0.5, 0.75]);
                if fInd == 1 
                   d.center = diskCentreL;
                   d.draw();
                elseif fInd == 2
                   d.center = diskCentreR;
                   d.draw();
                elseif fInd == 3
                   d.center = diskCentreL;
                   d.draw();                   
                elseif fInd == 4
                   d.center = diskCentreR;
                   d.draw();                   
                end                     
            case 5
                fInd = frame2ind(iFrame, para.seq.nFrame, [0, 0.25, 0.5, 0.75]);
                if fInd == 1 
                   d.center = diskCentreR;
                   d.draw();
                elseif fInd == 2
                   d.center = diskCentreL;
                   d.draw();
                elseif fInd == 3
                   d.center = diskCentreR;
                   d.draw();                   
                elseif fInd == 4
                   d.center = diskCentreL;
                   d.draw();   
                end
        end
        frameTimingMat(iTrial, iFrame) = d.flip();
    end
    
    parallelObj.send(0);
    fix.xy = centreL;
    fix.draw();
    fix.xy = centreR;    
    fix.play();
    % ======================= End of sequence presentation ======================= % 
    
    % data login 
    data.trialInfo(iTrial).trialEndTime = datestr(now,'yyyy-mm-dd HH:MM:SS');
    data.trialInfo(iTrial).frameTiming = frameTimingMat(iTrial, :);    
    
    % Save Timing Matrix
    data.frameTimingMat = frameTimingMat;
    
    
    % Save to file
    save(sprintf('data_s%s.mat', data.subjInfo.SubjectID), 'data');
    
end

%% End of the experiment
save(sprintf('data_s%s_all.mat', data.subjInfo.SubjectID));

w.close();
Priority(0);
mesg.blockMessageLarge('End Experiment');

