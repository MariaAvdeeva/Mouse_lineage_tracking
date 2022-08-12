
% for sequence of label images
% using sequence of registration transforms
% put all label images in same reference frame

function [] = VisualizeSequence(  )

firstTime = 1;
lastTime =  3;

data_path = './test/tif/';
name_of_embryo =  'klbOut_Cam_Long_';
name_of_embryo = strcat(data_path,name_of_embryo);
suffix_for_embryo = '.lux.label.tif';
suffix_for_embryo_alternative = '.lux_SegmentationCorrected.tif';

addpath(genpath('../CPD2/core'));
addpath(genpath('../CPD2/data'));

time_str = strcat(string(firstTime),'_',string(lastTime));
RegistrationFileName = strcat(data_path,'transforms', time_str,'.mat');
transforms = load(RegistrationFileName);

hold on;
for i=firstTime:lastTime
    s(i) = transforms.store_registration{i,1}.minSigma;
    t(i) = transforms.store_registration{i,1};
end
plot(firstTime:lastTime,s(firstTime:lastTime),'LineWidth',4,'Color','b');

xlabel('Frame');
ylabel('Registration Sigma ');
%title(data_path);

bMakeVideo = true;
%figure; % use this to look at pairs
if bMakeVideo
    % create the video writer with 1 fps
    writerObj = VideoWriter(strcat(data_path,'RegisteredPoints',time_str,'.avi'));
    writerObj.FrameRate = 2;
    % set the seconds per image
    % open the video writer
    open(writerObj);
end

G_based_on_nn = graph;

% Voxel size before making isotropic
pixel_size_xy_um = 0.208; % um
pixel_size_z_um = 2.0; % um
% Voxel size after making isotropic
xyz_res = 0.8320;
% Volume of isotropic voxel
voxel_vol = xyz_res^3;

% Initialize empty graph and cell array for storing registration
% Which image indices to run over...
which_number_vect = 1:lastTime;
valid_time_indices = which_number_vect;

figure;
xlim([-60,80]);
ylim([-60,80]);
zlim([-60,80]);
for time_index_index = firstTime:lastTime-1
     
    % store this time index
    time_index = valid_time_indices(time_index_index);
    
    % store next in series
    time_index_plus_1 = valid_time_indices(time_index_index+1);
    
    % store combined image for both.
    combined_image1 = read_embryo_frame(name_of_embryo, ...
            suffix_for_embryo_alternative, ...
            suffix_for_embryo, ...
            time_index);
    
    combined_image2 = read_embryo_frame(name_of_embryo, ...
            suffix_for_embryo_alternative, ...
            suffix_for_embryo, ...
            time_index_plus_1);
    
    % STORE MESHGRID
    [X, Y, Z] = meshgrid(1:size(combined_image1, 2), 1:size(combined_image1, 1), 1:size(combined_image1, 3));
    
    % FRACTION OF POINTS (DOWNSAMPLING)
    fraction_of_selected_points =  1/10;  % slow to run at full scale - but make full res points and xform?
    find1 = find(combined_image1(:)~=0); 
    number_of_points = length(find1);
        
    rng(1);
    p = randperm(number_of_points,round(number_of_points * fraction_of_selected_points));
    find1 = find1(p);
    
    meanX1 = transforms.store_registration{time_index,1}.Centroids1(1); 
    meanY1 = transforms.store_registration{time_index,1}.Centroids1(2); 
    meanZ1 = transforms.store_registration{time_index,1}.Centroids1(3);    
    ptCloud1 = [X(find1), Y(find1), Z(find1)] - [meanX1, meanY1, meanZ1];
   
    [X, Y, Z] = meshgrid(1:size(combined_image2, 2), 1:size(combined_image2, 1), 1:size(combined_image2, 3));

    find2 = find(combined_image2(:)~=0);
    number_of_points = length(find2);
    
    meanX2 = transforms.store_registration{time_index,1}.Centroids2(1); %mean(X(find2));
    meanY2 = transforms.store_registration{time_index,1}.Centroids2(2); %mean(Y(find2));
    meanZ2 = transforms.store_registration{time_index,1}.Centroids2(3); %mean(Z(find2));
    
    p = randperm(number_of_points,round(number_of_points * fraction_of_selected_points));
    find2 = find2(p);
    
    ptCloud2 = [X(find2), Y(find2), Z(find2)] - [meanX2, meanY2, meanZ2];
    ptCloud2 = pointCloud(ptCloud2);
    
    Y = ptCloud2.Location;
    X = ptCloud1;
    [M, D] = size(X);
    
    % perform the transformation iteratively (x1 -> x2 -> ... -> xn)
    if time_index_index == lastTime
        newX = X;
    else
        newX = X;
        for iFrame = time_index_index: lastTime -1 % last frame stays the same
            ThisTransform = t(iFrame);
            this_rotation = ThisTransform.Rotation;
            this_translation = ThisTransform.Translation(1,:);
            newX = newX*this_rotation + this_translation;  %%%%%%%% for pairs not newX
        end
    end
    % for no registration
    %newX = X;
    
    none = [];
    figure;
    hold all;
    title_str = strcat ( string(time_index_index), '.jpg');
    title(title_str); 
    xlim([-60,80]);
    ylim([-60,80]);
    zlim([-60,80]);
    view(45,45);

    bPairs = false;
    if bPairs  % video of each pair
        if (time_index_index == lastTime)
            cpd_plot_iter(X,X);
        else
            cpd_plot_iter(newX,ptCloud2.Location);
        end
    else
        labels = unique(combined_image1);
        nNuclei = size(labels,1) - 1;
        for ilabel=1:nNuclei
            ilabel = labels(ilabel);
            if (ilabel ~= 0)
                ind = find(newX == ilabel);
            end
        end
        % get cdx2 val
        % ind = find(combined_image1
        % this is to just plot one at a time per image for making the video
        if (mod(time_index_index,2) == 0) & (time_index_index <1000)
            plot3(newX(:,1),newX(:,2),newX(:,3),'b.');
        elseif (time_index_index < 10000)
            plot3(newX(:,1),newX(:,2),newX(:,3),'b.');  % set to red to look at pairs
        end
    end
    hold off
    F(time_index_index) = getframe(gcf) ;

    if (bMakeVideo)
        writeVideo(writerObj, F(time_index_index));
    end
    % close all;

end

close all;
% close the video writer object
close(writerObj);

end
