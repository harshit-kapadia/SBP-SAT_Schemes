% M is the highest tensor degree
function [] = ex_gaussian_collision_kinetic(M,nx)
%========================================================================
% Problem Parameters
%========================================================================
par = struct(...
    'name','advection equation',... % name of example
    'initial_condition',@initial_condition,... % it is defined below
    'exact_solution',@exact_solution,...
    'ax',[0 1 0 1],... % extents of computational domain
    'n',[nx nx],... % numbers of grid cells in each coordinate direction
    't_end',0.3,... % end time of computation
    'diff_order',2,... % the difference order in the physical space
    'RK_order',4,...
    'CFL',0.4,...      % crude cfl number
    'num_bc',4,... % number of boundaries in the domain
    'bc_inhomo',@bc_inhomo,... % source term (defined below)
    'var_plot',1,...
    'to_plot',false,...
    'compute_density',@compute_density,...
    'compute_ux',@compute_ux,...
    'compute_uy',@compute_uy,...
    'compute_theta',@compute_theta,...
    'compute_sigma_xx',@compute_sigma_xx,...
    'compute_sigma_xy',@compute_sigma_xy,...
    'compute_sigma_yy',@compute_sigma_yy,...
    'compute_qx',@compute_qx,...
    'compute_qy',@compute_qy,...
    'write_solution',@write_solution,...
    'steady_state',false...
    );

% file where the output is written
par.output_filename = strcat('results/gaussian_collision_kinetic/result_M',num2str(M),...
                             '_n',num2str(par.n(1)),'.txt');

par.M = M;

% we need the boundary matrix and the penalty matrix for all the
% boundaries
par.system.penalty_B = cell(par.num_bc,1);
par.system.penalty = cell(par.num_bc,1);
par.system.B = cell(par.num_bc,1);
par.system.rotator = cell(par.num_bc,1);
par.system.rhoW = cell(par.num_bc,1);   % vectors which store the rhoW
par.Kn = 0.1;

par.system.Ax = dvlp_Ax2D(M);
par.system.P = dvlp_Prod2D(M);
par.system.BIn = dvlp_BInflow2D(M);
par.system.BWall = dvlp_BWall2D(M);

par.n_eqn = size(par.system.Ax,1);
par.system.BIn = stabilize_boundary(par.system.Ax,par.system.BIn,M);
par.system.BWall = stabilize_boundary(par.system.Ax,par.system.BWall,M);
Btemp1 = change_odd_sign(par.system.BIn);

% first boundary
par.system.penalty{1} = dvlp_penalty_kinetic(par.system.Ax,M); 
%par.system.penalty{1} = dvlp_penalty_char(par.system.Ax,par.system.BWall);

% rotator for different boundaries
rotator = dvlp_RotatorCartesian(M,false);
Btemp = cell(par.num_bc,1);

% rotation matrices for hermite polynomials
par.normals_bc = [1,0;0,1;-1,0;0,-1];
par.system.Ay = rotator{2}' * par.system.Ax * rotator{2};

for i = 1 : par.num_bc
    par.system.penalty{i} = rotator{i}' * par.system.penalty{1} * rotator{i}; % kinetic penalty
    par.system.B{i} = eye(par.n_eqn); % kinetic penalty
    
    Btemp{i} = Btemp1 * rotator{i};
    par.system.rhoW{i} = Btemp{i}(1,:);
    par.system.rhoW{i} = par.system.rhoW{i}/par.system.rhoW{i}(1);
end

for i = 1 : par.num_bc
    par.system.penalty_B{i} = par.system.penalty{i}*par.system.B{i};
end

par.previous_M_data = 0; % actually useless for this example (unsteady)
result = solver_kinetic(par);

end

function [penalty] = dvlp_penalty_odd(Ax,M)

[odd_ID,~] = get_id_Odd(M);

odd_ID = flatten_cell(odd_ID);

% we pick the columns which get multiplied by the odd variables
penalty = Ax(:,odd_ID);
end

% read data contains the already read files
function f = initial_condition(x,y,j,read_data)

f = x * 0;

x0 = 0.50; % centered in the middle of domain
y0 = 0.50;

% if j==1 || j==2 % for both density and ux
if j==1
    f = exp( -((x-x0).^2 * 50) - ((y-y0).^2 * 50) ); % sigma_x=sigma_y=0.1
end


end

function f = bc_inhomo(B,rhoW)    

    f = cell(1,length(B(1,:)));
    
    % all the higher order moments are zero
    f{1} = rhoW;
    
    for i = 2:length(f)
        f{i} = f{1} * 0;
    end
end



function f = change_odd_sign(B)

% location of ones in the matrix
loc_one = find(B == 1);

if (size(loc_one) == size(B,1))
    error('assumption broken');
end

f = B;
f(loc_one) = -f(loc_one);

end

function [] = write_solution(temp,par,X,Y,M,residual)
density = par.compute_density(temp);
ux = par.compute_ux(temp);
uy = par.compute_uy(temp);
theta = par.compute_theta(temp);
sigma_xx = par.compute_sigma_xx(temp);
sigma_xy = par.compute_sigma_xy(temp);
sigma_yy = par.compute_sigma_yy(temp);
qx = par.compute_qx(temp);
qy = par.compute_qy(temp);

filename = par.output_filename;
dlmwrite(filename,X(:)','delimiter','\t','precision',10);
dlmwrite(filename,Y(:)','delimiter','\t','precision',10,'-append');
dlmwrite(filename,density(:)','delimiter','\t','-append','precision',10);

dlmwrite(filename,ux(:)','delimiter','\t','-append','precision',10);
dlmwrite(filename,uy(:)','delimiter','\t','-append','precision',10);

dlmwrite(filename,theta(:)','delimiter','\t','-append','precision',10);

dlmwrite(filename,sigma_xx(:)','delimiter','\t','-append','precision',10);
dlmwrite(filename,sigma_xy(:)','delimiter','\t','-append','precision',10);
dlmwrite(filename,sigma_yy(:)','delimiter','\t','-append','precision',10);

dlmwrite(filename,qx(:)','delimiter','\t','-append','precision',10);
dlmwrite(filename,qy(:)','delimiter','\t','-append','precision',10);

filename = strcat('gaussian_collision_odd/residual_M',num2str(M),'.txt');
dlmwrite(filename,residual(:)','delimiter','\t','-append','precision',10);
end

function f = compute_density(data)
f = data{1};
end

function f = compute_ux(data)
f = data{2};
end

function f = compute_uy(data)
f = data{3};
end

function f = compute_theta(data)
f = sqrt(2) * (data{4} + data{6} + data{7})/3;
end

function f = compute_sigma_xx(data)
f = sqrt(2) * (2 * data{4} - data{6} - data{7})/3;
end

function f = compute_sigma_xy(data)
% 110
f = data{5};
end

function f = compute_sigma_yy(data)
f = sqrt(2) * (-data{4} + 2 * data{6} - data{7})/3;
end

function f = compute_qx(data)
shift =7;   % shift for tensor degrees which come before 3 
% (3,0,0) + (1,2,0) + (1,0,2)
f = (sqrt(3) * data{shift + 1} + data{shift + 3} + data{shift + 4})/sqrt(2);
end

function f = compute_qy(data)
shift =7;   % shift for tensor degrees which come before 3 
% (0,3,0) + (2,1,0) + (0,1,2)
f = (sqrt(3) * data{shift + 5} + data{shift + 2} + data{shift + 6})/sqrt(2);
end

