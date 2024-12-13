% Tested on MATLAB 2024b.
% Requires MATLAB 2022b or higher.
% Requires the "GUI Layout Toolbox" (install it from the HOME tab, Adds-On:
%       Get Adds-On, search for GUI Layout Toolbox and install it).
% 
% written by Paola Patella, December 2024

%%
% clone or download the repository from:
% 

% input the local path to the dataExplorerGUI repository:
path2scripts = '/Users/galileo/GitHub/dataExplorerGUI'; 


% download the dataset from:
% https://www.dropbox.com/scl/fo/u6vliw62ffjoi0x42xfd1/AGrRWmn6oF9Ais_Ujc9TOr4?rlkey=l9jbuf0ospgi007t4trdsr67i&dl=0

% input the local path to the dataset:
expRootFolder = '/Users/galileo/Dropbox/Data/explorerGUI_dataset';


%%
addptah(genpath(path2scripts))
load(fullfile(expRootFolder, 'pooledTable.mat'), 'T')
load(fullfile(expRootFolder, 'pooledDataSet.mat'), 'ts')

dataExplorerGUI(T, ts);