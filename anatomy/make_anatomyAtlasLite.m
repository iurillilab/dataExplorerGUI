function A = make_anatomyAtlasLite(pathToAtlas, T, outFile, varargin)
% MAKE_ANATOMYATLASLITE  One-off precomputation of the light atlas file used
% by anatomyViewer.m (the "Open anatomy view" button of dataExplorerGUI).
%
%   A = make_anatomyAtlasLite(pathToAtlas, T, outFile)
%   A = make_anatomyAtlasLite(..., 'step3D', 5, 'stepSlices', 5, 'apMargin', 50)
%
% Run once, on a machine that has the full Allen atlas. Needed ONLY here:
%   - npy-matlab (readNPY)
%   - allenRegistration_iurilliLab on the path (loadStructureTree,
%     sliceOutlineWithRegionVec, sliceOutlineWithRegion, allenCCFbregma)
%   - Image Processing + Curve Fitting toolboxes (used by sliceOutline*)
% The GUI itself needs none of these afterwards.
%
% Inputs
%   pathToAtlas : folder with annotation_volume_10um_by_index.npy and
%                 structure_tree_safe_2017.csv
%   T           : pooled unit table (uses ccfX = AP in 10-um CCF voxels)
%   outFile     : output .mat, e.g. fullfile(expRootFolder, 'anatomyAtlasLite.mat')
% Options (all in 10-um voxels)
%   step3D      : sub-sampling of the annotation volume kept for 3D brain and
%                 region surfaces and coronal region fills (default 5 = 50 um)
%   stepSlices  : spacing of the precomputed coronal outlines (default 5 = 50 um)
%   apMargin    : outlines are computed from min(T.ccfX)-apMargin to
%                 max(T.ccfX)+apMargin (default 50 = 0.5 mm)
%
% Example
%   addpath(genpath('/Users/galileo/GitHub/allenRegistration_iurilliLab'))
%   addpath(genpath('/Users/galileo/GitHub/matlabUtilities/npy-matlab-master/npy-matlab'))
%   load('/Users/galileo/Dropbox/Data/explorerGUI_dataset/pooledTable.mat', 'T')
%   make_anatomyAtlasLite('/Users/galileo/Dropbox/allen brain template files', T, ...
%       '/Users/galileo/Dropbox/Data/explorerGUI_dataset/anatomyAtlasLite.mat');

p = inputParser;
addParameter(p, 'step3D', 5);
addParameter(p, 'stepSlices', 5);
addParameter(p, 'apMargin', 50);
parse(p, varargin{:});
o = p.Results;

disp('loading annotation volume and structure tree...')
av = readNPY(fullfile(pathToAtlas, 'annotation_volume_10um_by_index.npy'));   % AP x DV x ML, values = row in st
st = loadStructureTree(fullfile(pathToAtlas, 'structure_tree_safe_2017.csv'));
bregma = allenCCFbregma();

% ---- sub-sampled annotation volume (3D surfaces, coronal region fills)
apGrid = 1:o.step3D:size(av,1);
dvGrid = 1:o.step3D:size(av,2);
mlGrid = 1:o.step3D:size(av,3);
avSmall = av(apGrid, dvGrid, mlGrid);

% ---- coronal outlines (same function as plotCellsCoronalSlicesVolume.m)
apRange = [max(1, floor(min(T.ccfX)) - o.apMargin), ...
           min(size(av,1), ceil(max(T.ccfX)) + o.apMargin)];
apLevels = apRange(1):o.stepSlices:apRange(2);
outlines = cell(numel(apLevels), 1);
fprintf('computing %d coronal outlines (AP %d..%d, step %d um)...\n', ...
    numel(apLevels), apRange(1), apRange(2), 10*o.stepSlices);
for k = 1:numel(apLevels)
    avSlice = double(squeeze(av(apLevels(k), :, :)));   % DV x ML
    coords = sliceOutlineWithRegionVec(avSlice, [], [], []);
    xy = zeros(0, 2, 'single');
    for c = 1:numel(coords)
        xy = [xy; single([coords(c).x(:), coords(c).y(:)]); NaN NaN]; %#ok<AGROW>
    end
    outlines{k} = xy;          % column 1 = ML (x on the slice), column 2 = DV (y)
    if mod(k, 10) == 0, fprintf('  %d / %d\n', k, numel(apLevels)); end
end

A = struct();
A.avSmall = avSmall;
A.apGrid = apGrid;  A.dvGrid = dvGrid;  A.mlGrid = mlGrid;
A.apLevels = apLevels;
A.outlines = outlines;
A.st = st(:, {'id', 'name', 'acronym', 'structure_id_path', 'color_hex_triplet'});
A.bregma = bregma;
A.atlasResolution_mm = 0.010;
A.info = sprintf(['made by make_anatomyAtlasLite on %s; step3D = %d um, ', ...
    'stepSlices = %d um; coordinates in 10-um CCF voxels (AP, DV, ML)'], ...
    char(datetime('now')), 10*o.step3D, 10*o.stepSlices);

save(outFile, '-struct', 'A', '-v7');
d = dir(outFile);
fprintf('saved %s (%.1f MB)\n', outFile, d.bytes/1e6);
end
