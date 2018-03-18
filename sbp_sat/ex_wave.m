clear all
close all
clc

%========================================================================
% Problem Parameters
%========================================================================
par = struct(...
    'name','wave-equation',... % name of example
    'n_eqn',2,... % number of eq per grid point
    'initial_condition',@initial_condition,... % it is defined below
    'ax',[0 1 0 1],... % extents of computational domain
    'n',[100 100],... % numbers of grid cells in each coordinate direction
    't_end',0.2,... % end time of computation
    'diff_order',2,... % the difference order in the physical space
    'RK_order',2,...
    'CFL',0.5,...      % crude cfl number
    'num_bc',4,... % number of boundaries in the domain
    'output',@output... % problem-specific output routine (defined below)
    );

par.t_plot = linspace(0,par.t_end,50);

[par.system_data] = get_system_data(par.n_eqn);

% % the moment variable to be output
par.mom_output = 2;

% solve the system
solution = solver(par);

%========================================================================
% Problem Specific Functions
%========================================================================

function f = initial_condition(x,y)
% Maxwellian/Gaussian
x0 = 0.5; % centered in the middle of domain
y0=0.5;
sigma_x=0.1; % such that 6*sigma = 0.6 so in 0.2 length strip near boundary
sigma_y=0.1;                                         % function value = 0
f = exp( -((x-x0).^2 / (2*sigma_x.^2)) - ((y-y0).^2 / (2*sigma_y.^2)) );
end

function output(par,x,y,U,step)
% Plotting routine.
cax = [-7 0];                    % Colormap range used for log10 scaling.
vneg = cax(1)-diff(cax)/254;        % Value assigned where U is negative.
V = log10(max(U,1e-50));% Cap U s.t. U>0 and use logarithmic color scale.
Vcm = max(V,cax(1));                      % Cap colormap plot from below.
Vcm(U<0) = vneg;              % Assign special value where U is negative.
clf, subplot(1,3,1:2)
imagesc(x,y,Vcm'), axis xy equal tight, caxis([vneg cax(2)])
title(sprintf('t = %0.2f',par.t_plot(step)))
cm = jet(256); cm(1,:) = [1 1 1]*.5; % Change lowest color entry to gray.
colormap(cm), colorbar('ylim',cax)
xlabel('x'), ylabel('y')
subplot(1,3,3)
plot(y,interp2(x,y,V',y*0+0.5,y))   % Evaluate solution along line x=0.5.
axis([par.ax(1:2) cax+[-1 1]*.1])
title('Cut at x=0.5'), xlabel('y')
drawnow
end



