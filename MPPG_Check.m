function MPPG_Check
%MPPG_Check.m
%This script compares measured and calculated MPPG data for all tests.
%The tests need to be summarized in an XL spreadsheet according to the format outlined below
clear all;
close all;

%path and file name to spread sheet that describe each test
[meas_f_file,meas_f_path,FilterIndex] = uigetfile('*.xlsx','Choose test summary spreadsheet');
meas_f_full = [meas_f_path meas_f_file];
[~,~,measTable] = xlsread(meas_f_full, 1); %1 indicates which page of the XL workbook the summary data is in
cd(meas_f_path);

mD = measTable(2:end,:); %remove header row
[numTests numCols] = size(mD);

%plot flag, tells subroutines to plot or not
plotOn = 0;

%Which columns hold what data in summary table
testID = 1;     %name of the test (string)
enID = 2;       %energy (integer)
subTestID = 3;  %PDD or Cross beam (string)
mPageID = 4;    %Measured data XL workbook page
mDepRID = 5;    %Measured data dependent variable (nC)
mIndepRID = 6;  %Measured data independent variable (position)
depthID = 7;    %Depth (for cross beam measurements)
cPathID = 8;    %Path to calculated dicom file (Pinnacle output)
cFnameID = 9;   %Name of calculated dicom file (Pinnacle output)
mPathID = 10;   %Path to measured data XL file
mFnameID = 11;  %Name of measured data XL file
cOrigXID = 12;  %Calculated dose grid origin offset (Lat)
cOrigYID = 13;  %Calculated dose grid origin offset (Sup-Inf)
cOrigZID = 14;  %Calculated dose grid origin offset (Axial)
cOrigResID = 15;%Dose grid resolution
xOffsetID = 16;%X offset (Lat, 0,0 is center of beam) in cm
zOffsetID = 17;%Z offset (Sup-Inf, 0,0 is center of beam) in cm

%Loop through all verification tests
for v = [2, 6]
    if strcmp('PDD',mD(v,3))
        %Run PDD verification
        measPDD = GetMeasPDD(mD{v,mPathID}, mD{v,mFnameID}, mD{v,mPageID},...
            mD{v,mDepRID}, mD{v,mIndepRID}, plotOn, ...
            mD{v,testID}, mD{v,enID}, mD{v,subTestID});
        
        calcPDD = GetCalcPDD(mD{v,cPathID}, mD{v,cFnameID}, mD{v,cOrigXID},...
            mD{v,cOrigYID}, mD{v,cOrigZID}, mD{v,cOrigResID}, plotOn, ...
            mD{v,testID}, mD{v,enID}, mD{v,subTestID}, mD{v,xOffsetID}, mD{v,zOffsetID});
        [regMeas regCalc sh] = RegisterPDDs(measPDD, calcPDD);
        %display how far we needed to shift to get best correlation, should be same for all beams?
        disp(['num pixels to shift: ' num2str(sh)]);
        
        %display PDDs
        figure;
        plot(regMeas(:,1), regMeas(:,2),'LineWidth',3); hold all;
        plot(regCalc(:,1), regCalc(:,2),'--','LineWidth',3);
        ylim([0 1.25]);
        xlabel('Depth (cm)');
        ylabel('Normalized dose');
        
        %title(['PDD ' num2str(mD{v,enID}) ' MV']);
        
        
        %perform gamma evaluation
        vOut = VerifyPDD(regMeas, regCalc, plotOn);
        
        %display gamma
        %figure;
        plot(regMeas(:,1),vOut,'*-','LineWidth',3);
        ylim([0 1.25]);
        xlabel('Depth (cm)','FontSize',15);
        ylabel('Gamma & Normalized Dose','FontSize',15);
        %title(['PDD Gamma ' num2str(mD{v,enID}) ' MV']);
        legend('Measured', 'Calculated', 'Gamma'); hold off;
        %WriteSummary(vOut);
    elseif strcmp('Cross',mD(v,3))
        %Run cross beam verification
        measCross = GetMeasCross(mD{v,mPathID}, mD{v,mFnameID}, mD{v,mPageID},...
            mD{v,mDepRID}, mD{v,mIndepRID}, plotOn, ...
            mD{v,testID}, mD{v,enID}, mD{v,subTestID}, ...
            mD{v,depthID});
        
        calcCross = GetCalcCross(mD{v,cPathID}, mD{v,cFnameID}, mD{v,cOrigXID},...
            mD{v,cOrigYID}, mD{v,cOrigZID}, mD{v,cOrigResID}, plotOn, ...
            mD{v,testID}, mD{v,enID}, mD{v,subTestID}, ...
            mD{v,depthID});        
        
        [regMeas regCalc sh] = RegisterPDDs(measCross, calcCross);
        figure;
        plot(regMeas(:,1), regMeas(:,2),'LineWidth',3); hold all;
        plot(regCalc(:,1), regCalc(:,2),'--','LineWidth',3);
        ylim([0 1.25]);
        xlabel('Position (cm)');
        ylabel('Normalized dose','FontSize',15);
        %legend('Measured', 'Calculated');
        %title(['Cross ' num2str(mD{v,enID}) ' MV @ ' num2str(mD{v,depthID}) ' cm']);   
        
        %perform gamma evaluation
        vOut = VerifyPDD(regMeas, regCalc, plotOn);
        
        %display gamma
        %figure;
        plot(regMeas(:,1),vOut,'*-','LineWidth',3);
        ylim([0 1.25]);
        xlabel('Position (cm)','FontSize',15);
        ylabel('Gamma & Normalized Dose','FontSize',15);
        %title(['Cross Gamma ' num2str(mD{v,enID}) ' MV @ ' num2str(mD{v,depthID}) ' cm']); 
        legend('Measured', 'Calculated', 'Gamma');
    end
        
end

%==============================================
%==============================================
function measPDD = GetMeasPDD(path, fname, page, depR, indepR, plotOn, test, en, sub)
    dep = xlsread([path fname], page, depR); %dependent var
    indep = xlsread([path fname], page, indepR);
    measPDD = flipud([indep./10 dep]); %flip is for Wellhoffer, divide by 10 for cm
    
    if plotOn
        figure;
        plot(indep,dep);
        ttl = ['Measured ' test ' ' num2str(en) 'MV ' sub];
        title(ttl);
    end
end

%==============================================
%==============================================
function measCross = GetMeasCross(path, fname, page, depR, indepR, plotOn, test, en, sub, depth)
    dep = xlsread([path fname], page, depR); %dependent var
    indep = xlsread([path fname], page, indepR);
    measCross = [indep./10 dep];
    
    if plotOn
        figure;
        plot(indep,dep);
        ttl = ['Measured ' test ' ' num2str(en) 'MV ' sub ' ' num2str(depth) ' cm depth'];
        title(ttl);
    end
end

%==============================================
%==============================================
function calcPDD = GetCalcPDD(path, fname, origX, origY, origZ, res, plotOn, test, en, sub, xOff, zOff)
    
    info = dicominfo([path fname]);    
    Y = dicomread(info);
    X = squeeze(Y(:,:,1,:));
    
    %Get size of array
    [numPixX numPixY numPixZ] = size(X);

    %Get interogation point in image frame
    %The image frame has 0,0,0 at most right, post, sup
    pixX = round((-origX+xOff)/res);
    pixSurY = 1; %water surface in image frame
    pixZ = numPixZ - round((-origZ+zOff)/res);    
    OnAxPdd = squeeze(squeeze(X(pixSurY:end,pixX,pixZ)));
    OnAxPdd = info.DoseGridScaling*double(OnAxPdd); %convert to dose in Gy
    PddIndep = linspace(0,length(OnAxPdd)*res,length(OnAxPdd)); %in cm
    %interpolate
    interpFac = 10;
    PddIndepInt = linspace(0,length(OnAxPdd)*res,length(OnAxPdd)*interpFac);
    OnAxPddInt = spline(PddIndep, OnAxPdd, PddIndepInt);

    if plotOn
        figure;
        plot(PddIndep,OnAxPdd); hold all;
        plot(PddIndepInt,OnAxPddInt);
        ttl = ['Calculated ' test ' ' num2str(en) 'MV ' sub];
        title(ttl);        
    end    
    calcPDD = [PddIndep' OnAxPdd]; %return the calculated PDD data
end

%==============================================
%==============================================
function calcCross = GetCalcCross(path, fname, origX, origY, origZ, res, plotOn, test, en, sub, depth)
    
    info = dicominfo([path fname]);    
    Y = dicomread(info);
    X = squeeze(Y(:,:,1,:));
    
    %Get size of array
    [numPixX numPixY numPixZ] = size(X);

    %Get interogation point in image frame
    %The image frame has 0,0,0 at most right, post, sup
    pixX = round((-origX)/res);
    pixY = round(depth/res) + 8; %water surface in image frame, +8 is Kentucky windage right now
    pixZ = numPixZ - round(-origZ/res);    
    %crossB = squeeze(squeeze(X(pixY,:,pixZ)));
    crossB = squeeze(squeeze(X(pixY,pixX,:)));
    crossB = info.DoseGridScaling*double(crossB); %convert to dose in Gy
    crossBIndep = linspace(-length(crossB)*res/2,length(crossB)*res/2,length(crossB)); %in cm
    %interpolate
    interpFac = 10;
    crossBIndepInt = linspace(0,length(crossB)*res,length(crossB)*interpFac);
    crossBInt = spline(crossBIndep, crossB, crossBIndepInt);

    if plotOn
        figure;
        plot(crossBIndep,crossB); hold all;
        plot(crossBIndepInt,crossBInt);
        ttl = ['Calculated ' test ' ' num2str(en) 'MV ' sub ' ' num2str(depth) ' cm depth'];
        title(ttl);        
    end    
    calcCross = [crossBIndep' crossB]; %return the calculated PDD data
end

%==============================================
%==============================================
function [regMeas regCalc sh] = RegisterPDDs(measPDD, calcPDD)
    regMeas = measPDD;
    regCalc = calcPDD;
    
    %normalize, *** this should be fixed with a proper cal factor
    measPDD(:,2) = measPDD(:,2)/max(measPDD(:,2));
    calcPDD(:,2) = calcPDD(:,2)/max(calcPDD(:,2));
    
    %match up the resolution by interpolation
    calcPDDInt = interp1(calcPDD(:,1), calcPDD(:,2), measPDD(:,1),'cubic');
    
    %cross correlate
    [c,lags] = xcorr(measPDD(:,2), calcPDDInt, 200);
    
    %determine the peak correlation offset
    [~,i] = max(c);
    sh = lags(i); %number of pixels to shift (and direction)
    
    %shift one of the curves to match the other, *** this shouldn't be necessary
    B = circshift(calcPDDInt,sh); %shift     
    
    %get rid of shifted pixels on end
    regMeas = [measPDD(1:end-abs(sh),1) measPDD(1:end-abs(sh),2)];
    regCalc = [measPDD(1:end-abs(sh),1) B(1:end-abs(sh))];
    
end

%==============================================
%==============================================
function vOut = VerifyPDD(regMeas, regCalc, plotOn)
    %Perform gamma evaluation
    
    distThr = 4; %mm
    doseThr = 0.04; %Should be Gray    
    
    %Compute distance error (in mm)
    len = length(regMeas(:,1));
    rm = repmat(10*regMeas(:,1),1,len); %convert to mm
    rc = repmat(10*regCalc(:,1)',len,1); %convert to mm
    rE = (rm-rc).^2;
    rEThr = rE./(distThr.^2);
    if plotOn
        figure;
        imagesc(rEThr);
        colorbar;
    end
    
    %Compute dose error
    Drm = repmat(regMeas(:,2),1,len);
    Drc = repmat(regCalc(:,2)',len,1);
    dE = (Drm-Drc).^2;
    dEThr = dE./(doseThr.^2);    
    if plotOn
        figure;
        imagesc(dEThr);
        colorbar;
    end
    
    gam2 = sqrt(rEThr + dEThr);
    %take min down columns to get gamma as a function of position
    gam = min(gam2);
        
    vOut = gam;
end

end