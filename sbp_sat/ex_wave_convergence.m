clear all
close all
clc

%========================================================================
% Problem Parameters
%========================================================================
par = struct(...
    'name','wave-equation',... % name of example
    'n_eqn',3,... % number of variables
    'initial_condition',@initial_condition,... % it is defined below
    'theoretical_solution',@theoretical_solution,...
    'ax',[0 1 0 1],... % extents of computational domain
    'n',[100 100],... % numbers of grid cells in each coordinate direction
    't_end',0.2,... % end time of computation
    'diff_order',2,... % the difference order in the physical space
    'RK_order',2,...
    'CFL',0.5,...      % crude cfl number
    'num_bc',4,... % number of boundaries in the domain
    'bc_inhomo',@bc_inhomo,... % source term (defined below)
    'get_penalty',@get_penalty,...
    'var_plot',1,...
    'to_plot',true,...
    'output',@output... % problem-specific output routine (defined below)
    );

par.t_plot = linspace(0,par.t_end,50);

par.c = 1 ; % wave speed
[par.system] = get_system(par.c);

[par.system] = get_penalty(par.system, par.num_bc, par.c);


% %========================================================================
% % Run solver
% %========================================================================
% 
% % % solve the system
% % solution = solver(par);
% 
% resolution = [16 32 64 128 256];
% 
% error_l2 = zeros(par.n_eqn,length(resolution));
% for k = 1:length(resolution)                       % Loop over various grid resolutions.
%     par.n = [1 1]*resolution(k);                   % Numbers of grid cells.
%     solution = solver(par);                         % Run solver.
%     for j = 1:1                                % Loop over solution components.
%         [X,Y] = ndgrid(solution(j).x,solution(j).y);     % Grid on which solution lives.
%         U_theo = theoretical_solution(X,Y,par.t_end);     % Evaluate true solution.
%         error = abs(solution(j).U-U_theo);               % Difference between num. and true sol.
%         int_x = dot(transpose(error),transpose(solution(j).Px * error),2);  % integral along x.
%         int_xy = sum(solution(j).Py*int_x);  % integral along xy.
%         error_l2(j,k) = sqrt(int_xy);%Sc. L2 error.
%     end
% end
% figure
% loglog( (resolution), error_l2(1,:), '-o' )
% xlabel('# cells in each direction'), ylabel('l2-error')
% title('Convergence plot')
% 
% rate = log(error_l2(1,4)/error_l2(1,1)) / log((resolution(1))/(resolution(4)));
% rate
% 
% % rate = log(error_l2(1,4)/error_l2(1,1)) / log(sqrt(resolution(4))/sqrt(resolution(1)));
% % rate2 = log2( error_l2(1,3)/error_l2(1,4) );
% 
% % convg_rate = zeros(par.n_eqn,length(resolution));
% % for i = 1:1 % loop over components
% %     for j = 2:length(resolution)
% %         convg_rate(i,j) = log2( error_l2(i,j) / error_l2(i,j) );
% %     end
% % end


%========================================================================
% Run solver and study convergence
%========================================================================

resolution = [16 32 64 128];
grid_spacing = [];

for k = 1:length(resolution)                       % Loop over various grid resolutions.
    par.n = [1 1]*resolution(k);                   % Numbers of grid cells.
    solution = solver(par);                         % Run solver.
    error_temp = 0;
    disp('Resolution :');
    disp(par.n);
    for j = 1:par.n_eqn                               % Loop over solution components.
        X = solution(j).X;
        Y = solution(j).Y;
        PX = solution(j).PX;
        PY = solution(j).PY;
        U_theo = theoretical_solution(X,Y,par.t_end);     % Evaluate true solution.
        error = abs(solution(j).sol-U_theo);               % Difference between num. and true sol.
        int_x = dot(transpose(error),transpose(PX * error),2);  % integral along x.
        int_xy = sum(PY*int_x);  % integral along xy.
        error_temp = int_xy + error_temp;%Sc. L2 error.
    end
    error_L2(k) = sqrt(error_temp);
    grid_spacing = [grid_spacing max(solution(1).h)];
end

reference_line = exact_order(grid_spacing(1),error_L2(1),grid_spacing(end),2);

figure
loglog(grid_spacing, error_L2, '-o',reference_line(1:2),reference_line(3:4),'-*');
xlabel('h'), ylabel('l2-error');
legend('numerical','second order');
title('Convergence plot');

% convergence plot
convg_order = log(error_L2(end)/error_L2(1))/log(grid_spacing(end)/grid_spacing(1));
disp('convergence order');
disp(convg_order);

% plot error in domain
figure
contourf(X,Y,error), axis xy equal tight;

title('Error in domain');
colorbar;
xlabel('x'), ylabel('y')



%========================================================================
% Problem Specific Functions
%========================================================================

function[system] = get_system(c)
system.Ax = [0 c^2 0; 1 0 0; 0 0 0];
system.Ay = [0 0 c^2; 0 0 0; 1 0 0];
end

function[system] = get_penalty(system, num_bc, c)
system.nx = [1 0 -1 0] ; % size = num_bc and east-north-west-south order
system.ny = [0 1 0 -1] ;

% we need the boundary matrix and the penalty matrix for all the
% boundaries
system.penalty_B = cell(num_bc,1);
system.penalty = cell(num_bc,1);
system.B = cell(num_bc,1);

system.A_n = cell(num_bc,1);

for i = 1 : num_bc
    system.A_n{i} = system.Ax*system.nx(i) + system.Ay*system.ny(i);
    system.B{i} = [1 -c^2*system.nx(i) -c^2*system.ny(i)];
    
    A_n_positive{i} = sqrt(system.A_n{i}' * system.A_n{i});
    
    [system.X_n{i}, system.Lambda{i}] = eig(system.A_n{i});
    
    diag_Lambda = diag(system.Lambda{i});
    column_index = find(diag_Lambda<0);
    system.X_n_neg{i} = system.X_n{i}(:,column_index);
    
    system.penalty{i} = 0.5 * ( (system.A_n{i}-A_n_positive{i}) *...
                  system.X_n_neg{i} * inv(system.B{i}*system.X_n_neg{i}) );
    
    system.penalty_B{i} = system.penalty{i}*system.B{i};
end

end

function f = initial_condition(x,y)
% Maxwellian/Gaussian
x0 = 0.5; % centered in the middle of domain
y0 = 0.5;
sigma_x = 0.1; % such that 6*sigma = 0.6 so in 0.2 length strip near
sigma_y = 0.1;                           % boundary function value = 0
f = exp( -((x-x0).^2 / (2*sigma_x.^2)) - ((y-y0).^2 / (2*sigma_y.^2)) );
end

function f = theoretical_solution(x,y,t)
% Maxwellian/Gaussian
a = 1; % wave speed
x0 = 0.5 + a*t; % centered in the middle of domain
y0 = 0.5 + a*t;
sigma_x = 0.1; % such that 6*sigma = 0.6 so in 0.2 length strip near
sigma_y = 0.1;                           % boundary function value = 0
f = exp( -((x-x0).^2 / (2*sigma_x.^2)) - ((y-y0).^2 / (2*sigma_y.^2)) );
end

function f = bc_inhomo(B,bc_id,t)
switch bc_id
    % east boundary but in matrix - south, i.e. last row -> x-dir #cell
    case 1
        boundary_value = 0;
        % north boundary
    case 2
        boundary_value = 0;
        % west boundary
    case 3
        boundary_value = 0; % for g = 0
        % south boundary
    case 4
        boundary_value = 0; % for g = 0
end

f = boundary_value * diag(B); % multiplying by diag(B) so the structure
% we get is cell{#bc_ID}<--{n_eqn}<--vector(size = # nodes at boundary)
end

% function f = regular_unitstep(t) % regularized unitstep function
%     if t < 1
%         f = exp(-1/(1-(t-1)^2)+1);
%     else
%         f = 1;
%     end
% end

function[reference_order] = exact_order(x1,y1,x2,order)

y2 = y1 * exp(order * log(x2/x1));
reference_order = [x1 x2 y1 y2];
end

% function output(par,x,y,U,step)
% 
% % imagesc(x,y,U'), axis xy equal tight;
% 
% % surf(x,y,U'), axis xy equal tight;
% % % get rid of lines in surf
% % colormap summer;
% % shading interp;
% 
% contourf(x,y,U'), axis xy equal tight;
% 
% title(sprintf('t = %0.2f',par.t_plot(step)));
% colorbar;
% xlabel('x'), ylabel('y')
% 
% drawnow
% end


