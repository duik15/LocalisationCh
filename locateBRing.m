% This script run beamforming over some ping emission to find back the array. 
% 
% It use a folderIn location and an array of time to read
% Time to process might be specifiy by ptime = [datetime(xxx),datetime(xxx)]
% or by a get function [ploc, ptime ]  = getPingLoc('aav');
%
% The figure to plot can be specify by the argument showFig = [1 3 4..]
% Figure code and description are located in showFigBring.m and
% showGlobalFig.m
%
% last update 7/10/2021 by @kevDuquette


% -------------- Fixed variables --------------------

% Loading file information
[fileList, wavID] = getWavName(ptime, folderIn);
wavInfo = audioinfo([folderIn fileList{1}]);
nbF = length(fileList);

% Array information
[arrLoc, offset, arrOri] = getArrLoc(arrID);

% Spectro parameters
% Spectro windows
LFFT_spectro = 2048;
LFFT_FV = Ns;
REC = 0.9;
w_pond = kaiser(LFFT_spectro ,0.1102*(180-8.7)); w_pond = w_pond*sqrt(LFFT_spectro/sum(w_pond.^2));
fact_zp =4;

 % Length of wav in second to load
duraNs = Ns / 10000;     

% Sound velocities
c = 1500;

% Pcolor plot
Lmin = 30;
Lmax = 70;

NB_voies_visees = 72;

SH =-194;
G = 40;
D = 1;

duree_film = 60;

% Creating a circle vecteur
Nc = 20;
R = 10;
theta = 0: 2*pi/(Nc) : 2*pi-2*pi/(Nc);
%offset = - (90-67) * pi /180; 
% Set hydropohone location and oriemntation
if strcmp(arrOri,'clock')
    xc = R*sin(theta +  offset * pi /180);
    yc = R*cos(theta +  offset* pi /180);
elseif strcmp(arrOri,'counter')
    xc = R*cos(theta +  offset* pi /180);
    yc = R*sin(theta +  offset* pi /180);
end


% Creating the output folder
if ~isfolder(folderOut); disp(['Creating output folder: ' folderOut]); mkdir(folderOut); end

%% File loop

% _Pre-Initialisation
matEnergie = nan(nbF,360);
angleA = nan(nbF,nbPk);

for iFile =1:length(fileList)
    disp(['Executing beamforming for file ' num2str(iFile) '/' num2str(length(fileList))])
    close all
    
    
    % Reading wav
    [MAT_s,fe, tstart, dura] = readBring([folderIn fileList{iFile}], ptime(iFile),'duration',duraNs,'buffer',buffer,'power2',true);
    file_wav = fileList{iFile};     % file name alone
    
    % ------------------ BEAMFORMIGN -----------------------
    MAT_s_vs_t_h = 10^(-SH/20)*10^(-G/20)*D*MAT_s;
    aa = size(MAT_s_vs_t_h);
    Nsample = aa(1,1);
    Nc =aa(1,2);
    Duree = (Nsample-1)*1/fe;
    t = (0:1:Nsample-1)*1/fe;
    
    % visualisation spectrogramme channel 1
    [vec_temps, vec_freq, MAT_t_f_STFT_complexe, MAT_t_f_STFT_dB] = COMP_STFT_snapshot(MAT_s_vs_t_h(:,1),0, fe, LFFT_spectro, REC, w_pond, fact_zp);
    
    % focalisation sur 1 snapshot particulier
    MAT_s_vs_t_h_INT = MAT_s_vs_t_h;
    
    % formation des FFT des channels
    MAT_ffts_vs_f_h_INT = nan(size(MAT_s_vs_t_h_INT));
    for u = 1 : Nc
        MAT_ffts_vs_f_h_INT(:,u)=fft(MAT_s_vs_t_h_INT(:,u));
    end
    vec_f = (0:1:LFFT_FV-1)*fe/LFFT_FV;
     
    indi_f = find( (vec_f >= fmin_int)&(vec_f <= fmax_int));
    MAT_ffts_vs_f_h_INT_INT = MAT_ffts_vs_f_h_INT(indi_f,:);
    vec_f_INT = vec_f(indi_f);
    
    NN = 360;
    vec_azimut = linspace(0,2*pi-2*pi/NN,NN);
    % on raisonne en azimut vs le barycentre du réseau
    x0 = mean(xc);
    y0 = mean(yc);
    xc_rel = xc - x0;
    yc_rel = yc -y0;
    
    
    % formation des pondérations frequence, azimut
    % cette matrice de pondération pourrait etre calculee en avance et chargé&e
    MAT_POND_vs_azim_h_freq = zeros(length(vec_azimut),length(xc_rel),length(vec_f_INT));
    Ncapt = length(xc_rel);
    for u = 1 : length(vec_azimut)
        for v = 1 : length(xc_rel)
            d_marche =-xc_rel(v)*sin(vec_azimut(u))+-yc_rel(v)*(cos(vec_azimut(u)));
            %MAT_POND_vs_azim_h_freq(u,v,:) = 1/Ncapt*exp(-sqrt(-1)*2*pi*vec_f_INT*d_marche/c);
            MAT_POND_vs_azim_h_freq(u,v,:) = 1/Ncapt*exp(-sqrt(-1)*2*pi*vec_f_INT*d_marche/c);
        end
    end
    
    
    % Goniométrie -------------------> Figure 2,3
    Energie = nan(1,length(vec_azimut));
    df = vec_f(2) -vec_f(1);
    for u = 1 : length(vec_azimut)
        MAT_POND_vs_h_freq =squeeze(MAT_POND_vs_azim_h_freq(u,:,:));
        Energie(u) = 0;
        for v = 1 : length(vec_f_INT)
            vec_pond = (MAT_POND_vs_h_freq(:,v)');
            vec_sfft  = MAT_ffts_vs_f_h_INT_INT(v,:);
            %Energie(u) = Energie(u)+ (abs(sum(vec_pond.*vec_sfft)))^2;
            Energie(u) = Energie(u)+ 1/(Ns*fe)*(abs(sum(vec_pond.*vec_sfft)))^2*df;
        end
    end
    
    % Other form of Energie unity
    Energie_NORM = Energie/max(Energie);
    Energie_dB = 10*log10(Energie);
    
    % Find peak of energy
    [pk pkloc] = findpeaks(Energie_NORM,'SortStr','descend','NPeaks', 4 );%'MinPeakHeight',0.3);
    
    % Find the direction of source
    angleA(iFile, : )  = pkloc;  % Angle of arrival with side lobe
    angleM(1,iFile)  = pkloc(1);  % Max angle of arrival

   
    % Keep the energie value in a matrix
    matEnergie(iFile, :) = Energie;
    
    % Printing figure
    showFigBring;
    
end % end loop on file



% Show global figure
showGlobalFig;


% Saving data
if saveData == true
    if exist('angleR')
        save([folderOut 'dataAngleOfArrival_' outName '.mat'],'angleA','angleM','angleR','ptime','ploc','matEnergie')
    else
        save([folderOut 'dataAngleOfArrival_' outName '.mat'],'angleA','angleM','ptime','matEnergie')
    end
end
