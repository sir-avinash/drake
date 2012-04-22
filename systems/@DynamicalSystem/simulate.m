function traj = simulate(obj,tspan,x0,options)
% Simulates the dynamical system (using the simulink solvers)
%
% @param tspan a 1x2 vector of the form [t0 tf]
% @param x0 a vector of length(getNumStates) which contains the initial
% state
%
% @option FixedStep   for fixed-step solver only, generate output at the FixedStep spaced time points
% @option OutputOption 'RefineOutputTimes' | 'AdditionalOutputTimes' | 'SpecifiedOutputTimes' 
%            For variable step solver only
% @option OutputTimes to generate output in the time sequence options.OutputTimes

typecheck(tspan,'double');
if (length(tspan)<2) error('length(tspan) must be > 1'); end
if (nargin<4) options=struct([]); end
mdl = getModel(obj);

if (strcmp(get_param(mdl,'SimulationStatus'),'paused'))
  feval(mdl,[],[],[],'term');  % terminate model, in case it was still running before
end

pstruct = obj.simulink_params;
pstruct.StartTime = num2str(tspan(1));
pstruct.StopTime = num2str(tspan(end));
if(isfield(options,'FixedStep'))%if using fixed-step solver and want to generate output at a dt spaced time line.
    solver=get_param(mdl,'Solver');
    if(strcmp(solver,'ode1')||strcmp(solver,'ode2')||strcmp(solver,'ode3')||strcmp(solver,'ode4')||strcmp(solver,'ode5'))
        pstruct.FixedStep=num2str(options.FixedStep);
    else
        warning('FixedStep option can only be used for fixed-step solver');
    end
end
if (nargin>2) % handle initial conditions
  x0 = obj.stateVectorToStructure(x0);
  assignin('base',[mdl,'_x0'],x0);
  pstruct.InitialState = [mdl,'_x0'];
  pstruct.LoadInitialState = 'on';

  if (~isempty(find_system(mdl,'ClassName','InitialCondition')))
    warning('Your model appears to have an initial conditions block in it (e.g., from SimMechanics).  That block will overwrite any initial conditions that you pass in to simulate.');
  end
end

  function traj = makeSubTrajectory(t,y)
    if (length(t)<2) keyboard; end
    traj = PPTrajectory(spline(t,y));
    % todo: check for discrete outputs, and handle them by making a zoh
    % for discrete and cubic for continuous, then returning a
    % MixedTrajectory object.  Or just manually set the pp values for
    % higher orders to zero for the dt variables.
  end

if (nargout>0)
  if (getNumOutputs(obj)<1) error('this dynamical system doesn''t have any outputs'); end
  
  pstruct.SaveFormat = 'StructureWithTime';
  pstruct.SaveTime = 'on';
  pstruct.TimeSaveName = 'tout';
  pstruct.SaveState = 'off';
  pstruct.SaveOutput = 'on';
  pstruct.OutputSaveName = 'yout';
  pstruct.LimitDataPoints = 'off';

  if (~isDT(obj))
    pstruct.Refine = '3';  % shouldn't do anything for DT systems
  end
  
  %If we are using variable-step solver, and want to specify the output time
  if(isfield(options,'OutputOption'))
    %pstruct.OutputOption='SpecifiedOutputTimes';
    pstruct.OutputOption=options.OutputOption;
  end
  if(isfield(options,'OutputTimes'))
    pstruct.OutputTimes=['[',num2str(options.OutputTimes),']'];
  end
  %    pstruct.SaveOnModelUpdate = 'false';
  
  simout = sim(mdl,pstruct);
  
  t = simout.get('tout');
  y = simout.get('yout').signals.values';

  if (isDT(obj))
    traj = DTTrajectory(t',y);
  else
    % note: could make this more exact.  see comments in bug# 623.

    % find any zero-crossing events (they won't have the extra refine steps)
    zcs = find(diff(t)<1e-10);
    if (length(zcs)>0) % then we have a hybrid trajectory
      zcs = [0;zcs;length(t)];
      pptraj = {};
      i=1;
      while i<length(zcs)  % while instead of for so that I can zap zcs inside this loop (if they are fake zcs)
        % is there really a jump here? 
        if (i>1 && ~any(abs(y(:,zcs(i))-y(:,zcs(i)+1))>1e-6))
          % no jump that I can see.  remove this zc
          zcs=zcs([1:i-1,i+1:end]);
        else
          i=i+1;
        end
      end
      for i=1:length(zcs)-1
        % compute indices of this segment
        inds = (zcs(i)+1):zcs(i+1);
        if (length(inds)<2) % successive zero crossings?
          % commands like this are useful for debugging here:
          %  plot(y(2,:),y(3,:),'.-',y(2,zcs(2:end)),y(3,zcs(2:end)),'r*')
          %  keyboard;
          warning('successive zero crossings');
          i=i+1;
          continue;
        end
        pptraj = {pptraj{:},makeSubTrajectory(t([max(inds(1)-1,1),inds(2:end)]),y(:,inds))};  % use time of zc instead of 1e-10 past it.
        i=i+1;
      end
      if (length(pptraj)>1)
        traj = HybridTrajectory(pptraj);
      else
        traj = pptraj{1};
      end
    else
      traj = makeSubTrajectory(t,y);
    end
  end
else
  sim(mdl,pstruct);
end

end
