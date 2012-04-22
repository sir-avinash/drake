classdef StochasticRobotLibSystem < RobotLibSystem
% Interface a nonlinear stochastic discrete/continuous system 
% with (band-limited) white noise input
  
  methods % Derived classes should implement one or more of these
    function xcdot = stochasticDynamics(obj,t,x,u,w)
      % Defines the dynamics xcdot = fc(t,x,u,w), where w is a white noise input
      error('systems with continuous states must implement dynamics');
    end
    
    function xdn = stochasticUpdate(obj,t,x,u,w)
      % Defines the update xd[n+1] = fd(t,x,u,w), where w is a white noise input
      error('systems with continuous states must implement update');
    end
    
    function y = stochasticOutput(obj,t,x,u,w)
      % Defines the output y = g(t,x,u,w), where w is a white noise input
      error('systems with outputs must implement the output function');
    end
  end

  methods
    function obj = StochasticRobotLibSystem(num_xc,num_xd,num_u,num_y,direct_feedthrough_flag,time_invariant_flag,num_w,ts_w)
      % Construct a StochasticRobotLibSystem
      % 
      % @param num_xc number of continuous-time state variables
      % @param num_xd number of discrete-time state variables
      % @param num_u number of inputs
      % @param num_y number of outputs
      % @param direct_feedthrough_flag true means that the output depends
      %   directly on the input u.  Set to false if possible.
      % @param time_invariant_flag true means that the
      %   dynamics/update/output do not depend on time.  Set to true if
      %   possible.
      % @param num_w number of (band-limited) white noise inputs
      % @param ts_w time constant of the band-limited noise (see
      % documentation for the band-limited white noise block)
      
      obj = obj@RobotLibSystem(num_xc,num_xd,num_u,num_y,direct_feedthrough_flag,time_invariant_flag);
      if (~isnumeric(num_w) || ~isscalar(num_w) || num_w<1)
        error('num_w must be a positive integer');
      end
      obj.num_w = num_w;
    end
    
    function xcdot = dynamics(obj,t,x,u)
      % publish a deterministic dynamics interface by setting w=0
      xcdot = stochasticDynamics(obj,t,x,u,zeros(obj.num_w,1));
    end
    function xdn = update(obj,t,x,u)
      % publish a deterministic update interface by setting w=0;
      xdn = stochasticUpdate(obj,t,x,u,zeros(obj.num_w,1));
    end
    function y = output(obj,t,x,u)
      % publish a deterministic output interface by setting w=0
      y = stochasticOutput(obj,t,x,u,zeros(obj.num_w,1));
    end
    
    function mdl = getModel(obj)
      % Implements stochastic dynamics by adding a band-limited noise block
      % and a mux to pass in w through u. 
      mdl = getModel@RobotLibSystem(obj);

      if (obj.num_w>0)
        rand('seed',sum(100*clock));
        add_block('simulink3/Sources/Band-Limited White Noise',[mdl,'/noise'],...
          'Cov',mat2str(ones(obj.num_w,1)),...%mat2str((1/obj.ts_w)*eye(obj.num_w)),...
          'Ts', num2str(obj.ts_w),...
          'seed', mat2str(uint32(1e5*rand(obj.num_w,1))));

        if (getNumInputs(obj)>0)
          add_line(mdl,'noise/1','RobotLibSys/2');
        else
          add_line(mdl,'noise/1','RobotLibSys/1');
        end
      end
      
    end    
    
    function n = getNumDisturbances(obj)
      n=obj.num_w;
    end
  end
  
  properties (SetAccess=private, GetAccess=protected)
    num_w=0; % number of (band-limited) white noise inputs
    ts_w=.01; % sample time of the noise. should be ~100 smaller than the smallest time constant in the system
  end
end
  
