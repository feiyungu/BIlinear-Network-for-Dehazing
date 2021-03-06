function [delta_a, delta_t, energy_val] = vl_nnhazesquareloss(A, T, labels, in, dzdy)
%%%%%%%%%%%%%%%%% Error for hazy image %%%%%%%%%%%%%%%%%%%
batch_num = size(in,4);
%
J = labels(:,:,1:3,:);
gt_T = labels(:,:,4:end,:);
gt_T_tmp = repmat(gt_T, [1,1,3,1]);

A_gt = (in-J.* gt_T_tmp)./(1-gt_T_tmp); 

A_ini = A;
T_ini = T;

%%% The whole loss fcuntion %%%%%%%%%
% E1 = J * T' + (1-T')*A' – hazy;
% E2 = T' – T_GT;
% delta_t = G( E1 *(J-A')) + G(E2);
% delta_A = (1-T')*E1;

% calculate E1 and E2 
% T = repmat(T, [1,1, size(J,3), 1]);
hazyimg = gt_T_tmp.* J + (1-gt_T_tmp).*A; % The reconstructed hazy image from learned A and T
resdual_error1=(hazyimg-in(:,:,1:3,:));   % E1---composition error
resdual_error2=(T_ini-gt_T);              % E2---T error
resdual_error3=(A-A_gt);  
    
% The overall loss function
energy_val = 0.5 * sum(resdual_error1(:).^2)./ batch_num +0.5 * sum(resdual_error2(:).^2)./ batch_num +...
         0.5 * sum(resdual_error3(:).^2)./ batch_num ;

%% Do this if back propagation is not needed
if nargin <= 4 % return energy value
    delta_a = 0;
    delta_t = 0;
    
% Do back propagation
else  
  delta_a = 0.1 * resdual_error1.*(1-gt_T_tmp) + 0.9 * resdual_error3;
    
    %delta_t = resdual_error1.*(J-A);
    %delta_t = sum(delta_t,3)./3 + resdual_error2;
    delta_t = resdual_error2;
    delta_t = gather(delta_t);
    J = gather(J);
    delta_t_tmp = zeros(size(J,1),size(J,2),1,batch_num);
    % Calculate derivative for image guided filter
    for i=1:batch_num
        delta_t_tmp(:,:,:,i) = imguidedfilter(delta_t(:,:,:,i),J(:,:,:,i),'NeighborhoodSize',3,'DegreeOfSmoothing',0.01);
    end
    delta_t = single(delta_t_tmp);
    delta_t = gpuArray(delta_t);
     
end
