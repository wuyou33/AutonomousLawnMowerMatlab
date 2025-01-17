% Script for performing the CCPP algorithm

clear all
close all
clc

%% Define map and starting pose
mapName = 'map_10';
map = strcat(mapName,'.mat');
load(map);
pose = [2.05; 0.05; 0];

%% Initialize the control unit
controlUnit = ControlUnit(gridMap,pose);

%% Complete Coverage with particle filter localization

reqCoverage = 1.0;           % Coverage in percentage
maxTime = 100;              % maximum time in seconds
mode = 3;                    % Random Walk(1), NNCCPP(2), coverage with random(3), coverage with nnccpp(4), wallfollower(5)

[controlUnit,results] = controlUnit.completeCoverage(reqCoverage,maxTime,mode); 


%% Plot some results
figure
subplot(1,2,1)
plot(results.path(1,:),results.path(2,:))
title('true')
subplot(1,2,2)
plot(results.estPath(1,:),results.estPath(2,:))
title('estimated')

figure
coverageMap = occupancyMap(results.coverageMap);
show(coverageMap)

figure
plot(results.travelledDist,results.estCoverage)
hold on
plot(results.travelledDist,results.trueCoverage)
legend('Estimate','True')

%% Save the results
saveName = strcat(mapName,'_mode',num2str(mode),'.mat');
save(saveName,'results')


%% Plot some results
% figure()
% subplot(1,2,1)
% plot(polyMap.x,polyMap.y)
% hold on
% plot(coverageResults.path(1,:),coverageResults.path(2,:))
% subplot(1,2,2)
% plot(polyMap.x,polyMap.y)
% hold on
% plot(coverageResults.estPath(1,:),coverageResults.estPath(2,:))
% hold off
% figure()
% surf(coverageResults.groundTruth');
% title('groundTruth');
% figure()
% surf(coverageResults.particleCoverageMap');
% title('ParticleCoverageMap');
% figure()
% surf(coverageResults.coverageMap');
% title('CoverageMap');
% figure()
% particle = coverageResults.particleCoverageMap;
% particle(particle < controlUnit.Threshhold) = 0;
% particle(particle >= controlUnit.Threshhold) = 1;
% surf(particle');
% title('ParticleCoverageMapThreshhold');
% figure()
% coverage = coverageResults.coverageMap;
% coverage(coverage < controlUnit.Threshhold) = 0;
% coverage(coverage >= controlUnit.Threshhold) = 1;
% surf(coverage');
% title('CoverageMapThreshhold');
% if mode == 2 || mode == 4
%     figure()
%     surf(coverageResults.neuralActivity');
%     title('Neural Activity');
%     figure()
%     surf(coverageResults.externalInput');
%     title('External Input');
% end
% figure()
% surf(coverageResults.coverageMap')
% grid on
% xlabel('x in Zellen')
% ylabel('y in Zellen')
% title('Abdeckungskarte')
% colorbar
% pbaspect([1 1 1])
% figure()
% surf(coverageResults.particleCoverageMap')
% grid on
% xlabel('x in Zellen')
% ylabel('y in Zellen')
% title('Abdeckungskarte')
% colorbar
% pbaspect([1 1 1])
