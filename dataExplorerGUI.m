function buildGUI(T, ts)
    % Create full-screen GUI figure
    f = uifigure('Name', 'Custom GUI', 'NumberTitle', 'off', 'Units', 'normalized', 'WindowStyle', 'normal', 'Position', [0 0 1 1], 'AutoResizeChildren', 'on');
    % Define overall layout
    mainLayout = uix.VBox('Parent', f, 'Spacing', 10);

    % general constants and settings
    loc_tags = ["far", "near", "hit"];
    phase_tags = ["base", "main", "test", "any"];  % for indexing, use e.g.:    ismember(ts(mn).T.phase, [1:3])
    lit_tags = ["lit", "dark"];  % ONLY index [0,1] into:  ts(mn).T.isDarkTrial
    side_tags = ["right", "left"];  % [1,2]
    speed_tags = ["slow", "fast", "any"];
    d_tags = dictionary(cat(2, loc_tags, phase_tags, lit_tags, side_tags, speed_tags), [1, 2, 3, 1, 2, 3, 0, 0, 1, 1, 2, 1, 2, 0]);
    d_eventTimes = dictionary(1:4, ["Ton", "Toff", "Ton_rec", "Toff_rec"]);
    eventTimes_linestyles = ["-",":","-",":"];

    eventColorCode = [  0.6980    0.8745    0.5412; ...
                    0.1216    0.4706    0.7059; ...
                    0.4157    0.3176    0.6392; ...
                    0.8902    0.1020    0.1098; ...
                    0.3       0.3       0.3];
    d_colorEventName = dictionary(["start", "far", "near", "hit", "stop"], 1:5);


    psthTiming.preWindow = 2;
    psthTiming.postWindow = 3;
    psthTiming.binSize = 0.05;
    psthTimimg.baselineWindow = [-2, 0];  %make sure this is not bigger than actually contained in raster. Currently not robustly enforced.

    edges = -psthTiming.preWindow:psthTiming.binSize:psthTiming.postWindow;
    psth_time = edges(1:end-1) + psthTiming.binSize/2;
    scaleRaster = 0.8;
    smoothingw = 1;
    plotTime_lineWidth = 1.5;
    plot_raster_basic = 1;
    baseColor = 0.12 * [1 1 1];

    % initializations
    Tshow = T;
    vars2show  = ["ordinal", "mouseID", "uID", "name", "pANOVA_baseVStest", "pANOVA_darkVSlit", "pANOVA_RVSL", "pFARvsHIT" , "distalLitR_p", "distalLitR_h", "distalDarkAll_p", "distalDarkAll_h", "distalLitL_p", "distalLitL_h"];
    numModules = 0;
    h = struct;
    T_ordinal = 1;

    %% Top Section (1/3 height)
    topSection = uix.HBox('Parent', mainLayout, 'Spacing', 10);
    
    % Function 1: Table Visualization
    tablePanel = uix.Panel('Parent', topSection, 'Title', 'Data Table', 'FontSize', 9);
    dataTable = uitable('Parent', tablePanel, 'Tag', 'dataTable', 'Units', 'normalized', 'Position', [0 0 1 1]);
    dataTable.Data = Tshow(1:height(Tshow), vars2show);
    dataTable.CellSelectionCallback = @getSelectedRow;

    % Function 2: Filter/Sort Box
    filterPanel = uix.Panel('Parent', topSection, 'Title', 'Table Filtering', 'FontSize', 9);
    filterLayout = uix.VBox('Parent', filterPanel, 'Spacing', 2, 'Padding', 6);
    
    % Dropdown for variable selection
    uicontrol('Parent', filterLayout, 'Style', 'text', 'String', 'Select Variable:', 'HorizontalAlignment', 'left');
    variableDropdown = uicontrol('Parent', filterLayout, 'Style', 'popupmenu', 'String', T.Properties.VariableNames, 'Tag', 'variableDropdown', 'Value', 1, 'Callback', @updateRuleInput); %updated default value

    % Input for rule value
    uicontrol('Parent', filterLayout, 'Style', 'text', 'String', 'Enter Rule:', 'HorizontalAlignment', 'left');
    ruleInput = uicontrol('Parent', filterLayout, 'Style', 'edit', 'Tag', 'ruleInput', 'String', sprintf('T.%s ',T.Properties.VariableNames{1})); %updated default value

    % Logical operator selection
    uicontrol('Parent', filterLayout, 'Style', 'text', 'String', 'Logical Operator:', 'HorizontalAlignment', 'left');
    operatorDropdown = uicontrol('Parent', filterLayout, 'Style', 'popupmenu', 'String', {'AND', 'OR'}, 'Tag', 'operatorDropdown');

    % Add rule button
    uicontrol('Parent', filterLayout, 'Style', 'pushbutton', 'String', 'Add Rule', 'Callback', @addRule);

    % Reset rules button
    uicontrol('Parent', filterLayout, 'Style', 'pushbutton', 'String', 'Reset Rules', 'Callback', @resetRules);

    % Display rules
    uicontrol('Parent', filterLayout, 'Style', 'text', 'String', 'Current Rules:', 'HorizontalAlignment', 'left');
    rulesList = uicontrol('Parent', filterLayout, 'Style', 'edit', 'Tag', 'rulesList', 'Max', 10);

    % Apply filter button
    uicontrol('Parent', filterLayout, 'Style', 'pushbutton', 'String', 'Apply Filter', 'Callback', @applyFilter);

    set(filterLayout, 'Heights', [-2 -3 -2 -3 -2 -3 -3 -3 -2 -5 -3]); %[20 30 20 30 20 30 30 30 20 50 30]);


    % Function 3: Variable Settings
    rightDisplay = uix.VBox('Parent', topSection, 'Spacing', 8, 'Padding', 0);

    selectionPanel = uix.Panel('Parent', rightDisplay, 'Title', 'Cell Selection', 'FontSize', 9);
    selectionLayout = uix.VBox('Parent', selectionPanel, 'Spacing', 2, 'Padding', 6);
    uicontrol('Parent', selectionLayout, 'Style', 'text', 'String', 'Ordinal:', 'HorizontalAlignment', 'left');
    ordinalIndicator = uicontrol('Parent', selectionLayout, 'Style', 'edit', 'Tag', 'ordinalIndicator', ...
                                 'String', sprintf('%d',T_ordinal), 'HorizontalAlignment', 'left', 'Callback', @updateSelection);
    selectionIndicator = uicontrol('Parent', selectionLayout, 'Style', 'text', 'Tag', 'selectionIndicator', ...
                                   'String', sprintf('\nmouse: %s\tuID: %d\n%s',T.mouseID{T_ordinal}, T.uID(T_ordinal), T.name{T_ordinal}), 'HorizontalAlignment', 'left');
    
    set(selectionLayout, 'Heights', [-1 -1 -2]);


    settingsPanel = uix.Panel('Parent', rightDisplay, 'Title', 'Display Settings', 'FontSize', 9);
    settingsPanelLayout = uix.VBox('Parent', settingsPanel, 'Spacing', 2, 'Padding', 5);
    
    al2eventLayout = uix.HBox('Parent', settingsPanelLayout, 'Spacing', 4, 'Padding', 1);
    uicontrol('Parent',al2eventLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', sprintf('align to event: '));
    alignMenu = uicontrol('Parent', al2eventLayout, 'Style', 'popupmenu', 'HorizontalAlignment', 'center', 'String', string(1:4), 'Value', 1, 'Callback', @displayPSTHs);
    set(al2eventLayout, 'Widths', [-3 -1]);
    
    shadeLayout = uix.HBox('Parent', settingsPanelLayout, 'Spacing', 4, 'Padding', 1);
    uicontrol('Parent',shadeLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', sprintf('plot event boxes: '));
    shadeMenu = uicontrol('Parent', shadeLayout, 'Style', 'popupmenu', 'HorizontalAlignment', 'center', 'String', ["no", "yes"], 'Value', 2, 'Callback', @displayPSTHs);
    set(shadeLayout, 'Widths', [-3 -1]);

    moduleLayout = uix.HBox('Parent', settingsPanelLayout, 'Spacing', 4, 'Padding', 1);
    uicontrol('Parent', moduleLayout, 'Style', 'pushbutton', 'String', 'Add new PSTH', 'FontSize', 13, 'Callback', @addNewModule);
    uicontrol('Parent', moduleLayout, 'Style', 'pushbutton', 'String', 'Remove last PSTH', 'FontSize', 11, 'Callback', @removeLastModule);
    set(moduleLayout, 'Widths', [-3 -2]);

    uicontrol('Parent', settingsPanelLayout, 'Style', 'pushbutton', 'String', 'Merge PSTHs', 'FontSize', 12, 'ForegroundColor', 0.65*[ 1 1 1]); %function not implemented at the moment

    set(settingsPanelLayout, 'Heights', [-1 -1 -1.8 -1.8]);

    set(rightDisplay, 'Heights', [-1 -1]);

    set(topSection, 'Widths', [-2 -1 -1]);
 
    %% Bottom Section (2/3 height)
    bottomSection = uix.HBox('Parent', mainLayout, 'Spacing', 10);

    set(mainLayout, 'Heights', [-1 -2]);

    %% Nested Functions

    function getSelectedRow(~, event)
        if ~isempty(event.Indices)
            selectedRow = event.Indices(1); % Get the row index of the selected cell
            T_ordinal = Tshow.ordinal(selectedRow);
            ordinalIndicator.String = sprintf('%d', T_ordinal);
            employ_Tordinal(T_ordinal);
        end
    end

    function updateSelection(~, ~)
        T_ordinal = str2double(ordinalIndicator.String);
        employ_Tordinal(T_ordinal);
    end

    function employ_Tordinal(T_ordinal)
        % update display of basic cell information:
        selectionIndicator.String = sprintf('\nmouse: %s\tuID: %d\n%s',T.mouseID{T_ordinal}, T.uID(T_ordinal), T.name{T_ordinal});
        if numModules == 0
            addNewModule;
        else
            displayPSTHs;
        end
    end

    function addNewModule(~, ~)
        numModules = numModules + 1;
        addModules(bottomSection, numModules);
        displayPSTHs;
    end

    function addModules(parent, i)
        h(i).modulePanel = uix.VBox('Parent', parent, 'Spacing', 0, 'Padding', 4);
        
        % Selection Box
        h(i).selectionPanel = uix.Panel('Parent', h(i).modulePanel, 'Title', 'Event Selection', 'FontSize', 9);
        h(i).selectionPanelLayout = uix.VBox('Parent', h(i).selectionPanel, 'Spacing', 4, 'Padding', 6);

        h(i).locLayout = uix.HBox('Parent', h(i).selectionPanelLayout, 'Spacing', 1, 'Padding', 0);
        h(i).locText = uicontrol('Parent', h(i).locLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', 'End location: ');
        h(i).locMenu = uicontrol('Parent', h(i).locLayout, 'Style', 'popupmenu', 'String', loc_tags, 'Value', 1, 'Callback', @displayPSTHs);

        h(i).sideLayout = uix.HBox('Parent', h(i).selectionPanelLayout, 'Spacing', 1, 'Padding', 0);
        h(i).sideText = uicontrol('Parent', h(i).sideLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', 'Stimulus side: ');
        h(i).sideMenu = uicontrol('Parent', h(i).sideLayout, 'Style', 'popupmenu', 'String', side_tags, 'Value', 1, 'Callback', @displayPSTHs);

        h(i).lightLayout = uix.HBox('Parent', h(i).selectionPanelLayout, 'Spacing', 1, 'Padding', 0);
        h(i).lightText = uicontrol('Parent', h(i).lightLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', 'Illumination: ');
        h(i).lightMenu = uicontrol('Parent', h(i).lightLayout, 'Style', 'popupmenu', 'String', lit_tags, 'Value', 1, 'Callback', @displayPSTHs);

        h(i).speedLayout = uix.HBox('Parent', h(i).selectionPanelLayout, 'Spacing', 1, 'Padding', 0);
        h(i).speedText = uicontrol('Parent', h(i).speedLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', 'Stimulus speed: ');
        h(i).speedMenu = uicontrol('Parent', h(i).speedLayout, 'Style', 'popupmenu', 'String', speed_tags, 'Value', 1, 'Callback', @displayPSTHs);

        h(i).phaseLayout = uix.HBox('Parent', h(i).selectionPanelLayout, 'Spacing', 1, 'Padding', 0);
        h(i).phaseText = uicontrol('Parent', h(i).phaseLayout, 'Style', 'text', 'HorizontalAlignment', 'right', 'String', 'Session phase: ');
        h(i).phaseMenu = uicontrol('Parent', h(i).phaseLayout, 'Style', 'popupmenu', 'String', phase_tags, 'Value', 1, 'Callback', @displayPSTHs);
        

        % Main Panel (PSTH)
        h(i).mainPanel = uix.Panel('Parent', h(i).modulePanel, 'Title', 'Data Display', 'FontSize', 9);

        % % Setup tiling layout for plots
        % % h(i).t = tiledlayout(h(i).mainPanel, 'vertical');
        h(i).t = uix.VBox( 'Parent', h(i).mainPanel , 'Units', 'normalized');
        h(i).t.Units = 'normalized';
        h(i).t.Position = [0, 0, 1, 1];
 
        set(h(i).modulePanel, 'Heights', [-1 -3.5]);        
    end

    function removeLastModule(~, ~)
        if numModules == 0
            return;
        end
        delete(h(numModules).modulePanel);
        h(numModules) = [];
        numModules = numModules - 1;

        if isfield(h, 'data_ylim')
            h = rmfield(h, 'data_ylim');
        end
    end


    function displayPSTHs(~, ~)
        if numModules == 0 
            return;
        end
        for i = 1:numModules

            %% read the input tags for this module:
            tag_loc = loc_tags(h(i).locMenu.Value);
            tag_side = side_tags(h(i).sideMenu.Value);
            tag_lit = lit_tags(h(i).lightMenu.Value);
            tag_speed = speed_tags(h(i).speedMenu.Value);
            tag_phase = phase_tags(h(i).phaseMenu.Value);

            al2event = alignMenu.Value;
            plotTimeShades = shadeMenu.Value - 1;
            colorevents = ["start", tag_loc, tag_loc, "stop" ];

            %% extract corresponding data:
            mn = T.mouseNum(T_ordinal);
            cuse = T.uID(T_ordinal);

            % extract selected trials:
            trialsuse = ts(mn).T.endloc == d_tags(tag_loc) & ...
                ts(mn).T.sideIdx == d_tags(tag_side) & ...
                ts(mn).T.isDarkTrial == d_tags(tag_lit);
            if d_tags(tag_speed)~=0
                trialsuse = trialsuse & ...
                    ts(mn).T.speeds == d_tags(tag_speed);
            end
            if d_tags(tag_phase)~=0
                trialsuse = trialsuse & ...
                    ts(mn).T.phase == d_tags(tag_phase);
            end
            trialnumbers = find(trialsuse)';

            if sum(trialsuse)==0
                if ~isempty(h(i).t.Children)
                    delete(allchild(h(i).t))
                end
                continue
            end
            %%
            thisbaselinespikerate = nan(sum(trialsuse),1);
            clear psth rasterX rasterY
            for idx = 1:sum(trialsuse)
                ntr = trialnumbers(idx);
                spiketimes = ts(mn).T.raster{ntr};
                cellIDs = ts(mn).T.cellIDs{ntr};
                spiketimes = spiketimes(cellIDs==cuse);
                thisbaselinespikerate(ntr) = sum( spiketimes>psthTimimg.baselineWindow(1) & spiketimes<=psthTimimg.baselineWindow(2) ) / diff(psthTimimg.baselineWindow);
                % baseline is always calculated before the first event

                if al2event>1
                    % shift the raster spiketimes accordingly
                    deltaTE = ts(mn).T.(d_eventTimes(al2event))(ntr) - ts(mn).T.(d_eventTimes(1))(ntr);
                    spiketimes = spiketimes - deltaTE;
                end
                psth_trial = histcounts(spiketimes, edges)./psthTiming.binSize - thisbaselinespikerate(ntr);
                psth(idx,:) = gen_fx_gsmooth(psth_trial, smoothingw);

                % also set up raster:
                spiketimes(spiketimes<edges(1) | spiketimes>edges(end)) = [];
                [rasterX{idx},yy] = rasterize(spiketimes);
                rasterY{idx} = yy*scaleRaster-(scaleRaster/2)+idx;   
            end
            %ok

            %% display PSTH
            if ~isempty(h(i).t.Children)
                delete(allchild(h(i).t))
            end
            

            fapp = figure('Visible', 'off');
            h(i).ax1 = axes; hold on

            % main psth plot with error shade:
            stdshade_modified(psth,0.35,baseColor,psth_time,[],[], 2.5, 2);

            axYlims = [-200 500];
            h(i).data_ylim = h(i).ax1.YLim;
            axXlims = h(i).ax1.XLim;

            % polish axis and add event annotations
            for idx = 1:sum(trialsuse)
                ntr = trialnumbers(idx);
                for t = 1:4
                    alTimes(t) = ts(mn).T.(d_eventTimes(t))(ntr) - ts(mn).T.(d_eventTimes(al2event))(ntr);
                end
                plot([alTimes(1), alTimes(1)], axYlims, 'LineWidth', plotTime_lineWidth, 'Color', eventColorCode(d_colorEventName("start"),:), 'LineStyle',eventTimes_linestyles(1))
                plot([alTimes(4), alTimes(4)], axYlims, 'LineWidth', plotTime_lineWidth, 'Color', eventColorCode(d_colorEventName("stop"),:), 'LineStyle', eventTimes_linestyles(4))
                if plotTimeShades
                    fill([alTimes(2), alTimes(3), alTimes(3), alTimes(2)], ...
                        [axYlims(1), axYlims(1), axYlims(2), axYlims(2)], eventColorCode(d_colorEventName(tag_loc),:), 'FaceAlpha', 1/sum(trialsuse), 'LineStyle', "none");
                else
                    plot([alTimes(2), alTimes(2)], axYlims, 'LineWidth', plotTime_lineWidth, 'Color', eventColorCode(d_colorEventName(colorevents(2)),:), 'LineStyle', eventTimes_linestyles(2));
                    plot([alTimes(3), alTimes(3)], axYlims, 'LineWidth', plotTime_lineWidth, 'Color', eventColorCode(d_colorEventName(colorevents(3)),:), 'LineStyle', eventTimes_linestyles(3));
                end
            end

            h(i).ax1.Children = flipud(h(i).ax1.Children);
            h(i).ax1.XLim = axXlims;
            h(i).ax1.YLabel.String = sprintf('firing rate (spike/s)\nmean ± SEM (n=%d)', sum(trialsuse));
            h(i).ax1.XLabel.String = 'time (s)';

            % h(i).ViewContainer1 = uicontainer('Parent', h(i).t);
            h(i).ViewContainer1 = uix.Container('Parent', h(i).t,  'Units', 'normalized');
            h(i).ax1.Parent = h(i).ViewContainer1;
            close(fapp);


            %% display rasters
            if plot_raster_basic
                fapp = figure('Visible', 'off');
                h(i).ax2 = axes; hold on

                for idx = 1:sum(trialsuse)  
                    %  plot boxes
                    if plotTimeShades
                        ntr = trialnumbers(idx);
                        for t = 1:4
                            alTimes(t) = ts(mn).T.(d_eventTimes(t))(ntr) - ts(mn).T.(d_eventTimes(al2event))(ntr);
                        end
                        plot([alTimes(1), alTimes(1)], [0,1]+idx-0.5, 'Color', eventColorCode(d_colorEventName("start"),:), 'LineWidth', 0.75);
                        plot([alTimes(4), alTimes(4)], [0,1]+idx-0.5, 'Color', eventColorCode(d_colorEventName("stop"),:),  'LineWidth', 0.75, 'LineStyle', eventTimes_linestyles(4));

                        line([alTimes(2), alTimes(2), alTimes(3), alTimes(3), alTimes(2)], [0, 1, 1, 0, 0]*scaleRaster-(scaleRaster/2) +idx, ...
                            'LineWidth', 0.75, 'Color', eventColorCode(d_colorEventName(colorevents(2)),:));                      
                    end

                    % plot spike raster last, so it goes on top
                    plot(rasterX{idx}, rasterY{idx}, 'Color', 0.2*[1 1 1], 'LineWidth', 0.5)

                end
                axis tight
                h(i).ax2.XLim = [edges(1), edges(end)];
                h(i).ax2.XTick = h(i).ax1.XTick;
                h(i).ax2.TickDir = 'out';
                h(i).ax2.YDir = 'reverse';
                h(i).ax2.YLim = [0 sum(trialsuse)]+0.5;
                h(i).ax2.YTick = 1:sum(trialsuse);
                h(i).ax2.YTickLabel = string(trialnumbers(h(i).ax2.YTick));
                h(i).ax2.YLabel.String = 'trials';

                h(i).ViewContainer2 = uix.Container('Parent', h(i).t, 'Units', 'normalized');
                h(i).ax2.Parent = h(i).ViewContainer2;
                close(fapp);

            end

            % plot color-coded single-trial psths
            fapp = figure('Visible', 'off');
            h(i).ax3 = axes; hold on

            centroids = edges(2:end); % not really correct, but tick will be shifted at the end and that should do.
            desiredXTicks = h(i).ax1.XTick;
            imagesc(psth)
            colormap(h(i).ax3, bluewhitered(256));
            axis tight
            h(i).ax3.Box = 'off';
            h(i).ax3.TickDir = 'out';
            h(i).ax3.XTick = [0, find(ismember(centroids, desiredXTicks))]+0.5;
            h(i).ax3.XTickLabel = string(desiredXTicks);
            h(i).ax3.YDir = 'reverse';
            h(i).ax3.YLim = [0 sum(trialsuse)]+0.5;
            h(i).ax3.YTick = 1:sum(trialsuse);
            h(i).ax3.YTickLabel = string(trialnumbers(h(i).ax3.YTick));
            h(i).ax3.XLabel.String = 'time (s)';
            h(i).ax3.YLabel.String = 'trials';

            cb = colorbar;
            cb.Label.String = 'firing rate (spike/s)';

            h(i).ViewContainer3 = uix.Container('Parent', h(i).t, 'Units', 'normalized');
            h(i).ax3.Parent = h(i).ViewContainer3;
            close(fapp);

            %handle the color bar
            h(i).ax1.OuterPosition = h(i).ax3.OuterPosition;
            if plot_raster_basic
                h(i).ax2.OuterPosition = h(i).ax3.OuterPosition;
                % set relative heights:
                set(h(i).t, 'Heights', [-2 -1 -1]);
            else
                % set relative heights:
                set(h(i).t, 'Heights', [-2 -1]);
            end
            
            % units get reversed to pixels every time (not sure where), so 
            % reinstating this is necessary for correct formatting:
            h(i).t.Units = 'normalized';
            h(i).t.Position = [0, 0, 1, 1];
     
        end
        % link y-axes of psths
        ylims = cat(1, h(i).data_ylim);

        ylim_min = min(ylims,[],1);
        ylim_max = max(ylims,[],1);
        ylims = [ylim_min(1), ylim_max(2)];

        for i = 1:numModules
            if isvalid(h(i).ax1)
                h(i).ax1.YLim = ylims;
            end
        end
    end




    function updateRuleInput(~, ~)
        % Update rule input field when variable is selected
        selectedVariable = variableDropdown.String{variableDropdown.Value};
        ruleInput.String = sprintf('T.%s ', selectedVariable);
    end

    function addRule(~, ~)
        % Retrieve current rule details
        ruleValue = ruleInput.String;
        operator = operatorDropdown.String{operatorDropdown.Value};
        d_operator = dictionary(["AND","OR"], ["&", "|"]);
        
        % Append new rule to the list
        currentRules = rulesList.String;
        if isempty(currentRules)
            executableRule = ruleValue;
        else
            executableRule = sprintf('(%s) %s (%s)', currentRules, d_operator(operator), ruleValue);
        end
        rulesList.String = executableRule;
    end

    function resetRules(~, ~)
        % Clear all rules
        rulesList.String = {};
        disp('Rules have been reset.');
        Tshow = T;
        dataTable.Data = Tshow(1:end, vars2show);
    end

    function applyFilter(~, ~)
        % Collect rules and apply filter logic here
        if isempty(rulesList.String)
            disp('No rules to apply.');
            Tshow = T;
            dataTable.Data = Tshow(1:end, vars2show);
            return;
        end
        disp(['Applying filter with expression: ', rulesList.String]);
        % Actual filtering logic can be implemented here
        Tshow = T(eval(rulesList.String),:);
        dataTable.Data = Tshow(1:end, vars2show);
    end


end
