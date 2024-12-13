% v- 0.0.2
% Tested on MATLAB 2024b.
% Requires MATLAB 2022b or higher.
% Requires the "GUI Layout Toolbox" (install it from the HOME tab, Adds-On:
%       Get Adds-On, search for GUI Layout Toolbox and install it).
% 
% written by Paola Patella, December 2024

%% setting up instructions (set once):
% 1. clone or download the repository from:
% https://github.com/iurillilab/dataExplorerGUI

% 2. input the local path to the dataExplorerGUI repository:
path2scripts = '/Users/galileo/GitHub/dataExplorerGUI'; 


% 3. download the dataset from:
% https://www.dropbox.com/scl/fo/u6vliw62ffjoi0x42xfd1/AGrRWmn6oF9Ais_Ujc9TOr4?rlkey=l9jbuf0ospgi007t4trdsr67i&dl=0

% 4. input the local path to the dataset:
expRootFolder = '/Users/galileo/Dropbox/Data/explorerGUI_dataset';


%% running the code:
addpath(genpath(path2scripts))
load(fullfile(expRootFolder, 'pooledTable.mat'), 'T')
load(fullfile(expRootFolder, 'pooledDataSet.mat'), 'ts')

dataExplorerGUI(T, ts);