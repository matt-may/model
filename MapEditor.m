classdef MapEditor < handle
    
    properties(Constant)
        CLICK_MODE_NONE = 0;
        CLICK_MODE_PAN = 1;
        CLICK_MODE_ADD_SIDEWALK_VERTEX = 2;
        CLICK_MODE_ADD_ROAD_VERTEX = 3;
        CLICK_MODE_ADD_ENTRANCE_VERTEX = 4;
        CLICK_MODE_ADD_EXIT_VERTEX = 5;
        CLICK_MODE_REM_VERTEX = 6;
        
        ZOOM_IN_FACTOR = 1.25;
        ZOOM_OUT_FACTOR = 0.75;
        
        NODE_TYPE_SIDEWALK = 1;
        NODE_TYPE_ROAD     = 2;
        NODE_TYPE_ENTRANCE = 3;
        NODE_TYPE_EXIT     = 4;
        
    end
    
    properties(Access = private)
        m_Handles;
        
        % file stuff
        m_ImagePath;
        m_ImageFileName;
        m_VertexPath;
        m_VertexFileName;
        m_EdgePath;
        m_EdgeFileName;
        
        % internal variables
        m_Image;
        m_ImageHandle;
        
        m_CellFlags;
        m_CellImage;
        m_CellImageHandle;
        m_CellImageAlpha;
        
        m_MetersPerPixel;
        m_PixelsPerVertex;
        m_MouseMode;
        
        m_VertexList;
        m_NumVertices;
        m_EdgeList;
        m_NumEdges;
        m_SpecialEdgeList;
    end
    
    methods(Access = public)

        function Obj = MapEditor()
            % MAPEDITOR MATLAB code for MapEditor.fig
            %      MAPEDITOR, by itself, creates a new MAPEDITOR or raises the existing
            %      singleton*.
            %
            %      H = MAPEDITOR returns the handle to a new MAPEDITOR or the handle to
            %      the existing singleton*.
            %
            %      MAPEDITOR('CALLBACK',hObject,eventData,handles,...) calls the local
            %      function named CALLBACK in MAPEDITOR.M with the given input arguments.
            %
            %      MAPEDITOR('Property','Value',...) creates a new MAPEDITOR or raises the
            %      existing singleton*.  Starting from the left, property value pairs are
            %      applied to the GUI before MapEditor_OpeningFcn gets called.  An
            %      unrecognized property name or invalid value makes property application
            %      stop.  All inputs are passed to MapEditor_OpeningFcn via varargin.
            %
            %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
            %      instance to run (singleton)".
            %
            % See also: GUIDE, GUIDATA, GUIHANDLES

            % Edit the above text to modify the response to help MapEditor

            % Last Modified by GUIDE v2.5 07-Feb-2016 13:59:50

            % Begin initialization code - DO NOT EDIT
            gui_Singleton = 1;
            gui_State = struct('gui_Name',       mfilename, ...
                               'gui_Singleton',  gui_Singleton, ...
                               'gui_OpeningFcn', @MapEditor.MapEditor_OpeningFcn, ...
                               'gui_OutputFcn',  @MapEditor.MapEditor_OutputFcn, ...
                               'gui_LayoutFcn',  [] , ...
                               'gui_Callback',   []);

            hFormMain = gui_mainfcn(gui_State);
            
            MapEditor.GetSetInstance(Obj);
            Obj.m_Handles = guihandles(hFormMain);
            % End initialization code - DO NOT EDIT
            
            % default vals
            Obj.m_MetersPerPixel = 1;
            Obj.m_PixelsPerVertex = 3;
            Obj.m_ImagePath = [];
            Obj.m_ImageFileName = [];
            Obj.m_VertexPath = [];
            Obj.m_VertexFileName = [];
            Obj.m_EdgePath = [];
            Obj.m_EdgeFileName = [];
            Obj.m_VertexList = [];
            Obj.m_EdgeList = [];
            Obj.m_CellImage = [];
            
            % populate form stuff
            set(Obj.m_Handles.txtMetersPerPixel, 'String', Obj.m_MetersPerPixel);
            set(Obj.m_Handles.txtPixelsPerVertex, 'String', Obj.m_PixelsPerVertex);
            set(Obj.m_Handles.axisMain, 'ButtonDownFcn', @MapEditor.axisButtonDown);
            set(Obj.m_Handles.figureMain, 'WindowButtonUpFcn', {@MapEditor.dragFcnToggle, false});
            set(Obj.m_Handles.figureMain, 'KeyPressFcn', @MapEditor.handleKeyPress);
        end
    end
    
    methods(Access = public, Static)
        
        function Obj = GetSetInstance(Obj)
            persistent s_Instance;
            if(nargin == 1)
                s_Instance = Obj;
            else
                Obj = s_Instance;
            end
        end
        
        % --- Executes just before MapEditor is made visible.
        function MapEditor_OpeningFcn(hObject, eventdata, handles, varargin)
            % This function has no output args, see OutputFcn.
            % hObject    handle to figure
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            % varargin   command line arguments to MapEditor (see VARARGIN)

            % Choose default command line output for MapEditor
            handles.output = hObject;

            % Update handles structure
            guidata(hObject, handles);

            % UIWAIT makes MapEditor wait for user response (see UIRESUME)
            % uiwait(handles.figureMain);

        end

        % --- Outputs from this function are returned to the command line.
        function varargout = MapEditor_OutputFcn(hObject, eventdata, handles) 
            % varargout  cell array for returning output args (see VARARGOUT);
            % hObject    handle to figure
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)

            % Get default command line output from handles structure
            varargout{1} = handles.output;

        end
        
        function btnCreateVertexAndEdgeList_Callback()
            Obj = MapEditor.GetSetInstance();
            nCells = numel(Obj.m_CellFlags);
            nRows = size(Obj.m_CellFlags,1);
            nCols = size(Obj.m_CellFlags,2);
            
            % create vertex list
            Obj.m_VertexList.cellX = -1 * ones(nCells,1);
            Obj.m_VertexList.cellY = -1 * ones(nCells,1);
            Obj.m_VertexList.pixX = -1 * ones(nCells,1);
            Obj.m_VertexList.pixY = -1 * ones(nCells,1);
            Obj.m_VertexList.metersX = -1 * ones(nCells,1);
            Obj.m_VertexList.metersY = -1 * ones(nCells,1);
            Obj.m_VertexList.type    = -1 * ones(nCells,1);
            cellFlag1D = zeros(nCells, 1);
            
            % create edge list
            maxNumEdges = 4 * nRows * nCols - 3 * (nRows + nCols) + 2;
            Obj.m_EdgeList.V1 = -1 * ones(maxNumEdges, 1);
            Obj.m_EdgeList.V2 = -1 * ones(maxNumEdges, 1);
            Obj.m_EdgeList.lengthMeters = -1 * ones(maxNumEdges, 1);
            
            mpp = Obj.m_MetersPerPixel;
            ppv = Obj.m_PixelsPerVertex;
            nEdges = 0;
            for r = 1:nRows
                for c = 1:nCols
                    if(Obj.m_CellFlags(r,c))
                        idx = (r-1) * nCols + c;
                        cellFlag1D(idx) = 1;
                        pixCoord = MapEditor.cellCoord2PlotCoord([r c]);
                        Obj.m_VertexList.cellX(idx) = c;
                        Obj.m_VertexList.cellY(idx) = r;
                        Obj.m_VertexList.pixX(idx) = pixCoord(2);
                        Obj.m_VertexList.pixY(idx) = pixCoord(1);
                        Obj.m_VertexList.metersX(idx) = mpp * pixCoord(2);
                        Obj.m_VertexList.metersY(idx) = mpp * pixCoord(1);
                        Obj.m_VertexList.type(idx) = Obj.m_CellFlags(r,c);
                        
                        % check subset of 8-connected neighborhood; the
                        % subset is elements in the neighborhood that were
                        % previously visited (top row, and left of current
                        % cell)
                        if(c > 1 && r > 1)
                            % up and left of current cell
                            if(Obj.m_CellFlags(r-1, c-1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols - 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp * sqrt(2);
                            end
                        end
                        if(r > 1)
                            % up of current cell
                            if(Obj.m_CellFlags(r-1, c))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp;
                            end
                        end
                        if(r > 1 && c < nCols)
                            % up and right of current cell
                            if(Obj.m_CellFlags(r-1, c+1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols + 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp * sqrt(2);
                            end
                        end
                        if(c > 1)
                            % left of current cell
                            if(Obj.m_CellFlags(r, c-1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp;
                            end
                        end
                        
                    end %if current cell is a vertex
                    
                end %col loop
            end %row loop
            
            % need to re-index to make vertices contiguous
            mapVec = cumsum(cellFlag1D);
            for i = 1:nCells
                if(cellFlag1D(i))
                    % move vertex data
                    Obj.m_VertexList.cellX(mapVec(i))   = Obj.m_VertexList.cellX(i);
                    Obj.m_VertexList.cellY(mapVec(i))   = Obj.m_VertexList.cellY(i);
                    Obj.m_VertexList.pixX(mapVec(i))    = Obj.m_VertexList.pixX(i);
                    Obj.m_VertexList.pixY(mapVec(i))    = Obj.m_VertexList.pixY(i);
                    Obj.m_VertexList.metersX(mapVec(i)) = Obj.m_VertexList.metersX(i);
                    Obj.m_VertexList.metersY(mapVec(i)) = Obj.m_VertexList.metersY(i);
                    Obj.m_VertexList.type(mapVec(i))    = Obj.m_VertexList.type(i);
                end
            end
            
            % update edges so indexes are correct
            for i = 1:nEdges
                Obj.m_EdgeList.V1(i) = mapVec(Obj.m_EdgeList.V1(i));
                Obj.m_EdgeList.V2(i) = mapVec(Obj.m_EdgeList.V2(i));
            end
            
            % shorten vertex list
            Obj.m_NumVertices = sum(cellFlag1D);
            Obj.m_VertexList.cellX   = Obj.m_VertexList.cellX(1:Obj.m_NumVertices);
            Obj.m_VertexList.cellY   = Obj.m_VertexList.cellY(1:Obj.m_NumVertices);
            Obj.m_VertexList.pixX    = Obj.m_VertexList.pixX(1:Obj.m_NumVertices);
            Obj.m_VertexList.pixY    = Obj.m_VertexList.pixY(1:Obj.m_NumVertices);
            Obj.m_VertexList.metersX = Obj.m_VertexList.metersX(1:Obj.m_NumVertices);
            Obj.m_VertexList.metersY = Obj.m_VertexList.metersY(1:Obj.m_NumVertices);
            Obj.m_VertexList.type = Obj.m_VertexList.type(1:Obj.m_NumVertices);
            
            % shorten edge list
            Obj.m_NumEdges = nEdges;
            Obj.m_EdgeList.V1 = Obj.m_EdgeList.V1(1:Obj.m_NumEdges);
            Obj.m_EdgeList.V2 = Obj.m_EdgeList.V2(1:Obj.m_NumEdges);
            Obj.m_EdgeList.lengthMeters = Obj.m_EdgeList.lengthMeters(1:Obj.m_NumEdges);
            
            % plot vertices if configured to
            if(Obj.m_Handles.chkShowVerticesWhenDone.Value)
                Obj.m_Handles.axisMain;
                sidewalkX = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_SIDEWALK);
                sidewalkY = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_SIDEWALK);
                roadX     = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_ROAD);
                roadY     = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_ROAD);
                entranceX = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_ENTRANCE);
                entranceY = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_ENTRANCE);
                exitX     = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_EXIT);
                exitY     = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_EXIT);
                
                plot(Obj.m_Handles.axisMain, sidewalkX, sidewalkY, '.b', 'markersize', 2);
                plot(Obj.m_Handles.axisMain, roadX, roadY, '.', 'markersize', 2, 'color', [0.5 0.5 0]); % dark yellow
                plot(Obj.m_Handles.axisMain, entranceX, entranceY, '.', 'markersize', 2, 'color', [0.5 0.5 0]);
                plot(Obj.m_Handles.axisMain, exitX, exitY, '.', 'markersize', 2, 'color', [0.5 0 0]);
            end
            
            % plot edges if configured to
            if(Obj.m_Handles.chkShowEdgesWhenDone.Value)
                Obj.m_Handles.axisMain;
                % plot vertices
                for i = 1:Obj.m_NumEdges
                    v1Idx = Obj.m_EdgeList.V1(i);
                    v2Idx = Obj.m_EdgeList.V2(i);
                    plot(Obj.m_Handles.axisMain, ...
                        Obj.m_VertexList.pixX([v1Idx, v2Idx]), ...
                        Obj.m_VertexList.pixY([v1Idx, v2Idx]), ...
                        '.-b');
                end
                plot(Obj.m_Handles.axisMain, Obj.m_VertexList.pixX, Obj.m_VertexList.pixY, '.b', 'markersize', 2);
            end
        end %function
        
        function btnExportGraph_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % write vertices
            fid = fopen(fullfile(Obj.m_ImagePath, [Obj.m_ImageFileName, '.vertex']), 'w');
            fprintf(fid, '%f\n', Obj.m_MetersPerPixel);
            fprintf(fid, '%f\n', Obj.m_PixelsPerVertex);
            fprintf(fid, '%i\n', Obj.m_NumVertices);
            for i = 1:Obj.m_NumVertices
                fprintf(fid, '%i,%i,%f,%f,%f,%f,%i\n', ...
                    Obj.m_VertexList.cellX(i), ...
                    Obj.m_VertexList.cellY(i), ...
                    Obj.m_VertexList.pixX(i), ...
                    Obj.m_VertexList.pixY(i), ...
                    Obj.m_VertexList.metersX(i), ...
                    Obj.m_VertexList.metersY(i), ...
                    Obj.m_VertexList.type(i));
            end
            fclose(fid);
            
            % write edges
            fid = fopen(fullfile(Obj.m_ImagePath, [Obj.m_ImageFileName, '.edge']), 'w');
            fprintf(fid, '%i\n', Obj.m_NumEdges);
            for i = 1:Obj.m_NumEdges
                fprintf(fid, '%i,%i,%f\n', ...
                    Obj.m_EdgeList.V1(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_EdgeList.V2(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_EdgeList.lengthMeters(i));
            end
            fclose(fid);
            
        end
        
        function btnZoomIn_Callback()
            Obj = MapEditor.GetSetInstance();
            zoom(Obj.m_Handles.axisMain, Obj.ZOOM_IN_FACTOR);
        end
        
        function btnZoomOut_Callback()
            Obj = MapEditor.GetSetInstance();
            zoom(Obj.m_Handles.axisMain, Obj.ZOOM_OUT_FACTOR);
        end
        
        function chkShowGrid_Callback()
            MapEditor.toggleGrid();
        end
        
        function menuFile_OpenPicture_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % ask for image file
            [Obj.m_ImageFileName, Obj.m_ImagePath] = uigetfile({'*.png';'*.jpg';'*.gif'}, 'Select Image');
            
            % make sure user selected something
            if(numel(Obj.m_ImageFileName) > 1 && numel(Obj.m_ImagePath) > 1)
                % read image
                Obj.m_Image = imread(fullfile(Obj.m_ImagePath, Obj.m_ImageFileName));

                % display image
                MapEditor.setupImage();

                % establish grid data
                MapEditor.setupGrid();
            end
        end
        
        function menuFile_OpenVertexList_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % ask for image file
            [Obj.m_VertexFileName, Obj.m_VertexPath] = uigetfile({'*.vertex'}, 'Select Vertex File');
            
            % make sure user selected something and image exists
            if(numel(Obj.m_VertexFileName) > 1 && numel(Obj.m_VertexPath) > 1 && ...
               numel(Obj.m_ImageFileName) > 1 && numel(Obj.m_ImagePath) > 1)
                % read vertex file
                fid = fopen(fullfile(Obj.m_VertexPath, Obj.m_VertexFileName), 'r');
                
                % get meters per pixel and pixels per vertex
                mpp = textscan(fid, '%f', 1);
                ppv = textscan(fid, '%f', 1);
                
                Obj.m_MetersPerPixel = mpp{1};
                set(Obj.m_Handles.txtMetersPerPixel, 'String', num2str(mpp{1}));
                Obj.m_PixelsPerVertex = ppv{1};
                set(Obj.m_Handles.txtPixelsPerVertex, 'String', num2str(ppv{1}));
                
                MapEditor.setupGrid();
                
                nVertices = textscan(fid, '%f', 1);
                Obj.m_VertexList.cellX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.cellY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.pixX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.pixY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.metersX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.metersY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.type    = -1 * ones(nVertices{1},1);
                
                V = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ',');
                for i = 1:nVertices{1}
                    Obj.m_VertexList.cellX(i) = V{1}(i);
                    Obj.m_VertexList.cellY(i) = V{2}(i);
                    Obj.m_VertexList.pixX(i) = V{3}(i);
                    Obj.m_VertexList.pixY(i) = V{4}(i);
                    Obj.m_VertexList.metersX(i) = V{5}(i);
                    Obj.m_VertexList.metersY(i) = V{6}(i);
                    Obj.m_VertexList.type(i)    = V{7}(i);
                    
                    cc = [Obj.m_VertexList.cellX(i), Obj.m_VertexList.cellY(i)];
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.m_VertexList.type(i);
                    MapEditor.setCellImageValue(cc, Obj.m_CellFlags(cc(2),cc(1)))
                end

                fclose(fid);
            end
        end
        
        function menuFile_OpenEdgeList_Callback()
            Obj = MapEditor.GetSetInstance();
        end
        
        function radMouseNone_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_NONE;
            MapEditor.applyMouseMode();
        end
        
        function radMousePan_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_PAN;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddSidewalkVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddRoadVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_ROAD_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddEntranceVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddExitVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_EXIT_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseRemVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_REM_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function txtMetersPerPixel_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MetersPerPixel = str2double(get(Obj.m_Handles.txtMetersPerPixel, 'String'));
        end
        
        function txtPixelsPerVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            newVal = str2double(get(Obj.m_Handles.txtPixelsPerVertex, 'String'));
            if(Obj.m_PixelsPerVertex ~= newVal)
                Obj.m_PixelsPerVertex = newVal;
                MapEditor.setupImage()
                MapEditor.setupGrid();
                MapEditor.toggleGrid();
            end
        end
        
        
        
        
        
        function setupImage()
            Obj = MapEditor.GetSetInstance();
            Obj.m_Handles.axisMain;
            cla;
            Obj.m_ImageHandle = imshow(Obj.m_Image);
            hold on;
            set(Obj.m_ImageHandle, 'ButtonDownFcn', @MapEditor.axisButtonDown);
            set(Obj.m_ImageHandle, 'AlphaData', 0.40);
            
            % formatting
            axis image;
            axis equal;
            axis on;
        end
        
        % Sets up panning by clicking and dragging via the hand cursor.
        function [flag] = myPanCallbackFunction(obj, eventdata)
            % If the tag of the object is 'DoNotIgnore', then return true.
            % Indicate what the target is
%             disp(['In myPanCallbackFunction, you clicked on a ' get(obj,'Type') 'object']);
            objTag = get(obj, 'Tag');
            if strcmpi(objTag, 'DoNotIgnore')
                flag = true;
            else
                flag = false;
            end
        end
        
        function setupGrid()
            Obj = MapEditor.GetSetInstance();
            
            % set up grid lines for display on image
            Obj.m_Handles.axisMain.XTick = 0.5:Obj.m_PixelsPerVertex:size(Obj.m_Image,2);
            Obj.m_Handles.axisMain.YTick = 0.5:Obj.m_PixelsPerVertex:size(Obj.m_Image,1);
            set(Obj.m_Handles.axisMain, 'GridColor', 'magenta');
            set(Obj.m_Handles.axisMain, 'GridAlpha', 0.4);
            
            % set up cell flags
            sz = [size(Obj.m_Image, 1) size(Obj.m_Image,2)];
            szCell = floor(sz / Obj.m_PixelsPerVertex);
            Obj.m_CellFlags = zeros(szCell);
            
            % set up cell image for display (cyan)
            Obj.m_CellImageAlpha = zeros(size(Obj.m_Image,1), size(Obj.m_Image,2));
            Obj.m_CellImage = zeros([size(Obj.m_Image, 1), size(Obj.m_Image, 2), 3]);
            
            MapEditor.plotGrid();
        end
        
        function plotGrid()
            Obj = MapEditor.GetSetInstance();
            if(~isempty(Obj.m_CellImage))
                Obj.m_Handles.axisMain;
                Obj.m_CellImageHandle = imshow(Obj.m_CellImage);
                set(Obj.m_CellImageHandle, 'AlphaData', Obj.m_CellImageAlpha);
                set(Obj.m_CellImageHandle, 'ButtonDownFcn', @MapEditor.axisButtonDown);
                axis image;
                axis equal;
                axis on;
            end
        end
        
        function toggleGrid()
            Obj = MapEditor.GetSetInstance();
            if(Obj.m_Handles.chkShowGrid.Value ~= 0)
                grid(Obj.m_Handles.axisMain, 'on');
%                 set(Obj.m_Handles.axisMain, 'xticklabel', {[]});
%                 set(Obj.m_Handles.axisMain, 'yticklabel', {[]});
            else
                grid(Obj.m_Handles.axisMain, 'off');
            end
        end
        
        function applyMouseMode()
            Obj = MapEditor.GetSetInstance();
            
            % turn off panning if it's not set for it
            h = pan(Obj.m_Handles.figureMain);
            if(Obj.m_MouseMode == Obj.CLICK_MODE_PAN);
                set(h, 'Enable', 'on');
                addlistener(Obj.m_Handles.figureMain, 'WindowKeyPress', @MapEditor.handleKeyPress); %need to listen for keystrokes
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                set(h, 'Enable', 'off');
                set(Obj.m_Handles.figureMain, 'Pointer', 'crosshair');
            else
                set(Obj.m_Handles.figureMain, 'Pointer', 'arrow');
            end
        end
        
        function axisButtonDown(~, eventData)
            Obj = MapEditor.GetSetInstance();
            MapEditor.dragFcnToggle(0, 0, true);
%             fprintf('Button down! (%f, %f)\n', eventData.IntersectionPoint(1), eventData.IntersectionPoint(2));
%             fprintf('%s: ', eventData.EventName);
            pc = [0 0];
            cc = [0 0];

            if(strcmpi(eventData.EventName, 'WindowMouseMotion'))
                [pc, cc] = MapEditor.calcCellCoord(get(Obj.m_Handles.axisMain, 'CurrentPoint'));
            else
                [pc, cc] = MapEditor.calcCellCoord(eventData.IntersectionPoint);
            end
            
            % do add or removal, depending on click mode
            if(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_SIDEWALK)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_SIDEWALK;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_SIDEWALK);%[0 1 1]);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_ROAD)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_ROAD;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_ROAD);%[1 1 0.5]);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_ENTRANCE)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_ENTRANCE;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_ENTRANCE);%[0.5 1 0.5]);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_EXIT)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_EXIT;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_EXIT);%[1 0.5 0.5]);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)))
                    Obj.m_CellFlags(cc(2), cc(1)) = false;
                    MapEditor.setCellImageValue(cc, 0);%[0 0 0]);
%                     fprintf('Toggled cell to false\n');
                end
            end
        end
        
        function setCellImageValue(cellCoord, vertexType)
            Obj = MapEditor.GetSetInstance();
            
            % vertex type indicates color and alpha
            switch(vertexType)
                case Obj.NODE_TYPE_SIDEWALK
                    rgbTriplet = [0 1 1];
                    alphaVal = 0.5;
                case Obj.NODE_TYPE_ROAD
                    rgbTriplet = [1 1 0.5];
                    alphaVal = 0.5;
                case Obj.NODE_TYPE_ENTRANCE
                    rgbTriplet = [0.5 1 0.5];
                    alphaVal = 0.5;
                case Obj.NODE_TYPE_EXIT
                    rgbTriplet = [1 0.5 0.5];
                    alphaVal = 0.5;
                otherwise
                    rgbTriplet = [0 0 0];
                    alphaVal = 0;
            end
            
            ppv = Obj.m_PixelsPerVertex;
            startRow = (cellCoord(2) - 1) * ppv + 1;
            stopRow = startRow + ppv - 1;
            startCol = (cellCoord(1) - 1) * ppv + 1;
            stopCol = startCol + ppv - 1;
            
            Obj.m_CellImageAlpha(startRow:stopRow, startCol:stopCol) = alphaVal;
            
            rgbChunk = ones(stopRow - startRow + 1, ...
                            stopCol - startCol + 1, ...
                            3);
            rgbChunk(:,:,1) = rgbTriplet(1);
            rgbChunk(:,:,2) = rgbTriplet(2);
            rgbChunk(:,:,3) = rgbTriplet(3);
            
            Obj.m_CellImage(startRow:stopRow, startCol:stopCol, :) = rgbChunk;
            
            set(Obj.m_CellImageHandle, 'AlphaData', Obj.m_CellImageAlpha);
            set(Obj.m_CellImageHandle, 'CData', Obj.m_CellImage);
        end
        
        function [plotCoord, cellCoord] = calcCellCoord(coordIn)
            Obj = MapEditor.GetSetInstance();
            ppv = Obj.m_PixelsPerVertex;
            myCoord = coordIn(1,1:2); % strip z component and any other points passed in
            
%             fprintf('(%f, %f)\n', myCoord(1), myCoord(2));
            
            % compute cell coordinate
            szCellFlags = size(Obj.m_CellFlags);
            cellCoord = ceil((myCoord - 0.5) / ppv);
            
            % constrain to be valid cell
            cellCoord(cellCoord < 1) = 1;
            if(cellCoord(2) > szCellFlags(1))
                cellCoord(2) = szCellFlags(1);
            end
            if(cellCoord(1) > szCellFlags(2))
                cellCoord(1) = szCellFlags(2);
            end
            
            % compute plotting coordinate
            plotCoord = MapEditor.cellCoord2PlotCoord(cellCoord);
        end
        
        function plotCoord = cellCoord2PlotCoord(cellCoord)
            Obj = MapEditor.GetSetInstance();
            ppv = Obj.m_PixelsPerVertex;
            plotCoord = (cellCoord - 1) * ppv + (ppv / 2) + 0.5;
        end
        
        function dragFcnToggle(srcObj, eventData, startIt)
            Obj = MapEditor.GetSetInstance();
            if(startIt)
                % turn on callback for windowbuttonmotionfcn
                set(Obj.m_Handles.figureMain, 'WindowButtonMotionFcn', @MapEditor.axisButtonDown);
            else
                % turn off
                set(Obj.m_Handles.figureMain, 'WindowButtonMotionFcn', '');
            end
        end
        
        function handleKeyPress(srcObj, eventData)
            Obj = MapEditor.GetSetInstance();
            if(strcmpi(eventData.Character, 'n'))
                MapEditor.radMouseNone_Callback();
                Obj.m_Handles.radMouseNone.Value = 1;
            elseif(strcmpi(eventData.Character, 'v'))
                MapEditor.radMousePan_Callback();
                Obj.m_Handles.radMousePan.Value = 1;
            elseif(strcmpi(eventData.Character, 's'))
                MapEditor.radMouseAddSidewalkVertex_Callback();
                Obj.m_Handles.radMouseAddVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'r'))
                MapEditor.radMouseAddRoadVertex_Callback();
                Obj.m_Handles.radMouseAddRoadVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'e'))
                MapEditor.radMouseAddEntranceVertex_Callback();
                Obj.m_Handles.radMouseAddEntranceVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'x'))
                MapEditor.radMouseAddExitVertex_Callback();
                Obj.m_Handles.radMouseAddExitVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'z'))
                MapEditor.radMouseRemVertex_Callback();
                Obj.m_Handles.radMouseRemVertex.Value = 1;
            end
        end

        
        
    end
    
end
