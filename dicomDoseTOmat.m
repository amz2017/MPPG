function [ x, y, z, dose ] = dicomDoseTOmat(filename, offset)
% Converts a dicom 3D dose file to matlab-usable variables

% Read header and pixel map
info = dicominfo(filename);
I = dicomread(filename);

% Elements in X
cols = double(info.Columns); 

% Elements in Y
rows = double(info.Rows);

% Elemetns in Z
deps = double(info.NumberOfFrames);

% Establish Coordinate System [in cm]
% Note: PixelSpacing indices do not match ImagePositionPatient indicies.
x = (info.ImagePositionPatient(1) + info.PixelSpacing(2)*(0:(cols-1)))/10 - offset(1);
y = (info.ImagePositionPatient(2) + info.PixelSpacing(1)*(0:(rows-1)))/10 - offset(2);
z = (info.ImagePositionPatient(3) + info.GridFrameOffsetVector)/10 - offset(3);

% Remove 4th Dimension from Dose Grid
J = reshape(I(:,:,1,:),[rows cols deps]);

% Scale Dose Grid Using Stored Factor
dose = double(J)*info.DoseGridScaling;

if strcmp(info.DoseUnits,'CGY')
    dose = dose/100;
end

