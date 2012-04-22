function V = tilyap(obj,x0,Q)
% @retval V an msspoly representation of the quadratic Lyapunov candidate 

if (~isTI(obj)) error('I don''t know that this system is time invariant.  Set the TI flags and rerun this method if you believe the system to be.'); end
if (~isCT(obj)) error('only handle CT case so far'); end

nX = getNumStates(obj);
typecheck(x0,'double');
sizecheck(x0,[nX,1]);
typecheck(Q,'double');  
sizecheck(Q,[nX,nX]);
if (any(eig(Q)<=0)) error('Q must be positive definite'); end
if (~issymmetric(Q)) error('Q must be symmetric'); end

u0 = zeros(getNumInputs(obj),1);

tol = 1e-10;
[A,B,C,D,xdot0] = linearize(obj,0,x0,u0);
if (any(abs(xdot0)>tol))
  xdot0
  error('f(x0) is not a fixed point');
end

S=lyap(A,Q);

x=msspoly('x',getNumStates(obj));
V = (x-x0)'*S*(x-x0);

end

