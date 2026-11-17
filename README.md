## Requirements:

Clone (or download) this repository.

The script requires MATLAB 2022b or higher (currently tested on Matlab 2024b).

It also requires the "GUI Layout Toolbox", which can be installed directly from the Adds-On tab in Matlab, or from https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox




## How to use it:

Open launch_dataExplorerGUI.m

Follow the Setting-up instructions to (1) download the data and (2) set the paths.

Save the script and run it.

An interactive window will open. Select any cell to begin.




## Anatomy view (optional):

The "Open anatomy view" button (Display Settings panel) opens a separate window with unit locations in the Allen CCF:
- left: 3D brain; right: coronal slab (±100 µm) at the current anterior-posterior level.
- all units are shown in light gray; colored units = rows passing the current table filter (only when a filter is active) plus rows highlighted in the table (shift/cmd-click). The current unit has a black ring.
- "Color by": single color, or any column of T (categories get a legend, continuous values a colorbar).
- "Regions": Allen acronyms, comma-separated (e.g. `CP, SSp-ul`), shown as surfaces in 3D and filled areas in the coronal view (subregions included).

Mouse and keys:
- 3D view: drag = rotate; click = move the coronal level to the clicked point; shift-click = select the nearest unit.
- coronal view: click = select the nearest unit in the slab.
- scroll wheel, arrow keys or slider = move the coronal level.
- selecting a unit in the anatomy window updates the PSTHs in the main GUI.

Set-up (once): the view needs a light atlas file, `anatomyAtlasLite.mat`, made with `anatomy/make_anatomyAtlasLite.m` (see its header for an example call). This step requires the full Allen atlas files (annotation_volume_10um_by_index.npy, structure_tree_safe_2017.csv), npy-matlab, the allenRegistration_iurilliLab repository, and the Image Processing and Curve Fitting toolboxes. The GUI itself needs none of these afterwards.

Place `anatomyAtlasLite.mat` in the dataset folder (`expRootFolder` in launch_dataExplorerGUI.m); if it is not found, the GUI asks for the file when the button is pressed. The table T must contain the columns `ordinal`, `ccfX`, `ccfY`, `ccfZ` (AP, ML, DV in 10-µm CCF voxels).
