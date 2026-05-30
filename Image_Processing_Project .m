clc; clear; close all;
%% ── Section 1: Load Image ────────────────────────────────
IMAGE_PATH = '/MATLAB Drive/training/day/20151101_145511.jpg';  
 
img = imread(IMAGE_PATH);
img = double(img) / 255.0;
 
if size(img, 3) == 4
    img = img(:,:,1:3);
end
 
%% ── Section 2: RGB → Grayscale & HSV ────────────────────
R = img(:,:,1);
G = img(:,:,2);
B = img(:,:,3);
 
% Grayscale (BT.601)
gray = 0.299*R + 0.587*G + 0.114*B;
 
% HSV (manual)
Cmax  = max(max(R,G),B);
Cmin  = min(min(R,G),B);
delta = Cmax - Cmin;
delta = max(delta, 1e-6);
 
V = Cmax;
S = Cmax;
S(Cmax > 0) = delta(Cmax > 0) ./ Cmax(Cmax > 0);
S(Cmax == 0) = 0;
 
H = zeros(size(R));
H(Cmax==R) = mod(60*((G(Cmax==R)-B(Cmax==R))./delta(Cmax==R)), 360);
H(Cmax==G) = mod(60*((B(Cmax==G)-R(Cmax==G))./delta(Cmax==G))+120, 360);
H(Cmax==B) = mod(60*((R(Cmax==B)-G(Cmax==B))./delta(Cmax==B))+240, 360);
 
% Show the 3 images side by side
figure('Name','Image Conversions');
subplot(1,3,1); imshow(img);           title('Original Image');
subplot(1,3,2); imshow(gray,[]);       title('Grayscale');
subplot(1,3,3); imshow(H/360,[]);      title('HSV - Hue Channel');
sgtitle('RGB \rightarrow Grayscale & HSV');
 
%% ── Section 3: Feature Extraction ───────────────────────
[H_sz, W_sz, ~] = size(img);
total = H_sz * W_sz;
 
% Global brightness
brightness     = sum(gray(:)) / total;
brightness_std = sqrt(sum((gray(:)-brightness).^2) / total);
 
% Sky region (top 25%)
sky_end        = floor(H_sz * 0.25);
sky_gray       = gray(1:sky_end, :);
sky_brightness = sum(sky_gray(:)) / (sky_end * W_sz);
 
sky_h = H(1:sky_end, :);
sky_s = S(1:sky_end, :);
sky_pixels = sky_end * W_sz;
 
sky_blue_ratio = sum((sky_h>=180 & sky_h<=260 & sky_s>0.15), 'all') / sky_pixels;
sky_warm_ratio = sum(((sky_h<=60 | sky_h>=300) & sky_s>0.2), 'all') / sky_pixels;
 
% Global hue ratios
warm_ratio       = sum(((H<=60 | H>=300) & S>0.15), 'all') / total;
blue_ratio       = sum((H>=160 & H<=260 & S>0.15), 'all') / total;
red_orange_ratio = sum((H<=30 & S>0.2), 'all') / total;
 
% Artificial light (lower half)
lower_gray = gray(floor(H_sz/2):end, :);
lower_S    = S(floor(H_sz/2):end, :);
artificial_light_ratio = sum((lower_gray>0.7 & lower_S<0.3), 'all') / numel(lower_gray);
 
% Dark / bright
dark_ratio        = sum(gray(:) < 0.15) / total;
high_bright_ratio = sum(gray(:) > 0.75) / total;
 
% Color temperature R/B
R_mean = sum(R(:)) / total;
B_mean = sum(B(:)) / total;
color_temp_ratio = R_mean / (B_mean + 1e-6);
 
%% ── Section 4: Day / Night Classification ────────────────
score = 0;
score = score + brightness       * 5;
score = score + sky_brightness   * 3;
score = score + sky_blue_ratio   * 4;
score = score + warm_ratio       * 2;
score = score - dark_ratio       * 6;
score = score - artificial_light_ratio * 4;
 
if score > 1.2
    label = 'Day';
else
    label = 'Night';
end
 
%% ── Section 5: Time Estimation ──────────────────────────
if strcmp(label, 'Night')
    period = 'Night';
 
elseif brightness > 0.6 && sky_blue_ratio > 0.1 && color_temp_ratio < 1.3
    period = 'Noon';
 
else
    eve = (brightness>0.25 && brightness<0.6) + ...
          (red_orange_ratio>0.07) + ...
          (sky_warm_ratio>0.1)    + ...
          (color_temp_ratio>1.25) + ...
          (warm_ratio>0.2);
 
    mor = (brightness>0.3 && brightness<0.65) + ...
          (color_temp_ratio>1.1) + ...
          (sky_blue_ratio>0.05)  + ...
          (sky_warm_ratio>0.05);
 
    if eve >= 3
        period = 'Evening';
    elseif mor >= 3
        period = 'Morning';
    elseif brightness > 0.5
        period = 'Noon';
    elseif color_temp_ratio > 1.2
        period = 'Morning';
    else
        period = 'Evening';
    end
end
 
%% ── Section 6: Print Report ──────────────────────────────
fprintf('========================================\n');
fprintf('  RESULT:  %s  (%s)\n', label, period);
fprintf('========================================\n');
fprintf('  %-28s %.4f\n', 'brightness',             brightness);
fprintf('  %-28s %.4f\n', 'brightness_std',          brightness_std);
fprintf('  %-28s %.4f\n', 'sky_brightness',          sky_brightness);
fprintf('  %-28s %.4f\n', 'sky_blue_ratio',          sky_blue_ratio);
fprintf('  %-28s %.4f\n', 'sky_warm_ratio',          sky_warm_ratio);
fprintf('  %-28s %.4f\n', 'warm_ratio',              warm_ratio);
fprintf('  %-28s %.4f\n', 'blue_ratio',              blue_ratio);
fprintf('  %-28s %.4f\n', 'red_orange_ratio',        red_orange_ratio);
fprintf('  %-28s %.4f\n', 'artificial_light_ratio',  artificial_light_ratio);
fprintf('  %-28s %.4f\n', 'dark_ratio',              dark_ratio);
fprintf('  %-28s %.4f\n', 'high_bright_ratio',       high_bright_ratio);
fprintf('  %-28s %.4f\n', 'color_temp_ratio',        color_temp_ratio);
fprintf('========================================\n\n');
 
%% ── Section 7: Visualization ─────────────────────────────
period_colors = containers.Map(...
    {'Morning','Noon','Evening','Night'}, ...
    {[0.957 0.635 0.380], [0.914 0.769 0.412], [0.906 0.435 0.318], [0.149 0.271 0.325]});
 
if isKey(period_colors, period)
    pc = period_colors(period);
else
    pc = [0.5 0.5 0.5];
end
 
figure('Name','Result','Position',[100 100 1000 420]);
 
% Left: image
subplot(1,2,1);
imshow(img);
title(sprintf('%s  (%s)', label, period), ...
      'FontSize',14,'FontWeight','bold','Color',pc);
 
% Right: feature bar chart
subplot(1,2,2);
feat_names = {'brightness','sky\_brightness','sky\_blue','sky\_warm',...
              'warm\_ratio','red\_orange','dark\_ratio','art\_light','color\_temp'};
feat_vals  = [brightness, sky_brightness, sky_blue_ratio, sky_warm_ratio, ...
              warm_ratio, red_orange_ratio, dark_ratio, ...
              artificial_light_ratio, min(color_temp_ratio/2, 1)];
 
barh(feat_vals, 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'YTick',1:9, 'YTickLabel', feat_names, 'XLim',[0 1]);
xlabel('Value (normalised)');
title('Extracted Features','FontSize',12,'FontWeight','bold');
grid on;
 
saveas(gcf, 'result.png');
fprintf('Result saved to result.png\n');