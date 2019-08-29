% Example 02:
% Simulate the robot (driving along the boundary lines), afterwards
% generate a map estimate based on the simulated data without parameter
% optimization and show the map estimate.
clear all
close all
clc

%% Choose the map and starting pose
map = 'map_6.mat';
load(map);
pose = [0; 0; 0];

%% Initialize the control unit
controlUnit = ControlUnit(polyMap,pose);

%% Follow the boundary line
T = 2000;       % Simulation time in seconds
startPose = 0;  % Choose a random start pose
[controlUnit,path,estPath] = controlUnit.wallFollowing(T,startPose);

%% Get the path of the sensor
% out = get_config('Sensor');
% deltaSensor = out.posRight;
%
% sensorPath = zeros(size(path));
% estSensorPath = zeros(size(estPath));
% for i=1:1:size(path,2)
%     phi = path(3,i);
%     sensorPath(1:2,i) = path(1:2,i) + [cos(phi) -sin(phi); sin(phi) cos(phi)] * deltaSensor;
% end
% for i=1:1:size(estPath,2)
%     phi = estPath(3,i);
%     estSensorPath(1:2,i) = estPath(1:2,i) + [cos(phi) -sin(phi); sin(phi) cos(phi)] * deltaSensor;
% end
%
% optimize.loopClosure = true;
% optimize.mapping = false;
% [controlUnit,mappingResults] = controlUnit.mapping(estSensorPath,optimize);

%% Generate map estimate from odometry data
optimize.loopClosure = true;
optimize.mapping = 1;
[controlUnit,mappingResults] = controlUnit.mapping(estPath,optimize);

%% Compare estimated map with groundtruth
comparisonResults = controlUnit.compare(6);

%% Plots
figure,
plot(estPath(1,:),estPath(2,:))
title('Estimated Path')

figure;
plot(mappingResults.estMap.x,mappingResults.estMap.y)
title('Map Estimate')
