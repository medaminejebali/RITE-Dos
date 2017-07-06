function [  ] = RITEDosPatientCalc( PatientEPIDdir )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

%% Prepare Patient EPIDs and TPS
EPID = EPIDprep(PatientEPIDdir);

[TPS_dosemap_name, path] = uigetfile('RP*.dcm');
TPS_dosemap_name = [path TPS_dosemap_name];
tps=dicomread(TPS_dosemap_name); 
tps_info=dicominfo(TPS_dosemap_name); 
tps=double(tps);
tps=100*tps*tps_info.DoseGridScaling/nFractions;


%% Adjusts the EPIDs for left-right and superior-inferior displacement.
epid_elements=sort(EPID(:),'descend');
epid_64_max=mean(epid_elements(1:64));
epid_64_min=mean(epid_elements(end-100:end-150));
epid=+(EPID>abs(epid_64_max+epid_64_min)/4);

tps_64_max=sort(tps(:),'descend');
tps_64_max=mean(tps_64_max(101:151));
mask_tps=+(tps>abs(tps_64_max)*.5);

mask_diff = mask-mask_tps;

epidsagSImagn=abs(sum(mask_diff(1:192,256))-sum(mask_diff(193:384,256)))/2;
epidsagSIsign=sign((sum(mask_diff(1:192,256))-sum(mask_diff(193:384,256))));

epidsagLRmagn=abs(sum(mask_diff(192,1:256))-sum(mask_diff(192,257:512)))/2;
epidsagLRsign=sign((sum(mask_diff(192,1:256))-sum(mask_diff(192,257:512))));    

EPID = circshift(EPID, [round(epidsagSIsign*epidsagSImagn) round(epidsagLRsign*epidsagLRmagn)]);   

mask_epid=+(EPID>abs(epid_64_max+epid_64_min)/4);


l_tps=round(sqrt(nnz(mask_tps)*0.05227*0.05227));
l_epid=round(sqrt(nnz(mask_tps)*0.05227*0.05227));

if abs(l_tps - l_epid) > 1
    disp('Field sizes of the treatment planning system and EPID images taken do not seem to match')
else
    l=l_epid;
end
% May also have an option to override when l's don't match.
w=round(WEDCAX(3));




%% Load commissioning data
% Will include the F, f, and TPR arrays
% and the w_s, l_s, d_s, and depths the data was taken at.
% Gaussian weights


g1 = gauss_distribution(1:1000,500,1.7/.523);
g2 = gauss_distribution(1:1000,500,1.7*2/.523);
g3 = gauss_distribution(1:1000,500,1.7*10/.523);
g4 = gauss_distribution(1:1000,500,1.7*30/.523);

%% Get patient w, l, and d map from CT (DAVID)

% Choose RT plan file
% plan=dicominfo(planfile(1).name);
% nFractions=plan.FractionGroupSequence.Item_1.NumberOfFractionsPlanned;


w_map=WEDsource2iso+WEDiso2epid;
d_map=WEDiso2epid-WEDsource2iso;
WEDtotavg = mean2(w_map(189:196,253:260));



%% Construct F, f, and TPR maps from w, l, and d

Fwindex = round((w_map-ones(384,512)*(Fw_s(1)))/0.1)+1;
Flindex = round((l-Fl_s(1))/0.1)+1;

F_map = FmatInt(Fwindex,Flindex);
F_map = reshape(F_map,384,512);

fdindex = round((d_map-ones(384,512)*(fd_s(1)))/0.1)+1;
flindex = round((l-fl_s(1))/0.1)+1;

f_map = fmatInt(fdindex,flindex);
f_map = reshape(f_map,384,512);

TPRlindex = round((l-TPRfields(1))/0.1)+1;
TPRwindex = round((w_map./2-TPRdepth(1))/0.1)+1;
TPRwdindex = round((w_map./2-d_map-TPRdepth(1))/0.1)+1;

TPR1 = TPRmatInt(TPRwdindex,TPRlindex);
TPR1 = reshape(TPR1, 384, 512);
TPR2 = TPRmatInt(TPRwindex,TPRlindex);
TPR2 = reshape(TPR2, 384, 512);

TPRR_map = TPR1./TPR2;

% Find map with w and l to weights.
[ w_close, wwindex ] = min(abs(Fw_s - w));
[ l_close, wlindex ] = min(abs(Fl_s - l));

gsumcr=(w_cr(1)*g1+w_cr(2)*g2+w_cr(3)*g3+w_cr(4)*g4)/trapz(w_cr(1)*g1+w_cr(2)*g2+w_cr(3)*g3+w_cr(4)*g4);
gsumin=(w_in(1)*g1+w_in(2)*g2+w_in(3)*g3+w_in(4)*g4)/trapz(w_in(1)*g1+w_in(2)*g2+w_in(3)*g3+w_in(4)*g4);

%% Create Patient Dose maps
% Before convolution
DOSE_NOCORR=mask_epid.*epid.*TMRratio.*fmatrix./Fmatrix;

%Convolving
PatDoseConv = getDoseConv(EPID,epid_mask,gsumcr,gsumin,TPRR_map,F_map,f_map);
end

