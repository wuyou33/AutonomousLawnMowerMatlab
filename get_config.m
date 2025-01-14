function out = get_config(caseString)
% This function gives back the configuration required for different
% setting, e.g. PD controller, the odometry, etc.

out = [];
switch caseString
    case 'PDControl'
        out.Kp = 10;
        out.Kv = 1;
        out.Kr = 1;
        out.Kw = 1;
    case 'WallFollower'
        out.a_mu = 0.7;
        out.a_v = 0.7;
        out.M = 20;
    case 'VelLimitations'
        out.v_max = 0.6;
        out.w_max = 0.3;
    case 'Sensor'
        out.posRight = [0.265; -0.1];   
        out.posLeft = [0.265; 0.1];
        % Noise of the sensor, 0 means no noise, 1 means totally random
        out.noise = 0.0;                   
    case 'kinModelNoise'  
        % Variance parameters for the velocity motion model
        out.a = [0.01130, 0.003417, .0196777, 0.191406, 0.0, 0.0];
    case 'mowerParameter'
        out.L = 0.1825;
        out.dR = 0.215;
        out.dL = 0.215;
    case 'odometryModelNoise'
        % Variance parameters for the odometry motion model
        out.a = [0.002361, 0.000346, 0.000223, 0.000069]; 
    case 'system'
        % Time step size
        out.dt = 0.05;
    case 'mapping'
        % Standard: l_min = 0.1, e_max = 0.001, M = 100
        out.l_min = 0.1;
        out.e_max = 0.001;
        out.l_nh = 50;
        out.c_max = 0.21;
        out.phi_cycle = 1.5;
        out.M = 100;
        out.beta = [0.0002874, 0.00008569, 0.0022, 0.0013];
        out.gamma = [0.001, 100]; 
        out.modelStepSize = 0.01;
        out.icp = 10 * out.modelStepSize;
        out.bayRate = 1000;
	case 'globalLocalization'
        % Standard: l_min = 0.05, e_max = 0.001, u_min = 0.5
        out.l_min = 0.05;
        out.e_max = 0.001;
        out.u_min = 0.5;
        out.l_nh = 15;
        out.c_min = 0.1;
        out.c_diff = 0;
    case 'particleFilter'
        out.n_P = 250;                      % Number particles
        out.poseVariance = [0.5;0.5;0.5];   % Variance for distributing the particles around a initial pose estimate
        out.n_M = 1;                        % Measure n_M times before updating weights of the particle filter
        out.increaseNoise = 1;            	% Factor which increases the noise of the odometry model for the particles
        out.n_S = 2;                      	% Number sensors used, (1 or 2)
        out.thresholdResampling = 0.7;   	% Resampling treshold  
    case 'coverageMap'
        out.resolution = 5;                 % Resolution in cells per meter (Integer)
        out.threshhold = 0.9;               % threshhold for confidence of cell
        out.wallFollow = 0.4;               % threshhold for wallfollowing since spread too high
        out.divider = 3;                    % Divider for area sammpling resolution (Integer)
    case 'planning'
        out.a = 10;                         % Passive decay rate
        out.b = 1;                          % Upper bound
        out.d = 1;                          % Lower bound
        out.e = 100;                         % Maximum Gain, for gradient
        out.c = 0.1;                        % Control gain
        out.threshhold = 0.9;               % threshhold for confidence of cell
        out.dt = 0.001;                     % timestep parameter for neuralactivity
        out.g = 0.5;                        % minimum gradient value
end
end

