function U_topoplot(vector,  layout_file, chn_names, image_file, zlim, highlight_chns)

cfg = [];
if(nargin == 4)
    cfg.image = image_file;
end
if(nargin < 5)
    zlim = -1;
end
if(nargin < 6)
    highlight_chns = [];
end

% ===== Main ====
cfg.layout = layout_file;
cfg.style = 'both'; % both, straight, contour
cfg.marker  ='on';
cfg.markersymbol = '.';
cfg.markersize = 20;
cfg.comment = 'no';
cfg.colorbar = 'yes';
data.powspctrm = vector; % [N x 1]
data.label = chn_names; % {1 x N}
if(~isempty(highlight_chns))
    cfg.highlight= 'channel';
    cfg.highlightchannel = chn_names(highlight_chns);
    cfg.highlightsymbol='.';
    cfg.highlightsize = 30;
    cfg.highlightfontsize = 30;
    cfg.highlightcolor    = [164,47,50]/255;
    cfg.colormap = 'ice';
    
end

% chn_names = allchannels;
% nonsigchannels = setdiff([1:length(allchannels)], smallmarkerchannels);
% for i = 1:length(nonsigchannels)
%     chn_names{nonsigchannels(i)} = ' ';
% end

%if the layout_file is a structure (not a file), exclude the channels not included in layout_file
if(~isstr(cfg.layout))
    chn_includes=ones(1,length(data.label));
    for i=1:length(data.label)
        tmp=strfind(cfg.layout.label,data.label{i});
        data_found=0;
        for j=1:length(tmp)
            if(~isempty(tmp{j}))
                data_found=1;
                break;
            end
        end
        if(data_found==0)
            chn_includes(i)=0;
        end
    end
    chn_includes=find(chn_includes==1);
    data.powspctrm = data.powspctrm(chn_includes,1); % [N x 1]
    data.label = data.label(1,chn_includes); % {1 x N}
end
data.freq = 1;
data.dimord = 'chan_freq';
if(zlim~=-1)
    cfg.zlim = [-zlim zlim]; % codes for customized view
end

ft_topoplotER(cfg,data);

% layout preparation by U_PrepareLayout
% e.g. U_PrepareLayout({'HuangCanSen'});