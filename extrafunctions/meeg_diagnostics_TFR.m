function h = meeg_diagnostics_TFR(tfr,diag,figtitle,savepath)
TOPO_MAXCOL = 4; % maximum number of columns of topoplot mosaic 
TOL = 1e-8;

if nargin < 3, figtitle = 'Sample'; end

if ~iscell(tfr), tfr = {tfr}; end

if ~isfield(diag,'layout'), diag.layout = ft_prepare_layout([],tfr{1}); end
dispcfg = [];
dispcfg.layout = diag.layout;
dispcfg.marker = 'labels';
dispcfg.interactive = 'no';
dispcfg.showoutline = 'yes';
dispcfg.comment = 'no';
dispcfg.zlim = [0 prctile(cell2mat(cellfun(@(x) x.powspctrm, tfr, 'UniformOutput', false)),99,'all')]; % max colour at 99 percentile of all data
dispcfg.colorbar = 'yes';

cfgmulti = dispcfg;
cfgtopo = dispcfg;

cfgmulti.showlabels  = 'yes';
if isfield(tfr{1},'stat')
    stat = tfr{1}.stat;
    tfr{1} = rmfield(tfr{1},'stat');
    if strcmp(stat.cfg.correctm,'cluster')
        if isfield(stat,'posclusters') && ~isempty(stat.posclusters)
            pos_cluster_pvals = [stat.posclusters(:).prob];
            pos_signif_clust = find(pos_cluster_pvals < stat.cfg.alpha);
            pos = ismember(stat.posclusterslabelmat, pos_signif_clust);
        else
            pos = stat.mask*0;
        end
        
        if isfield(stat,'negclusters') && ~isempty(stat.negclusters)
            neg_cluster_pvals = [stat.negclusters(:).prob];
            neg_signif_clust = find(neg_cluster_pvals < stat.cfg.alpha);
            neg = ismember(stat.negclusterslabelmat, neg_signif_clust);
        else
            neg = stat.mask*0;
        end
    else
        pos = stat.mask & (stat.stat > 0);
        neg = stat.mask & (stat.stat < 0);
    end
    tfr{1}.mask = stat.mask;
    cfgmulti.maskparameter = 'mask';
    cfgmulti.maskstyle = 'opacity';
    cfgtopo.highlight = 'on';
    [iLabER,iLabStat] = match_str(tfr{1}.label, stat.label);
    if isfield(diag,'topohighlight')
        topoHighlightFun = str2func(diag.topohighlight);
    else
        topoHighlightFun = @all;
    end
end

if numel(tfr{1}.time) > 1
    if numel(tfr{1}.label) == 1 % single channel data
        cfgmulti.linewidth = 2;
        ft_singleplotTFR(cfgmulti, tfr{:});
        diag.videotwoi =  [];
        diag.snapshottwoi = [];
    else
        ft_multiplotTFR(cfgmulti, tfr{:});
    end
    set(gcf,'Name',figtitle);
    if nargin >= 4 
        set(gcf,'Position',[0,0,1080 1080]);
        set(gcf,'PaperPositionMode','auto');
        print(gcf,'-noui',[savepath '_multiplot.jpg'],'-djpeg','-r300');
        close(gcf);
    else
        h.multiplot = gcf;
    end
else
    diag.videotwoi =  [];
    diag.snapshottwoi = [tfr{1}.time tfr{1}.time]*1000;
end

if numel(tfr) > 1
    labels = arrayfun(@(x) sprintf('group #%d',x),1:numel(tfr),'UniformOutput',false);
    if exist('stat','var')
        tfr = [tfr(1) tfr];
        tfr{1}.avg = stat.stat;
        labels = [{'stat'} labels];
    end
else
    labels = {''};
end
    
if ~isempty(diag.snapshottwoi) && ~isempty(diag.snapshotfwoi)
    indTFR = 1:numel(tfr);
    if strcmp(labels{1},'stat'), indTFR = 2:numel(tfr); end
    
    % specify color scaling based on data
    alldat = cellfun(@(x) x.powspctrm, tfr(indTFR), 'UniformOutput', false);
    alldat = vertcat(alldat{:});
    if numel(tfr{1}.time) > 1 || numel(tfr{1}.freq) > 1 % smooth multiD data
        zlimSmooth = mean(diff(diag.snapshottwoi'))/1000*1/mean(diff(tfr{1}.time))*3; % increase the size for the gaussian kernel
        alldat = arrayfun(@(x) smoothdata(alldat(x,:,:),'gaussian',zlimSmooth),1:size(alldat,1),'UniformOutput',false);
        alldat = horzcat(alldat{:});
    end
    zlim = prctile(alldat,[1 99],'all');
   
    for f = 1:size(diag.snapshotfwoi,1)
        cfgtopo.ylim = diag.snapshotfwoi(f,:);
        fig = figure('Name',sprintf('%s_freq-%1.2f-%1.2f',figtitle,diag.snapshotfwoi(f,:)));
        colPlot = min([TOPO_MAXCOL numel(tfr)*ceil(sqrt(size(diag.snapshottwoi,1)))]);
        colPlot = floor(colPlot/numel(tfr))*numel(tfr);
        rowPlot = ceil(size(diag.snapshottwoi,1)*numel(tfr)/colPlot);
        if rowPlot > colPlot % figure will likely not fit to screen
            warning('Topoplot figure is too large to fit to screen -> It will be hidden.')
            set(fig,'Visible','off');
        end
        set(fig,'Position',[0,0,1080 ceil(1080/colPlot*rowPlot)]);
        
        cbOn = false;
        for t = 1:size(diag.snapshottwoi,1)
            cfgtopo.xlim = diag.snapshottwoi(t,:)/1000;
            
            if exist('stat','var')
                % Get the index of each significant channel
                [junk, sampStart] = min(abs(tfr{1}.time - cfgtopo.xlim(1)));
                if tfr{1}.time(sampStart)+TOL < cfgtopo.xlim(1), sampStart=sampStart+1; end
                [junk, sampEnd] = min(abs(tfr{1}.time - cfgtopo.xlim(2)));
                if tfr{1}.time(sampEnd)-TOL > cfgtopo.xlim(2), sampEnd=sampEnd+1; end
                
                pos_int = zeros(numel(tfr{1}.label),1);
                neg_int = zeros(numel(tfr{1}.label),1);
                pos_int(iLabER) = topoHighlightFun(pos(iLabStat, sampStart:sampEnd), 2);
                neg_int(iLabER) = topoHighlightFun(neg(iLabStat, sampStart:sampEnd), 2);
                cfgtopo.highlightchannel = find(pos_int | neg_int);
            end
            
            for e = 1:numel(tfr)
                if all(cfgtopo.xlim < min(tfr{e}.time)) || all(cfgtopo.xlim > max(tfr{e}.time)) ||...
                        all(cfgtopo.ylim < min(tfr{e}.freq)) || all(cfgtopo.ylim > max(tfr{e}.freq))
                    warning('no data within the range')
                    continue
                end
                tmpdat = ft_selectdata(struct('latency',cfgtopo.xlim,'frequency',cfgtopo.ylim),tfr{e});
                if all(isnan(tmpdat.powspctrm(:))), continue; end % skip empty data
                
                cfgtopo.colorbar = 'no';
                if strcmp(labels{e},'stat')
                    cfgtopo.zlim = [min(tfr{e}.avg(:)) max(tfr{e}.avg(:))];
                    if ~cbOn, cfgtopo.colorbar = 'West'; cbOn = true; end
                else
                    cfgtopo.zlim = zlim;
                    if ~cbOn && (isempty(labels{e}) || strcmp(labels{e},'group #1')), cfgtopo.colorbar = 'West'; cbOn = true; end
                end
                subplot(rowPlot,colPlot,(t-1)*numel(tfr)+e);
                title(sprintf('%s %03d-%03d ms',labels{e},diag.snapshottwoi(t,:)));
                ft_topoplotTFR(cfgtopo, tfr{e});
            end
        end
        % Put colorbars between the axes
        cbs = findall(fig,'type','ColorBar');
        axs = findall(fig,'type','Axes');
        dPos = cbs(1).Position.*[0 0 0.25 0.25];
        if numel(axs) > 1
            dPos(1) = (-(diff(arrayfun(@(x) x.Position(1), axs(1:2))))-axs(1).Position(3))/2;
        end
        for c = cbs'
            c.YAxisLocation = 'left';
            c.Location = 'manual';
            c.Position = c.Position-dPos;
        end
        if nargin >= 4
            set(fig,'PaperPositionMode','auto');
            print(fig,'-noui',sprintf('%s_topoplot_freq-%1.2f-%1.2f.jpg',savepath,diag.snapshotfwoi(f,:)),'-djpeg','-r150');
            close(fig)
        else
            h.topoplot(f) = fig;
        end
    end
end