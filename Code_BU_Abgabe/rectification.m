function [img_L_r,img_R_r,...
          TL,TR,R_rect,offset_x,...
          img_L_r_full,...
          img_R_r_full,...
          d_cut_up_L,d_cut_down_L,...
          d_cut_up_R,d_cut_down_R,min_y_full,max_y_full] = rectification (img1, img2,K,T,R)
% This function rectifies the gray images img1 and img2. The parameters,
% which must be given are EF (essential or fundamental matrix) and if EF is
% the essential matrix a camera calibratrion matrix K. Furthermore the
% correspondence_points must be given.
% Euclidean Movement is defined from Image1 to Image2

% http://www.sci.utah.edu/~gerig/CS6320-S2013/Materials/CS6320-CV-F2012-Rectification.pdf
% A compact algorithm for rectification of stereo pairs
% Andrea Fusiello1, Emanuele Trucco2, Alessandro Verri3
% http://people.scs.carleton.ca/~c_shu/Courses/comp4900d/notes/rectification.pdf


%% Rectification Algorithum (von Paper Fusiello)
Po1 = K*[1 0 0 0; 0 1 0 0; 0 0 1 0];
Po2 = K*[R, T];
[TL, TR,R_rect] = rectify_fusiello(Po1,Po2,K);

% Schnittpunkt optische Achse mit Bildebene entspricht Bildmitte
% Linkes und rechtes Bild sind gleich groÃŸ.
[row, col] = size(img1);
center_row = round(row/2);
center_col = round(col/2);

% Berechnung & Drehung der Bildmitte, so dass Bildebenen parallel zu
% Translationsvektor liegen
center = [center_col; center_row; 1];
center_L_r = TL*center;
center_R_r = TR*center;

% Vertikaler Versatz der begradigten Bilder (Y-Achse) soll nun gleich
% sein, bzw. Bilder sollen vertikal auf gleicher HÃ¶he liegen.
dL(2) = center(2) - center_L_r(2)/center_L_r(3);
dR(2) = center(2) - center_R_r(2)/center_R_r(3);
% Bildausschnitt in x-Richtung wird spÃ¤ter passend gewÃ¤hlt.
dL(1) = 0;
dR(1) = 0;
% Homographien erneut mit angepasster Kalibrierung berechnen.
[TL, TR,~] = rectify_fusiello(Po1,Po2,K,R_rect,dL,dR);

TL_inv = inv(TL);
TR_inv = inv(TR);


% Zur Interpolation werden die Bildaussschnitte zuerst in das neue
% Koordinatensystem und daraufhin zurÃ¼cktransformiert. HierfÃ¼r mÃ¼ssen
% die Bildecken bekannt sein.
% Linkes und rechtes Bild sind gleich groÃŸ.
[size_y, size_x] = size(img1);
corners_L_r = TL*[0, size_x,size_x, 0;
    size_y, size_y, 0, 0;
    ones(1,4)]; % Bildecken in rotierten Pixelkoordinaten
corners_L_r = corners_L_r./corners_L_r(3,:);% Normalisierung der z-Komponente auf eins.

corners_R_r = TR*[0, size_x,size_x,0;
    size_y, size_y,0,0;
    ones(1,4)];
corners_R_r = corners_R_r./corners_R_r(3,:);% Normalisierung der z-Komponente auf eins.

%% Der Bildausschnitt, der nun beide Bilder enthÃ¤lt, wird nun ermittelt

    % ZusammenfÃ¼gen der corners (corners_L_r und corners_R_r) und
    % darauffolgendes sortieren der x- und y-Werte nach aufsteigender
    % Reihenfolge. Die grÃ¶ÃŸte links/oben liegende x-/y-Koordinate befindet
    % sich dann bei rechteckigen Bildern an Position 4. Die kleinste
    % rechts/unten liegenden x-/y-Koordinate befindet sich dann an Position
    % 5 der sortierten Koordinaten. 
    corners_L_x_sorted = sort(corners_L_r(1,:));
    corners_R_x_sorted = sort(corners_R_r(1,:));
    corners_LR_y_sorted = sort([corners_L_r(2,:), corners_R_r(2,:)]);
    
    % Bestimme Grenzen so, dass keine schwarzen RÃ¤nder entstehen.
    % Dadurch wird der Versatz zwischen beiden Bildern reduziert. Speichere
    % diese Differenz in der Variable offset_x, um spÃ¤ter die DisparitÃ¤t
    % richtig zu berechnen.
    % Ansicht fÃ¼r depth_map
    offset_x = ceil(corners_L_x_sorted(2))-ceil(corners_R_x_sorted(2));
    max_L_xy(1) = floor(corners_L_x_sorted(3));
    min_L_xy(1) = ceil(corners_L_x_sorted(2));
    max_R_xy(1) = floor(corners_R_x_sorted(3));
    min_R_xy(1) = ceil(corners_R_x_sorted(2));
    max_L_xy(2) = floor(corners_LR_y_sorted(5));
    min_L_xy(2) = ceil(corners_LR_y_sorted(4));
    max_R_xy(2) = floor(corners_LR_y_sorted(5));
    min_R_xy(2) = ceil(corners_LR_y_sorted(4));
    
    % Bestimme weiteren Ausschnitt, der das gesamte rektifizierte Bild
    % zeigt (ohne in y-Richtung etwas abzuschneiden). Dabei sollen beide
    % Bilder vollständig beinhaltet sein.
    % Ansicht fuer Derektifizierung
    
    min_y_full = min(ceil(min(corners_L_r(2,:))),ceil(min(corners_R_r(2,:))));
    max_y_full = max(floor(max(corners_L_r(2,:))),floor(max(corners_R_r(2,:))));
    
    min_L_xy_full = min_L_xy;
    max_L_xy_full = max_L_xy;
    min_L_xy_full(2) = min_y_full;%ceil(min(corners_L_r(2,:)));%
    max_L_xy_full(2) = max_y_full;%floor(max(corners_L_r(2,:)));%
    min_R_xy_full = min_R_xy;
    max_R_xy_full = max_R_xy;
    min_R_xy_full(2) = min_y_full;%ceil(min(corners_R_r(2,:)));%
    max_R_xy_full(2) = max_y_full;%floor(max(corners_R_r(2,:)));%
    
   
    % Gebe jeweils fÃ¼r oben und unten den Abstand zurÃ¼ck, um den die
    % Ansicht fÃ¼r die Derektifizierung grÃ¶ÃŸer ist, als die Ansicht fÃ¼r die
    % Depth Map
    d_cut_up_L = max_L_xy_full(2)-max_L_xy(2);
    d_cut_down_L = min_L_xy(2)-min_L_xy_full(2);
    d_cut_up_R = max_R_xy_full(2)-max_R_xy(2);
    d_cut_down_R = min_R_xy(2)-min_R_xy_full(2);

%% Meshgrid
% Um interpolieren zu kÃ¶nnen wird ein meshgrid benÃ¶tigt, das
% zurÃ¼cktransformiert werden kann
% Ansicht fÃ¼r depth_map
[meshX_L_r,meshY_L_r] = meshgrid(min_L_xy(1):max_L_xy(1),...
    min_L_xy(2):max_L_xy(2));
meshZ_L_r = ones(size(meshX_L_r));
[meshX_R_r,meshY_R_r] = meshgrid(min_R_xy(1):max_R_xy(1),...
    min_R_xy(2):max_R_xy(2));
meshZ_R_r = ones(size(meshX_R_r));

% Ansicht fuer Derektifizierung
[meshX_L_r_full,meshY_L_r_full] = meshgrid(min_L_xy_full(1):max_L_xy_full(1),...
    min_L_xy_full(2):max_L_xy_full(2));
meshZ_L_r_full = ones(size(meshX_L_r_full));
[meshX_R_r_full,meshY_R_r_full] = meshgrid(min_R_xy_full(1):max_R_xy_full(1),...
    min_R_xy_full(2):max_R_xy_full(2));
meshZ_R_r_full = ones(size(meshX_R_r_full));

%% RÃ¼cktransformation der Meshgrids zur Interpolation
% Ansichten fÃ¼r depth map
meshZ_L_dr = TL_inv(3,1)*meshX_L_r + TL_inv(3,2)*meshY_L_r ...
    + TL_inv(3,3)*meshZ_L_r;
meshX_L_dr = (TL_inv(1,1)*meshX_L_r + TL_inv(1,2)*meshY_L_r...
    + TL_inv(1,3)*meshZ_L_r)./meshZ_L_dr;
meshY_L_dr = (TL_inv(2,1)*meshX_L_r + TL_inv(2,2)*meshY_L_r...
    + TL_inv(2,3)*meshZ_L_r)./meshZ_L_dr;

meshZ_R_dr = TR_inv(3,1)*meshX_R_r + TR_inv(3,2)*meshY_R_r...
    + TR_inv(3,3)*meshZ_R_r;
meshX_R_dr = (TR_inv(1,1)*meshX_R_r + TR_inv(1,2)*meshY_R_r...
    + TR_inv(1,3)*meshZ_R_r)./meshZ_R_dr;
meshY_R_dr = (TR_inv(2,1)*meshX_R_r + TR_inv(2,2)*meshY_R_r...
    + TR_inv(2,3)*meshZ_R_r)./meshZ_R_dr;

% Ansicht fuer Derektifizierung
meshZ_L_dr_full = TL_inv(3,1)*meshX_L_r_full + TL_inv(3,2)*meshY_L_r_full ...
    + TL_inv(3,3)*meshZ_L_r_full;
meshX_L_dr_full = (TL_inv(1,1)*meshX_L_r_full + TL_inv(1,2)*meshY_L_r_full...
    + TL_inv(1,3)*meshZ_L_r_full)./meshZ_L_dr_full;
meshY_L_dr_full = (TL_inv(2,1)*meshX_L_r_full + TL_inv(2,2)*meshY_L_r_full...
    + TL_inv(2,3)*meshZ_L_r_full)./meshZ_L_dr_full;

meshZ_R_dr_full = TR_inv(3,1)*meshX_R_r_full + TR_inv(3,2)*meshY_R_r_full ...
    + TR_inv(3,3)*meshZ_R_r_full;
meshX_R_dr_full = (TR_inv(1,1)*meshX_R_r_full + TR_inv(1,2)*meshY_R_r_full...
    + TR_inv(1,3)*meshZ_R_r_full)./meshZ_R_dr_full;
meshY_R_dr_full = (TR_inv(2,1)*meshX_R_r_full + TR_inv(2,2)*meshY_R_r_full...
    + TR_inv(2,3)*meshZ_R_r_full)./meshZ_R_dr_full;

%% Interpolation
% Meshgrid / StÃ¼tzstellen an denen Werte bekannt sind
[meshX, meshY] = meshgrid(1:size_x,1:size_y);
% Bestimmte unbekannte Werte and den Stellen meshX_L_dr bzw. meshY_L_dr
% durch Interpolation
img_L_r = uint8(interp2(meshX,meshY,double(img1),...
    meshX_L_dr,meshY_L_dr,'linear',NaN));
img_R_r = uint8(interp2(meshX,meshY,double(img2),...
    meshX_R_dr,meshY_R_dr,'linear',NaN));
img_L_r_full = uint8(interp2(meshX,meshY,double(img1),...
    meshX_L_dr_full,meshY_L_dr_full,'linear',NaN));
img_R_r_full = uint8(interp2(meshX,meshY,double(img2),...
    meshX_R_dr_full,meshY_R_dr_full,'linear',NaN));

if(false)
    figure
    subplot(1,2,1)
    imshow(uint8(img_L_r));
    subplot(1,2,2)
    imshow(uint8(img_R_r));
    
    figure
    im1 = imshow(uint8(img_L_r));hold all;
    im2 = imshow(uint8(img_R_r));
    im1.AlphaData = 0.5;
    im2.AlphaData = 0.5;
end

end
