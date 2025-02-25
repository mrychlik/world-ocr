%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% This script preloads/computes the lines of text
%%%
%%% This file is a preamble to other files, which perform real processing
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Where to put objects found in pages
file=fullfile('.','images', 'sinat-074.png');
% Where to find pages of scanned text
imagedir=fullfile('.','images');
diacritical_marks='on';


%% Build a cache of objects in the image
% Strings identifying page numbers in image files
% Where to save objects
savefile=fullfile('.','Cache','ara_sinat_objects.mat');
if exist(savefile,'file') 
    load(savefile)
else 
    I=imread(file);                         % Note: the image is BW
    I=imrotate(I,.4);
    I=imcrop(I,[60,40,size(I,2)-180,size(I,1)-100]);
    BW=im2bw(I,.7);
    BW=~BW;
    [objects,lines]=bounding_boxes(BW,...
                                   'Display','off',...
                                   'DiacriticalMarks','off',...
                                   'Method','kmeans');
    save(savefile,'objects','lines')
end

get_image=@(obj)uint8(255.*obj.bwimage);
is_diacritical=@(ob)ob.FilledArea<600;

visualize_text(objects,lines,'TextDirection','RightToLeft',...
               'GetImageFunction',get_image, ...
               'IsDiacriticalFunction',is_diacritical,...
               'Display',false);