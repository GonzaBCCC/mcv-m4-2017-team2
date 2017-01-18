function [AUC,precision,recall,F1]= task2(connectivity, show_video, write_video)


addpath('../utils');
%datapath = 'st_gm_sequences/';

%show_video = 0; write_video = 0;

videoname = {'fall','highway','traffic'}; 
%connectivity = 4;
tic;

for v=1:size(videoname,2)
    sequence=[];
    seq_opened =[];

%     % Compute detection with Stauffer and Grimson:
    filename = strcat('st_gm_filled_area_', int2str(connectivity), '_', videoname{v});
% 
%     [start_img, range_images, dirInputs, dirGT] = load_data(videoname{v});
% 
%     t = start_img; 
%     for i=1:range_images
%         sequence(:,:,i)= imread(strcat(datapath,videoname{v},'/','res_',sprintf('%06d', t),'.png'));
%         t=t+1;
%     end
    [start_img, range_images, dirInputs] = load_data(videoname{v});
    input_files = list_files(dirInputs);

    if strcmp(videoname{v}, 'highway')
        % Best results: Alpha = 2.75, Rho = 0.2, F1 = 0.72946
        alpha_val = 2.75;
        rho_val = 0.2;
        dirGT = strcat('../datasets/cdvd/dataset/baseline/highway/groundtruth/');
    else
        if strcmp(videoname{v}, 'fall')
            % Best results: Alpha = 3.25, Rho = 0.05, F1 = 0.70262
            alpha_val = 3.25;
            rho_val = 0.05;
            dirGT = strcat('../datasets/cdvd/dataset/dynamicBackground/fall/groundtruth/');
        else
            % Best results: Alpha = 3.25, Rho = 0.15, F1 = 0.66755
            alpha_val = 3.25;
            rho_val = 0.15; 
            dirGT = strcat('../datasets/cdvd/dataset/cameraJitter/traffic/groundtruth/');
        end
    end

    background = 50;
    foreground = 255;

    % Either perform an exhaustive grid search to find the best alpha and rho,
    % or just use the adaptive model if they are already computed.
    [mu_matrix, sigma_matrix] = train_background(start_img, range_images, input_files, dirInputs);
  
    sequence = single_alpha_adaptive(alpha_val, rho_val, mu_matrix, sigma_matrix, range_images, start_img, dirInputs, input_files, background, foreground, dirGT, false);
    
    sequence = fill_holes(double(sequence), connectivity);

    pace=50;

    for p=0:pace:1000
        p_index = 1 + (p/pace);
        P_number(p_index)= p;
        for i=1:size(sequence,3)
            seq_opened(:,:,i) = bwareaopen(sequence(:,:,i),p);
        end
        [precision(v,p_index), recall(v,p_index), F1(v,p_index), AUC(v,p_index)] = ...
            test_sequence_2val(seq_opened, videoname{v}, show_video, write_video, ...
            filename, false,range_images);
    end

end
toc

indexmaxfall = find(max(AUC(1,:))==AUC(1,:));
indexmaxhigh = find(max(AUC(2,:))==AUC(2,:));
indexmaxtraf = find(max(AUC(3,:))==AUC(3,:));

AUCmax_fall = AUC(1,indexmaxfall);
AUCmax_high = AUC(2,indexmaxhigh);
AUCmax_traf = AUC(3,indexmaxtraf);

label_1 = strcat({'Fall max AUC = '},num2str(AUCmax_fall));
label_2 = strcat({'Highway max AUC = '},num2str(AUCmax_high));
label_3 = strcat({'Traffic max AUC = '},num2str(AUCmax_traf));

p_str_fall = strcat({'P = '},num2str(P_number(indexmaxfall)));
p_str_high = strcat({'P = '},num2str(P_number(indexmaxhigh)));
p_str_traf = strcat({'P = '},num2str(P_number(indexmaxtraf)));

figure(1)
plot(P_number, AUC(1,:),'g',P_number, AUC(2,:),'b', P_number, AUC(3,:),'r'); 
legend([label_1, label_2, label_3]);
title('AUC vs Pixels');
xlabel('Pixels');
ylabel('AUC');

text(P_number(indexmaxfall),0.82,p_str_fall,'HorizontalAlignment','left');
text(P_number(indexmaxhigh),0.87,p_str_high,'HorizontalAlignment','left');
text(P_number(indexmaxtraf),0.59,p_str_traf,'HorizontalAlignment','left');

hold on;
plot(P_number(indexmaxfall), AUC(1,indexmaxfall), 'o', P_number(indexmaxhigh), AUC(2,indexmaxhigh), 'o', P_number(indexmaxtraf), AUC(3,indexmaxtraf), 'o');

end

function [detection] = single_alpha_adaptive(alpha_val, rho_val, mu_matrix, sigma_matrix, range_images, start_img, dirInputs, input_files, background, foreground, dirGT, create_animated_gif)

     for i=1:(round(range_images/2)+1)
        
        % read frame and ground truth
        index = i + (start_img + range_images/2) - 1;
        file_number = input_files(index).name(3:8);
        frame = double(rgb2gray(imread(strcat(dirInputs,'in',file_number,'.jpg'))));
        gt = imread(strcat(dirGT,'gt',file_number,'.png'));
        gt_back = gt <= background;
        gt_fore = gt >= foreground;

        % compute detection using model
        detection(:,:,i) = abs(frame - mu_matrix) >= alpha_val.*(sigma_matrix+2);
        
        % adapt model using pixels belonging to the background
        % [mu_matrix, sigma_matrix] = adaptModel(mu_matrix, sigma_matrix, rho_val, detection, frame);
        [mu_matrix, sigma_matrix] = adaptModel(frame, detection(:,:,i), mu_matrix, sigma_matrix, rho_val);
    
    end

end


function [mean_matrix,variance_matrix] = adaptModel(frame, detection, mean_matrix, variance_matrix, rho)
    % background pixels: ~detection
    mean_matrix(~logical(detection))=rho*frame(~logical(detection)) + (1-rho)*mean_matrix(~logical(detection));
    variance_matrix(~logical(detection))=sqrt(rho*(frame(~logical(detection))-mean_matrix(~logical(detection))).^2 + (1-rho)*variance_matrix(~logical(detection)).^2);
end