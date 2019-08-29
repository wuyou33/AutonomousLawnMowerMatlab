% Example 02:
% Simulate the robot (driving along the boundary lines), afterwards
% generate a map estimate based on the simulated data without parameter
% optimization and show the map estimate.
clear all
close all
clc

%% Define number of iteration
iter = 20;
results = cell(iter,2);
for i=1:iter

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
optimize.loopClosure = false;
optimize.mapping = 0;
[controlUnit,mappingResults] = controlUnit.mapping(estPath,optimize);

%% Compare estimated map with groundtruth
[~,comparisonResults] = controlUnit.compare(6);

%% Allocate results
results{i,1} = mappingResults;
results{i,2} = comparisonResults;

%% Clear the controlUnit
clear controlUnit
end

%% Evaluate Results
compResult = zeros(iter,1);
for i=1:iter
    compResult(i) = results{i,2}.error;
end
mu = mean(compResult)
sigma = std(compResult)

%% Save
% save('map_7_stdNoise.mat','results')

%%
% for i=1:6
%     for j=1:2
%         results{14+i,j} = result2{i,j};
%     end
% end
