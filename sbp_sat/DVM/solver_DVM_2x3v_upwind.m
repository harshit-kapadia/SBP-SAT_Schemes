function output = solver_DVM_2x3v_upwind(par)

if ~isfield(par,'save_during'), par.save_during = false; end % default value of save during the computation

if ~isfield(par,'ic'),       par.ic = @zero; end% Default: no init. cond.

if ~isfield(par,'source'),  par.source = @zero; end % Default: no source.


if par.num_bc ~=4
    assert(1 == 0, 'not valid num bc'); 
end   

% if we are not looking for the steady state then take the residual to be
% simply zero. 
if ~isfield(par,'steady_state')
    par.steady_state = false;
end

% find which of the given data is time dependent
time_dep = [nargin(par.source)>2 nargin(par.bc_inhomo_inflow)>7];
        
% if the number of arguments are greater than 3 then definitely we have 
% an anisotropic source term.
if ~isfield(par,'source_ind') 
    par.source_ind = 1:par.n_eqn;  
end

% corresponding to every row in Ax, stores the non-zero indices
Ix = cellfun(@find,num2cell(par.system.Ax',1),'Un',0);         
Iy = cellfun(@find,num2cell(par.system.Ay',1),'Un',0);

% positive and negative velocities
pos_vx = find(diag(par.system.Ax) > 0);
neg_vx = find(diag(par.system.Ax) < 0);

pos_vy = find(diag(par.system.Ay) > 0);
neg_vy = find(diag(par.system.Ay) < 0);
%% Grid Setup

% size of the grid. h1 for the x direction and h2 for the y direction
h = (par.ax([2 4])-par.ax([1 3]))./par.n; % ./ does right-array division

% Set of grid nodes in x and y direction
x{1} = par.ax(1):h(1):par.ax(2);
y{1} = par.ax(3):h(2):par.ax(4);

% Generate both grids. X contains the x coordinates and Y contains
% the y coordinates.


[X,Y] = cellfun(@ndgrid,x,y,'Un',0);


%% Time-step

% a crude approximation for delta_t
par.dt = min(h)/max(abs(diag(par.system.Ax)))/par.CFL; % 1 eigenv.

disp('delta t');
disp(par.dt);

% with largest magnitude

%% initialisation of solution variables
% we have two systems now, one corresponding to g and the other to h
U = cell(2,par.n_eqn); dxU = U; dyU = U; UTemp = U; 
fM = cell(2,par.n_eqn);

% data structure for storing the values at the boundaries. The one coming
% from Sigma * B and the one coming from Sigma * g are both stored in
% bc_values. 
k_RK = cell(4,2);

for i = 1 : 2
    for j = 1:par.n_eqn
        fM{i,j} = X{1}*0;
    end
end

% prescribe the initial conditions
if isfield(par,'ic')
    U = capargs(par.ic,X{1},Y{1},par.system.Ax,par.system.Ay, ...
                    par.mass_matrix,par.inv_mass_matrix,par.value_f0);
end

% we need to initialize the dxU data structure
for i = 1 : 2
    for j = 1 : par.n_eqn
        dxU{i,j} = U{i,j} * 0;
        dyU{i,j} = U{i,j} * 0;
    end
end

%% Related to boundary treatment

% compute the boundary inhomogeneity
t = 0;

%% Time Loop
cputime = zeros(1,3);
t = 0; step_count = 0;
rho = par.compute_density(U,par.system.Ax,par.system.Ay,par.all_w);

residual = 0;

while t < par.t_end || residual > 10^(-3)
   
    if ~par.steady_state
        if t+par.dt > par.t_end
            par.dt = par.t_end-t;
        end
    end
    
    % the ode sytem can be written as U_t = Op.
    % RK = 4 implementation
     tic
     switch par.RK_order
         case 2
             t_temp = [t t + par.dt/2];
             dt_temp = [0 par.dt/2];
             weight = [0 1];
         case 4
             t_temp = [t t + par.dt/2 t + par.dt/2 t + par.dt];
             dt_temp = [0 par.dt/2 par.dt/2 par.dt];
             weight = [1/6 2/6 2/6 1/6];
         otherwise
             assert(1==0, 'Should run with Runge Kutta order 2 or 4');
     end
     
     UTemp = U; 
     for RK = 1 : par.RK_order
         evaluate = time_dep & (t_temp(RK) > 0);
         
         
         rho = par.compute_density(UTemp,par.system.Ax,par.system.Ay,par.all_w);
         [ux,uy] = par.compute_velocity(UTemp,par.system.Ax,par.system.Ay,par.all_w);
         theta = par.compute_theta(UTemp,par.system.Ax,par.system.Ay,par.all_w);
        
         % we need to reconstruct the maxwellian which is independent of
         % the coming computation and therefore not influenced.
         fM = store_minimized_entropy(par.system.Ax,par.system.Ay, ...
                            par.mass_matrix,par.inv_mass_matrix,rho,ux,uy,theta,par.value_f0);
         
                      
         % compute the derivatives for g and h
         for i = 1 : 2
                          
             % loop over the different velocities. grid in velocity is the
             % same in all the directions
             for j = 1 : length(pos_vx)
                 % (u_i-u_{i-1})/delta_x
                 dxU{i,pos_vx(j)}(2:end,:) = (UTemp{i,pos_vx(j)}(2:end,:)-UTemp{i,pos_vx(j)}(1:(end-1),:))/h(1);
                 % (u_{i+1}-u_i)/delta_x
                 dxU{i,neg_vx(j)}(1:end-1,:) = (UTemp{i,neg_vx(j)}(2:end,:)-UTemp{i,neg_vx(j)}(1:end-1,:))/h(1);
                 % (u_i-u_{i-1})/delta_y
                 dyU{i,pos_vy(j)}(:,2:end) = (UTemp{i,pos_vy(j)}(:,2:end)-UTemp{i,pos_vy(j)}(:,1:end-1))/h(2);
                 % (u_{i+1}-u_i)/delta_y
                 dxU{i,neg_vy(j)}(:,1:end-1) = (UTemp{i,neg_vx(j)}(:,2:end)-UTemp{i,neg_vx(j)}(:,1:end-1))/h(2);
             end
            
            
                   
             for j = 1 : par.n_eqn
                 
                 % assuming that the system is diagonal
                 %W = - (dxU{i,j} * par.system.Ax(j,j) +  dyU{i,j} * par.system.Ay(j,j));
                 W = - (dxU{i,j} * par.system.Ax(j,j));
                 
                 k_RK{RK,i}{j} = W;
             
                 k_RK{RK,i}{j} = k_RK{RK,i}{j} + ...
                                 (-UTemp{i,j}+fM{i,j})/par.Kn;
             end
         end
         
         if RK ~= par.RK_order
             for i = 1 : 2
                 for j = 1 : par.n_eqn
                     UTemp{i,j} = U{i,j} + k_RK{RK,i}{j} * dt_temp(RK + 1);      
                 end
             end
             
             % computes the values to be prescribed at the boundaries
             bc_g =  get_values_at_boundary(par,UTemp,t_temp(RK));
             
             % prescribes the values computed in the previous routine
             update_boundary_values(bc_g,UTemp,pos_vx,pos_vy,neg_vx,neg_vy);
         end
     end
    
    rho = par.compute_density(U,par.system.Ax,par.system.Ay,par.all_w);
    [ux,uy] = par.compute_velocity(U,par.system.Ax,par.system.Ay,par.all_w);
    theta = par.compute_theta(U,par.system.Ax,par.system.Ay,par.all_w);
    
    for RK = 1 : par.RK_order
        for i = 1 : 2
            for j = 1 : par.n_eqn
                U{i,j} = U{i,j} + weight(RK) * k_RK{RK,i}{j} * par.dt;
            end
        end
        
        % computes the values to be prescribed at the boundaries
        bc_g = get_values_at_boundary(par,U,t + par.dt);
        % prescribes the values computed in the previous routine
        update_boundary_values(bc_g,U,pos_vx,pos_vy,neg_vx,neg_vy);
    end
        
    step_count = step_count + 1;
    t = t + par.dt;
    cputime(1) = cputime(1) + toc;


    if mod(step_count,10) == 0
        disp('time: neqn: step_count:');
        disp(t);
        disp(par.n_eqn);
        disp(step_count);
        
        rho_new = par.compute_density(U,par.system.Ax,par.system.Ay,par.all_w);
        [ux_new,uy_new] = par.compute_velocity(U,par.system.Ax,par.system.Ay,par.all_w);
        theta_new = par.compute_theta(U,par.system.Ax,par.system.Ay,par.all_w);
                
        % if we are computing for the steady state
        if par.steady_state
            %residual =  norm(uy-uy_new)^2+ ...
            %            norm(ux-ux_new)^2+ ...
            %            norm(theta-theta_new)^2;
                    
           residual = norm(theta-theta_new)^2;
        end
    
        % change in density
        disp('change in density');
        % earlier we computed the square of the norm
        residual = sqrt(residual)/par.dt;
        disp('residual');
        disp(residual);
    end
    
    tic
    
    if par.t_plot
        var_plot = par.compute_density(U,par.system.Ax,par.system.Ay,par.all_w);

        figure(1);
        contourf(X{1},Y{1},var_plot), axis xy equal tight;
        
        title(sprintf('t = %0.2f',t));
        colorbar;
        xlabel('x'), ylabel('y');
        
        xlim(par.ax([1 2]));
        ylim(par.ax([3 4]));
        zlim([-0.1 1]);
        
        drawnow

    end
    
    % option to save the data during time step, required for convergence
    % studies
    if par.save_during && mod(step_count,100) == 0
        % we compute the norms of the different features of the solution
        capargs(par.compute_during,U,weight,k_RK,PX,DX,t);
    end
    
    cputime(2) = cputime(2) + toc;
end

fprintf('%0.0f time steps\n',step_count)           % Display test
cputime = reshape([cputime;cputime/sum(cputime)*1e2],1,[]);   % case info
fprintf(['CPU-times\n advection:%15.2fs%5.0f%%\n',... % and CPU times.
    'plotting:%16.2fs%5.0f%%\n'],cputime)

output = struct('X',X{1}, ...
                'Y',Y{1}, ...  
                'sol',U, ...
                 'PX',PX{1}, ...
                 'PY',PY{1}, ...
                 'h',h);
end


function z = capargs(fct,varargin)
% Call function fct with as many arguments as it requires (at least 1),
% and ignore further arguments.
narg = max(nargin(fct),1);
z = fct(varargin{1:narg});

end

function f = zero(varargin)
% Zero function.
f = zeros(size(varargin{1}));
end

function S = sumcell(A,w)
% Add vector of cells A, weighted with vector w.
S = 0;

for j = 1:length(w)
    S = S+A{j}*w(j);
end

end


function f = integrate_xy(data,PX,PY)
diag_PX = diag(PX);
diag_PY = diag(PY);

% integral along x at different y points
int_x = zeros(size(data,2),1);

for i = 1 : length(int_x)
    int_x(i) = dot(diag_PX,data(:,i));
end

% integrate along the y direction
f = full(dot(int_x,diag_PY));
end

function bc_g = get_values_at_boundary(par,UTemp,t_temp)

            bc_g = cell(2,par.num_bc);
            rhoW = cell(par.num_bc,1);
            
            for i = 1 : 2
              % extract all the value at x = x_end.
              bc_ID = 1;
             
             if par.wall_boundary(bc_ID) % if the we have a gas wall then we recompute bc_g
                rhoW{bc_ID} = -sumcell(cellfun(@(a) a(end,:),...
                              UTemp(1,par.pos_U{bc_ID}),'Un',0),par.rhoW_vect{bc_ID})...
                             - par.compute_thetaW(bc_ID,t_temp) * par.rhoW_value{bc_ID};
                % for a wall bc_g{i,bc_ID} is a cell with every element being a vector. For the in
                %-flow boundary, every element of the cell is a scalar
                %quantity. This is because in case of wall, the density at
                %the wall changes along the entire boundary. 
                bc_g{i,bc_ID} = capargs(par.bc_inhomo_wall, par.system.B{bc_ID}, bc_ID,...
                        par.system.Ax, par.system.Ay, rhoW{bc_ID}, i,t_temp);
             end
             
             
          bc_ID = 2;
          
          if par.wall_boundary(bc_ID) % if the we have a gas wall then we recompute bc_g
              rhoW{bc_ID} = -sumcell(cellfun(@(a) a(:,end),...
                  UTemp(1,par.pos_U{bc_ID}),'Un',0),par.rhoW_vect{bc_ID})...
                  - par.compute_thetaW(bc_ID,t_temp) * par.rhoW_value{bc_ID};
              
              bc_g{i,bc_ID} = capargs(par.bc_inhomo_wall, par.system.B{bc_ID}, bc_ID,...
                  par.system.Ax, par.system.Ay, rhoW{bc_ID}, i,t_temp);
          end
          
          bc_ID = 3;
             
             if par.wall_boundary(bc_ID) % if the we have a gas wall then we recompute bc_g
                rhoW{bc_ID} = -sumcell(cellfun(@(a) a(1,:),...
                              UTemp(1,par.pos_U{bc_ID}),'Un',0),par.rhoW_vect{bc_ID})...
                             - par.compute_thetaW(bc_ID,t_temp) * par.rhoW_value{bc_ID};
                bc_g{i,bc_ID} = capargs(par.bc_inhomo_wall, par.system.B{bc_ID}, bc_ID,...
                        par.system.Ax, par.system.Ay, rhoW{bc_ID}, i,t_temp);
             end
             

             bc_ID = 4;
             
             if par.wall_boundary(bc_ID) % if the we have a gas wall then we recompute bc_g
                 rhoW{bc_ID} = -sumcell(cellfun(@(a) a(:,1),...
                     UTemp(1,par.pos_U{bc_ID}),'Un',0),par.rhoW_vect{bc_ID})...
                     - par.compute_thetaW(bc_ID,t_temp) * par.rhoW_value{bc_ID};
                 bc_g{i,bc_ID} = capargs(par.bc_inhomo_wall, par.system.B{bc_ID}, bc_ID,...
                     par.system.Ax, par.system.Ay, rhoW{bc_ID}, i,t_temp);
             end
            end
             
end

function [] = update_boundary_values(bc_g,UTemp,pos_vx,pos_vy,neg_vx,neg_vy)
    
    velocity_to_prescribe = length(pos_vx); % total points, at each space point, we would like to prescribe the velocity to.

    for i = 1 : 2
        %% update for bc_id = 1
        for j = 1 : velocity_to_prescribe
            UTemp{i,neg_vx(j)}(end,:) = bc_g{i,1}{neg_vx(j)}(:) * 0;
        end
        
%         %% update for bc_id = 2
%         for j = 1 : velocity_to_prescribe
%             UTemp{i,neg_vy(j)}(:,end) = bc_g{i,2}{neg_vy(j)}(:) * 0;
%         end
        
        %% update for bc_id = 3
        for j = 1 : velocity_to_prescribe
            UTemp{i,pos_vx(j)}(1,:) = bc_g{i,3}{pos_vx(j)}(:) * 0;
        end
        
%         %% update for bc_id = 4
%         for j = 1 : velocity_to_prescribe
%             UTemp{i,pos_vy(j)}(:,1) = bc_g{i,4}{pos_vy(j)}(:) * 0;
%         end
    end
    
end