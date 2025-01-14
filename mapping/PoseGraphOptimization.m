classdef PoseGraphOptimization
    % This class is used for pose graph optimization as presented in (1).
    % Please refer to the manual.
    %
    % Methods:
    %  	PoseGraphOptimization(pathData)
    %       This is the constructor of the class

    % Nils Rottmann (Nils.Rottmann@rob.uni-luebeck.de)
    % 24.01.2018

    properties
        PathData;       % Data retieved by driving with the vehicle along the boundary line

        L_min;          % Parameter for data pruning
        E_max;
        L_nh;           % Parameter for correlation calculation
        C_max;
        Phi_cycle;
        M;
        Gamma1;         % Parameter for PGO (Loop Closure)
        Gamma2;
        Beta1;          % Parameter for PGO (Odometry Model)
        Beta2;
        Beta3;
        Beta4;
        Icp;            % Parameter for ICP performance
        
        ModelStepSize;  % Step size for generating model points for icp

        BayRate;        % Bayesian Optimization Parameter
        
        DP_indices;     % Indices signaling which path points have been used for the DPs
    end

    methods
        function obj = PoseGraphOptimization()
            % This is the constructor of the class

            % Get Parameters
            out = get_config('mapping');
            obj.L_min = out.l_min;
            obj.E_max = out.e_max;
            obj.L_nh = out.l_nh;
            obj.C_max = out.c_max;
            obj.Phi_cycle = out.phi_cycle;
            obj.M = out.M;
            obj.Beta1 = out.beta(1);
            obj.Beta2 = out.beta(2);
            obj.Beta3 = out.beta(3);
            obj.Beta4 = out.beta(4);
            obj.Gamma1 = out.gamma(1);
            obj.Gamma2 = out.gamma(2);
            obj.Icp = out.icp;
            obj.BayRate = out.bayRate;
            obj.ModelStepSize = out.modelStepSize;
            
            obj.DP_indices = 0;
        end

        function [obj,X,A,Circumference] = generateMap(obj,pathData,optimize,mode,plotting)
            % This is the main function of the class which runs the mapping
            % algorithm and gives back an map estimate
            %
            % Syntax:
            %       [] = generateMap(obj)
            %
            % Input:
            %   obj:        Object of the this class
            %   pathData:   The path data required for mapping
            %   optimize:   struct for optimization
            %       loopClosure:    if true, we optimize l_nh and c_max
            %       mapping:        if true, we optimize gamma(1) and
            %                       gamma(2)
            %   mode:       struct for determining modes
            %       loopClosure:    mode for the loop closure detection
            %   plotting:           if true, graphs are plotted 
            %
            % Output:
            %   X:      Pose Graph
            %   A:      Incidence matrix
            %

            % (0) Allocate path data
            % Check size, matrix has to be 2 x N
            if ~(length(pathData(:,1)) == 2)
                error('PoseGraphOptimization: Size of path data incorrect, should be 2 x N!')
            end
            obj.PathData = pathData;
            
            % (0 after) Print original data  
            if plotting.flag
                h = figure;
                set(h, 'Units','centimeters','Position', [1 1 plotting.width plotting.height])
                plot(pathData(1,:),pathData(2,:),'LineWidth',1.5)
                set(gca ,'FontSize' ,10)
                scalebar;
                box off
                axis off
            end

            % (1) Data Pruning of the odometry data
            disp(['Prune ',num2str(length(obj.PathData(1,:))),' data points ...'])
            pruningParam.e_max = obj.E_max;
            pruningParam.l_min = obj.L_min;
            [DP,obj.DP_indices] = generateDPs(obj.PathData,pruningParam);
            disp(['Data points number reduced to ',num2str(length(DP(1,:))),'!'])
            
                            
            % (1 after) Print pruned data  
            if plotting.flag
                h = figure;
                set(h, 'Units','centimeters','Position', [1 1 plotting.width plotting.height])
                plot(DP(1,:),DP(2,:),'LineWidth',1.5)
                hold on
                plot(DP(1,:),DP(2,:),'r.','MarkerSize',5)
                set(gca ,'FontSize' ,10)
                scalebar;
                box off
                axis off
            end
            
            for iter=1:1:1
                % (2) Generate measurements from the pruned data set
                disp(['Generate measurement data from ',num2str(length(DP(1,:))),' dominant points ...'])
                xi = PoseGraphOptimization.generateMeasurements(DP);
                disp('Generated measurement data!')
            
                
                % (3 before) Generate Model points
                model_points = DP(:,1);
                idx_vertices = 1;
                for ii=1:1:length(DP(1,:))-1
                    vec = DP(:,ii+1) - DP(:,ii);
                    dphi = atan2(vec(2),vec(1));
                    dx = DP(1,ii):cos(dphi)*obj.ModelStepSize:DP(1,ii+1);
                    dy = DP(2,ii):sin(dphi)*obj.ModelStepSize:DP(2,ii+1);
                    model_points = [model_points, [dx(2:end); dy(2:end)]];
                    idx_vertices = [idx_vertices; length(model_points(1,:))];
                end
                model.model_points = model_points;
                model.idx_vertices = idx_vertices;
                model.stepSize = obj.ModelStepSize;

                % (3) Find pairs of DPs for Loop Closure
                disp('Search for loop closures ...')
                correlationParam.l_nh = obj.L_nh;
                correlationParam.c_max = obj.C_max;
                correlationParam.phi_cycle = obj.Phi_cycle;
                correlationParam.m = obj.M;
                [SP,corr,L,Phi,optimParam] = PoseGraphOptimization.generateSPs(DP,...
                            correlationParam,model,optimize.loopClosure,mode.loopClosure);
                obj.L_nh = optimParam.l_nh;
                obj.C_max = optimParam.c_max;
                obj.Phi_cycle = optimParam.phi_cycle;
                disp(['Found ',num2str(length(L)),' loop closures!'])
                
                % (3 after) Print constraints  
                if plotting.flag
                    h = figure;
                    set(h, 'Units','centimeters','Position', [1 1 plotting.width plotting.height])
                    plot(DP(1,:),DP(2,:),'LineWidth',1.5)
                    hold on
                    plot(DP(1,:),DP(2,:),'r.','MarkerSize',5)
                    for i=1:1:length(DP(1,:))-1
                        for j=(1+i):1:length(DP(1,:))-1
                            if SP(i,j) == 1
                                plot(DP(1,[i j]),DP(2,[i j]),'r-','LineWidth',1.5)
                            end
                        end
                    end
                    set(gca ,'FontSize' ,10)
                    scalebar;
                    box off
                    axis off
                end
                
                % (4) PGO
                disp('Optimize the pose graph ...')
                optParam.gamma1 = obj.Gamma1;
                optParam.gamma2 = obj.Gamma2;
                optParam.icp = obj.Icp;
                optParam.beta1 = obj.Beta1;
                optParam.beta2 = obj.Beta2;
                optParam.beta3 = obj.Beta3;
                optParam.beta4 = obj.Beta4;
                optParam.l_nh = obj.L_nh;
                [X,A,Circumference,optimParam] = PoseGraphOptimization.tutorialPGO(xi,SP,corr,...
                                                                    L,optParam,model,optimize.mapping,mode.mapping);
                obj.Gamma1 = optimParam.gamma1;
                obj.Gamma2 = optimParam.gamma2;
                obj.Icp = optimParam.icp;
                obj.Beta1 = optimParam.beta1;
                obj.Beta2 = optimParam.beta2;
                obj.Beta3 = optimParam.beta3;
                obj.Beta4 = optimParam.beta4;
                disp('Pose graph optimization completed successfully!')
                
                DP = [X(1:2,:), DP(:,end)];
            end
            
            % (5) Print final optimized pose graph
            if plotting.flag
                h = figure;
                set(h, 'Units','centimeters','Position', [1 1 plotting.width plotting.height])
                plot(DP(1,:),DP(2,:),'LineWidth',1.5)
                hold on
                plot(DP(1,:),DP(2,:),'r.','MarkerSize',5)
                for i=1:1:length(DP(1,:))-1
                    for j=(1+i):1:length(DP(1,:))-1
                        if SP(i,j) == 1
                            plot(DP(1,[i j]),DP(2,[i j]),'r-','LineWidth',1.5)
                        end
                    end
                end
                set(gca ,'FontSize' ,10)
                scalebar;
                box off
                axis off
                legend('Graph','DPs','LCs')
                legend boxoff
            end
            
%             %%%%%%%%%%%%%% Test %%%%%%%%%%%%%%%
%             % Get more loop closures based on the circumference
%             % information
%             [~,idx11] = min(A(:,length(DP(1,:))-1:end)); 	% First loop closing constraint
%             idx1 = min(idx11);
%             [~,idx22] = max(A(:,length(DP(1,:))-1:end));	% Last loop closing constraint
%             idx2 = max(idx22);
%             
%             numRoundSamples = 1000;
%             
%             cutDP = DP(:,idx1:idx2);
%             l_cum = 0;
%             t = 0;
%             delta = Circumference/numRoundSamples;
%             
%             samplePoints = [];
%             
%             for i=2:1:length(cutDP(1,:))
%                 v = cutDP(:,i) - cutDP(:,i-1);
%                 
%                 point = cutDP(:,i-1) + (t-l_cum)*(v/norm(v));
%                 time = (t/Circumference); time = floor((time - floor(time)) * numRoundSamples);
%                 
%                 samplePoints = [samplePoints, [point; time]];
%                 
%                 while true
%                     t =  t + delta;
%                     if (t > (l_cum + norm(v)))
%                         l_cum = l_cum + norm(v);
%                         break
%                     else
%                         point = cutDP(:,i-1) + (t-l_cum)*(v/norm(v));
%                         time = (t/Circumference); time = floor((time - floor(time)) * numRoundSamples);
%                 
%                         samplePoints = [samplePoints, [point; time]];
%                     end
%                 end
%             end
%             
%             %%%%%
%             % Generatee closed map estimate
%             closedMap = [];
%             % Add loop closing constraints
%             for i=0:1:numRoundSamples-1
%                 idx = find(samplePoints(3,:) == i);
%                 closedMap = [closedMap, mean(samplePoints(1:2,idx),2)];
%             end
%             closedMap = [closedMap, closedMap(:,1)];
%             
%             figure
%             plot(closedMap(1,:),closedMap(2,:))
            
%             %%%%%
%             % Generate pose graph
%             graph = poseGraph;
%             
%             % Add odometrc constraints
%             xi = PoseGraphOptimization.generateMeasurements(samplePoints(1:2,:));
%             for i=1:1:length(xi(1,:))
%                 addRelativePose(graph, xi(:,i));
%             end
%             
%             % Add loop closing constraints
%             for i=0:1:numRoundSamples-1
%                 idx = find(samplePoints(3,:) == i);
%                 for j=1:1:length(idx)
%                     for k=j+1:1:length(idx)
%                         if (idx(j) < graph.NumNodes && idx(k) < graph.NumNodes)
%                             if (idx(j) ~= idx(k) && idx(j)+1 ~= idx(k)) 
%                                 addRelativePose(graph, [0,0,0],[1 0 0 1 0 1],idx(j),idx(k));
%                             end
%                         end
%                     end
%                 end
%             end
%             
%             updatedGraph = optimizePoseGraph(graph);
%             figure
%             show(updatedGraph,'IDs','off')
            
            
%             %%%%%%%%%%%%%%%%% Test %%%%%%%%%%%%%%%%%%%%
%             % Get more loop closures based on the circumference
%             % information
%             [~,idx11] = min(A(:,length(DP(1,:))-1:end)); 	% First loop closing constraint
%             idx1 = min(idx11);
%             [~,idx22] = max(A(:,length(DP(1,:))-1:end));	% Last loop closing constraint
%             idx2 = max(idx22);
%             
%             % Generate pose graph
%             graph = poseGraph;
%             
%             % Add odometrc constraints
%             for i=idx1:1:idx2
%                 addRelativePose(graph, xi(:,i));
%             end
%             
%             % Add loop closing constraints
%             for i=1:1:length(SP(1,:))
%                 for j=(1+i):1:length(SP(1,:))
%                     if SP(i,j) == 1
%                         addRelativePose(graph, [0,0,0],[1 0 0 1 0 1],i-(idx1-1),j-(idx1-1));
%                     end
%                 end
%             end
            
        end
    end

    methods (Static)
        function xi = generateMeasurements(data)
            % Function to generate the measurement data from a pruned data
            % set of positions. Therefore we define the orientation of
            % node_i as the orientation of the vector from node_i to node
            % node_i+1
            %
            % input:
            %   data:   data set with pruned data points (e.g. DPs) as a 2
            %   x M matrix
            % output:
            %   xi:     relative poses

            M = length(data(1,:));

            % Here we create relative measurements for the Pose Graph
            % formulation
            theta = zeros(1,M-1);
            for i=2:1:M
                v = data(:,i) - data(:,i-1);
                theta(i-1) = atan2(v(2),v(1));
            end
            xi = zeros(3,M-2);
            for i=2:1:(M-1)
                R = [cos(theta(i-1)), -sin(theta(i-1)); ...
                                sin(theta(i-1)), cos(theta(i-1))];
                xi(1:2,i-1) = R' * (data(:,i) - data(:,i-1));
                % Regularization
                xi(3,i-1) = theta(i) - theta(i-1);
                if xi(3,i-1) > pi
                    xi(3,i-1) = xi(3,i-1) - 2*pi;
                elseif xi(3,i-1) < -pi
                    xi(3,i-1) = xi(3,i-1) + 2*pi;
                end
            end
        end

         function X = generatePoses(xi,x0)
            % Function to generate the poses from the given measurements of
            % the odometry
            %
            % input:
            %   xi:     measurements of the odometry (relative poses)
            %   x0:     Starting pose
            % output:
            %   X:      Poses

            N = length(xi(1,:));
            X = zeros(3,N+1);
            X(:,1) = x0;
            for i=1:1:N
                R = [cos(X(3,i)), -sin(X(3,i)); ...
                                sin(X(3,i)), cos(X(3,i))];
                X(1:2,i+1) = X(1:2,i) + R*xi(1:2,i);
                X(3,i+1) = X(3,i) + xi(3,i);
            end
        end

        function [SP,corr,L,Phi,optimParam] = generateSPs(data,param,model,optimize,mode)
            % Calculate the similar points in regard to the given data set
            % and the given parameters
            %
            % input:
            %   data:           Data set with positions as matrix 2 x N,
            %                   e.g. DPs
            %   param:          Parameter required for the algorithm
            %       m:          Number of points for evaluation
            %       l_nh:       Length of Neighborhood
            %       c_max:      Mimimum required correlation error
            %   optimize:       If true, we optimize the parameters
            %                   required, if false, we use the parameters
            %                   from the get_config file
            %   mode:           
            %       1:          Scan alignment
            %       2:          Scan alignment with ICP
            % output:
            %   SP:             Incident matrix with similar points
            %
            
            model_points = model.model_points;
            idx_vertices = model.idx_vertices;
            
            M = length(data(1,:)) - 1;                              % Number of data points
            l_nh = optimizableVariable('l_nh',[20,40]);
            c_max = optimizableVariable('c_max',[0.01,1]);
            phi_cycle = optimizableVariable('phi_cycle',[pi/2,pi]);
           
            if (mode == 1 || mode == 2)
                
                % Get length and orientations
                phi = zeros(M,1);
                l = zeros(M+1,1);
                for i=2:1:M                                     % Go through all DPs
                    v = data(:,i) - data(:,i-1);
                    phi(i-1) = atan2(v(2),v(1));              	% Orientation of line segments
                    l(i) = norm(v);                             % Length of line segments
                end
                l(M+1) = [];
                
                % Accumulate Orientations
                phi_cumulated = zeros(M,1);
                l_cumulated = zeros(M,1);
                for i = 2:1:M
                  delta_phi = phi(i) - phi(i-1);
                    % Regularization
                    if abs(delta_phi) > pi
                      if phi(i-1) > 0.0
                        delta_phi = delta_phi + 2*pi;
                      else
                        delta_phi = delta_phi - 2*pi;
                      end
                    end
                  phi_cumulated(i) = phi_cumulated(i-1) + delta_phi;
                  l_cumulated(i) = l_cumulated(i-1) + l(i);
                end
                
                % Decide wether we would like to generate a plot of the
                % cost function or not
                if optimize.plotting.flag
                    num_p = 50;
                    disp(['Start generating plot for the cost function'])
                    
                    my_fun = @loopClosureCost;
                    
                    l_nh_tmp = linspace(10.2,20,num_p);
                    c_max_tmp = linspace(0.01,0.5,num_p);
                    cost_plot_tmp = zeros(num_p);
                    parfor i_tmp = 1:1:num_p
                        for j_tmp = 1:1:num_p
                            theta_tmp = [];
                            theta_tmp.l_nh = l_nh_tmp(i_tmp);
                            theta_tmp.c_max = c_max_tmp(j_tmp);
                            theta_tmp.phi_cycle = 1.5;
                            cost_plot_tmp(i_tmp,j_tmp) = my_fun(theta_tmp);
                            % Plot status
                            disp([num2str((i_tmp-1)*num_p + j_tmp),'/',num2str(num_p^2)])
                        end
                    end
                    
                    % Plotting everything
                    cost_plot_tmp(isinf(cost_plot_tmp)) = nan;
                    [XX,YY] = meshgrid(l_nh_tmp,c_max_tmp);
                    h1 = figure;
                    set(h1, 'Units','centimeters','Position', [1 1 optimize.plotting.width optimize.plotting.height])
                    surf(XX,YY,cost_plot_tmp)
                    set(gca,'YScale','log')
                    set(gca ,'FontSize' ,10)
                    hold on
                    [~,h2] = contourf(XX,YY,cost_plot_tmp,20);
                    % set_contour_z_level(h2, -9)
                    box off
                end
                
                % Decide wether a parameter optimization is required or not
                if ~optimize.flag
                    % Calculate similar points
                    if mode == 1
                        [SP,L,Phi,corr] = calculateSP(param);
                    else
                        [SP,L,Phi,corr] = calculateSP_ICP(param);
                    end
                    optimParam = param;
                else
                    % Bayes Optimization
                    disp('Optimize parameters for loop closure detection ...')
                    thetaOpt = [l_nh,c_max,phi_cycle];
                    results = bayesopt(@loopClosureCost,thetaOpt,'Verbose',1,'PlotFcn',{});
                    % Calculate optimized similar points
                    if mode == 1
                        [SP,L,Phi,corr] = calculateSP(results.XAtMinObjective);
                    else
                        [SP,L,Phi,corr] = calculateSP_ICP(results.XAtMinObjective);
                    end
                    optimParam = results.XAtMinObjective;
                    disp(['Optimized Parameters:' newline 'l_nh:  ' num2str(optimParam.l_nh) newline 'c_max: ' num2str(optimParam.c_max) newline 'phi_cycle: ' num2str(optimParam.phi_cycle)])
                end
            else
                error('No valid mode chosen!')
            end
                                    

            % Define cost function for Bayesian Optimization
            function cost = loopClosureCost(theta)
                % Get loop closing pairs
                if mode == 1
                    [~,U,U_phi,~] = calculateSP(theta);
                else 
                    [~,U,U_phi,~] = calculateSP_ICP(theta);
                end
                % Calculate costs based on path distances
                cost_U = inf;
                if (size(U,1) > size(U,2))
                    for ll = 1:1:length(U)-1
                        GMModel = fitgmdist(U,ll,'RegularizationValue',0.1);
                        newcost = GMModel.NegativeLogLikelihood/(length(U));
                        % newcost = GMModel.NegativeLogLikelihood;
                        diff = cost_U - newcost;
                        if diff < 1
                            break;
                        else
                            cost_U = newcost;
                        end
                    end
                end
                % Calculate cost based on angles
                cost_U_phi = inf;
                if size(U_phi,1) > size(U_phi,2)
                    if (ll >= 2)
                        k_GM = ll-1;
                    else
                        k_GM = 1;
                    end
                    GMModel_phi = fitgmdist(U_phi,k_GM,'RegularizationValue',0.1);
                    cost_U_phi = GMModel_phi.NegativeLogLikelihood/(length(U_phi));
                    % cost_U_phi = GMModel_phi.NegativeLogLikelihood;
                end
                % Add costs together
                cost = cost_U - log(length(U)); % + cost_U_phi;  % - log(length(U));
            end

            % This function generates the loop closing pairs (SP)
            function [SP,L,Phi,corr] = calculateSP(theta)
                % (1) Calculate correlation error
                corr = zeros(M);
                l_evaluation = linspace(-theta.l_nh,theta.l_nh,param.m);
                for ii=1:1:M
                    l_cumulated_i = l_cumulated - l_cumulated(ii);
                    phi_cumulated_i = phi_cumulated - phi_cumulated(ii);
                    for jj=1:1:M
                        l_cumulated_j = l_cumulated - l_cumulated(jj);
                        phi_cumulated_j = phi_cumulated - phi_cumulated(jj);
                        for kk=1:1:param.m
                            corr(ii,jj) = corr(ii,jj) ...
                                + (getOrientation(phi_cumulated_i,l_cumulated_i,l_evaluation(kk)) ...
                                        - getOrientation(phi_cumulated_j,l_cumulated_j,l_evaluation(kk)))^2;
                        end
                        corr(ii,jj) = corr(ii,jj) / param.m;
                    end
                end        

                % (2) Decide which pairs of poses are loop closing pairs
                % dependend on the correlation error
                l_min = theta.l_nh;                         % Minimum Length
                l_max = l_cumulated(end) - theta.l_nh;      % Maximum Length
                SP = zeros(M);
                L = zeros(M*M,1);                           % length between the loop closing points
                Phi = zeros(M*M,1);                         % angle between loop closing poses
                ll = 0;                                     % counter for the loop closing lengths
                for ii=1:1:M
                    if l_cumulated(ii) > l_min && l_cumulated(ii) < l_max
                        % [pks, locs] = findpeaks(-corr(ii,:));
                        [pks, locs] = findpeaks(-corr(ii,ii:end));
                        locs = locs + (ii-1);
                        
                        locs(abs(pks) > theta.c_max) = [];
                        SP(ii,locs) = 1;
                        for jj=1:1:length(locs)
                            L_new = abs(l_cumulated(ii) - l_cumulated(locs(jj)));
                            Phi_new = abs(phi_cumulated(ii) - phi_cumulated(locs(jj)));
                            % Solve cycling recurrent structures and avoid loop closings to near to each other
                            if (abs(pi-rem(Phi_new,(2*pi))) > theta.phi_cycle) && (L_new > 2*theta.l_nh)
                                ll = ll + 1;
                                L(ll) = L_new;
                                Phi(ll) = Phi_new;
                            else
                                SP(ii,locs(jj)) = 0;
                            end
                        end
                    end
                end
                % Shrink the array
                L = L(1:ll);
                Phi = Phi(1:ll);
            end
            
            % This function generates the loop closing pairs using the ICP algorithm
            function [SP,L,Phi,corr] = calculateSP_ICP(theta)               
                % (1) Calculate correlation error
                corr = zeros(M);
                N_NH = round(theta.l_nh/step_size);
                for ii=1:1:M
                    if (idx_vertices(ii) > N_NH && idx_vertices(ii) < idx_vertices(end)-N_NH)
                        for jj=ii:1:M
                            if (idx_vertices(jj) < idx_vertices(end)-N_NH)
                                % Put points together
                                dx = model_points(:,idx_vertices(jj)) - model_points(:,idx_vertices(ii));
                                dphi = phi(ii) - phi(jj);
                                R_rot = [cos(dphi) -sin(dphi); sin(dphi) cos(dphi)];
                                modelSet = model_points(:,idx_vertices(ii)-N_NH:idx_vertices(ii)+N_NH);
                                testSet = model_points(:,idx_vertices(jj)-N_NH:idx_vertices(jj)+N_NH);
                                testSetNew = R_rot*(testSet - model_points(:,idx_vertices(ii))) + model_points(:,idx_vertices(ii)) - dx;
                                res = 0;
                                for hh=1:1:2*N_NH+1
                                    res = res + norm(modelSet(:,hh) - testSetNew(:,hh));
                                end
                                corr(ii,jj) = res/(2*N_NH+1);
                            end
                        end
                    end
                end        

                % (2) Decide which pairs of poses are loop closing pairs
                % dependend on the correlation error
                l_min = theta.l_nh;                         % Minimum Length
                l_max = l_cumulated(end) - theta.l_nh;      % Maximum Length
                SP = zeros(M);
                L = zeros(M*M,1);                           % length between the loop closing points
                Phi = zeros(M*M,1);                         % angle between loop closing poses
                ll = 0;                                     % counter for the loop closing lengths
                for ii=1:1:M
                    if l_cumulated(ii) > l_min && l_cumulated(ii) < l_max
                        % [pks, locs] = findpeaks(-corr(ii,:));
                        [pks, locs] = findpeaks(-corr(ii,ii:end));
                        locs = locs + (ii-1);
                        
                        locs(abs(pks) > theta.c_max) = [];
                        SP(ii,locs) = 1;
                        for jj=1:1:length(locs)
                            L_new = abs(l_cumulated(ii) - l_cumulated(locs(jj)));
                            Phi_new = abs(phi_cumulated(ii) - phi_cumulated(locs(jj)));
                            % Solve cycling recurrent structures and avoid loop closings to near to each other
                            if (abs(pi-rem(Phi_new,(2*pi))) > theta.phi_cycle) && (L_new > 2*theta.l_nh)
                                ll = ll + 1;
                                L(ll) = L_new;
                                Phi(ll) = Phi_new;
                            else
                                SP(ii,locs(jj)) = 0;
                            end
                        end
                    end
                end
                % Shrink the array
                L = L(1:ll);
                Phi = Phi(1:ll);
            end
            
            function E = distortionError(theta,x1,x2)
                % Distortion Error between the set of point in x1,x2
                % x1,x2 in R^{2xN}
                
                if (size(x1) ~= size(x2))
                    error('x1 and x2 do not have the same size');
                end
                
                N = length(x1(1,:));
                T = theta(1:2);
                w = theta(3);
                
                E = 0;
                R = [cos(w) -sin(w); sin(w) cos(w)];
                for jj=1:N
                    E = E + norm(R*x1(:,jj) + T - x2(:,jj))^2;
                end
            end
        end

        function [X_opt,A,Circumference,optimParam] = tutorialPGO(xi,SP,corr,L,param,model,optimize,mode)
            % Optimizes the pose graph using the method presented in (1)
            %
            % (1) A tutorial on graph-based SLAM
            %
            % input:
            %   xi:         measurements from the odometry (the orientations are
            %               already regulized)
            %   SP:         Matrix which contains informations about loop closures
            %   corr:       Correlation matrix according to the SPs
            %   L:          The distances betwee loop closing pairs
            %   param:      Parameter for PGO
            %       gamma1: Parameter for the Loop Closing variance
            %       gamma2: ...
            %       beta1:  Parameter for the odometry variance
            %       beta2:  ...
            %       beta3:  ...
            %       beta4:  ...
            %   optimize:  
            %       0: Nothing is optimized
            %       1: gamma1, gamma2 are optimized
            %       2: gamma1, gamma2, beta1 - beta4 are optimized
            %   mode:
            %       1: Standard mode (ECMR Paper)
            %       2: Optimize points onto each other using ICP
            % output:
            %   X:   	Estimation of new pose graph nodes
            %   A:      Incidence Matrix

            % check sizes
            if (length(xi(1,:)) + 1) ~= length(SP(1,:))
                error('Sizes between xi and SP are not correct!')
            end

            % Generate the reduced incidence matrix for the odometry
            % measurements (without the starting point)
            N = length(xi(1,:));
            A = diag(-1*ones(N,1)) + diag(ones(N-1,1),-1);
            A = [A; [zeros(1,N-1), 1]];

            % Add loop closure constraints
            C = [];
            for i=1:1:(N+1)
                for j=(1+i):1:(N+1)
                    % If there is a connection we add a column to the
                    % incidence matrix
                    if SP(i,j) == 1
                        v = zeros(N+1,1);
                        v(i) = -1; v(j) = 1;
                        A = [A, v];
                        C = [C, corr(i,j)];
                    end
                end
            end
            
            % Number of loop closures
            M = length(A(1,:)) - N;

            % Generate initial guess of the poses using the odometry
            % measurements with [0,0,0]^T as starting point
            X = PoseGraphOptimization.generatePoses(xi,[0;0;0]);
            
            % Calculate the circumference
            logLikelihood = inf;
            GMModelOld = [];
            for ll = 1:1:length(L)-1
                GMModel = fitgmdist(L,ll,'RegularizationValue',0.1);
                diff = logLikelihood - GMModel.NegativeLogLikelihood;
                if diff < 1
                    break;
                else
                    logLikelihood = GMModel.NegativeLogLikelihood;
                    GMModelOld = GMModel;
                end
            end
            if (isempty(GMModelOld))
                Circumference = L;
            else
                Circumference = min(GMModelOld.mu);
                Cluster = GMModelOld.NumComponents;
            end

            % Decide wether we optimize mapping parameter
            if (optimize == 0)
                % Optimize the path data
                [X_opt] = getOptimizedPath(param);
                optimParam = param;
            elseif (optimize == 1)
                disp('Optimize parameters for pose graph optimization (gamma values) ...')
                % Optimize parameters using Bayesian Optimization
                gamma1 = optimizableVariable('gamma1',[0.001,1000],'Transform','log');
                gamma2 = optimizableVariable('gamma2',[0.001,1000],'Transform','log');
                thetaOpt = [gamma1,gamma2];
                results = bayesopt(@PGOCost_gamma,thetaOpt,'MaxObjectiveEvaluations',30,'Verbose',1,'PlotFcn',{});
                % Calculate optimized similar points
                optimParam = results.XAtMinObjective;
                optimParam.beta1 = param.beta1;
                optimParam.beta2 = param.beta2;
                optimParam.beta3 = param.beta3;
                optimParam.beta4 = param.beta4;
                optimParam.icp = param.icp;
                [X_opt] = getOptimizedPath(optimParam);
                disp(['Optimized Parameters:' newline ...
                    'gamma1: ' num2str(optimParam.gamma1) newline ...
                    'gamma2: ' num2str(optimParam.gamma2) newline ...
                    ])
        	elseif (optimize == 2)
                disp('Optimize parameters for pose graph optimization (gamma and icp values) ...')
                % Optimize parameters using Bayesian Optimization
                gamma1 = optimizableVariable('gamma1',[0.001,1000],'Transform','log');
                gamma2 = optimizableVariable('gamma2',[0.001,1000],'Transform','log');
                icp = optimizableVariable('icp',[5*model.stepSize,100*model.stepSize]);
                thetaOpt = [gamma1,gamma2,icp];
                results = bayesopt(@PGOCost_gamma_icp,thetaOpt,'Verbose',1,'PlotFcn',{});
                % Calculate optimized similar points
                optimParam = results.XAtMinObjective;
                optimParam.beta1 = param.beta1;
                optimParam.beta2 = param.beta2;
                optimParam.beta3 = param.beta3;
                optimParam.beta4 = param.beta4;
                [X_opt] = getOptimizedPath(optimParam);
                disp(['Optimized Parameters:' newline ...
                    'gamma1: ' num2str(optimParam.gamma1) newline ...
                    'gamma2: ' num2str(optimParam.gamma2) newline ...
                    'icp: ' num2str(optimParam.icp) newline ...
                    ])
            elseif (optimize == 3)
                disp('Optimize parameters for pose graph optimization (gamma and beta values) ...')
                % Optimize parameters using Bayesian Optimization
                gamma1 = optimizableVariable('gamma1',[0.001,1000],'Transform','log');
                gamma2 = optimizableVariable('gamma2',[0.001,1000],'Transform','log');
                icp = optimizableVariable('icp',[5*model.stepSize,100*model.stepSize]);
                beta1 = optimizableVariable('beta1',[0.000001,1],'Transform','log');
                beta2 = optimizableVariable('beta2',[0.000001,1],'Transform','log');
                beta3 = optimizableVariable('beta3',[0.000001,1],'Transform','log');
                beta4 = optimizableVariable('beta4',[0.000001,1],'Transform','log');
                thetaOpt = [gamma1,gamma2,icp,beta1,beta2,beta3,beta4];
                results = bayesopt(@PGOCost,thetaOpt,'Verbose',1,'PlotFcn',{});
                % Calculate optimized similar points
                [X_opt] = getOptimizedPath(results.XAtMinObjective);
                optimParam = results.XAtMinObjective;
                disp(['Optimized Parameters:' newline ...
                    'gamma1: ' num2str(optimParam.gamma1) newline ...
                    'gamma2: ' num2str(optimParam.gamma2) newline ...
                    'icp: ' num2str(optimParam.icp) newline ...
                    'beta1: ' num2str(optimParam.beta1) newline ...
                    'beta2: ' num2str(optimParam.beta2) newline ...
                    'beta3: ' num2str(optimParam.beta3) newline ...
                    'beta4: ' num2str(optimParam.beta4) newline ...
                    ])
            else
                error('PGO_Tutorial: Wrong optimization value chosen!')
            end
            
            function cost = PGOCost_gamma(theta)
                theta.beta1 = param.beta1;
                theta.beta2 = param.beta2;
                theta.beta3 = param.beta3;
                theta.beta4 = param.beta4;
                theta.icp = param.icp;
                cost = PGOCost(theta);
            end
            
            function cost = PGOCost_gamma_icp(theta)
                theta.beta1 = param.beta1;
                theta.beta2 = param.beta2;
                theta.beta3 = param.beta3;
                theta.beta4 = param.beta4;
                cost = PGOCost(theta);
            end
                
            function cost = PGOCost(theta)
                [X_tmp] = getOptimizedPath(theta);
                % Go through all loop closures and calculate lengths
                U = zeros(M,1);
                for ii=N+1:1:N+M
                    [~,idx_min] = min(A(:,ii));
                    [~,idx_max] = max(A(:,ii));
                    for jj=1:1:idx_max-idx_min
                        U(ii-N) = U(ii-N) + norm(X_tmp(1:2,idx_min+jj) - X_tmp(1:2,idx_min+(jj-1)));
                    end
                end
                % Use mixture Models to get estimated circumference
                U(isnan(U)) = [];
                [n_check, d_check] = size(U);
                if n_check <= d_check
                    warning('U is not suitable');
                end
                if n_check > d_check
                    GMModel_tmp = fitgmdist(U,Cluster,'RegularizationValue',0.1);
                    U_mean = min(GMModel_tmp.mu);
                elseif length(U) == 1
                    U_mean = U;
                else
                    U_mean = 0;
                end

                % Calculate cost
                cost = abs(Circumference - U_mean);
            end

            function [X_opt] = getOptimizedPath(theta)
                
                % Add measurements for the loop closure. Here we assume that
                % the difference in distance and orientation are zero
                if mode == 1
                    xi_all = [xi, zeros(3,M)];
                elseif mode == 2
                    [xi_lc,e_dist] = PoseGraphOptimization.lc_icp(SP,model.model_points,model.idx_vertices,param.l_nh,theta.icp);
                    xi_all = [xi, xi_lc];
                else
                    error("Wrong mode chosen!")
                end
                
                % Define information gain matrices
                Omega = cell(N+M,1);
                % Get information gain for the odometry measurements
                for ii=1:1:N         % Odometric constraints
                    sigma(1) = (theta.beta1*abs(xi(1,ii)) + theta.beta2*abs(xi(3,ii)));
                    sigma(2) = (theta.beta1*abs(xi(2,ii)) + theta.beta2*abs(xi(3,ii)));
                    sigma(3) = (theta.beta3*abs(xi(3,ii)) + theta.beta4 * (abs(xi(1,ii)) + abs(xi(2,ii))));
                    for jj=1:1:3     % Avoid singularities
                        if sigma(jj) < 10^(-6)
                            sigma(jj) = 10^(-6);
                        end
                    end
                    Omega{ii} = diag(sigma)^(-1);
                end
                % Adjust loop closing constraints according to the given
                % parameters
                for ii=N+1:1:N+M   	% Loop closing constraints
                    if mode == 1
                        Omega{ii} = diag([1/theta.gamma1 1/theta.gamma1 1/theta.gamma2]) * (1/C(ii-N));
                    elseif mode == 2
                        Omega{ii} = diag([1/theta.gamma1 1/theta.gamma1 1/theta.gamma2]) * (1/C(ii-N));
                        % Omega{ii} = diag([1/theta.gamma1 1/theta.gamma1 1/theta.gamma2]) * (1/e_dist(ii-N));
                    else
                        error('Wrong mode chosen!')
                    end
                end
                % Compute Hessian and coefficient vector
                e = inf;
                count = 0;
                while (e > 0.001) && (count < 100)
                    count = count + 1;
                    b = zeros(3*(N+1),1);
                    H = zeros(3*(N+1));
                    for ii=1:1:(N+M)
                        [~,i] = min(A(:,ii));
                        [~,j] = max(A(:,ii));
                        [AA,BB] = PoseGraphOptimization.jacobianTutorial(xi_all(:,ii),X(:,i),X(:,j));
                        i1 = 3*i-2; i2 = 3*i;
                        j1 = 3*j-2; j2 = 3*j;
                        % Hessians
                        H(i1:i2,i1:i2) = H(i1:i2,i1:i2) + AA'*Omega{ii}*AA;
                        H(i1:i2,j1:j2) = H(i1:i2,j1:j2) + AA'*Omega{ii}*BB;
                        H(j1:j2,i1:i2) = H(j1:j2,i1:i2) + BB'*Omega{ii}*AA;
                        H(j1:j2,j1:j2) = H(j1:j2,j1:j2) + BB'*Omega{ii}*BB;
                        % coefficient vector
                        e_ij = PoseGraphOptimization.errorTutorial(xi_all(:,ii),X(:,i),X(:,j));
                        b(i1:i2) = b(i1:i2) + AA'*Omega{ii}*e_ij;
                        b(j1:j2) = b(j1:j2) + BB'*Omega{ii}*e_ij;
                    end
                    % Keep first node fixed
                    H(1:3,1:3) = H(1:3,1:3) + eye(3);
                    % Solve the linear system
                    dX_tmp = (H \ (-b));
                    e = norm(dX_tmp);
                    % Update poses
                    dX = zeros(3,N+1);
                    for ii=1:1:(N+1)
                        dX(:,ii) = dX_tmp(((ii*3)-2):(ii*3));
                        
                        if (isnan(dX))
                            disp('Damnit!')
                        end
                        
                    end
                    X = X + dX;
                end
                X_opt = X;
            end
        end

        function [A,B] = jacobianTutorial(z,xi,xj)
            % Calculates the Jacobian A and B
            %
            % input:
            %   z:      Measurement
            %   xi:     Pose i
            %   xj:     Pose j
            %
            % output:
            %   A,B:    Jacobians
            %

            dx = 10^(-9);

            e = PoseGraphOptimization.errorTutorial(z,xi,xj);
            A = zeros(3);
            B = zeros(3);
            for i=1:1:3
                xi_tmp = xi; xi_tmp(i) = xi_tmp(i) + dx;
                xj_tmp = xj; xj_tmp(i) = xj_tmp(i) + dx;
                A(:,i) = ((PoseGraphOptimization.errorTutorial(z,xi_tmp,xj)) - e) / dx;
                B(:,i) = ((PoseGraphOptimization.errorTutorial(z,xi,xj_tmp)) - e) / dx;
            end
        end

        function e = errorTutorial(z,xi,xj)
            % Calculates the error measurements between the relative pose
            % measurement z and the current point xi and xj
            R = [cos(xi(3)), -sin(xi(3)); ...
                            sin(xi(3)), cos(xi(3))];
            z_star = [R' * (xj(1:2) - xi(1:2)); xj(3)-xi(3)];
            % Regularization
            z_star(3) = z_star(3) - floor(z_star(3)/(2*pi))*2*pi;
            if z_star(3) > pi
                z_star(3) = z_star(3) - 2*pi;
            elseif z_star(3) < -pi
                z_star(3) = z_star(3) + 2*pi;
            end
            e = z - z_star;
        end

        function R = rotationMatrix(A,theta)
            % Generates a rotation matrix required for the LAGO algorithm
            %
            % input:
            %   A:      Reduced incidence matrix
            %   theta:  Angles theta
            %
            % output:
            %   R:      Rotation matrix
            %

            NM = length(A(1,:));
            R = zeros(2*NM);
            for i=1:1:NM
                [~,idx] = min(A(:,i));
                R_tmp = [cos(theta(idx)), -sin(theta(idx)); ...
                                sin(theta(idx)), cos(theta(idx))];
                R((2*i-1):(2*i),(2*i-1):(2*i)) = R_tmp;
            end
        end
        
        function [xi_lc,e_dist] = lc_icp(SP,model_points,idx_vertices,l_nh,icp_param)
            % Generates relative measurements based on the result of the
            % ICP algorithm
            %
            % input:
            %   l_nh:       Neighborhood length
            %   toLearn:    Learnable parameter
            %
            % output:
            %   R:      Rotation matrix
            %
            N_NH = floor(l_nh/icp_param);
            M = length(idx_vertices) - 1;
            xi_lc = [];
            e_dist = [];
            for ii=1:1:M
                for jj=(1+ii):1:M
                    % If there is a LC we do ICP
                    if SP(ii,jj) == 1
                        % Check of index exceeds array bounds
                        if (idx_vertices(jj)+N_NH > length(model_points(1,:)))
                            N_NH = length(model_points(1,:)) - idx_vertices(jj);
                        end  
                        % Define Sets for comparison and put them as close
                        % as possible together
                        modelSet = model_points(:,idx_vertices(ii)-N_NH:idx_vertices(ii)+N_NH);
                        modelSet = modelSet - modelSet(:,N_NH+1);
                        testSet = model_points(:,idx_vertices(jj)-N_NH:idx_vertices(jj)+N_NH);
                        testSet = testSet - testSet(:,N_NH+1);
                        % Define angles and adjust sets onto each other for
                        % getting a good starting position for the ICP
                        % algorithm
                        modelVec = modelSet(:,N_NH+2) - modelSet(:,N_NH+1);
                        modelPhi = atan2(modelVec(2),modelVec(1));
                        testVec = testSet(:,N_NH+2) - testSet(:,N_NH+1);
                        testPhi = atan2(testVec(2),testVec(1));
                        dphi = modelPhi - testPhi;
                        R_rot = [cos(dphi) -sin(dphi); sin(dphi) cos(dphi)];
                        testSet = R_rot*testSet;
                        % Do the ICP
                        [R,T,~,res] = icp(modelSet,testSet);
                        % Transform points
                        testSet = R*testSet + T;
                        % Define pose
                        testVec = testSet(:,N_NH+2) - testSet(:,N_NH+1);
                        testPhi = atan2(testVec(2),testVec(1));
                        % Get relative measurements
                        xi_lc_tmp = zeros(3,1);
                        R_xi = [cos(modelPhi), -sin(modelPhi); ...
                                sin(modelPhi), cos(modelPhi)];
                        xi_lc_tmp(1:2) = R_xi' * (testSet(:,N_NH+1) - modelSet(:,N_NH+1));
                        % Regularization
                        xi_lc_tmp(3) = testPhi - modelPhi;
                        if xi_lc_tmp(3) > pi
                            xi_lc_tmp(3) = xi_lc_tmp(3) - 2*pi;
                        elseif xi_lc_tmp(3) < -pi
                            xi_lc_tmp(3) = xi_lc_tmp(3) + 2*pi;
                        end
                        xi_lc = [xi_lc, xi_lc_tmp];
                        e_dist = [e_dist; res];
                    end
                end
            end
        end
    end
end
