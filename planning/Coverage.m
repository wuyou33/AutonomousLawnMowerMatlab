classdef Coverage
    % A coverage map class based on (1)
    %
    % Date:     06.03.2019
    % Author:   Nils Rottmann (Nils.Rottmann@rob.uni-luebeck.de)
    %
    % (1): A Probabilistic Approach to High-Confidence Cleaning Guarantees for Low-Cost Cleaning Robots
    
    properties
        % Storage variables
        PolyMap;            % A polygon map of the world
        CoverageMap;        % A matrix which shows the coverage of the area
        ObstacleMap;        % A matrix which shows the obstacles in the area
        N;                  % Total number of cells x-dimension
        M;                  % Total number of cells y-dimension
        Pose;               % Pose estimate
        
        % Parameters
        Resolution;         % The map resolution
    end
    
    methods
        function obj = Coverage()
            % Constructor
            out = get_config('coverageMap');
            obj.Resolution = out.resolution;
            
            % Initialize Pose estimate
            obj.Pose = [inf;inf];
        end
        
        function obj = initializeCoverageMap(obj,polyMap)
            % This method initializes the coverage and obstacle map based
            % on the given polygon map
            % Syntax:
            %       obj = initializeCoverageMap(polyMap)
            % Input:
            %   polyMap:        A polygon map of the environment
            
            % Allocate polygon map
            obj.PolyMap = polyMap;
            
            % Generate obstacle map, [N,M] Matrix initialized with zeros
            % when inside and ones when outside of a the environment
            obj.N = round((polyMap.XWorldLimits(2) - polyMap.XWorldLimits(1)) * obj.Resolution);
            obj.M = round((polyMap.YWorldLimits(2) - polyMap.YWorldLimits(1)) * obj.Resolution);
            obj.ObstacleMap = zeros(obj.N,obj.M);
            stepSize = 1/obj.Resolution;
            x_s = polyMap.XWorldLimits(1) + 0.5*stepSize;
            for i=1:1:obj.N
                y_s = polyMap.YWorldLimits(1) + 0.5*stepSize;
                for j=1:1:obj.M
                    if ~(inpolygon(x_s,y_s,polyMap.x,polyMap.y))
                        obj.ObstacleMap(i,j) = 1;
                    end
                    y_s = y_s + stepSize;
                end
                x_s = x_s + stepSize;
            end
            
            % Initialize Coverage map
            obj.CoverageMap = zeros(obj.N,obj.M);
        end
        
        function obj = updateCoverageMap(obj,particles,estPose)
            % This method updates the coverage map given the current
            % particle distribution
            % Syntax:
            %       obj = initializeCoverageMap(particles, estPose)
            % Input:
            %   particles:          Particles form the particle filter
            %   estPose:            Current pose estimate
            estimate = [ceil((estPose(1)-obj.PolyMap.XWorldLimits(1))*obj.Resolution);ceil((estPose(2)-obj.PolyMap.YWorldLimits(1))*obj.Resolution)];
            if norm(estimate-obj.Pose) > 1/obj.Resolution
                obj.Pose = estimate;
                n = length(particles(1,:));
                prob = zeros(obj.N,obj.M);
                for i=1:1:n
                    idx_x = ceil((particles(1,i) - obj.PolyMap.XWorldLimits(1)) * obj.Resolution);
                    idx_y = ceil((particles(2,i) - obj.PolyMap.YWorldLimits(1)) * obj.Resolution);
                    if ((idx_x>=1 && idx_x<=obj.N) && (idx_y>=1 && idx_y<=obj.M))   % Check boundaries
                        prob(idx_x,idx_y) = prob(idx_x,idx_y) + 1/n;
                    end
                end
                obj.CoverageMap = obj.CoverageMap + prob - prob.*obj.CoverageMap;
            end
        end
    end
end