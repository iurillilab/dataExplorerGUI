function V = anatomyViewer(T, atlas, onSelectUnit)
% ANATOMYVIEWER  3D brain + scrollable coronal slab view of unit locations.
%
%   V = anatomyViewer(T, atlas, onSelectUnit)
%
%   T            : unit table with ordinal, ccfX (AP), ccfY (ML), ccfZ (DV),
%                  in 10-um CCF voxels
%   atlas        : path to the file made by make_anatomyAtlasLite.m, or the
%                  struct loaded from it
%   onSelectUnit : function handle called as onSelectUnit(ordinal) when a
%                  unit is picked in the viewer (may be empty)
%
%   V.update(coloredOrdinals, currentOrdinal)  redraw with a new selection
%   V.isOpen()                                 true while the window exists
%   V.focus()                                  bring the window to front
%
% Mouse / keys
%   3D view   : drag = rotate | click = move the coronal level to the
%               clicked point | shift-click = select the nearest unit
%   coronal   : click = select the nearest unit in the slab
%   anywhere  : scroll wheel or arrow keys = move the coronal level
%
% Gray = all units; colored = selection; ringed marker = current unit.

if ischar(atlas) || isstring(atlas)
    atlas = load(atlas);
end
if nargin < 3, onSelectUnit = []; end

%% constants
slabHalf   = 10;                  % coronal slab half-width, 10-um voxels (= +/-100 um)
grayCol    = 0.72*[1 1 1];
singleCol  = [0.85 0.15 0.15];
brainCol   = [0.75 0.80 0.90];
planeCol   = [1.00 0.55 0.00];
res_mm     = atlas.atlasResolution_mm;
bregma     = atlas.bregma;
step3D     = atlas.apGrid(2) - atlas.apGrid(1);
stepSlice  = atlas.apLevels(min(2, end)) - atlas.apLevels(1);
if stepSlice == 0, stepSlice = 1; end

%% data
n  = height(T);
X  = double(T.ccfX);  Y = double(T.ccfY);  Z = double(T.ccfZ);   % AP, ML, DV
ok = ~isnan(X) & ~isnan(Y) & ~isnan(Z);
S.colored = false(n,1);
S.current = NaN;                                  % row in T
S.ap      = clampAP(round(median(X(ok))));
S.regions = struct('acr', {}, 'idx', {}, 'col', {});
S.drag    = struct('active', false);

% candidate "color by" variables: column vectors that are numeric, logical,
% categorical, string or cellstr
vn = T.Properties.VariableNames;
colorVars = {};
for iv = 1:numel(vn)
    x = T.(vn{iv});
    if size(x,1) == n && size(x,2) == 1 && ...
            (isnumeric(x) || islogical(x) || iscategorical(x) || isstring(x) || iscellstr(x))
        colorVars{end+1} = vn{iv}; %#ok<AGROW>
    end
end

%% figure and controls
fig = figure('Name', 'Anatomy view', 'NumberTitle', 'off', 'Color', 'w', ...
    'Units', 'normalized', 'Position', [0.08 0.08 0.84 0.78], ...
    'MenuBar', 'none', 'ToolBar', 'figure');
ax3 = axes('Parent', fig, 'Position', [0.01 0.13 0.50 0.84]);
ax2 = axes('Parent', fig, 'Position', [0.55 0.13 0.42 0.80]);

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.065 0.06 0.03], ...
    'String', 'Color by:', 'HorizontalAlignment', 'right', 'BackgroundColor', 'w');
hColorBy = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', 'Position', [0.075 0.07 0.13 0.03], ...
    'String', [{'(single color)'}, colorVars], 'Value', 1, 'Callback', @(~,~) redrawAll());

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.21 0.065 0.06 0.03], ...
    'String', 'Regions:', 'HorizontalAlignment', 'right', 'BackgroundColor', 'w');
hRegEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', 'Position', [0.275 0.07 0.14 0.03], ...
    'String', '', 'TooltipString', 'Allen acronyms, comma-separated (e.g. CP, SSp-ul); subregions included', ...
    'HorizontalAlignment', 'left');
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.42 0.07 0.05 0.03], ...
    'String', 'Show', 'Callback', @(~,~) setRegions());

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.025 0.05 0.03], ...
    'String', 'View:', 'HorizontalAlignment', 'right', 'BackgroundColor', 'w');
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.065 0.03 0.045 0.03], ...
    'String', 'top', 'Callback', @(~,~) setView([90 90]));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.112 0.03 0.045 0.03], ...
    'String', 'side', 'Callback', @(~,~) setView([0 0]));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [0.159 0.03 0.045 0.03], ...
    'String', 'oblique', 'Callback', @(~,~) setView([-37.5 30]));
hGrayChk = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', 'Position', [0.215 0.03 0.12 0.03], ...
    'String', 'show gray units', 'Value', 1, 'BackgroundColor', 'w', 'Callback', @(~,~) redrawAll());
hStatus = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.01 0.0 0.53 0.025], ...
    'String', '3D: drag = rotate | click = set coronal level | shift-click = select unit.   Coronal: click = select unit.   Scroll / arrows = move level', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', 'ForegroundColor', 0.35*[1 1 1]);

apL = atlas.apLevels;
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.55 0.025 0.06 0.03], ...
    'String', 'anterior', 'HorizontalAlignment', 'right', 'BackgroundColor', 'w');
hSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', 'Position', [0.615 0.03 0.30 0.03], ...
    'Min', apL(1), 'Max', max(apL(end), apL(1)+1), 'Value', S.ap, ...
    'SliderStep', min(1, [stepSlice, 10*stepSlice] / max(1, apL(end)-apL(1))), ...
    'Callback', @(src,~) setAP(round(src.Value)));
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.92 0.025 0.06 0.03], ...
    'String', 'posterior', 'HorizontalAlignment', 'left', 'BackgroundColor', 'w');

fig.WindowButtonDownFcn   = @onDown;
fig.WindowButtonMotionFcn = @onMotion;
fig.WindowButtonUpFcn     = @onUp;
fig.WindowScrollWheelFcn  = @onScroll;
fig.WindowKeyPressFcn     = @onKey;

%% static 3D content: brain surface, coronal plane
hold(ax3, 'on');
fvBrain = makeSurface(atlas.avSmall > 1, 0.25);
hBrain = patch(ax3, fvBrain, 'FaceColor', brainCol, 'EdgeColor', 'none', ...
    'FaceAlpha', 0.06, 'PickableParts', 'none', 'HitTest', 'off');
mlLim = [atlas.mlGrid(1), atlas.mlGrid(end)];
dvLim = [atlas.dvGrid(1), atlas.dvGrid(end)];
hPlane = patch(ax3, S.ap*[1 1 1 1], mlLim([1 2 2 1]), dvLim([1 1 2 2]), planeCol, ...
    'FaceAlpha', 0.15, 'EdgeColor', planeCol, 'LineWidth', 1, 'PickableParts', 'none', 'HitTest', 'off');
hRegSurf = gobjects(0);
hUnits3 = gobjects(0);

set(ax3, 'ZDir', 'reverse');
axis(ax3, 'equal'); axis(ax3, 'vis3d'); axis(ax3, 'off');
view(ax3, [90 90]);
hLight = camlight(ax3, 'headlight');
lighting(ax3, 'gouraud');

set(ax2, 'YDir', 'reverse');
redrawAll();

%% outputs
V.update = @update;
V.isOpen = @() isvalid(fig);
V.focus  = @() figure(fig);

% =====================================================================
%  public
% =====================================================================
    function update(coloredOrdinals, currentOrdinal)
        if ~isvalid(fig), return; end
        S.colored = ismember(T.ordinal, coloredOrdinals);
        r = find(T.ordinal == currentOrdinal, 1);
        if isempty(r), S.current = NaN; else, S.current = r; end
        redrawAll();
    end

% =====================================================================
%  drawing
% =====================================================================
    function redrawAll()
        drawUnits3D();
        drawCoronal();
    end

    function [C, info] = unitColors(rows)
        % C: numel(rows) x 3 RGB, or numel(rows) x 1 scalar (info.type)
        info = struct('type', 'rgb', 'cats', strings(0,1), 'catCols', zeros(0,3), 'clim', [0 1], 'var', '');
        k = hColorBy.Value;
        if k == 1
            C = repmat(singleCol, numel(rows), 1);
            return
        end
        var = colorVars{k-1};
        info.var = var;
        xall = T.(var);
        if (isnumeric(xall) || islogical(xall)) && numel(unique(xall(~isnan(double(xall))))) > 12
            info.type = 'scalar';
            C = double(xall(rows));
            v = double(xall(S.colored));  v = v(~isnan(v));
            if isempty(v), v = double(xall(~isnan(double(xall)))); end
            if isempty(v), v = [0 1]; end
            lo = min(v); hi = max(v);
            if hi <= lo, hi = lo + 1; end
            info.clim = [lo hi];
            return
        end
        s = string(xall);
        cats = unique(s(~ismissing(s)));
        pal = palette(numel(cats));
        [~, ic] = ismember(s(rows), cats);
        C = repmat(grayCol, numel(rows), 1);
        C(ic > 0, :) = pal(ic(ic > 0), :);
        info.cats = cats;  info.catCols = pal;
    end

    function drawUnits3D()
        delete(hUnits3(isvalid(hUnits3)));
        hUnits3 = gobjects(0);
        showGray = hGrayChk.Value == 1;
        g = ok & ~S.colored;
        if showGray && any(g)
            hUnits3(end+1) = plot3(ax3, X(g), Y(g), Z(g), '.', 'Color', grayCol, 'MarkerSize', 4, ...
                'PickableParts', 'none');
        end
        c = find(ok & S.colored);
        if ~isempty(c)
            [C, info] = unitColors(c);
            hUnits3(end+1) = scatter3(ax3, X(c), Y(c), Z(c), 14, C, 'filled', 'PickableParts', 'none');
            if strcmp(info.type, 'scalar'), colormap(ax3, parula(256)); clim(ax3, info.clim); end
        end
        if ~isnan(S.current) && ok(S.current)
            [C, info] = unitColors(S.current);
            if strcmp(info.type, 'scalar'), C = singleCol; end
            hUnits3(end+1) = plot3(ax3, X(S.current), Y(S.current), Z(S.current), 'o', ...
                'MarkerSize', 11, 'MarkerFaceColor', C(1,:), 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
                'PickableParts', 'none');
        end
    end

    function drawCoronal()
        cla(ax2); hold(ax2, 'on');
        % region fills from the sub-sampled annotation slice
        [~, ia] = min(abs(atlas.apGrid - S.ap));
        sl = squeeze(atlas.avSmall(ia, :, :));                 % DV x ML
        for ir = 1:numel(S.regions)
            m = double(ismember(sl, S.regions(ir).idx));
            if ~any(m(:)), continue; end
            cm = contourc(atlas.mlGrid, atlas.dvGrid, m, [0.5 0.5]);
            for pp = parseContour(cm)
                fill(ax2, pp{1}(:,1), pp{1}(:,2), S.regions(ir).col, 'FaceAlpha', 0.25, ...
                    'EdgeColor', S.regions(ir).col, 'PickableParts', 'none');
            end
        end
        % precomputed outline closest to the current level
        [~, il] = min(abs(atlas.apLevels - S.ap));
        xy = atlas.outlines{il};
        if ~isempty(xy)
            plot(ax2, xy(:,1), xy(:,2), 'k', 'LineWidth', 1, 'PickableParts', 'none');
        end
        % units in the slab
        inSlab = ok & abs(X - S.ap) <= slabHalf;
        g = inSlab & ~S.colored;
        if hGrayChk.Value == 1 && any(g)
            scatter(ax2, Y(g), Z(g), 10, grayCol, 'filled', 'PickableParts', 'none');
        end
        c = find(inSlab & S.colored);
        info = struct('type', 'rgb', 'cats', strings(0,1));
        if ~isempty(c)
            [C, info] = unitColors(c);
            scatter(ax2, Y(c), Z(c), 32, C, 'filled', 'PickableParts', 'none');
        end
        if ~isnan(S.current) && inSlab(S.current)
            [Cc, ic] = unitColors(S.current);
            if strcmp(ic.type, 'scalar'), Cc = singleCol; end
            plot(ax2, Y(S.current), Z(S.current), 'o', 'MarkerSize', 11, 'MarkerFaceColor', Cc(1,:), ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'PickableParts', 'none');
        end
        % color legend / colorbar
        colorbar(ax2, 'off'); legend(ax2, 'off');
        if strcmp(info.type, 'scalar')
            colormap(ax2, parula(256)); clim(ax2, info.clim);
            cb = colorbar(ax2); cb.Label.String = info.var; cb.Label.Interpreter = 'none';
        elseif ~isempty(info.cats) && ~isempty(c)
            present = unique(string(T.(info.var)(S.colored & ok)));
            present = present(~ismissing(present));
            if numel(present) <= 20
                hL = gobjects(numel(present), 1);
                for ip = 1:numel(present)
                    k = find(info.cats == present(ip), 1);
                    hL(ip) = plot(ax2, NaN, NaN, 'o', 'MarkerFaceColor', info.catCols(k,:), ...
                        'MarkerEdgeColor', 'none', 'DisplayName', char(present(ip)));
                end
                lg = legend(ax2, hL, 'Location', 'eastoutside', 'Interpreter', 'none', 'Box', 'off');
                title(lg, info.var, 'Interpreter', 'none');
            end
        end
        axis(ax2, 'image');
        xlim(ax2, [atlas.mlGrid(1), atlas.mlGrid(end) + step3D]);
        ylim(ax2, [atlas.dvGrid(1), atlas.dvGrid(end) + step3D]);
        set(ax2, 'YDir', 'reverse');
        axis(ax2, 'off');
        title(ax2, sprintf('bregma %+.2f mm  (CCF AP %d, slab \\pm%d \\mum)   units: %d in slab, %d selected', ...
            (bregma(1) - S.ap) * res_mm, S.ap, slabHalf*10, nnz(inSlab), numel(c)), 'FontWeight', 'normal');
        hold(ax2, 'off');
    end

    function setAP(ap)
        S.ap = clampAP(ap);
        if isvalid(hSlider), hSlider.Value = S.ap; end
        set(hPlane, 'XData', S.ap*[1 1 1 1]);
        drawCoronal();
    end

    function setView(v)
        view(ax3, v);
        camlight(hLight, 'headlight');
    end

    function setRegions()
        acrs = strtrim(split(string(hRegEdit.String), ','));
        acrs = acrs(acrs ~= "");
        delete(hRegSurf(isvalid(hRegSurf)));
        hRegSurf = gobjects(0);
        S.regions = struct('acr', {}, 'idx', {}, 'col', {});
        stAcr  = string(atlas.st.acronym);
        stPath = string(atlas.st.structure_id_path);
        notFound = strings(0,1);
        for ia = 1:numel(acrs)
            r = find(strcmpi(stAcr, acrs(ia)), 1);
            if isempty(r), notFound(end+1) = acrs(ia); continue; end %#ok<AGROW>
            id = double(atlas.st.id(r));
            idx = find(contains(stPath, "/" + id + "/"));   % region + all subregions (rows = av values)
            col = hexColor(atlas.st.color_hex_triplet(r));
            S.regions(end+1) = struct('acr', stAcr(r), 'idx', idx, 'col', col);
            fv = makeSurface(ismember(atlas.avSmall, idx), 1);
            if ~isempty(fv.vertices)
                hRegSurf(end+1) = patch(ax3, fv, 'FaceColor', col, 'EdgeColor', 'none', ...
                    'FaceAlpha', 0.12, 'PickableParts', 'none', 'HitTest', 'off'); %#ok<AGROW>
            end
        end
        if ~isempty(notFound)
            hStatus.String = "acronym(s) not found: " + strjoin(notFound, ', ');
        end
        drawCoronal();
    end

% =====================================================================
%  mouse and keys
% =====================================================================
    function onDown(~, ~)
        S.drag = struct('active', true, 'start', fig.CurrentPoint, 'last', fig.CurrentPoint, ...
            'moved', false, 'sel', fig.SelectionType, 'where', whereIsPointer(), ...
            'ray3', ax3.CurrentPoint, 'pt2', ax2.CurrentPoint(1,1:2));
    end

    function onMotion(~, ~)
        if ~S.drag.active || ~strcmp(S.drag.where, 'ax3') || ~strcmp(S.drag.sel, 'normal'), return; end
        cp = fig.CurrentPoint;
        figPx = getpixelposition(fig);
        dpx = (cp - S.drag.last) .* figPx(3:4);              % normalized -> pixels
        if norm((cp - S.drag.start) .* figPx(3:4)) > 4, S.drag.moved = true; end
        if S.drag.moved
            [az, el] = view(ax3);
            view(ax3, az - 0.4*dpx(1), max(-90, min(90, el - 0.4*dpx(2))));
            camlight(hLight, 'headlight');
        end
        S.drag.last = cp;
    end

    function onUp(~, ~)
        if ~S.drag.active, return; end
        d = S.drag;
        S.drag.active = false;
        if d.moved, return; end
        switch d.where
            case 'ax3'
                if strcmp(d.sel, 'extend')
                    r = nearestToRay(d.ray3);
                    if ~isnan(r)
                        setAP(round(X(r)));
                        pickUnit(r);
                    end
                elseif strcmp(d.sel, 'normal')
                    ap = apFromRay(d.ray3);
                    if ~isnan(ap), setAP(round(ap)); end
                end
            case 'ax2'
                if strcmp(d.sel, 'normal')
                    r = nearestInSlab(d.pt2);
                    if ~isnan(r), pickUnit(r); end
                end
        end
    end

    function onScroll(~, evt)
        setAP(S.ap + evt.VerticalScrollCount * stepSlice);
    end

    function onKey(~, evt)
        switch evt.Key
            case {'rightarrow', 'downarrow'}, setAP(S.ap + stepSlice);
            case {'leftarrow', 'uparrow'},    setAP(S.ap - stepSlice);
        end
    end

    function w = whereIsPointer()
        w = '';
        figPx = getpixelposition(fig);
        cpx = fig.CurrentPoint .* figPx(3:4);               % normalized -> pixels
        for nm = {'ax3', 'ax2'}
            if strcmp(nm{1}, 'ax3'), a = ax3; else, a = ax2; end
            p = getpixelposition(a);
            if cpx(1) >= p(1) && cpx(1) <= p(1)+p(3) && cpx(2) >= p(2) && cpx(2) <= p(2)+p(4)
                w = nm{1}; return
            end
        end
    end

    function pickUnit(r)
        S.current = r;
        redrawAll();
        hStatus.String = sprintf('selected ordinal %d', T.ordinal(r));
        if ~isempty(onSelectUnit)
            onSelectUnit(T.ordinal(r));
        end
    end

% =====================================================================
%  geometry helpers
% =====================================================================
    function ap = apFromRay(ray)
        % AP of the brain voxels crossed by the click ray (mean of inside samples)
        t = linspace(0, 1, 600)';
        P = ray(1,:) + t .* (ray(2,:) - ray(1,:));           % [AP ML DV]
        ia = round((P(:,1) - atlas.apGrid(1)) / step3D) + 1;
        im = round((P(:,2) - atlas.mlGrid(1)) / step3D) + 1;
        id = round((P(:,3) - atlas.dvGrid(1)) / step3D) + 1;
        sz = size(atlas.avSmall);
        in = ia >= 1 & ia <= sz(1) & id >= 1 & id <= sz(2) & im >= 1 & im <= sz(3);
        inside = false(size(t));
        inside(in) = atlas.avSmall(sub2ind(sz, ia(in), id(in), im(in))) > 1;
        if any(inside), ap = mean(P(inside, 1)); else, ap = NaN; end
    end

    function r = nearestToRay(ray)
        % nearest unit to the click ray; colored units preferred within 200 um
        d = ray(2,:) - ray(1,:);  d = d / norm(d);
        Pm = [X Y Z] - ray(1,:);
        dist = vecnorm(cross(Pm, repmat(d, n, 1), 2), 2, 2);
        dist(~ok) = Inf;
        if hGrayChk.Value == 0, dist(~S.colored) = Inf; end
        r = pickPreferColored(dist, 20, 50);
    end

    function r = nearestInSlab(pt)
        dist = hypot(Y - pt(1), Z - pt(2));
        dist(~ok | abs(X - S.ap) > slabHalf) = Inf;
        if hGrayChk.Value == 0, dist(~S.colored) = Inf; end
        r = pickPreferColored(dist, 15, 30);
    end

    function r = pickPreferColored(dist, tolColored, tolAll)
        r = NaN;
        dc = dist; dc(~S.colored) = Inf;
        [m, k] = min(dc);
        if m <= tolColored, r = k; return; end
        [m, k] = min(dist);
        if m <= tolAll, r = k; end
    end

    function fv = makeSurface(mask, reduceFrac)
        Vm = double(permute(mask, [3 1 2]));                 % ML x AP x DV
        fv = isosurface(atlas.apGrid, atlas.mlGrid, atlas.dvGrid, Vm, 0.5);
        if reduceFrac < 1 && size(fv.faces, 1) > 20000
            fv = reducepatch(fv, reduceFrac);
        end
    end

    function ap = clampAP(ap)
        ap = min(max(ap, atlas.apLevels(1)), atlas.apLevels(end));
    end
end

% =====================================================================
%  local functions
% =====================================================================
function polys = parseContour(cm)
polys = {};
k = 1;
while k < size(cm, 2)
    np = cm(2, k);
    polys{end+1} = cm(:, k+1:k+np)'; %#ok<AGROW>
    k = k + np + 1;
end
end

function c = hexColor(h)
h = regexprep(char(string(h)), '[^0-9a-fA-F]', '');
if numel(h) == 6
    c = [hex2dec(h(1:2)), hex2dec(h(3:4)), hex2dec(h(5:6))] / 255;
else
    c = [0.2 0.6 0.2];
end
end

function pal = palette(k)
base = [0.122 0.467 0.706; 1.000 0.498 0.055; 0.173 0.627 0.173; 0.839 0.153 0.157; ...
        0.580 0.404 0.741; 0.549 0.337 0.294; 0.890 0.467 0.761; 0.498 0.498 0.498; ...
        0.737 0.741 0.133; 0.090 0.745 0.812];               % tab10
if k <= size(base, 1)
    pal = base(1:k, :);
else
    pal = turbo(k);
end
end
