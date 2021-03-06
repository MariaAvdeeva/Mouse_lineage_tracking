
function [] = track_nuclei_based_on_CPD_Masha_divisions()
% uses already tracked embryo that was easy that Masha gave to me
% performs 'easy' registration
% creates graph
% shows some visualizations..

addpath(genpath('/Users/mavdeeva/Desktop/Software/CPD2/core'));
addpath(genpath('/Users/mavdeeva/Desktop/Software/CPD2/data'));
%%

G_based_on_nn = graph;
sigma_thres = 30;
reg_avail = false;
trans_path = '/Users/mavdeeva/Desktop/mouse/HaydensCode2022/stack_1_transformsMatchGood1_125.mat';
cell_assoc = '/Users/mavdeeva/Desktop/mouse/HaydensCode2022/stacks_1_2_7_8.csv';
cm = readtable(cell_assoc);
% Voxel size before making isotropic
pixel_size_xy_um = 0.208; % um
pixel_size_z_um = 2.0; % um
% Voxel size after making isotropic
xyz_res = 0.8320;
% Volume of isotropic voxel
voxel_vol = xyz_res^3;

% Which image indices to run over...
which_number_vect = 1:75;


% What is the prefix for the embryo names?
%name_of_embryo = '/Users/hnunley/Desktop/test_for_maddy/OG_st0_NANOGGATA6_2105_better_model/Stardist3D_klbOut_Cam_Long_';
%  stack 1 in 211018. 
% from here: /mnt/home/mavdeeva/ceph/mouse/data/segmentation_out/211018. /stack1_channel_2_obj_left/nuclear
%name_of_embryo = '/mnt/ceph/users/mavdeeva/mouse/data/segmentation_out/211018/stack_1_channel_2_obj_left/nuclear/Stardist3D_klbOut_Cam_Long_';
%name_of_embryo = '/Users/lbrown/Documents/PosfaiLab/Registration/HaydensReg2022/211018_stack_1/Stardist3D_klbOut_Cam_Long_';
%name_of_embryo = '/Users/mavdeeva/Desktop/mouse/HaydensCode2022/stack_5_211019/Stardist3D_klbOut_Cam_Long_';
name_of_embryo = '/Users/mavdeeva/Desktop/mouse/HaydensCode2022/stack_1_210809/Stardist3D_Cam_Long_';


% Suffix: yours is probably '.lux.tif'
suffix_for_embryo = '.lux.tif';

% Initialize empty graph and cell array for storing registration
valid_time_indices = which_number_vect;
store_registration = cell((length(valid_time_indices)-1), 1);
sigma2_vect_saved = zeros((length(valid_time_indices)-1), 1);
% also, check the alignment of this one with the time frame after
%for time_index_index = 146:(length(valid_time_indices)-1)
for time_index_index = 15:17

    if (time_index_index == 16)
        reg_avail = false;
    else
        reg_avail = true;
    end
    disp(reg_avail);
    % store this time indexs
    time_index = valid_time_indices(time_index_index)
    
    % store next in series
    time_index_plus_1 = valid_time_indices(time_index_index+1);
    
    % store combined image for both.
    A = imread([name_of_embryo,num2str(time_index,'%05.5d'),suffix_for_embryo],1);
    tiff_info = imfinfo([name_of_embryo,num2str(time_index,'%05.5d'),suffix_for_embryo]);
    % combine all tiff stacks into 1 3D image.
    combined_image = zeros(size(A,1), size(A,2), size(tiff_info, 1));
    for j = 1:size(tiff_info, 1)
        A = imread([name_of_embryo,num2str(time_index,'%05.5d'),suffix_for_embryo],j);
        combined_image(:,:,j) = A(:,:,1);
    end
    combined_image1 = combined_image;
  
    resXY = 0.208;
    resZ = 2.0;
    reduceRatio = 1/4;
    combined_image1 = isotropicSample_nearest(double(combined_image1), resXY, resZ, reduceRatio);
    
    A = imread([name_of_embryo,num2str(time_index_plus_1,'%05.5d'),suffix_for_embryo],1);
    tiff_info = imfinfo([name_of_embryo,num2str(time_index_plus_1,'%05.5d'),suffix_for_embryo]);
    % combine all tiff stacks into 1 3D image.
    combined_image = zeros(size(A,1), size(A,2), size(tiff_info, 1));
    for j = 1:size(tiff_info, 1)
        A = imread([name_of_embryo,num2str(time_index_plus_1,'%05.5d'),suffix_for_embryo],j);
        combined_image(:,:,j) = A(:,:,1);
    end
    combined_image2 = combined_image;
    
    resXY = 0.208;
    resZ = 2.0;
    reduceRatio = 1/4;
    combined_image2 = isotropicSample_nearest(double(combined_image2), resXY, resZ, reduceRatio);
    
    % STORE MESHGRID
    [X, Y, Z] = meshgrid(1:size(combined_image1, 2), 1:size(combined_image1, 1), 1:size(combined_image1, 3));
    
    % FRACTION OF POINTS (DOWNSAMPLING)
    fraction_of_selected_points =  1/10;  % slow to run at full scale - but make full res points and xform?
    %
    find1 = find(combined_image1(:)~=0);  % this is the indices into combined_image1 to get indices into (X,Y,Z) to the full set of point
    number_of_points = length(find1);
    
    % why random points - why not just subsample by 10 ?
    p = randperm(number_of_points,round(number_of_points * fraction_of_selected_points));
    %full_ptCloud1 =  [X(find1), Y(find1), Z(find1)] - [mean(X(find1)), mean(Y(find1)), mean(Z(find1))];
    find1 = find1(p);
    
    ptCloud1 = [X(find1), Y(find1), Z(find1)] - [mean(X(find1)), mean(Y(find1)), mean(Z(find1))];
    %
    find2 = find(combined_image2(:)~=0);
    number_of_points = length(find2);
    
    p = randperm(number_of_points,round(number_of_points * fraction_of_selected_points));
    find2 = find2(p);
    
    ptCloud2 = [X(find2), Y(find2), Z(find2)] - [mean(X(find2)), mean(Y(find2)), mean(Z(find2))];
    ptCloud2 = pointCloud(ptCloud2);
   
    if ~reg_avail
        % Example 3. 3D Rigid CPD point-set registration. Full options intialization.
        %  3D face point-set.
    
        %Try previous Transform
        sigma2 = 100;
        % Set the options
        opt.method='rigid'; % use rigid registration
        opt.viz=0;          % show every iteration
        opt.outliers=0;     % do not assume any noise
    
        opt.normalize=0;    % normalize to unit variance and zero mean before registering (default)
        opt.scale=0;        % estimate global scaling too (default)
        opt.rot=1;          % estimate strictly rotational matrix (default)
        opt.corresp=0;      % do not compute the correspondence vector at the end of registration (default)
    
        opt.max_it=200;     % max number of iterations
        opt.tol=1e-3;       % tolerance
    
%         if exist('Transform','var') == 1
%             disp('Transform exists');
%             tform = rigid3d(Transform.R, [0,0,0]);%transpose(Transform.t))
%             ptCloud2 = pctransform(ptCloud2,transpose(tform));
%             ptCloud2Loc = ptCloud2.Location;
%             [Transform, ~, sigma2]=cpd_register(ptCloud1,ptCloud2Loc,opt);
%             if sigma2<sigma_thres
%                 disp('save');
%                 opt_ptCloud2 = ptCloud2Loc;
%             end
%         end
        opt.tol=1e-3;  
        if sigma2>=sigma_thres
            disp('Trying identity initialization')
            tform = rigid3d(eye(3), [0,0,0]);
    
            ptCloud2 = pctransform(ptCloud2,tform); % this makes ptCloud a pointCloud
            ptCloud2Loc = ptCloud2.Location;
            % registering Y to X
           % [Transform, ~, sigma2]=cpd_register(ptCloud1,ptCloud2,opt);
            [Transform, ~, sigma2]=cpd_register(ptCloud1,ptCloud2Loc,opt);
            if sigma2<sigma_thres
                disp('save');
                opt_ptCloud2 = ptCloud2Loc;
            end
        end
        
        sigma2_vect = zeros(100, 1);
        theta_vect = zeros(100, 3);
        opt.tol=1e-3;  
        which_rot = 1;
        opt_sigma = 100;
        while (sigma2 > sigma_thres) && (which_rot < 100)    
        
            theta1 =rand*360;
            rot1 = [ cosd(theta1) -sind(theta1) 0; ...
            sind(theta1) cosd(theta1) 0; ...
            0 0 1];
            theta2 =rand*360;
            rot2 = [ 1 0 0; ...
            0 cosd(theta2) -sind(theta2); ...
            0 sind(theta2) cosd(theta2)];
            theta3 =rand*360;
            rot3 = [ cosd(theta3) 0 sind(theta3); ...
            0 1 0; ...
            -sind(theta3) 0 cosd(theta3)];
            tform = rigid3d(rot1*rot3*rot2,[0,0,0]);
            ptCloud2 = pctransform(ptCloud2,tform);
            ptCloud2Loc = ptCloud2.Location;
            theta_vect(which_rot, 1) = theta1;
            theta_vect(which_rot, 2) = theta2;
            theta_vect(which_rot, 3) = theta3;
     
            % registering Y to X
            [Transform, ~, sigma2]=cpd_register(ptCloud1,ptCloud2Loc,opt);
            %disp(sigma2);
            %disp(opt_sigma);
            %disp(sigma_thres);
            if ((sigma2<opt_sigma) || (sigma2<sigma_thres))
                disp('save');
                opt_sigma= sigma2;
                opt_transform = Transform;
                opt_ptCloud2 = ptCloud2Loc;
            end
            which_rot = which_rot + 1;
            %close all;
        end
        opt.tol=1e-5;       % change tolerance for more accuracy
        [Transform, ~, sigma2]=cpd_register(ptCloud1,opt_ptCloud2,opt);
    else
        transforms = load(trans_path);
        Transform = transforms.store_registration{time_index_index, 1};
        R = Transform.Rotation;
        t = Transform.Translation;
        [M, D]=size(ptCloud2.Location);
        Transform.Y=ptCloud2.Location*R'-repmat(t(1,:), [M,1]);
    end
    %sigma2_vect(which_rot) = sigma2;
    store_registration{time_index_index, 1} = Transform;

        %figure; hold all; title('Before'); cpd_plot_iter(ptCloud1, ptCloud2);
       % figure; hold all;
        %title([num2str(theta1),';',num2str(theta2),';',num2str(theta3)]);
        %cpd_plot_iter(ptCloud1, ptCloud2Loc);
        %figure; hold all; title('After registering Y to X.'); cpd_plot_iter(ptCloud1, Transform.Y);
    
    % need to pick the one with the lowest sigma
    %index_min = find(sigma2_vect ==min(sigma2_vect));
    %disp(['min sigma ',sigma2_vect(index_min)]);
    %figure; hold all; title('Before'); cpd_plot_iter(ptCloud1, ptCloud2);
    %close all;
%     figure; hold all;
%         %title([num2str(theta1),';',num2str(theta2),';',num2str(theta3)]);
%     cpd_plot_iter(ptCloud1, ptCloud2Loc);
    figure; hold all; title('After registering Y to X.'); cpd_plot_iter(ptCloud1, Transform.Y);
        
        
  
    
    [iou_matrix, M, corresponding_ious_for_matches, ...
            cell_labels_I_care_about1, cell_labels_I_care_about2, ...
            center_point_for_each_label1, center_point_for_each_label2, ...
            match_based_on_nearest_neighbors, ~, ~, ...
            alpha_shape_for_each_label1, alpha_shape_for_each_label2] = compute_matches_based_on_point_clouds_CPD(Transform.Y,ptCloud1,...
            combined_image1,combined_image2,find1,find2);
     %tp t
     %disp(center_point_for_each_label1);
     %tp t+1
     %disp(center_point_for_each_label2);
     %disp((center_point_for_each_label1 - center_point_for_each_label2));
     %disp(iou_matrix);
     %dists = vecnorm((center_point_for_each_label1 - center_point_for_each_label2).');
     %disp(dists);
     store_matches{time_index_index, 1} = M;
     store_iou_table{time_index_index, 1} = iou_matrix;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % make the graph..
        
    [nn_three nd]=kNearestNeighbors(center_point_for_each_label1, center_point_for_each_label2,min(3,length(center_point_for_each_label2)));
    %remove good matches

    nn_orig = nn_three;
    disp(nn_orig);
    bad_matches = [];%unique(1:size(nn_orig,1));
    to_bad_matches = [];%unique(nn_orig(:,1));
    dup=find_duplicates(nn_three(:,1));
    for i=1:size(nn_orig,1)
        to = nn_orig(i,1);
        from = i;

        %[k,to_volume] = convhull(alpha_shape_for_each_label1{to,:}.Points);
        %[k,from_volume] = convhull(alpha_shape_for_each_label2{from,:}.Points);
        to_vols = cm(strcmp(cm.stack,'stack_1') & (cm.Nuclear_Label == to) & (cm.Time == time_index_index),'Cell_Volume');
        
        from_vols = cm(strcmp(cm.stack,'stack_1') & (cm.Nuclear_Label == from) & (cm.Time == time_index_index+1),'Cell_Volume');
        disp(from);
        disp(to);
        disp(to_vols);
        disp(from_vols);
        
        flag = true;
        for lvd=1:size(dup,1)
            if to == dup(lvd).val;
                flag = false;
            end
        end
        disp(flag);
        if ~flag
            disp('adding')
            bad_matches = [bad_matches, from];
            to_bad_matches = [to_bad_matches, to];
        else
            if (size(to_vols,1)>0)&(size(from_vols,1)>0)
                to_cell_volume = to_vols(1,1).Cell_Volume;
                from_cell_volume = from_vols(1,1).Cell_Volume;
                disp(from_cell_volume);
                disp(to_cell_volume);
                if ((to_cell_volume>0.8*from_cell_volume)&(to_cell_volume<1.2*from_cell_volume))
                    %disp(from);
                    %disp(to);
                
                    %disp('removing');
                    %bad_matches = bad_matches(bad_matches~=from);
                    %to_bad_matches = to_bad_matches(to_bad_matches~=to);
                else
                    disp('adding')
                    bad_matches = [bad_matches, from];
                    to_bad_matches = [to_bad_matches, to];
                end
            end
%         else
%             disp('adding')
%                 bad_matches = [bad_matches, from];
%                 to_bad_matches = [to_bad_matches, to];
        end
%         else
%             if (size(from_vols,1)>0)
%                 disp('adding from')
%                 bad_matches = [bad_matches, from];
%             end
%             if (size(to_vols,1)>0)
%                 disp('adding to')
%                 to_bad_matches = [to_bad_matches, to];
%             end
%             
    end
    disp(bad_matches);
    disp(to_bad_matches);
    for i=1:size(nn_orig,1)
        to = nn_orig(i,1);
        from = i;
        disp(from);
        disp(to);
        [k,to_volume] = convhull(alpha_shape_for_each_label1{to,:}.Points);
        [k,from_volume] = convhull(alpha_shape_for_each_label2{from,:}.Points);
        to_vols = cm(strcmp(cm.stack,'stack_1') & (cm.Nuclear_Label == to) & (cm.Time == time_index_index),'Cell_Volume');
        
        from_vols = cm(strcmp(cm.stack,'stack_1') & (cm.Nuclear_Label == from) & (cm.Time == time_index_index+1),'Cell_Volume');
        %disp(from);
        %disp(to);
        %disp(from_cell_volume);
        %disp(to_cell_volume);
        flag = true;
        for lvd=1:size(dup,1)
            if to == dup(lvd).val;
                flag = false;
            end
        end
        if (size(to_vols,1)>0)&(size(from_vols,1)>0)
            to_cell_volume = to_vols(1,1).Cell_Volume;
            from_cell_volume = from_vols(1,1).Cell_Volume;
            
            disp(from_cell_volume);
            disp(to_cell_volume);
            nuclear_flag = (from_volume>2/3*to_volume);
            if ((to_cell_volume>0.8*from_cell_volume)& (to_cell_volume<1.2*from_cell_volume)&nuclear_flag)% & flag)
                %disp(from);
                %disp(to);
            
                disp('removing');
                bad_matches = bad_matches(bad_matches~=from);
                to_bad_matches = to_bad_matches(to_bad_matches~=to);
                disp(bad_matches);
                disp(to_bad_matches);
            end
        end
    end
    for (j=cell_labels_I_care_about1)
        if (~ismember(j, nn_orig(:,1)))
            disp('adding back');
            disp(j);
            to_bad_matches = [to_bad_matches, j];
        end
    end
%     disp(bad_matches);
%     disp(to_bad_matches);

%     dup=find_duplicates(nn_three(:,1));
%     for lvd=1:size(dup,1)
%         from = dup(lvd).ind;
%         to = dup(lvd).val;
%         [k,to_volume] = convhull(alpha_shape_for_each_label1{to,:}.Points);
%         disp(to_volume);
%         daughter_flag = true;
%         for i=1:length(from)
%             disp(from(i));
% 
%             disp(to);
%             [k,fv] = convhull(alpha_shape_for_each_label2{from(i),:}.Points);
%             disp(fv);
%             if fv>0.6*to_volume
%                 daughter_flag = false;
%             end
%         end
%         if (daughter_flag) |(size(dup,1)>2)
%             to_bad_matches = [to_bad_matches,to];
%             for j=1:length(from)
%                 bad_matches = [bad_matches,from(j)];
%             end
%         end
%     end
    disp(bad_matches)
    disp(to_bad_matches)

    bad_matches = unique(bad_matches);
    to_bad_matches = unique(to_bad_matches);
    disp('bad matches');
    disp(bad_matches);
    disp('to bad matches');
    disp(to_bad_matches);
    center1 = center_point_for_each_label1(to_bad_matches,:);
    center2 = center_point_for_each_label2(bad_matches,:);
    disp(center1);
    disp(size(center2));
    
    if (size(center1,1)>0)
        [nn_three nd]=kNearestNeighbors(center1, center2,min(3,size(center1,1)));%length(center2)));
    
        disp(nn_three);
        %minimal distance between mother and daughters
        dist_thres = 0;
        %maximal distance between mother and daughters' centroid
        dist_cent_thres = 100;
        
        alpha1 = alpha_shape_for_each_label1(to_bad_matches,:);
        alpha2 = alpha_shape_for_each_label2(bad_matches,:);
        if length(nn_three(:,1))~=length(unique(nn_three(:,1))) % Reject duplicate nearest neighbors
            dup=find_duplicates(nn_three(:,1));
            disp(dup);
            for lvd=1:size(dup,1)
                %flag indicates divisions
                flag = 0;
                from = dup(lvd).ind;
                to = dup(lvd).val;
                disp(from);
                disp(to);
                to_cell = center1(to,:);
                disp(alpha1(to,:));
                %[k,to_volume] = convhull(alpha1{to,:}.Points);
                to_vols = cm(strcmp(cm.stack,'stack_1') & (cm.Nuclear_Label == to_bad_matches(to)) & (cm.Time == time_index_index),'Cell_Volume');
                to_cell_volume = to_vols(1,1).Cell_Volume;
                
                disp(to_volume);
                daughter_flag = true;
                from_vols = cm(strcmp(cm.stack,'stack_1') & (logical(sum(cm.Nuclear_Label == (bad_matches(from)),2))) & (cm.Time == time_index_index+1),'Cell_Volume');
                rat = sum(unique(from_vols.Cell_Volume))/to_cell_volume;
                disp(from_vols);
                disp(to_cell_volume);
                disp(rat);
                if ((rat<0.8) | (rat>1.2))
                    daughter_flag = false;
                end
%                 for i=1:length(from)
%                     %disp(i);
%     
%                     %disp(to);
%                     [k,fv] = convhull(alpha2{from(i),:}.Points);
%                     
%                     (fv);
%                     if fv>2/3*to_volume
%                         daughter_flag = false;
%                         disp('One of the daughters is too large');
%                     end
%                 end
                if (dup(lvd).length==2) & daughter_flag
                    %check if 2 matches are likely to be daughters
                    from_cell_1 = center2(from(1),:);
                    from_cell_2 = center2(from(2),:);
                    dist_1 = vecnorm(from_cell_1-to_cell);
                    dist_2 = vecnorm(from_cell_2-to_cell);
                    center = (from_cell_1+from_cell_2)/2;
                    dist_cent = vecnorm(center-to_cell);
                    if ((dist_1>dist_thres)&(dist_2>dist_thres)&(dist_cent<dist_cent_thres))
                        flag = 1;
                        disp('found a pair');
                        disp(dist_1);
                        disp(dist_2);
                        disp(to_cell);
                        disp(from_cell_2);
                        disp(center);
    
                    end
                end
                %if not daughters resolve conflicts using second nearest
                %neighbors
                if (flag == 0) & (size(nn_three,2)>1)
                    disp('Flag is zero');
                    disp(from);
                    disp(nn_three(from,2));
                    [ic,ia,ib]=intersect(nn_three(from,2),setdiff(1:size(nn_three,1),nn_three(:,1)));
                    %disp(ic);s
                    %disp(ia);
                    %disp(ib);
                    if ~isempty(ia)
                        nn_three(from(ia),1)=nn_three(from(ia),2);
                        nd(from(ia),1)=nd(from(ia),2);
                        loi=from(setdiff(1:size(from,1),ia)); % treat triple and more entries
                        if length(loi)>1
                            [mv,mi]=min(nd(loi,1));
                            loi1=setdiff(1:length(loi),mi);
                            nn_three(loi(loi1),1)=NaN;
                        end
                    else
                        [mv mi]=min(sum(nd(from,1),2));
                        loi=setdiff(from,from(mi));
                        nn_three(loi,1)=NaN;
                    end
                else
                    if (flag == 0) & (size(nn_three,2)>0)
                        [mv mi]=min(sum(nd(from,1),2));
                        loi=setdiff(from,from(mi));
                        nn_three(loi,1)=NaN;
                    end
                end
            end
        end
    else
        nn_three = NaN*zeros(length(bad_matches),1);
    end
    nn=nn_orig(:,1);
    disp(nn);
    good_inds = nn_three(~isnan(nn_three(:,1)),1);
    nn(bad_matches(~isnan(nn_three(:,1))),1) = to_bad_matches(good_inds);
    nn(bad_matches(isnan(nn_three(:,1))),1) = NaN;
    disp(nn);
    %nn = nn_three(:,1);
    nd=nd(:,1);
    
    sample_graph = graph;
    for iind = 1:length(cell_labels_I_care_about1)
        this_label = cell_labels_I_care_about1(iind);
        
        
        % store node props table... so that node can be added with volume
        NodePropsTable = table({[num2str(time_index,'%05.3d'),'_', num2str(this_label,'%05.3d')]}, center_point_for_each_label1(iind, 1), center_point_for_each_label1(iind, 2), center_point_for_each_label1(iind, 3), ...
            'VariableNames',{'Name' 'xpos' 'ypos' 'zpos'});
        
        sample_graph = addnode(sample_graph, NodePropsTable);
        
    end
    
    for iind = 1:length(cell_labels_I_care_about2)
        this_label = cell_labels_I_care_about2(iind);
        
        
        % store node props table... so that node can be added with volume
        NodePropsTable = table({[num2str(time_index_plus_1,'%05.3d'),'_', num2str(this_label,'%05.3d')]}, center_point_for_each_label2(iind, 1), center_point_for_each_label2(iind, 2), center_point_for_each_label2(iind, 3), ...
            'VariableNames',{'Name' 'xpos' 'ypos' 'zpos'});
        
        sample_graph = addnode(sample_graph, NodePropsTable);
        
    end
    
    for point_index = 1:length(nn)
        
        if (~isnan(nn(point_index)))
            % make directed edges (in time) between matches + store iou for the match as a graph weight
            sample_graph = addedge(sample_graph, [num2str(time_index,'%05.3d'),'_', num2str(cell_labels_I_care_about1(nn(point_index)),'%05.3d')],...
                [num2str(time_index_plus_1,'%05.3d'),'_', num2str(cell_labels_I_care_about2(point_index),'%05.3d')]);
        end
        if (~isnan(nn(point_index)))
            
            % make directed edges (in time) between matches + store iou for the match as a graph weight
            G_based_on_nn = addedge(G_based_on_nn, [num2str(time_index,'%05.3d'),'_', num2str(cell_labels_I_care_about1(nn(point_index)),'%05.3d')],...
                [num2str(time_index_plus_1,'%05.3d'),'_', num2str(cell_labels_I_care_about2(point_index),'%05.3d')]);
            dist = vecnorm(center_point_for_each_label1(nn(point_index)) - center_point_for_each_label2(point_index));
            %disp(dist);
            %if (dist>5)
            %    disp('Large distance detected')
            %    %search for another neighbor
            %end 
        end
        
    end
    % visualization for checking if everything is correct
    hold all; plot(sample_graph, 'XData', sample_graph.Nodes.xpos, 'YData', sample_graph.Nodes.ypos, 'ZData', sample_graph.Nodes.zpos, 'EdgeColor', 'k', 'LineWidth', 2.0);

    figure; 
    h1 = plot(sample_graph, 'XData', sample_graph.Nodes.xpos, 'YData', sample_graph.Nodes.ypos, 'ZData', sample_graph.Nodes.zpos, 'EdgeColor', 'k', 'LineWidth', 2.0,'NodeLabel',sample_graph.Nodes.Name);
    disp(time_index);


        
    % loop through all matches
    % LB: M is nMatches x 2 (label at time t, label at time t+1) 

    % DISPLAY CURRENT TIME INDEX (just to make sure that calculation is not stalled).
    figure;
    plot(G_based_on_nn, 'Layout', 'layered');    

    for i = 1:length(M)
        find_non_zero_please = find(iou_matrix(M(i,1),:));
        if (length(find_non_zero_please) > 1)  % more than one iou match
            figure; hold all; cpd_plot_iter(ptCloud1, Transform.Y);
            hold all; plot(alpha_shape_for_each_label1{M(i,1),1},'FaceColor','red','FaceAlpha',0.5);
            for j = 1:length(find_non_zero_please)
                if (find_non_zero_please(j) == M(i,2)) % this is the best match?
                    hold all; plot(alpha_shape_for_each_label2{M(i,2),1},'FaceColor','green','FaceAlpha',0.5);
                else
                    hold all; plot(alpha_shape_for_each_label2{find_non_zero_please(j),1},'FaceColor','black','FaceAlpha',0.5);
                end
                
            end
            
            title([num2str(corresponding_ious_for_matches(i)),';',num2str(i)]);
            
        end
    end
    

    %openvar('G_based_on_nn.Edges')
    %save('graph.mat','G_based_on_nn');
    disp('time index');
    disp(time_index);
    %pause;
    %close all;
end

% Save vector of transformations...
save('transform_labels_pCloud.mat', 'store_registration');
save('matches.mat','store_matches');
save('iou_table.mat','store_iou_table');
save('graph.mat','G_based_on_nn');


end

