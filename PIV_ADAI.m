function PIV_ADAI()
%PIV_ADAI  Image velocimetry and tracking of firebrands and particles.
%
%   PIV_ADAI opens a graphical user interface for the analysis of
%   firebrands (or any bright or dark particles) recorded in laboratory
%   and field fire experiments.
%
%   Developed at ADAI (Associacao para o Desenvolvimento da Aerodinamica
%   Industrial) and CEIF (Centro de Estudos sobre Incendios Florestais),
%   Department of Mechanical Engineering, University of Coimbra, Portugal.
%
%   Main features
%     * Image sequences of unlimited length (frames are read from disk on
%       demand) or video files (AVI, MP4, MOV, MJ2, ...)
%     * Automatic OR manual brightness / contrast / gamma, CLAHE, histogram
%       equalisation, background subtraction, filtering, colour channel
%     * Automatic (Otsu, mean + k*std), manual or adaptive thresholding,
%       size filters and user-drawn region of interest (rectangle/polygon)
%     * Particle tracking velocimetry (PTV): trajectories, velocity,
%       direction, size, travel distance of every firebrand
%     * Particle image velocimetry (PIV) with user-defined interrogation
%       area size and overlap, sub-pixel Gaussian peak fit and normalised
%       median-test validation
%     * Post-processing: vector fields, speed maps, streamlines, direction
%       rose, speed and size distributions, number-density maps and time
%       series
%     * Export: CSV tables, MAT file, JSON settings, 300-dpi figures and
%       annotated frame sequences
%
%   Requirements: MATLAB R2021a or newer + Image Processing Toolbox.
%
%   Author : MohammadReza Modarres
%            ADAI / CEIF - Centro de Estudos sobre Incendios Florestais,
%            University of Coimbra (mohammad@adai.pt)
%   Licence: MIT (see LICENSE)

APP.name    = 'PIV_ADAI';
APP.version = '1.0.0';
APP.author  = 'MohammadReza Modarres';
APP.affil   = 'ADAI  |  CEIF - Centro de Estudos sobre Incendios Florestais  |  University of Coimbra';
appDir = fileparts(mfilename('fullpath'));
if ~isempty(appDir)
    addpath(appDir);
end

checkRequirements();

S = initState();
P = defaultParams();
H = struct();
H.ctrl = struct();
H.sld  = struct();

buildUI();
updateEnable();
showSplash();

%% =====================================================================
%  USER INTERFACE
%  =====================================================================
    function buildUI()
        H.fig = uifigure('Name', sprintf('%s v%s  |  ADAI - CEIF, University of Coimbra', APP.name, APP.version), ...
            'Position', [40 40 1500 920], 'Color', [0.96 0.96 0.97], ...
            'CloseRequestFcn', @onClose, 'WindowKeyPressFcn', @onKey);

        main = uigridlayout(H.fig, [2 2]);
        main.RowHeight   = {104, '1x'};
        main.ColumnWidth = {410, '1x'};
        main.Padding = [8 8 8 8];
        main.RowSpacing = 6;
        main.ColumnSpacing = 8;

        % ---------------- header -----------------------------------------
        hdr = uigridlayout(main, [1 3]);
        hdr.Layout.Row = 1;
        hdr.Layout.Column = [1 2];
        hdr.ColumnWidth = {300, '1x', 190};
        hdr.Padding = [6 2 6 2];
        hdr.BackgroundColor = [1 1 1];

        % PIV_ADAI logo, with the ADAI and CEIF logos small below it
        lg = uigridlayout(hdr, [2 1]);
        lg.RowHeight = {'1x', 30};
        lg.Padding = [0 2 0 2];
        lg.RowSpacing = 2;
        lg.BackgroundColor = [1 1 1];
        addLogo(lg, 'piv_adai_logo.png', 'PIV_ADAI');
        sm = uigridlayout(lg, [1 3]);
        sm.ColumnWidth = {62, 26, '1x'};
        sm.Padding = [6 0 0 0];
        sm.ColumnSpacing = 6;
        sm.BackgroundColor = [1 1 1];
        addLogo(sm, 'adai_logo.png', 'ADAI');
        addLogo(sm, 'ceif_logo.png', 'CEIF');
        uilabel(sm, 'Text', 'ADAI | CEIF - University of Coimbra', 'FontSize', 10, ...
            'FontColor', [0.69 0.33 0.11]);
        try
            H.fig.Icon = fullfile(appDir, 'logo', 'piv_adai_icon.png');
        catch
        end

        tg = uigridlayout(hdr, [2 1]);
        tg.RowHeight = {'1x', '1x'};
        tg.Padding = [4 6 4 6];
        tg.RowSpacing = 0;
        tg.BackgroundColor = [1 1 1];
        uilabel(tg, 'Text', [APP.name ' - image velocimetry and tracking of firebrands and particles (PIV / PTV)'], ...
            'FontSize', 18, 'FontWeight', 'bold', 'FontColor', [0.16 0.16 0.19]);
        uilabel(tg, 'Text', [APP.affil '   |   ' APP.author], ...
            'FontSize', 12, 'FontColor', [0.72 0.09 0.07]);

        rg0 = uigridlayout(hdr, [2 1]);
        rg0.Padding = [4 8 4 8];
        rg0.BackgroundColor = [1 1 1];
        uilabel(rg0, 'Text', sprintf('Version %s', APP.version), 'HorizontalAlignment', 'right', ...
            'FontColor', [0.4 0.4 0.4]);
        uibutton(rg0, 'Text', 'About / How to cite', 'ButtonPushedFcn', @onAbout);

        % ---------------- left: settings tabs -----------------------------
        H.tabs = uitabgroup(main);
        H.tabs.Layout.Row = 2;
        H.tabs.Layout.Column = 1;
        buildInputTab();
        buildImageTab();
        buildDetectTab();
        buildAnalysisTab();
        buildResultsTab();

        % ---------------- right: viewer -----------------------------------
        rg = uigridlayout(main, [3 1]);
        rg.Layout.Row = 2;
        rg.Layout.Column = 2;
        rg.RowHeight = {'1x', 36, 22};
        rg.Padding = [0 0 0 0];
        rg.RowSpacing = 4;

        H.viewTabs = uitabgroup(rg);
        H.tabImg   = uitab(H.viewTabs, 'Title', 'Image view');
        H.tabStats = uitab(H.viewTabs, 'Title', 'Statistics');
        g1 = uigridlayout(H.tabImg, [1 1]);   g1.Padding = [2 2 2 2];
        g2 = uigridlayout(H.tabStats, [1 1]); g2.Padding = [8 8 8 8];
        H.ax  = uiaxes(g1);
        H.axS = uiaxes(g2);

        bar = uigridlayout(rg, [1 6]);
        bar.ColumnWidth = {44, 70, 44, '1x', 140, 300};
        bar.Padding = [0 0 0 0];
        bar.ColumnSpacing = 6;
        uibutton(bar, 'Text', '<', 'Tooltip', 'Previous frame (left arrow)', ...
            'ButtonPushedFcn', @(s,e) setFrame(S.current - P.frameStep));
        H.playBtn = uibutton(bar, 'Text', 'Play', 'ButtonPushedFcn', @onPlay);
        uibutton(bar, 'Text', '>', 'Tooltip', 'Next frame (right arrow)', ...
            'ButtonPushedFcn', @(s,e) setFrame(S.current + P.frameStep));
        H.frameSlider = uislider(bar, 'Limits', [1 2], 'Value', 1, 'MajorTicks', [], ...
            'MinorTicks', [], 'ValueChangedFcn', @(s,e) setFrame(s.Value));
        H.frameLbl = uilabel(bar, 'Text', 'Frame - / -', 'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold');
        vg = uibuttongroup(bar, 'BorderType', 'none');
        items = {'Raw', 'Processed', 'Binary'};
        xs = [4 70 170];
        for i = 1:3
            rb = uiradiobutton(vg, 'Text', items{i}, 'Position', [xs(i) 6 95 22]);
            if strcmp(items{i}, P.viewMode)
                vg.SelectedObject = rb;
            end
        end
        vg.SelectionChangedFcn = @(s,e) onParam('viewMode', e.NewValue.Text);
        H.ctrl.viewMode = vg;

        H.status = uilabel(rg, 'Text', 'Ready.', 'FontColor', [0.25 0.25 0.3]);
    end

    function buildInputTab()
        gp = makeTab('1 Input');
        secHdr(gp, 'Image source');
        btnRow(gp, {'Image folder...', 'Select images...', 'Video file...'}, ...
            {@onLoadFolder, @onSelectFiles, @onLoadVideo});
        H.info = infoLabel(gp, 58, 'No data loaded. Load a whole folder or pick individual images (Ctrl/Shift-click). Frames are read from disk when needed, so the number of images is unlimited.');
        secHdr(gp, 'Image list');
        r = nextRow(gp, 26);
        lbl(gp, r, 'Filename filter (e.g. *.tif; img_02*)');
        fsub = uigridlayout(gp, [1 2]);
        fsub.ColumnWidth = {'1x', 60};
        fsub.Padding = [0 0 0 0];
        fsub.Layout.Row = r;
        fsub.Layout.Column = 2;
        H.filterFld = uieditfield(fsub, 'text', 'Placeholder', '*', 'ValueChangedFcn', @onApplyFilter);
        uibutton(fsub, 'Text', 'Apply', 'ButtonPushedFcn', @onApplyFilter);
        r = nextRow(gp, 170);
        H.fileList = uilistbox(gp, 'Items', {}, 'Multiselect', 'on', 'ValueChangedFcn', @onListSelect);
        H.fileList.Layout.Row = r;
        H.fileList.Layout.Column = [1 2];
        btnRow(gp, {'Keep selected only', 'Remove selected'}, {@onKeepSelected, @onRemoveSelected});
        btnRow(gp, {'Add images...', 'Restore full list'}, {@onAddFiles, @onRestoreAll});
        secHdr(gp, 'Frame range');
        numField(gp, 'First frame', 'frameStart', [1 Inf]);
        numField(gp, 'Last frame', 'frameEnd', [1 Inf]);
        numField(gp, 'Frame step', 'frameStep', [1 Inf]);
        secHdr(gp, 'Time');
        radioGroup(gp, 'Time base', {'Frame rate (fps)', 'Time step dt (s)'}, 'timeMode');
        numField(gp, 'Frame rate (fps)', 'fps', [1e-9 Inf]);
        numField(gp, 'Time step dt (s)', 'dt', [1e-15 Inf]);
        secHdr(gp, 'Spatial calibration');
        radioGroup(gp, 'Units', {'Pixels (uncalibrated)', 'Calibrated (mm)'}, 'units');
        numField(gp, 'Scale (mm / pixel)', 'scale', [1e-12 Inf]);
        numField(gp, 'Known length for line (mm)', 'calibLength', [1e-12 Inf]);
        c = btnRow(gp, {'Calibrate by drawing a line on the image'}, {@onCalibrate});
        H.calBtn = c{1};
        secHdr(gp, 'Region of interest (ROI)');
        btnRow(gp, {'Rectangle', 'Polygon', 'Clear ROI'}, {@onRoiRect, @onRoiPoly, @onRoiClear});
        infoLabel(gp, 40, 'Only objects and interrogation areas inside the ROI are analysed. Use the axes toolbar to zoom/pan.');
    end

    function buildImageTab()
        gp = makeTab('2 Image');
        btnRow(gp, {'Apply recommended automatic settings'}, {@onAutoSettings});
        secHdr(gp, 'Colour channel and background');
        ddField(gp, 'Channel', {'Grayscale', 'Red', 'Green', 'Blue', 'Max(RGB)'}, 'channel', false);
        ddField(gp, 'Background removal', {'None', 'Top-hat (local, per frame)', 'Median (bright particles)', ...
            'Mean (bright particles)', 'Minimum (bright particles)', 'Median (dark particles)', ...
            'Absolute difference (median)'}, 'bgMode', false);
        numField(gp, 'Top-hat radius (px, > largest particle radius)', 'tophatRadius', [1 500]);
        numField(gp, 'Frames used for sequence background', 'bgFrames', [2 5000]);
        infoLabel(gp, 54, ['Top-hat removes uneven illumination frame by frame. Sequence backgrounds ' ...
            '(median/mean/min) remove static bright objects but need many frames.']);
        chkField(gp, 'Invert image (dark particles on bright background)', 'invert');
        numField(gp, 'Median filter size (px, 0 = off)', 'medianSize', [0 25]);
        numField(gp, 'Gaussian smoothing sigma (px, 0 = off)', 'gaussSigma', [0 20]);
        secHdr(gp, 'Brightness and contrast');
        radioGroup(gp, 'Adjustment', {'Automatic', 'Manual'}, 'contrastMode');
        ddField(gp, 'Automatic method', {'Stretch limits', 'CLAHE (adaptive)', 'Histogram equalization', 'None'}, 'autoMethod', false);
        numField(gp, 'Saturated pixels for stretch (%)', 'saturation', [0 20]);
        sliderField(gp, 'Brightness', 'brightness', [-1 1]);
        sliderField(gp, 'Contrast', 'contrast', [0.1 5]);
        sliderField(gp, 'Gamma', 'gamma', [0.2 3]);
        c = btnRow(gp, {'Reset manual values'}, {@onResetManual});
        H.resetBtn = c{1};
    end

    function buildDetectTab()
        gp = makeTab('3 Detect');
        radioGroup(gp, 'Threshold', {'Automatic (robust noise level)', 'Automatic (Otsu)', ...
            'Automatic (mean + k*std)', 'Manual', 'Adaptive (local)'}, 'threshMode');
        numField(gp, 'k for robust noise level (x sigma)', 'kNoise', [0.5 50]);
        numField(gp, 'Otsu multiplier', 'otsuFactor', [0.05 10]);
        numField(gp, 'k for mean + k*std', 'kStd', [0 50]);
        sliderField(gp, 'Manual level', 'threshLevel', [0 1]);
        sliderField(gp, 'Adaptive sensitivity', 'adaptSens', [0 1]);
        secHdr(gp, 'Object filters');
        numField(gp, 'Minimum area (px^2)', 'minArea', [1 Inf]);
        numField(gp, 'Maximum area (px^2)', 'maxArea', [1 Inf]);
        numField(gp, 'Opening radius (px, 0 = off)', 'openRadius', [0 20]);
        chkField(gp, 'Fill holes inside objects', 'fillHoles');
        chkField(gp, 'Remove objects touching the image border', 'clearBorder');
        chkField(gp, 'Intensity-weighted centroid (sub-pixel)', 'weightedCentroid');
        btnRow(gp, {'Preview detection on current frame'}, {@onPreviewDetection});
        H.detInfo = infoLabel(gp, 40, '');
    end

    function buildAnalysisTab()
        gp = makeTab('4 Analyse');
        radioGroup(gp, 'Analysis mode', {'Detection only (statistics)', 'PTV - track individual firebrands', ...
            'PIV - cross-correlation field', 'PTV + PIV'}, 'mode');
        secHdr(gp, 'PTV - particle tracking');
        numField(gp, 'Max displacement per step (px)', 'maxDisp', [0.1 Inf]);
        numField(gp, 'Minimum track length (frames)', 'minTrackLen', [2 Inf]);
        numField(gp, 'Maximum gap (frames)', 'maxGap', [0 20]);
        chkField(gp, 'Use velocity prediction for linking', 'usePrediction');
        secHdr(gp, 'PIV - interrogation areas');
        ddField(gp, 'Interrogation area size (px)', {'16', '24', '32', '48', '64', '96', '128'}, 'iaSize', true);
        ddField(gp, 'Overlap (%)', {'0', '25', '50', '75'}, 'overlap', true);
        ddField(gp, 'Passes (window offset)', {'1', '2', '3'}, 'pivPasses', true);
        numField(gp, 'Frame separation in a pair', 'pivPairStep', [1 1000]);
        numField(gp, 'Minimum IA intensity std', 'minIAStd', [0 1]);
        numField(gp, 'Median-test threshold', 'medianThr', [0.5 20]);
        chkField(gp, 'Replace outliers by neighbour median', 'replaceOutliers');
        chkField(gp, 'Show interrogation-area grid on image', 'showGrid');
        secHdr(gp, 'Run');
        c = btnRow(gp, {'RUN ANALYSIS'}, {@onRun});
        c{1}.BackgroundColor = [0.72 0.09 0.07];
        c{1}.FontColor = [1 1 1];
        c{1}.FontWeight = 'bold';
        H.runInfo = infoLabel(gp, 40, 'The progress window has a Cancel button; results up to that frame are kept.');
    end

    function buildResultsTab()
        gp = makeTab('5 Results');
        radioGroup(gp, 'Image overlay', {'None', 'Detections', 'Trajectories', 'PTV velocity vectors', ...
            'PIV vectors (current pair)', 'PIV vectors (time-mean)', 'Velocity magnitude map (time-mean)', ...
            'Streamlines (time-mean)', 'Number density map'}, 'overlay');
        radioGroup(gp, 'Statistics plot', {'Direction rose', 'Speed histogram', 'Size distribution', ...
            'Count vs time', 'Mean speed vs time', 'u-v scatter'}, 'statPlot');
        ddField(gp, 'Colormap', {'turbo', 'jet', 'parula', 'hot', 'hsv', 'gray'}, 'cmap', false);
        numField(gp, 'Vector scale (x displacement / frame)', 'vecScale', [0.01 1000]);
        numField(gp, 'Streamline seeds per side', 'streamDensity', [2 200]);
        numField(gp, 'Grid bins across width (maps)', 'gridBins', [2 500]);
        secHdr(gp, 'Summary');
        r = nextRow(gp, 170);
        H.summary = uitextarea(gp, 'Editable', 'off', 'Value', {'No results yet.'}, 'FontName', 'Consolas');
        H.summary.Layout.Row = r;
        H.summary.Layout.Column = [1 2];
        secHdr(gp, 'Export');
        btnRow(gp, {'Export CSV tables...', 'Save MAT results...'}, {@onExportCSV, @onSaveMAT});
        btnRow(gp, {'Save current figure...', 'Export annotated frames...'}, {@onSaveFigure, @onExportFrames});
        btnRow(gp, {'Save settings (JSON)...', 'Load settings (JSON)...'}, {@onSaveSettings, @onLoadSettings});
    end

%% ---------------------------------------------------------------------
%  UI helpers
%  ---------------------------------------------------------------------
    function addLogo(parent, file, fallback)
        lf = fullfile(appDir, 'logo', file);
        if isfile(lf)
            uiimage(parent, 'ImageSource', lf, 'ScaleMethod', 'fit');
        else
            uilabel(parent, 'Text', fallback, 'FontWeight', 'bold', 'FontSize', 14, ...
                'HorizontalAlignment', 'center', 'FontColor', [0.10 0.09 0.43]);
        end
    end

    function gp = makeTab(title)
        t = uitab(H.tabs, 'Title', title);
        gp = uigridlayout(t, [1 2]);
        gp.ColumnWidth = {185, '1x'};
        gp.RowSpacing = 5;
        gp.Padding = [8 8 8 8];
        gp.Scrollable = 'on';
        gp.UserData = 0;
    end

    function r = nextRow(gp, hgt)
        r = gp.UserData + 1;
        gp.UserData = r;
        rh = gp.RowHeight;
        rh{r} = hgt;
        gp.RowHeight = rh;
    end

    function secHdr(gp, txt)
        r = nextRow(gp, 26);
        l = uilabel(gp, 'Text', txt, 'FontWeight', 'bold', 'FontColor', [0.72 0.09 0.07], ...
            'VerticalAlignment', 'bottom');
        l.Layout.Row = r;
        l.Layout.Column = [1 2];
    end

    function lbl(gp, r, txt)
        l = uilabel(gp, 'Text', txt, 'WordWrap', 'on');
        l.Layout.Row = r;
        l.Layout.Column = 1;
    end

    function h = infoLabel(gp, hgt, txt)
        r = nextRow(gp, hgt);
        h = uilabel(gp, 'Text', txt, 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
            'FontColor', [0.3 0.3 0.35]);
        h.Layout.Row = r;
        h.Layout.Column = [1 2];
    end

    function hs = btnRow(gp, labels, cbs)
        r = nextRow(gp, 28);
        n = numel(labels);
        sub = uigridlayout(gp, [1 n]);
        sub.Padding = [0 0 0 0];
        sub.ColumnSpacing = 6;
        sub.Layout.Row = r;
        sub.Layout.Column = [1 2];
        hs = cell(1, n);
        for i = 1:n
            hs{i} = uibutton(sub, 'Text', labels{i}, 'ButtonPushedFcn', cbs{i});
        end
    end

    function h = numField(gp, txt, tag, lims)
        r = nextRow(gp, 24);
        lbl(gp, r, txt);
        h = uieditfield(gp, 'numeric', 'Value', P.(tag), 'Limits', lims, ...
            'ValueChangedFcn', @(s,e) onParam(tag, s.Value));
        h.Layout.Row = r;
        h.Layout.Column = 2;
        H.ctrl.(tag) = h;
    end

    function h = ddField(gp, txt, items, tag, isNum)
        r = nextRow(gp, 24);
        lbl(gp, r, txt);
        v = P.(tag);
        if isNum
            v = num2str(v);
        end
        h = uidropdown(gp, 'Items', items, 'Value', v, ...
            'ValueChangedFcn', @(s,e) onParam(tag, ddValue(s.Value, isNum)));
        h.Layout.Row = r;
        h.Layout.Column = 2;
        H.ctrl.(tag) = h;
    end

    function h = chkField(gp, txt, tag)
        r = nextRow(gp, 24);
        h = uicheckbox(gp, 'Text', txt, 'Value', P.(tag), ...
            'ValueChangedFcn', @(s,e) onParam(tag, s.Value));
        h.Layout.Row = r;
        h.Layout.Column = [1 2];
        H.ctrl.(tag) = h;
    end

    function h = sliderField(gp, txt, tag, lims)
        r = nextRow(gp, 46);
        l = uilabel(gp, 'Text', sprintf('%s: %.2f', txt, P.(tag)));
        l.Layout.Row = r;
        l.Layout.Column = 1;
        h = uislider(gp, 'Limits', lims, 'Value', P.(tag), ...
            'ValueChangingFcn', @(s,e) set(l, 'Text', sprintf('%s: %.2f', txt, e.Value)), ...
            'ValueChangedFcn', @(s,e) sliderChanged(s, l, txt, tag));
        h.Layout.Row = r;
        h.Layout.Column = 2;
        H.ctrl.(tag) = h;
        H.sld.(tag) = {l, txt};
    end

    function sliderChanged(s, l, txt, tag)
        l.Text = sprintf('%s: %.2f', txt, s.Value);
        onParam(tag, s.Value);
    end

    function bg = radioGroup(gp, title, items, tag)
        n = numel(items);
        r = nextRow(gp, 24*n + 30);
        bg = uibuttongroup(gp, 'Title', title);
        bg.Layout.Row = r;
        bg.Layout.Column = [1 2];
        for i = 1:n
            rb = uiradiobutton(bg, 'Text', items{i}, 'Position', [10, 24*(n-i) + 6, 340, 22]);
            if strcmp(items{i}, P.(tag))
                bg.SelectedObject = rb;
            end
        end
        bg.SelectionChangedFcn = @(s,e) onParam(tag, e.NewValue.Text);
        H.ctrl.(tag) = bg;
    end

    function syncControls()
        fn = fieldnames(H.ctrl);
        for k = 1:numel(fn)
            tag = fn{k};
            h = H.ctrl.(tag);
            v = P.(tag);
            if isa(h, 'matlab.ui.container.ButtonGroup')
                rb = findobj(h.Children, 'flat', 'Text', v);
                if ~isempty(rb)
                    h.SelectedObject = rb(1);
                end
            elseif isa(h, 'matlab.ui.control.DropDown')
                if isnumeric(v)
                    v = num2str(v);
                end
                if any(strcmp(h.Items, v))
                    h.Value = v;
                end
            elseif isa(h, 'matlab.ui.control.Slider')
                h.Value = min(max(v, h.Limits(1)), h.Limits(2));
                if isfield(H.sld, tag)
                    H.sld.(tag){1}.Text = sprintf('%s: %.2f', H.sld.(tag){2}, h.Value);
                end
            elseif isa(h, 'matlab.ui.control.NumericEditField')
                h.Value = min(max(v, h.Limits(1)), h.Limits(2));
            elseif isa(h, 'matlab.ui.control.CheckBox')
                h.Value = logical(v);
            end
        end
    end

    function updateEnable()
        c = H.ctrl;
        isAuto = strcmp(P.contrastMode, 'Automatic');
        setEn({c.autoMethod, c.saturation}, isAuto);
        setEn({c.brightness, c.contrast, c.gamma, H.resetBtn}, ~isAuto);
        setEn({c.otsuFactor}, strcmp(P.threshMode, 'Automatic (Otsu)'));
        setEn({c.kNoise}, strcmp(P.threshMode, 'Automatic (robust noise level)'));
        setEn({c.tophatRadius}, startsWith(P.bgMode, 'Top-hat'));
        setEn({c.kStd}, strcmp(P.threshMode, 'Automatic (mean + k*std)'));
        setEn({c.threshLevel}, strcmp(P.threshMode, 'Manual'));
        setEn({c.adaptSens}, strcmp(P.threshMode, 'Adaptive (local)'));
        setEn({c.fps}, startsWith(P.timeMode, 'Frame'));
        setEn({c.dt}, ~startsWith(P.timeMode, 'Frame'));
        setEn({c.bgFrames}, ~strcmp(P.bgMode, 'None') && ~startsWith(P.bgMode, 'Top-hat'));
        doPTV = startsWith(P.mode, 'PTV');
        doPIV = contains(P.mode, 'PIV');
        setEn({c.maxDisp, c.minTrackLen, c.maxGap, c.usePrediction}, doPTV);
        setEn({c.iaSize, c.overlap, c.pivPasses, c.pivPairStep, c.minIAStd, c.medianThr, c.replaceOutliers}, doPIV);
    end

    function setStatus(msg)
        if isfield(H, 'status') && isvalid(H.status)
            H.status.Text = msg;
            drawnow limitrate;
        end
    end

    function showSplash()
        ax = H.ax;
        cla(ax);
        bf = fullfile(appDir, 'logo', 'piv_adai_banner.png');
        if isfile(bf)
            image(ax, imread(bf));
            axis(ax, 'image');
        else
            text(ax, 0.5, 0.6, 'PIV\_ADAI', 'Units', 'normalized', 'FontSize', 48, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0.11 0.15 0.43]);
        end
        axis(ax, 'off');
        title(ax, 'Load an image folder or a video in tab "1 Input" to begin', ...
            'FontWeight', 'normal', 'FontSize', 13, 'Color', [0.35 0.35 0.4]);
        plotStats();
    end

%% =====================================================================
%  CALLBACKS
%  =====================================================================
    function onParam(tag, val)
        P.(tag) = val;
        if any(strcmp(tag, {'frameStart', 'frameEnd'})) && S.nFrames > 0
            P.frameStart = min(max(round(P.frameStart), 1), S.nFrames);
            P.frameEnd   = min(max(round(P.frameEnd), 1), S.nFrames);
            if P.frameStart > P.frameEnd
                if strcmp(tag, 'frameStart')
                    P.frameEnd = P.frameStart;
                else
                    P.frameStart = P.frameEnd;
                end
            end
            syncControls();
        end
        updateEnable();

        if strcmp(tag, 'statPlot')
            H.viewTabs.SelectedTab = H.tabStats;
            plotStats();
            return
        end
        if strcmp(tag, 'overlay')
            H.viewTabs.SelectedTab = H.tabImg;
        end
        if any(strcmp(tag, {'units', 'scale', 'cmap', 'gridBins'}))
            updateSummary();
            plotStats();
        end
        analysisTags = {'frameStart', 'frameEnd', 'frameStep', 'timeMode', 'fps', 'dt', 'channel', ...
            'bgMode', 'bgFrames', 'invert', 'medianSize', 'gaussSigma', 'contrastMode', 'autoMethod', ...
            'saturation', 'brightness', 'contrast', 'gamma', 'threshMode', 'kNoise', 'tophatRadius', 'otsuFactor', 'kStd', ...
            'threshLevel', 'adaptSens', 'minArea', 'maxArea', 'openRadius', 'fillHoles', 'clearBorder', ...
            'weightedCentroid', 'mode', 'maxDisp', 'minTrackLen', 'maxGap', 'usePrediction', 'iaSize', ...
            'overlap', 'pivPasses', 'pivPairStep', 'minIAStd', 'medianThr', 'replaceOutliers'};
        if S.results.done && any(strcmp(tag, analysisTags))
            setStatus('Settings changed - press RUN ANALYSIS (tab 4) to update the results.');
        end
        refreshView();
    end

    function onLoadFolder(~, ~)
        folder = uigetdir(S.lastDir, 'Select the folder containing the image sequence');
        figure(H.fig);
        if isequal(folder, 0)
            return
        end
        d = dir(folder);
        d = d(~[d.isdir]);
        names = {d.name};
        [~, ~, e] = cellfun(@fileparts, names, 'UniformOutput', false);
        keep = ismember(lower(strrep(e, '.', '')), imageExts());
        if ~any(keep)
            uialert(H.fig, 'No supported image files were found in this folder.', 'No images');
            return
        end
        files = natSort(fullfile(folder, names(keep))');
        S.lastDir = folder;
        S.allFiles = files;
        H.filterFld.Value = '';
        setImageList(files, sprintf('%d images in %s', numel(files), folder));
    end

    function files = pickImages(titleTxt)
        files = {};
        pat = strjoin(strcat('*.', imageExts()), ';');
        [f, p] = uigetfile({pat, 'Image files'}, titleTxt, S.lastDir, 'MultiSelect', 'on');
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        f = cellstr(f);
        files = natSort(fullfile(p, f(:)));
        S.lastDir = p;
    end

    function onSelectFiles(~, ~)
        files = pickImages('Select images (Ctrl/Shift-click to select several)');
        if isempty(files)
            return
        end
        S.allFiles = files;
        H.filterFld.Value = '';
        setImageList(files, sprintf('%d selected images in %s', numel(files), S.lastDir));
    end

    function onAddFiles(~, ~)
        if ~strcmp(S.source, 'images')
            onSelectFiles();
            return
        end
        files = pickImages('Add images to the list');
        if isempty(files)
            return
        end
        S.allFiles = natSort(unique([S.allFiles(:); files(:)]));
        setImageList(natSort(unique([S.files(:); files(:)])), ...
            sprintf('%d images (list edited)', numel(unique([S.files(:); files(:)]))));
    end

    function onKeepSelected(~, ~)
        idx = H.fileList.Value;
        if ~strcmp(S.source, 'images') || isempty(idx)
            uialert(H.fig, 'Select one or more images in the list first (Ctrl/Shift-click).', 'Image list');
            return
        end
        setImageList(S.files(idx), sprintf('%d images selected from the list', numel(idx)));
    end

    function onRemoveSelected(~, ~)
        idx = H.fileList.Value;
        if ~strcmp(S.source, 'images') || isempty(idx)
            uialert(H.fig, 'Select one or more images in the list first (Ctrl/Shift-click).', 'Image list');
            return
        end
        keep = true(numel(S.files), 1);
        keep(idx) = false;
        if ~any(keep)
            uialert(H.fig, 'At least one image must remain in the list.', 'Image list');
            return
        end
        setImageList(S.files(keep), sprintf('%d images (%d removed)', nnz(keep), numel(idx)));
    end

    function onRestoreAll(~, ~)
        if ~strcmp(S.source, 'images') || isempty(S.allFiles)
            return
        end
        H.filterFld.Value = '';
        setImageList(S.allFiles, sprintf('%d images (full list)', numel(S.allFiles)));
    end

    function onApplyFilter(~, ~)
        if ~strcmp(S.source, 'images') || isempty(S.allFiles)
            return
        end
        pat = strtrim(H.filterFld.Value);
        if isempty(pat) || strcmp(pat, '*')
            onRestoreAll();
            return
        end
        parts = strtrim(strsplit(pat, ';'));
        parts = parts(~cellfun(@isempty, parts));
        rx = strjoin(cellfun(@(q) ['^' regexptranslate('wildcard', q) '$'], parts, ...
            'UniformOutput', false), '|');
        [~, n, e] = cellfun(@fileparts, S.allFiles, 'UniformOutput', false);
        m = ~cellfun(@isempty, regexpi(strcat(n, e), rx, 'once'));
        if ~any(m)
            uialert(H.fig, sprintf('No file name matches "%s".', pat), 'Filter');
            return
        end
        setImageList(S.allFiles(m), sprintf('%d images match "%s"', nnz(m), pat));
    end

    function onListSelect(src, ~)
        v = src.Value;
        if isnumeric(v) && numel(v) == 1 && strcmp(S.source, 'images')
            setFrame(v);
        end
    end

    function setImageList(files, desc)
        S.source = 'images';
        S.files = files(:);
        S.vr = [];
        S.nFrames = numel(S.files);
        afterLoad(desc);
        updateFileList();
    end

    function updateFileList()
        if strcmp(S.source, 'images') && ~isempty(S.files)
            [~, n, e] = cellfun(@fileparts, S.files, 'UniformOutput', false);
            set(H.fileList, 'Items', strcat(n, e)', 'ItemsData', 1:numel(n));
            try
                H.fileList.Value = zeros(1, 0);
            catch
            end
        else
            set(H.fileList, 'Items', {}, 'ItemsData', []);
        end
    end

    function onLoadVideo(~, ~)
        [f, p] = uigetfile({'*.avi;*.mp4;*.mov;*.mj2;*.wmv;*.m4v;*.mpg', 'Video files'}, ...
            'Select a video file', S.lastDir);
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        try
            vr = VideoReader(fullfile(p, f));
        catch ME
            uialert(H.fig, ME.message, 'Cannot open video');
            return
        end
        S.source = 'video';
        S.vr = vr;
        S.files = {};
        S.allFiles = {};
        S.lastDir = p;
        S.nFrames = vr.NumFrames;
        P.fps = vr.FrameRate;
        P.timeMode = 'Frame rate (fps)';
        afterLoad(sprintf('Video %s (%d frames, %.2f fps)', f, S.nFrames, vr.FrameRate));
        updateFileList();
    end

    function afterLoad(desc)
        try
            I = getRaw(1);
        catch ME
            uialert(H.fig, ME.message, 'Cannot read first frame');
            return
        end
        oldSize = S.imSize;
        S.imSize = [size(I, 1) size(I, 2)];
        if strcmp(S.source, 'images') && S.nFrames > 1
            try
                inf2 = imfinfo(S.files{end});
                if ~isequal([inf2(1).Height inf2(1).Width], S.imSize)
                    uialert(H.fig, ['The images in the list do not all have the same size. ' ...
                        'Use the filter or the list to keep images of one size only.'], ...
                        'Different image sizes', 'Icon', 'warning');
                end
            catch
            end
        end
        S.bg = [];
        S.bgKey = '';
        S.results = emptyResults();
        S.current = 1;
        P.frameStart = 1;
        P.frameEnd = S.nFrames;
        if ~isequal(oldSize, S.imSize)
            P.roi = [];
        end
        nLim = max(S.nFrames, 2);
        H.ctrl.frameStart.Limits = [1 nLim];
        H.ctrl.frameEnd.Limits = [1 nLim];
        H.frameSlider.Limits = [1 nLim];
        if S.nFrames > 1
            H.frameSlider.Enable = 'on';
        else
            H.frameSlider.Enable = 'off';
        end
        H.info.Text = {desc, sprintf('Image size: %d x %d px, %d channel(s), class %s', ...
            S.imSize(2), S.imSize(1), size(I, 3), class(I))};
        cla(H.ax, 'reset');
        S.axReady = false;
        syncControls();
        updateEnable();
        updateSummary();
        plotStats();
        H.viewTabs.SelectedTab = H.tabImg;
        setFrame(1);
        setStatus(['Loaded: ' desc]);
    end

    function setFrame(k)
        if S.nFrames == 0
            return
        end
        k = min(max(round(k), 1), S.nFrames);
        S.current = k;
        H.frameSlider.Value = min(max(k, H.frameSlider.Limits(1)), H.frameSlider.Limits(2));
        H.frameLbl.Text = sprintf('Frame %d / %d', k, S.nFrames);
        refreshView();
    end

    function onPlay(~, ~)
        if S.nFrames == 0
            return
        end
        S.playing = ~S.playing;
        if ~S.playing
            H.playBtn.Text = 'Play';
            return
        end
        H.playBtn.Text = 'Pause';
        while S.playing && isvalid(H.fig)
            nxt = S.current + P.frameStep;
            if nxt > P.frameEnd || nxt < P.frameStart
                nxt = P.frameStart;
            end
            setFrame(nxt);
            drawnow;
            pause(0.02);
        end
        if isvalid(H.fig)
            H.playBtn.Text = 'Play';
        end
    end

    function onKey(~, e)
        switch e.Key
            case 'rightarrow'
                setFrame(S.current + P.frameStep);
            case 'leftarrow'
                setFrame(S.current - P.frameStep);
        end
    end

    function onClose(~, ~)
        S.playing = false;
        delete(H.fig);
    end

    function onCalibrate(~, ~)
        if S.nFrames == 0
            return
        end
        H.viewTabs.SelectedTab = H.tabImg;
        setStatus('Calibration: click the start and the end of an object of known length.');
        try
            L = drawline(H.ax, 'Color', 'y', 'LineWidth', 1.5);
        catch ME
            uialert(H.fig, ['Interactive drawing failed: ' ME.message], 'Calibration');
            return
        end
        if ~isvalid(L) || isempty(L.Position)
            return
        end
        dpx = norm(diff(L.Position));
        delete(L);
        if dpx < 1
            uialert(H.fig, 'The line is too short.', 'Calibration');
            return
        end
        P.scale = P.calibLength / dpx;
        P.units = 'Calibrated (mm)';
        syncControls();
        updateSummary();
        plotStats();
        refreshView();
        setStatus(sprintf('Calibration: %.2f px = %.4g mm  ->  %.6g mm/px', dpx, P.calibLength, P.scale));
    end

    function onRoiRect(~, ~)
        if S.nFrames == 0
            return
        end
        H.viewTabs.SelectedTab = H.tabImg;
        setStatus('ROI: drag a rectangle on the image.');
        try
            r = drawrectangle(H.ax, 'Color', 'c');
        catch ME
            uialert(H.fig, ME.message, 'ROI');
            return
        end
        if ~isvalid(r) || isempty(r.Position)
            return
        end
        p = r.Position;
        delete(r);
        if any(p(3:4) < 2)
            return
        end
        P.roi = [p(1) p(2); p(1)+p(3) p(2); p(1)+p(3) p(2)+p(4); p(1) p(2)+p(4)];
        refreshView();
        setStatus('Rectangular ROI set.');
    end

    function onRoiPoly(~, ~)
        if S.nFrames == 0
            return
        end
        H.viewTabs.SelectedTab = H.tabImg;
        setStatus('ROI: click polygon vertices, double-click (or click the first point) to close.');
        try
            r = drawpolygon(H.ax, 'Color', 'c');
        catch ME
            uialert(H.fig, ME.message, 'ROI');
            return
        end
        if ~isvalid(r) || size(r.Position, 1) < 3
            return
        end
        P.roi = r.Position;
        delete(r);
        refreshView();
        setStatus('Polygon ROI set.');
    end

    function onRoiClear(~, ~)
        P.roi = [];
        refreshView();
        setStatus('ROI cleared - the full image is analysed.');
    end

    function onAutoSettings(~, ~)
        P.contrastMode = 'Automatic';
        P.autoMethod = 'Stretch limits';
        P.saturation = 1;
        P.threshMode = 'Automatic (robust noise level)';
        P.kNoise = 6;
        P.medianSize = 3;
        P.gaussSigma = 0;
        P.bgMode = 'Top-hat (local, per frame)';
        syncControls();
        updateEnable();
        refreshView();
        setStatus('Recommended automatic settings applied. Fine-tune manually if needed.');
    end

    function onResetManual(~, ~)
        P.brightness = 0;
        P.contrast = 1;
        P.gamma = 1;
        syncControls();
        refreshView();
    end

    function onPreviewDetection(~, ~)
        P.overlay = 'Detections';
        syncControls();
        H.viewTabs.SelectedTab = H.tabImg;
        refreshView();
    end

    function onAbout(~, ~)
        msg = sprintf(['%s v%s\n\n' ...
            'Image-based analysis of firebrands and particles: detection, PTV, PIV, ' ...
            'velocity, direction, size, number density and streamlines.\n\n' ...
            'Author: %s\n%s\n' ...
            'ADAI - Associacao para o Desenvolvimento da Aerodinamica Industrial\n' ...
            'CEIF - Centro de Estudos sobre Incendios Florestais\n\n' ...
            'How to cite: %s'], ...
            APP.name, APP.version, APP.author, APP.affil, citeText());
        uialert(H.fig, msg, 'About', 'Icon', 'info');
    end

    function t = citeText()
        doi = readDoi(appDir);
        if isempty(doi)
            doi = 'DOI not assigned yet - see CITATION.cff';
        else
            doi = ['https://doi.org/' doi];
        end
        t = sprintf('%s (2026). %s: image velocimetry and tracking of firebrands and particles (v%s). %s', ...
            APP.author, APP.name, APP.version, doi);
    end

%% =====================================================================
%  IMAGE PIPELINE
%  =====================================================================
    function I = getRaw(k)
        k = min(max(round(k), 1), S.nFrames);
        if strcmp(S.source, 'video')
            I = read(S.vr, k);
        else
            [I, map] = imread(S.files{k});
            if ~isempty(map)
                I = ind2rgb(I, map);
            end
        end
        if size(I, 3) == 4
            I = I(:, :, 1:3);
        elseif size(I, 3) == 2
            I = I(:, :, 1);
        end
    end

    function G = toChannel(I)
        I = im2double(I);
        if size(I, 3) == 3
            switch P.channel
                case 'Red'
                    G = I(:, :, 1);
                case 'Green'
                    G = I(:, :, 2);
                case 'Blue'
                    G = I(:, :, 3);
                case 'Max(RGB)'
                    G = max(I, [], 3);
                otherwise
                    G = rgb2gray(I);
            end
        else
            G = I(:, :, 1);
        end
    end

    function B = getBackground()
        B = [];
        if strcmp(P.bgMode, 'None') || startsWith(P.bgMode, 'Top-hat') || S.nFrames == 0
            return
        end
        if contains(P.bgMode, 'Mean')
            bgType = 'mean';
        elseif contains(P.bgMode, 'Minimum')
            bgType = 'min';
        else
            bgType = 'median';
        end
        key = sprintf('%s|%s|%d|%d|%d|%d', P.channel, bgType, P.frameStart, P.frameEnd, ...
            round(P.bgFrames), S.nFrames);
        if ~isempty(S.bg) && strcmp(S.bgKey, key)
            B = S.bg;
            return
        end
        nUse = min(round(P.bgFrames), P.frameEnd - P.frameStart + 1);
        idx = unique(round(linspace(P.frameStart, P.frameEnd, max(nUse, 1))));
        stack = zeros(S.imSize(1), S.imSize(2), numel(idx), 'single');
        dlg = uiprogressdlg(H.fig, 'Title', 'Computing background', 'Message', ...
            sprintf('Reading %d frames...', numel(idx)));
        for i = 1:numel(idx)
            stack(:, :, i) = single(toChannel(getRaw(idx(i))));
            dlg.Value = i / numel(idx);
        end
        switch bgType
            case 'mean'
                B = mean(stack, 3);
            case 'min'
                B = min(stack, [], 3);
            otherwise
                B = median(stack, 3);
        end
        close(dlg);
        B = double(B);
        S.bg = B;
        S.bgKey = key;
    end

    function J = prepFrame(G)
        J = G;
        if startsWith(P.bgMode, 'Top-hat')
            if P.invert
                J = 1 - J;
            end
            J = imtophat(J, strel('disk', max(1, round(P.tophatRadius))));
            bgRemoved = true;
        else
            B = getBackground();
            bgRemoved = ~isempty(B) && isequal(size(B), size(G));
            if bgRemoved
                switch P.bgMode
                    case 'Median (dark particles)'
                        J = max(B - G, 0);
                    case 'Absolute difference (median)'
                        J = abs(G - B);
                    otherwise
                        J = max(G - B, 0);
                end
            end
            if P.invert
                J = 1 - J;
            end
        end
        if P.medianSize >= 2
            k = round(P.medianSize);
            J = medfilt2(J, [k k], 'symmetric');
        end
        if P.gaussSigma > 0
            J = imgaussfilt(J, P.gaussSigma);
        end
        J = adjustContrast(J, bgRemoved);
    end

    function J = adjustContrast(J, bgRemoved)
        if strcmp(P.contrastMode, 'Automatic')
            switch P.autoMethod
                case 'Stretch limits'
                    tol = P.saturation / 100;
                    lims = stretchlim(J, [tol/2, 1 - tol/2]);
                    if lims(2) > lims(1)
                        J = imadjust(J, lims, []);
                    end
                case 'CLAHE (adaptive)'
                    J = adapthisteq(J);
                case 'Histogram equalization'
                    J = histeq(J);
            end
        else
            if bgRemoved
                J = rescale(J);
            end
            J = (J - 0.5) * P.contrast + 0.5 + P.brightness;
            J = min(max(J, 0), 1);
            if P.gamma ~= 1
                J = J .^ P.gamma;
            end
        end
    end

    function M = getMask(sz)
        if isempty(P.roi)
            M = [];
        else
            M = poly2mask(P.roi(:, 1), P.roi(:, 2), sz(1), sz(2));
        end
    end

    function [BW, D] = detect(J)
        % D columns: 1 x | 2 y | 3 area | 4 eqDiam | 5 major | 6 minor |
        %            7 orientation | 8 meanI | 9 maxI   (pixel units)
        switch P.threshMode
            case 'Automatic (robust noise level)'
                lev = robustLevel(J, P.kNoise);
                BW = J > lev;
            case 'Automatic (Otsu)'
                lev = min(graythresh(J) * P.otsuFactor, 0.999);
                BW = J > lev;
            case 'Automatic (mean + k*std)'
                lev = min(mean(J(:)) + P.kStd * std(J(:)), 0.999);
                BW = J > lev;
            case 'Manual'
                BW = J > P.threshLevel;
            otherwise
                BW = imbinarize(J, 'adaptive', 'Sensitivity', P.adaptSens, 'ForegroundPolarity', 'bright');
        end
        if P.openRadius >= 1
            BW = imopen(BW, strel('disk', round(P.openRadius)));
        end
        if P.fillHoles
            BW = imfill(BW, 'holes');
        end
        M = getMask(size(J));
        if ~isempty(M)
            BW = BW & M;
        end
        if P.clearBorder
            BW = imclearborder(BW);
        end
        BW = bwareafilt(BW, [P.minArea, max(P.maxArea, P.minArea)]);
        st = regionprops(BW, J, 'Area', 'Centroid', 'WeightedCentroid', 'EquivDiameter', ...
            'MajorAxisLength', 'MinorAxisLength', 'Orientation', 'MeanIntensity', 'MaxIntensity');
        if isempty(st)
            D = zeros(0, 9);
            return
        end
        c = vertcat(st.Centroid);
        if P.weightedCentroid
            cw = vertcat(st.WeightedCentroid);
            ok = all(isfinite(cw), 2);
            c(ok, :) = cw(ok, :);
        end
        D = [c(:, 1), c(:, 2), [st.Area]', [st.EquivDiameter]', [st.MajorAxisLength]', ...
            [st.MinorAxisLength]', [st.Orientation]', [st.MeanIntensity]', [st.MaxIntensity]'];
    end

%% =====================================================================
%  ANALYSIS
%  =====================================================================
    function onRun(~, ~)
        if S.nFrames == 0
            uialert(H.fig, 'Load an image sequence or a video first.', 'No data');
            return
        end
        S.playing = false;
        frames = P.frameStart:round(P.frameStep):P.frameEnd;
        nF = numel(frames);
        doPTV = startsWith(P.mode, 'PTV');
        doPIV = contains(P.mode, 'PIV');
        if doPTV && nF < 2
            uialert(H.fig, 'PTV needs at least two frames in the selected range.', 'Too few frames');
            return
        end
        try
            getBackground();
        catch ME
            uialert(H.fig, ME.message, 'Background error');
            return
        end
        dtF = frameDt();
        M = getMask(S.imSize);

        R = emptyResults();
        R.det = cell(nF, 1);
        R.dtF = dtF;
        R.mode = P.mode;
        R.params = P;
        pivU = {};
        pivV = {};
        pivF = [];
        X = [];
        Y = [];
        nTot = 0;
        nOut = 0;
        cacheIdx = -1;
        cacheJ = [];
        lastDone = 0;

        dlg = uiprogressdlg(H.fig, 'Title', 'Analysing sequence', 'Message', 'Starting...', ...
            'Cancelable', 'on');
        try
            t0 = tic;
            for i = 1:nF
                if dlg.CancelRequested
                    break
                end
                f = frames(i);
                if cacheIdx == f
                    J = cacheJ;
                else
                    J = prepFrame(toChannel(getRaw(f)));
                end
                [~, D] = detect(J);
                R.det{i} = D;
                if doPIV
                    f2 = f + round(P.pivPairStep);
                    if f2 <= S.nFrames
                        J2 = prepFrame(toChannel(getRaw(f2)));
                        [X, Y, U, V] = pivCore(J, J2, M, P.iaSize, P.overlap, P.minIAStd, P.pivPasses);
                        nTot = nTot + nnz(~isnan(U));
                        [U, V, no] = medianTest(U, V, P.medianThr, P.replaceOutliers);
                        nOut = nOut + no;
                        pivU{end + 1} = U; %#ok<AGROW>
                        pivV{end + 1} = V; %#ok<AGROW>
                        pivF(end + 1) = f; %#ok<AGROW>
                        cacheIdx = f2;
                        cacheJ = J2;
                    end
                end
                lastDone = i;
                if mod(i, 2) == 0 || i == nF
                    el = toc(t0);
                    dlg.Value = i / nF;
                    dlg.Message = sprintf('Frame %d  (%d of %d)  |  %d objects  |  about %.0f s left', ...
                        f, i, nF, size(D, 1), el / i * (nF - i));
                end
            end
            R.frames = frames(1:lastDone);
            R.det = R.det(1:lastDone);
            trackOf = {};
            if doPTV && lastDone >= 2
                dlg.Message = 'Linking trajectories...';
                dlg.Indeterminate = 'on';
                trackOf = trackParticles(R.det);
            end
            R.A = buildA(R.det, R.frames, trackOf, dtF, P.minTrackLen);
            if ~isempty(pivU)
                R.piv.X = X;
                R.piv.Y = Y;
                R.piv.U = cat(3, pivU{:});
                R.piv.V = cat(3, pivV{:});
                R.piv.frameA = pivF;
                R.piv.pairStep = round(P.pivPairStep);
                R.piv.nTot = nTot;
                R.piv.nOut = nOut;
            end
        catch ME
            close(dlg);
            uialert(H.fig, sprintf('%s\n(%s, line %d)', ME.message, ME.stack(1).name, ME.stack(1).line), ...
                'Analysis error');
            return
        end
        close(dlg);

        R.done = true;
        S.results = R;
        if doPTV
            P.overlay = 'Trajectories';
        elseif doPIV
            P.overlay = 'PIV vectors (time-mean)';
        else
            P.overlay = 'Detections';
        end
        syncControls();
        updateSummary();
        plotStats();
        refreshView();
        setStatus(sprintf('Analysis finished: %d frames, %d detections.', numel(R.frames), size(R.A, 1)));
    end

    function trackOf = trackParticles(det)
        % Greedy nearest-neighbour linking with optional constant-velocity
        % prediction and gap closing. Distances in pixels per analysed step.
        nF = numel(det);
        trackOf = cell(nF, 1);
        nextId = 0;
        aId = zeros(0, 1); aX = aId; aY = aId; aVx = aId; aVy = aId; aLen = aId; aGap = aId;
        for i = 1:nF
            D = det{i};
            n = size(D, 1);
            tid = zeros(n, 1);
            if n > 0 && ~isempty(aId)
                g = aGap + 1;
                if P.usePrediction
                    useV = double(aLen >= 2);
                    pX = aX + aVx .* g .* useV;
                    pY = aY + aVy .* g .* useV;
                else
                    pX = aX;
                    pY = aY;
                end
                Dm = sqrt((pX - D(:, 1)').^2 + (pY - D(:, 2)').^2);
                thr = P.maxDisp .* g;
                Dm(Dm > thr) = Inf;
                [r, c] = find(isfinite(Dm));
                if ~isempty(r)
                    d = Dm(sub2ind(size(Dm), r, c));
                    [~, o] = sort(d);
                    usedR = false(numel(aId), 1);
                    usedC = false(n, 1);
                    for k = o(:)'
                        rr = r(k);
                        cc = c(k);
                        if ~usedR(rr) && ~usedC(cc)
                            usedR(rr) = true;
                            usedC(cc) = true;
                            tid(cc) = aId(rr);
                            aVx(rr) = (D(cc, 1) - aX(rr)) / g(rr);
                            aVy(rr) = (D(cc, 2) - aY(rr)) / g(rr);
                            aX(rr) = D(cc, 1);
                            aY(rr) = D(cc, 2);
                            aLen(rr) = aLen(rr) + 1;
                            aGap(rr) = -1;
                        end
                    end
                end
            end
            aGap = aGap + 1;
            keep = aGap <= P.maxGap;
            aId = aId(keep); aX = aX(keep); aY = aY(keep);
            aVx = aVx(keep); aVy = aVy(keep); aLen = aLen(keep); aGap = aGap(keep);
            newIdx = find(tid == 0);
            m = numel(newIdx);
            if m > 0
                ids = nextId + (1:m)';
                nextId = nextId + m;
                tid(newIdx) = ids;
                aId = [aId; ids]; %#ok<AGROW>
                aX = [aX; D(newIdx, 1)]; %#ok<AGROW>
                aY = [aY; D(newIdx, 2)]; %#ok<AGROW>
                aVx = [aVx; zeros(m, 1)]; %#ok<AGROW>
                aVy = [aVy; zeros(m, 1)]; %#ok<AGROW>
                aLen = [aLen; ones(m, 1)]; %#ok<AGROW>
                aGap = [aGap; zeros(m, 1)]; %#ok<AGROW>
            end
            trackOf{i} = tid;
        end
    end

    function dt = frameDt()
        if startsWith(P.timeMode, 'Frame')
            dt = 1 / P.fps;
        else
            dt = P.dt;
        end
    end

    function [lu, vu, kp, kv] = getUnits()
        if startsWith(P.units, 'Calibrated')
            lu = 'mm';
            vu = 'm/s';
            kp = P.scale;
            kv = P.scale / 1000;
        else
            lu = 'px';
            vu = 'px/s';
            kp = 1;
            kv = 1;
        end
    end

    function tf = hasPTV()
        tf = S.results.done && ~isempty(S.results.A) && any(S.results.A(:, 3) > 0);
    end

    function tf = hasPIV()
        tf = S.results.done && ~isempty(S.results.piv.U);
    end

    function [u, v, src] = velocitySamples()
        % Physical velocity samples, v positive upwards.
        R = S.results;
        [~, ~, ~, kv] = getUnits();
        u = [];
        v = [];
        src = '';
        if hasPTV()
            m = R.A(:, 3) > 0 & ~isnan(R.A(:, 13));
            u = R.A(m, 13) * kv;
            v = -R.A(m, 14) * kv;
            src = 'PTV';
        elseif hasPIV()
            dtp = R.piv.pairStep * R.dtF;
            u = R.piv.U(:) / dtp * kv;
            v = -R.piv.V(:) / dtp * kv;
            ok = ~isnan(u) & ~isnan(v);
            u = u(ok);
            v = v(ok);
            src = 'PIV';
        end
    end

    function [xe, ye] = binEdges()
        nr = S.imSize(1);
        nc = S.imSize(2);
        nb = max(2, round(P.gridBins));
        bs = nc / nb;
        ny = max(2, round(nr / bs));
        xe = linspace(0.5, nc + 0.5, nb + 1);
        ye = linspace(0.5, nr + 0.5, ny + 1);
    end

    function [xc, yc, Ug, Vg] = ptvField()
        % Eulerian field (px/s, image coordinates) from binned PTV samples.
        A = S.results.A;
        m = A(:, 3) > 0 & ~isnan(A(:, 13));
        [xe, ye] = binEdges();
        sz = [numel(ye) - 1, numel(xe) - 1];
        ix = discretize(A(m, 4), xe);
        iy = discretize(A(m, 5), ye);
        u = A(m, 13);
        v = A(m, 14);
        ok = ~isnan(ix) & ~isnan(iy);
        Ug = accumarray([iy(ok) ix(ok)], u(ok), sz, @mean, NaN);
        Vg = accumarray([iy(ok) ix(ok)], v(ok), sz, @mean, NaN);
        xc = (xe(1:end-1) + xe(2:end)) / 2;
        yc = (ye(1:end-1) + ye(2:end)) / 2;
    end

    function [xc, yc, Uf, Vf, src] = meanField()
        % Time-mean velocity field in px/s, image coordinates (v down).
        R = S.results;
        xc = []; yc = []; Uf = []; Vf = []; src = '';
        if hasPIV()
            dtp = R.piv.pairStep * R.dtF;
            xc = R.piv.X(1, :);
            yc = R.piv.Y(:, 1)';
            Uf = mean(R.piv.U, 3, 'omitnan') / dtp;
            Vf = mean(R.piv.V, 3, 'omitnan') / dtp;
            src = 'PIV';
        elseif hasPTV()
            [xc, yc, Uf, Vf] = ptvField();
            src = 'PTV (binned)';
        end
    end

    function [xc, yc, Dn, ustr] = densityMap()
        R = S.results;
        [~, ~, kp] = getUnits();
        [xe, ye] = binEdges();
        A = R.A;
        cnt = histcounts2(A(:, 5), A(:, 4), ye, xe);
        binArea = (xe(2) - xe(1)) * (ye(2) - ye(1));
        if startsWith(P.units, 'Calibrated')
            binArea = binArea * (kp / 1000)^2;
            ustr = 'particles / (m^2 frame)';
        else
            ustr = 'particles / (px^2 frame)';
        end
        Dn = cnt / (binArea * max(numel(R.frames), 1));
        xc = (xe(1:end-1) + xe(2:end)) / 2;
        yc = (ye(1:end-1) + ye(2:end)) / 2;
    end

%% =====================================================================
%  DISPLAY
%  =====================================================================
    function refreshView()
        if S.nFrames == 0 || ~isvalid(H.fig)
            return
        end
        ax = H.ax;
        f = S.current;
        try
            I = getRaw(f);
            needJ = ~strcmp(P.viewMode, 'Raw') || strcmp(P.overlay, 'Detections');
            J = [];
            if needJ
                J = prepFrame(toChannel(I));
            end
            switch P.viewMode
                case 'Processed'
                    base = repmat(J, [1 1 3]);
                case 'Binary'
                    BW = detect(J);
                    base = repmat(double(BW), [1 1 3]);
                otherwise
                    base = im2double(I);
                    if size(base, 3) == 1
                        base = repmat(base, [1 1 3]);
                    end
            end
        catch ME
            setStatus(['Display error: ' ME.message]);
            return
        end

        keepLim = S.axReady && isequal(S.lastSize, [size(base, 1) size(base, 2)]);
        if keepLim
            xl = ax.XLim;
            yl = ax.YLim;
        end
        cla(ax);
        colorbar(ax, 'off');
        image(ax, base);
        hold(ax, 'on');
        axis(ax, 'image');
        ax.YDir = 'reverse';
        if keepLim
            ax.XLim = xl;
            ax.YLim = yl;
        end
        try
            drawOverlay(J);
        catch ME
            setStatus(['Overlay error: ' ME.message]);
        end
        drawROI();
        drawIAGrid();
        hold(ax, 'off');
        title(ax, sprintf('Frame %d / %d    t = %.5g s    [%s view]', f, S.nFrames, ...
            (f - 1) * frameDt(), P.viewMode), 'FontWeight', 'normal');
        S.axReady = true;
        S.lastSize = [size(base, 1) size(base, 2)];
    end

    function drawOverlay(J)
        ax = H.ax;
        R = S.results;
        f = S.current;
        [~, vu, ~, kv] = getUnits();
        dtF = frameDt();
        switch P.overlay
            case 'Detections'
                [~, D] = detect(J);
                if ~isempty(D)
                    [cx, cy] = circlesPoly(D(:, 1), D(:, 2), max(D(:, 4) / 2 + 2, 3));
                    plot(ax, cx, cy, '-', 'Color', [0.1 1 0.2], 'LineWidth', 1);
                    plot(ax, D(:, 1), D(:, 2), '+', 'Color', [1 0.25 0.2], 'MarkerSize', 4);
                end
                H.detInfo.Text = sprintf('%d objects detected in frame %d with the current settings.', ...
                    size(D, 1), f);

            case 'Trajectories'
                if ~hasPTV()
                    axNote('Run a PTV analysis (tab 4) to see trajectories.');
                    return
                end
                A = R.A;
                B = sortrows(A(A(:, 3) > 0 & A(:, 1) <= f, :), [3 1]);
                cols = lines(7);
                for gI = 0:6
                    Bg = B(mod(B(:, 3), 7) == gI, :);
                    if isempty(Bg)
                        continue
                    end
                    [xs, ys] = nanSeparate(Bg(:, 3), Bg(:, 4), Bg(:, 5));
                    plot(ax, xs, ys, '-', 'Color', cols(gI + 1, :), 'LineWidth', 1.2);
                end
                cur = A(A(:, 1) == f & A(:, 3) > 0, :);
                plot(ax, cur(:, 4), cur(:, 5), 'o', 'Color', [1 1 1], 'MarkerSize', 5);

            case 'PTV velocity vectors'
                if ~hasPTV()
                    axNote('Run a PTV analysis (tab 4) to see velocity vectors.');
                    return
                end
                A = R.A;
                cur = A(A(:, 1) == f & A(:, 3) > 0 & ~isnan(A(:, 13)), :);
                if isempty(cur)
                    axNote('No tracked firebrands in this frame.');
                    return
                end
                k = R.dtF * P.vecScale;
                quiver(ax, cur(:, 4), cur(:, 5), cur(:, 13) * k, cur(:, 14) * k, 0, ...
                    'Color', [1 0.85 0], 'LineWidth', 1.4, 'MaxHeadSize', 0.8);
                spd = hypot(cur(:, 13), cur(:, 14)) * kv;
                axNote(sprintf('%d vectors, mean speed %.3g %s', size(cur, 1), mean(spd), vu));

            case {'PIV vectors (current pair)', 'PIV vectors (time-mean)'}
                if ~hasPIV()
                    axNote('Run a PIV analysis (tab 4) to see the vector field.');
                    return
                end
                if strcmp(P.overlay, 'PIV vectors (current pair)')
                    p = find(R.piv.frameA <= f, 1, 'last');
                    if isempty(p)
                        p = 1;
                    end
                    U = R.piv.U(:, :, p);
                    V = R.piv.V(:, :, p);
                    lab = sprintf('PIV pair %d-%d', R.piv.frameA(p), R.piv.frameA(p) + R.piv.pairStep);
                else
                    U = mean(R.piv.U, 3, 'omitnan');
                    V = mean(R.piv.V, 3, 'omitnan');
                    lab = sprintf('Time-mean PIV field (%d pairs)', numel(R.piv.frameA));
                end
                k = P.vecScale / R.piv.pairStep;
                quiver(ax, R.piv.X, R.piv.Y, U * k, V * k, 0, 'Color', [1 0.85 0], 'LineWidth', 1);
                axNote(lab);

            case 'Velocity magnitude map (time-mean)'
                [xc, yc, Uf, Vf, src] = meanField();
                if isempty(Uf)
                    axNote('Run a PTV or PIV analysis first.');
                    return
                end
                spd = hypot(Uf, Vf) * kv;
                hI = imagesc(ax, xc, yc, spd);
                hI.AlphaData = 0.65 * double(~isnan(spd));
                colormap(ax, P.cmap);
                cb = colorbar(ax);
                cb.Label.String = ['Speed (' vu ')'];
                k = dtF * P.vecScale;
                [XX, YY] = meshgrid(xc, yc);
                quiver(ax, XX, YY, Uf * k, Vf * k, 0, 'Color', [1 1 1], 'LineWidth', 0.8);
                axNote(['Source: ' src]);

            case 'Streamlines (time-mean)'
                [xc, yc, Uf, Vf, src] = meanField();
                if isempty(Uf) || numel(xc) < 2 || numel(yc) < 2
                    axNote('Run a PTV or PIV analysis first.');
                    return
                end
                spd = hypot(Uf, Vf) * kv;
                hI = imagesc(ax, xc, yc, spd);
                hI.AlphaData = 0.45 * double(~isnan(spd));
                colormap(ax, P.cmap);
                cb = colorbar(ax);
                cb.Label.String = ['Speed (' vu ')'];
                [XX, YY] = meshgrid(xc, yc);
                Uf(isnan(Uf)) = 0;
                Vf(isnan(Vf)) = 0;
                ns = max(2, round(P.streamDensity));
                [sx, sy] = meshgrid(linspace(xc(1), xc(end), ns), linspace(yc(1), yc(end), ns));
                h1 = streamline(ax, XX, YY, Uf, Vf, sx, sy);
                h2 = streamline(ax, XX, YY, -Uf, -Vf, sx, sy);
                set([h1(:); h2(:)], 'Color', [0.2 0.95 1], 'LineWidth', 1);
                axNote(['Streamlines of the time-mean field. Source: ' src]);

            case 'Number density map'
                if ~S.results.done || isempty(R.A)
                    axNote('Run an analysis first.');
                    return
                end
                [xc, yc, Dn, ustr] = densityMap();
                hI = imagesc(ax, xc, yc, Dn);
                hI.AlphaData = 0.7 * double(Dn > 0);
                colormap(ax, P.cmap);
                cb = colorbar(ax);
                cb.Label.String = ustr;
        end
    end

    function axNote(txt)
        text(H.ax, 0.01, 0.99, txt, 'Units', 'normalized', 'Color', [1 1 0.6], ...
            'VerticalAlignment', 'top', 'BackgroundColor', [0 0 0], 'FontSize', 10, 'Margin', 3);
    end

    function drawROI()
        if isempty(P.roi)
            return
        end
        plot(H.ax, P.roi([1:end 1], 1), P.roi([1:end 1], 2), '--', 'Color', [0 1 1], 'LineWidth', 1.5);
    end

    function drawIAGrid()
        if ~P.showGrid || S.nFrames == 0
            return
        end
        w = P.iaSize;
        stp = max(1, round(w * (1 - P.overlap / 100)));
        nr = S.imSize(1);
        nc = S.imSize(2);
        cx = (1:stp:(nc - w + 1)) + (w - 1) / 2;
        cy = (1:stp:(nr - w + 1)) + (w - 1) / 2;
        [CX, CY] = meshgrid(cx, cy);
        plot(H.ax, CX(:), CY(:), '.', 'Color', [1 0.6 0.1], 'MarkerSize', 4);
        if isempty(cx) || isempty(cy)
            return
        end
        x0 = cx(ceil(end / 2)) - (w - 1) / 2;
        y0 = cy(ceil(end / 2)) - (w - 1) / 2;
        rectangle(H.ax, 'Position', [x0 y0 w w], 'EdgeColor', [1 0.3 0.1], 'LineWidth', 2);
        rectangle(H.ax, 'Position', [x0 + stp y0 w w], 'EdgeColor', [1 0.8 0.2], 'LineWidth', 1.2, ...
            'LineStyle', '--');
        text(H.ax, x0, y0 - 4, sprintf('IA %d x %d px, overlap %d%% (step %d px), %d x %d vectors', ...
            w, w, P.overlap, stp, numel(cx), numel(cy)), 'Color', [1 0.6 0.2], ...
            'VerticalAlignment', 'bottom', 'FontSize', 9, 'BackgroundColor', [0 0 0]);
    end

    function plotStats()
        ax = H.axS;
        cla(ax, 'reset');
        R = S.results;
        if ~R.done
            text(ax, 0.5, 0.5, 'Run an analysis (tab 4) to see statistics here.', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.4 0.4 0.45]);
            ax.XTick = [];
            ax.YTick = [];
            return
        end
        [lu, vu, kp, kv] = getUnits();
        [u, v, src] = velocitySamples();
        red = [0.72 0.09 0.07];
        orange = [0.93 0.42 0.05];
        switch P.statPlot
            case 'Direction rose'
                if isempty(u)
                    statNote(ax, 'No velocity data (run PTV or PIV).');
                    return
                end
                roseManual(ax, atan2d(v, u), 24, P.cmap, ...
                    sprintf('Direction of motion - %s, n = %d', src, numel(u)));
                return
            case 'Speed histogram'
                if isempty(u)
                    statNote(ax, 'No velocity data (run PTV or PIV).');
                    return
                end
                spd = hypot(u, v);
                histogram(ax, spd, 'Normalization', 'probability', 'FaceColor', orange, 'EdgeColor', 'w');
                xline(ax, mean(spd), '--k', sprintf('mean = %.3g', mean(spd)), 'LineWidth', 1.2);
                xlabel(ax, sprintf('Speed (%s)', vu));
                ylabel(ax, 'Probability');
                title(ax, sprintf('Speed distribution - %s, n = %d', src, numel(spd)));
            case 'Size distribution'
                d = R.A(:, 7) * kp;
                if isempty(d)
                    statNote(ax, 'No detections.');
                    return
                end
                histogram(ax, d, 'Normalization', 'probability', 'FaceColor', red, 'EdgeColor', 'w');
                xline(ax, mean(d), '--k', sprintf('mean = %.3g %s', mean(d), lu), 'LineWidth', 1.2);
                xlabel(ax, sprintf('Equivalent diameter (%s)', lu));
                ylabel(ax, 'Probability');
                title(ax, sprintf('Projected size of detected objects, n = %d', numel(d)));
            case 'Count vs time'
                c = cellfun(@(z) size(z, 1), R.det);
                t = (R.frames - 1) * R.dtF;
                plot(ax, t, c, '-o', 'Color', red, 'MarkerSize', 3, 'MarkerFaceColor', red);
                xlabel(ax, 'Time (s)');
                ylabel(ax, 'Detected objects per frame');
                title(ax, sprintf('Object count (mean %.1f per frame)', mean(c)));
            case 'Mean speed vs time'
                hold(ax, 'on');
                leg = {};
                if hasPTV()
                    A = R.A;
                    m = A(:, 3) > 0 & ~isnan(A(:, 13));
                    [uf, ~, ic] = unique(A(m, 1));
                    ms = accumarray(ic, hypot(A(m, 13), A(m, 14)) * kv, [], @mean);
                    plot(ax, (uf - 1) * R.dtF, ms, '-o', 'Color', red, 'MarkerSize', 3);
                    leg{end + 1} = 'PTV (mean of tracked firebrands)';
                end
                if hasPIV()
                    dtp = R.piv.pairStep * R.dtF;
                    sp = hypot(R.piv.U, R.piv.V) / dtp * kv;
                    ms = mean(reshape(sp, [], size(sp, 3)), 1, 'omitnan')';
                    plot(ax, (R.piv.frameA - 1) * R.dtF, ms, '-s', 'Color', orange, 'MarkerSize', 3);
                    leg{end + 1} = 'PIV (spatial mean)';
                end
                hold(ax, 'off');
                if isempty(leg)
                    statNote(ax, 'No velocity data (run PTV or PIV).');
                    return
                end
                legend(ax, leg, 'Location', 'best');
                xlabel(ax, 'Time (s)');
                ylabel(ax, sprintf('Mean speed (%s)', vu));
                title(ax, 'Mean speed vs time');
            case 'u-v scatter'
                if isempty(u)
                    statNote(ax, 'No velocity data (run PTV or PIV).');
                    return
                end
                scatter(ax, u, v, 8, hypot(u, v), 'filled', 'MarkerFaceAlpha', 0.4);
                colormap(ax, P.cmap);
                cb = colorbar(ax);
                cb.Label.String = ['Speed (' vu ')'];
                xline(ax, 0, ':k');
                yline(ax, 0, ':k');
                axis(ax, 'equal');
                xlabel(ax, sprintf('u (%s), positive to the right', vu));
                ylabel(ax, sprintf('v (%s), positive upwards', vu));
                title(ax, sprintf('Velocity components - %s, n = %d', src, numel(u)));
        end
        grid(ax, 'on');
        box(ax, 'on');
    end

    function statNote(ax, txt)
        text(ax, 0.5, 0.5, txt, 'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 12, 'Color', [0.4 0.4 0.45]);
        ax.XTick = [];
        ax.YTick = [];
    end

    function updateSummary()
        R = S.results;
        if ~R.done
            H.summary.Value = {'No results yet.'};
            return
        end
        [lu, vu, kp, kv] = getUnits();
        c = cellfun(@(z) size(z, 1), R.det);
        L = {sprintf('Mode            : %s', R.mode), ...
            sprintf('Frames analysed : %d (frame %d to %d)', numel(R.frames), R.frames(1), R.frames(end)), ...
            sprintf('Frame interval  : %.6g s', R.dtF), ...
            sprintf('Units           : %s (scale %.6g mm/px)', lu, P.scale), ...
            sprintf('Detections      : %d (%.1f per frame, max %d)', size(R.A, 1), mean(c), max([c(:); 0]))};
        if ~isempty(R.A)
            L{end + 1} = sprintf('Mean eq. diam.  : %.4g %s', mean(R.A(:, 7)) * kp, lu);
        end
        if hasPTV()
            A = R.A;
            nT = numel(unique(A(A(:, 3) > 0, 3)));
            m = A(:, 3) > 0 & ~isnan(A(:, 13));
            uu = A(m, 13) * kv;
            vv = -A(m, 14) * kv;
            spd = hypot(uu, vv);
            L{end + 1} = sprintf('Tracks (PTV)    : %d', nT);
            L{end + 1} = sprintf('Speed mean/med. : %.4g / %.4g %s', mean(spd), median(spd), vu);
            L{end + 1} = sprintf('Speed max       : %.4g %s', max(spd), vu);
            L{end + 1} = sprintf('Mean direction  : %.1f deg (0 = +x, 90 = up)', ...
                mod(atan2d(mean(vv), mean(uu)), 360));
        end
        if hasPIV()
            dtp = R.piv.pairStep * R.dtF;
            Um = mean(R.piv.U, 3, 'omitnan') / dtp * kv;
            Vm = mean(R.piv.V, 3, 'omitnan') / dtp * kv;
            sp = hypot(Um, Vm);
            L{end + 1} = sprintf('PIV pairs       : %d, grid %d x %d', numel(R.piv.frameA), ...
                size(R.piv.X, 2), size(R.piv.X, 1));
            L{end + 1} = sprintf('PIV outliers    : %.1f %% of %d vectors', ...
                100 * R.piv.nOut / max(R.piv.nTot, 1), R.piv.nTot);
            L{end + 1} = sprintf('PIV mean speed  : %.4g %s (time-mean field)', mean(sp(:), 'omitnan'), vu);
        end
        H.summary.Value = L;
    end

%% =====================================================================
%  EXPORT
%  =====================================================================
    function T = particleTable()
        [lu, vu, kp, kv] = getUnits();
        vt = strrep(vu, '/', '_');
        A = S.results.A;
        u = A(:, 13) * kv;
        v = -A(:, 14) * kv;
        T = table(A(:, 1), A(:, 2), A(:, 3), A(:, 4) * kp, A(:, 5) * kp, A(:, 6) * kp^2, A(:, 7) * kp, ...
            A(:, 8) * kp, A(:, 9) * kp, A(:, 10), A(:, 11), A(:, 12), u, v, hypot(u, v), ...
            mod(atan2d(v, u), 360), 'VariableNames', {'frame', 'time_s', 'track_id', ['x_' lu], ...
            ['y_down_' lu], ['area_' lu '2'], ['eq_diameter_' lu], ['major_axis_' lu], ...
            ['minor_axis_' lu], 'orientation_deg', 'mean_intensity', 'max_intensity', ['u_' vt], ...
            ['v_up_' vt], ['speed_' vt], 'direction_deg'});
    end

    function T = trackTable()
        [lu, vu, kp, kv] = getUnits();
        vt = strrep(vu, '/', '_');
        A = S.results.A;
        A = sortrows(A(A(:, 3) > 0, :), [3 1]);
        names = {'track_id', 'first_frame', 'last_frame', 'n_points', 'duration_s', ...
            ['path_length_' lu], ['net_displacement_' lu], ['mean_speed_' vt], ['max_speed_' vt], ...
            ['mean_u_' vt], ['mean_v_up_' vt], 'mean_direction_deg', ['mean_eq_diameter_' lu], ...
            ['mean_area_' lu '2']};
        if isempty(A)
            T = array2table(zeros(0, numel(names)), 'VariableNames', names);
            return
        end
        st = find([true; diff(A(:, 3)) ~= 0]);
        en = [st(2:end) - 1; size(A, 1)];
        out = nan(numel(st), numel(names));
        for k = 1:numel(st)
            B = A(st(k):en(k), :);
            x = B(:, 4);
            y = B(:, 5);
            u = B(:, 13) * kv;
            v = -B(:, 14) * kv;
            spd = hypot(u, v);
            mu = mean(u, 'omitnan');
            mv = mean(v, 'omitnan');
            out(k, :) = [B(1, 3), B(1, 1), B(end, 1), size(B, 1), B(end, 2) - B(1, 2), ...
                sum(hypot(diff(x), diff(y))) * kp, hypot(x(end) - x(1), y(end) - y(1)) * kp, ...
                mean(spd, 'omitnan'), max(spd, [], 'omitnan'), mu, mv, mod(atan2d(mv, mu), 360), ...
                mean(B(:, 7)) * kp, mean(B(:, 6)) * kp^2];
        end
        T = array2table(out, 'VariableNames', names);
    end

    function T = frameTable()
        [lu, vu, kp, kv] = getUnits();
        vt = strrep(vu, '/', '_');
        R = S.results;
        nF = numel(R.frames);
        A = R.A;
        [~, fi] = ismember(A(:, 1), R.frames);
        cnt = accumarray(fi, ones(size(fi)), [nF 1]);
        dm = accumarray(fi, A(:, 7) * kp, [nF 1], @mean, NaN);
        m = A(:, 3) > 0 & ~isnan(A(:, 13));
        nTr = accumarray(fi(m), ones(nnz(m), 1), [nF 1]);
        ms = accumarray(fi(m), hypot(A(m, 13), A(m, 14)) * kv, [nF 1], @mean, NaN);
        T = table(R.frames(:), (R.frames(:) - 1) * R.dtF, cnt, dm, nTr, ms, 'VariableNames', ...
            {'frame', 'time_s', 'n_objects', ['mean_eq_diameter_' lu], 'n_tracked', ['mean_speed_' vt]});
    end

    function T = pivMeanTable()
        [lu, vu, kp, kv] = getUnits();
        vt = strrep(vu, '/', '_');
        R = S.results;
        dtp = R.piv.pairStep * R.dtF;
        Um = mean(R.piv.U, 3, 'omitnan') / dtp * kv;
        Vm = -mean(R.piv.V, 3, 'omitnan') / dtp * kv;
        Nv = sum(~isnan(R.piv.U), 3);
        T = table(R.piv.X(:) * kp, R.piv.Y(:) * kp, Um(:), Vm(:), hypot(Um(:), Vm(:)), Nv(:), ...
            'VariableNames', {['x_' lu], ['y_down_' lu], ['u_' vt], ['v_up_' vt], ['speed_' vt], 'n_valid'});
    end

    function T = pivAllTable()
        [lu, vu, kp, kv] = getUnits();
        vt = strrep(vu, '/', '_');
        R = S.results;
        dtp = R.piv.pairStep * R.dtF;
        np = numel(R.piv.frameA);
        ng = numel(R.piv.X);
        fr = repelem(R.piv.frameA(:), ng);
        X = repmat(R.piv.X(:), np, 1) * kp;
        Y = repmat(R.piv.Y(:), np, 1) * kp;
        U = R.piv.U(:) / dtp * kv;
        V = -R.piv.V(:) / dtp * kv;
        T = table(fr, (fr - 1) * R.dtF, X, Y, U, V, hypot(U, V), 'VariableNames', ...
            {'frame_a', 'time_s', ['x_' lu], ['y_down_' lu], ['u_' vt], ['v_up_' vt], ['speed_' vt]});
    end

    function ok = needResults()
        ok = S.results.done;
        if ~ok
            uialert(H.fig, 'Run an analysis first (tab 4).', 'No results');
        end
    end

    function onExportCSV(~, ~)
        if ~needResults()
            return
        end
        folder = uigetdir(S.lastDir, 'Select output folder for CSV tables');
        figure(H.fig);
        if isequal(folder, 0)
            return
        end
        try
            writetable(particleTable(), fullfile(folder, 'firebrand_particles.csv'));
            writetable(frameTable(), fullfile(folder, 'firebrand_frame_statistics.csv'));
            if hasPTV()
                writetable(trackTable(), fullfile(folder, 'firebrand_tracks.csv'));
            end
            if hasPIV()
                writetable(pivMeanTable(), fullfile(folder, 'piv_mean_field.csv'));
                writetable(pivAllTable(), fullfile(folder, 'piv_instantaneous_fields.csv'));
            end
            writeSettings(fullfile(folder, 'analysis_settings.json'));
        catch ME
            uialert(H.fig, ME.message, 'Export error');
            return
        end
        setStatus(['CSV tables written to ' folder]);
    end

    function onSaveMAT(~, ~)
        if ~needResults()
            return
        end
        [f, p] = uiputfile('*.mat', 'Save results', fullfile(S.lastDir, 'piv_adai_results.mat'));
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        results = S.results; %#ok<NASGU>
        settings = P; %#ok<NASGU>
        particles = particleTable(); %#ok<NASGU>
        frameStats = frameTable(); %#ok<NASGU>
        tracks = []; %#ok<NASGU>
        if hasPTV()
            tracks = trackTable(); %#ok<NASGU>
        end
        info = struct('software', sprintf('%s v%s', APP.name, APP.version), 'source', S.source, ...
            'files', {S.files}, 'imageSize', S.imSize, 'created', char(datetime('now'))); %#ok<NASGU>
        save(fullfile(p, f), 'results', 'settings', 'particles', 'frameStats', 'tracks', 'info', '-v7.3');
        setStatus(['Results saved to ' fullfile(p, f)]);
    end

    function onSaveFigure(~, ~)
        if H.viewTabs.SelectedTab == H.tabStats
            ax = H.axS;
        else
            ax = H.ax;
        end
        [f, p] = uiputfile({'*.png', 'PNG image'; '*.tif', 'TIFF image'; '*.pdf', 'PDF'; '*.jpg', 'JPEG'}, ...
            'Save figure', fullfile(S.lastDir, 'piv_adai_figure.png'));
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        exportgraphics(ax, fullfile(p, f), 'Resolution', 300);
        setStatus(['Figure saved: ' fullfile(p, f)]);
    end

    function onExportFrames(~, ~)
        if S.nFrames == 0
            return
        end
        folder = uigetdir(S.lastDir, 'Folder for annotated frames');
        figure(H.fig);
        if isequal(folder, 0)
            return
        end
        H.viewTabs.SelectedTab = H.tabImg;
        frames = P.frameStart:round(P.frameStep):P.frameEnd;
        dlg = uiprogressdlg(H.fig, 'Title', 'Exporting frames', 'Cancelable', 'on');
        for i = 1:numel(frames)
            if dlg.CancelRequested
                break
            end
            setFrame(frames(i));
            drawnow;
            exportgraphics(H.ax, fullfile(folder, sprintf('annotated_%06d.png', frames(i))), 'Resolution', 150);
            dlg.Value = i / numel(frames);
        end
        close(dlg);
        setStatus(['Annotated frames written to ' folder]);
    end

    function writeSettings(file)
        Q = P;
        Q.software = sprintf('%s v%s', APP.name, APP.version);
        Q.saved = char(datetime('now'));
        fid = fopen(file, 'w');
        if fid < 0
            error('Cannot write %s', file);
        end
        fprintf(fid, '%s', jsonencode(Q, 'PrettyPrint', true));
        fclose(fid);
    end

    function onSaveSettings(~, ~)
        [f, p] = uiputfile('*.json', 'Save analysis settings', fullfile(S.lastDir, 'piv_adai_settings.json'));
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        writeSettings(fullfile(p, f));
        setStatus(['Settings saved: ' fullfile(p, f)]);
    end

    function onLoadSettings(~, ~)
        [f, p] = uigetfile('*.json', 'Load analysis settings', S.lastDir);
        figure(H.fig);
        if isequal(f, 0)
            return
        end
        try
            Q = jsondecode(fileread(fullfile(p, f)));
        catch ME
            uialert(H.fig, ME.message, 'Cannot read settings');
            return
        end
        Dft = defaultParams();
        fn = fieldnames(Dft);
        for k = 1:numel(fn)
            if ~isfield(Q, fn{k})
                continue
            end
            val = Q.(fn{k});
            if ischar(Dft.(fn{k})) && ~ischar(val)
                continue
            end
            if strcmp(fn{k}, 'roi') && ~isempty(val) && size(val, 2) ~= 2
                continue
            end
            P.(fn{k}) = val;
        end
        if S.nFrames > 0
            P.frameStart = min(max(P.frameStart, 1), S.nFrames);
            P.frameEnd = min(max(P.frameEnd, P.frameStart), S.nFrames);
        end
        syncControls();
        updateEnable();
        refreshView();
        setStatus(['Settings loaded: ' fullfile(p, f)]);
    end

end   % ===================== end of main (nested) function =================


%% =========================================================================
%  LOCAL FUNCTIONS
%  =========================================================================
function S = initState()
S.source = '';
S.files = {};
S.allFiles = {};
S.vr = [];
S.nFrames = 0;
S.imSize = [0 0];
S.current = 1;
S.bg = [];
S.bgKey = '';
S.results = emptyResults();
S.playing = false;
S.axReady = false;
S.lastSize = [0 0];
S.lastDir = pwd;
end

function P = defaultParams()
% Input
P.frameStart = 1;
P.frameEnd = 1;
P.frameStep = 1;
P.timeMode = 'Frame rate (fps)';
P.fps = 1000;
P.dt = 1e-3;
P.units = 'Pixels (uncalibrated)';
P.scale = 1;            % mm per pixel
P.calibLength = 10;     % mm
P.roi = [];             % N x 2 polygon (pixels)
% Image
P.channel = 'Grayscale';
P.bgMode = 'Top-hat (local, per frame)';
P.tophatRadius = 15;
P.bgFrames = 50;
P.invert = false;
P.medianSize = 0;
P.gaussSigma = 0;
P.contrastMode = 'Automatic';
P.autoMethod = 'Stretch limits';
P.saturation = 1;
P.brightness = 0;
P.contrast = 1;
P.gamma = 1;
% Detection
P.threshMode = 'Automatic (robust noise level)';
P.kNoise = 6;
P.otsuFactor = 1;
P.kStd = 4;
P.threshLevel = 0.5;
P.adaptSens = 0.5;
P.minArea = 4;
P.maxArea = 20000;
P.openRadius = 0;
P.fillHoles = true;
P.clearBorder = false;
P.weightedCentroid = true;
% Analysis
P.mode = 'PTV + PIV';
P.maxDisp = 30;
P.minTrackLen = 3;
P.maxGap = 1;
P.usePrediction = true;
P.iaSize = 32;
P.overlap = 50;
P.pivPasses = 2;
P.pivPairStep = 1;
P.minIAStd = 0.005;
P.medianThr = 2;
P.replaceOutliers = true;
P.showGrid = false;
% Display / results
P.viewMode = 'Raw';
P.overlay = 'Detections';
P.statPlot = 'Direction rose';
P.cmap = 'turbo';
P.vecScale = 3;
P.streamDensity = 15;
P.gridBins = 24;
end

function R = emptyResults()
R.done = false;
R.frames = [];
R.det = {};
R.A = zeros(0, 14);
R.dtF = 1;
R.mode = '';
R.params = struct();
R.piv = struct('X', [], 'Y', [], 'U', [], 'V', [], 'frameA', [], 'pairStep', 1, 'nTot', 0, 'nOut', 0);
end

function checkRequirements()
try
    if verLessThan('matlab', '9.10') %#ok<VERLESSMATLAB>
        warning('PIV_ADAI:version', 'MATLAB R2021a or newer is recommended.');
    end
catch
end
if isempty(ver('images'))
    warning('PIV_ADAI:ipt', ...
        'The Image Processing Toolbox is required for detection and filtering.');
end
end

function e = imageExts()
e = {'tif', 'tiff', 'png', 'jpg', 'jpeg', 'bmp', 'jp2', 'pgm', 'ppm'};
end

function lev = robustLevel(J, k)
% Threshold = median + k * sigma, with sigma estimated from the median
% absolute deviation (robust to the few bright particles in the image).
v = double(J(:));
if numel(v) > 2e6
    v = v(1:ceil(numel(v) / 2e6):end);
end
med = median(v);
sig = 1.4826 * median(abs(v - med));
if sig < 1e-6
    low = v(v <= med + 3 * std(v));
    sig = std(low);
end
if sig < 1e-6
    sig = std(v);
end
lev = min(max(med + k * sig, 1e-3), 0.999);
end

function doi = readDoi(appDir)
% Read the DOI from CITATION.cff (an uncommented "doi:" line), if present.
doi = '';
f = fullfile(appDir, 'CITATION.cff');
if ~isfile(f)
    return
end
tok = regexp(fileread(f), '^doi:\s*"?([^"\s#]+)', 'tokens', 'once', 'lineanchors');
if ~isempty(tok)
    doi = tok{1};
end
end

function v = ddValue(s, isNum)
if isNum
    v = str2double(s);
else
    v = s;
end
end

function f = natSort(f)
% Natural sort of file names (frame_2 before frame_10).
[~, n] = cellfun(@fileparts, f, 'UniformOutput', false);
key = cell(size(n));
for i = 1:numel(n)
    [tok, txt] = regexp(lower(n{i}), '\d+', 'match', 'split');
    k = txt{1};
    for j = 1:numel(tok)
        k = [k sprintf('%015d', str2double(tok{j})) txt{j + 1}]; %#ok<AGROW>
    end
    key{i} = k;
end
[~, o] = sort(key);
f = f(o);
end

function A = buildA(det, frames, trackOf, dtF, minLen)
% Assemble all detections into one matrix (pixel units):
%  1 frame | 2 time | 3 track id | 4 x | 5 y | 6 area | 7 eqDiam | 8 major |
%  9 minor | 10 orientation | 11 meanI | 12 maxI | 13 u (px/s) | 14 v (px/s, down)
nPer = cellfun(@(d) size(d, 1), det(:));
A = zeros(sum(nPer), 14);
A(:, 13:14) = NaN;
row = 0;
for i = 1:numel(det)
    n = nPer(i);
    if n == 0
        continue
    end
    rr = row + (1:n);
    A(rr, 1) = frames(i);
    A(rr, 2) = (frames(i) - 1) * dtF;
    if ~isempty(trackOf)
        A(rr, 3) = trackOf{i}(:);
    end
    A(rr, 4:12) = det{i};
    row = row + n;
end
if isempty(trackOf) || isempty(A) || ~any(A(:, 3) > 0)
    return
end
ids = A(:, 3);
cnt = accumarray(ids(ids > 0), 1);
shortIds = find(cnt < minLen);
A(ismember(ids, shortIds), 3) = 0;
pos = A(:, 3) > 0;
if ~any(pos)
    return
end
[~, ~, newId] = unique(A(pos, 3));
A(pos, 3) = newId;
[~, ord] = sortrows(A(:, [3 1]));
As = A(ord, :);
st = find([true; diff(As(:, 3)) ~= 0]);
en = [st(2:end) - 1; size(As, 1)];
for k = 1:numel(st)
    a = st(k);
    b = en(k);
    if As(a, 3) == 0 || b - a < 1
        continue
    end
    t = As(a:b, 2);
    As(a:b, 13) = gradient(As(a:b, 4), t);
    As(a:b, 14) = gradient(As(a:b, 5), t);
end
A(ord, :) = As;
end

function [X, Y, U, V] = pivCore(A, B, M, w, overlapPct, minStd, nPass)
% FFT cross-correlation PIV with 3-point Gaussian sub-pixel peak fit.
% Passes > 1 use an integer window offset predicted by the previous pass
% (reduces the loss-of-pairs bias). Returns window centres (X, Y) and
% displacements (U right, V down) in pixels.
if nargin < 7
    nPass = 1;
end
A = single(A);
B = single(B);
[nr, nc] = size(A);
stp = max(1, round(w * (1 - overlapPct / 100)));
r0 = 1:stp:(nr - w + 1);
c0 = 1:stp:(nc - w + 1);
[C0, R0] = meshgrid(c0, r0);
X = C0 + (w - 1) / 2;
Y = R0 + (w - 1) / 2;
U = nan(size(R0));
V = nan(size(R0));
N = numel(R0);
if N == 0
    return
end
inRoi = true(N, 1);
if ~isempty(M)
    inRoi = M(sub2ind([nr nc], round(Y(:)), round(X(:))));
end
startA = (C0(:) - 1) * nr + R0(:);
offR = zeros(N, 1);
offC = zeros(N, 1);
for pass = 1:max(1, round(nPass))
    if pass > 1
        [Ut, Vt] = medianTest(U, V, 2, true);
        if all(isnan(Ut(:)))
            break
        end
        Ut(isnan(Ut)) = median(Ut(~isnan(Ut)));
        Vt(isnan(Vt)) = median(Vt(~isnan(Vt)));
        rB = min(max(R0(:) + round(Vt(:)), 1), nr - w + 1);
        cB = min(max(C0(:) + round(Ut(:)), 1), nc - w + 1);
        offR = rB - R0(:);
        offC = cB - C0(:);
    end
    startB = startA + offC * nr + offR;
    [du, dv] = correlateWindows(A, B, startA, startB, inRoi, w, nr, minStd);
    U = reshape(du + offC, size(R0));
    V = reshape(dv + offR, size(R0));
end
end

function [du, dv] = correlateWindows(A, B, startA, startB, use, w, nr, minStd)
N = numel(startA);
du = nan(N, 1);
dv = nan(N, 1);
base = (0:w-1)' + (0:w-1) * nr;
ctr = floor(w / 2) + 1;
chunk = max(1, floor(4e6 / (w * w)));
lg = @(z) log(max(z, 1e-6));
for k0 = 1:chunk:N
    kk = k0:min(N, k0 + chunk - 1);
    kk = kk(use(kk));
    if isempty(kk)
        continue
    end
    n = numel(kk);
    a = A(base + reshape(startA(kk), 1, 1, n));
    b = B(base + reshape(startB(kk), 1, 1, n));
    a = a - mean(mean(a, 1), 2);
    b = b - mean(mean(b, 1), 2);
    sa = sqrt(sum(sum(a.^2, 1), 2));
    sb = sqrt(sum(sum(b.^2, 1), 2));
    C = real(ifft2(conj(fft2(a)) .* fft2(b)));
    C = fftshift(fftshift(C, 1), 2);
    C = C ./ max(sa .* sb, eps('single'));
    [pk, li] = max(reshape(C, w * w, n), [], 1);
    [pr, pc] = ind2sub([w w], li);
    onEdge = pr == 1 | pr == w | pc == 1 | pc == w;
    pr = min(max(pr, 2), w - 1);
    pc = min(max(pc, 2), w - 1);
    off = (0:n-1) * w * w;
    cc = C(pr + (pc - 1) * w + off);
    cu = C(pr - 1 + (pc - 1) * w + off);
    cdn = C(pr + 1 + (pc - 1) * w + off);
    cl = C(pr + (pc - 2) * w + off);
    cr = C(pr + pc * w + off);
    dr = (lg(cu) - lg(cdn)) ./ (2 * (lg(cu) - 2 * lg(cc) + lg(cdn)));
    dc = (lg(cl) - lg(cr)) ./ (2 * (lg(cl) - 2 * lg(cc) + lg(cr)));
    dr(~isfinite(dr) | abs(dr) > 1) = 0;
    dc(~isfinite(dc) | abs(dc) > 1) = 0;
    sdA = reshape(sa, 1, n) / w;
    sdB = reshape(sb, 1, n) / w;
    ok = ~onEdge & pk > 0 & sdA >= minStd & sdB >= minStd;
    u = double(pc + dc - ctr);
    v = double(pr + dr - ctr);
    u(~ok) = NaN;
    v(~ok) = NaN;
    du(kk) = u;
    dv(kk) = v;
end
end

function [U, V, nOut] = medianTest(U, V, thr, doReplace)
% Normalised median test (Westerweel & Scarano, 2005), 3x3 neighbourhood.
eps0 = 0.1;
[ny, nx] = size(U);
out = false(ny, nx);
for i = 1:ny
    for j = 1:nx
        if isnan(U(i, j))
            continue
        end
        ii = max(1, i - 1):min(ny, i + 1);
        jj = max(1, j - 1):min(nx, j + 1);
        nu = U(ii, jj);
        nv = V(ii, jj);
        self = false(size(nu));
        self(i - ii(1) + 1, j - jj(1) + 1) = true;
        ok = ~self & ~isnan(nu) & ~isnan(nv);
        nu = nu(ok);
        nv = nv(ok);
        if numel(nu) < 3
            continue
        end
        mu = median(nu);
        mv = median(nv);
        ru = median(abs(nu - mu));
        rv = median(abs(nv - mv));
        if max(abs(U(i, j) - mu) / (ru + eps0), abs(V(i, j) - mv) / (rv + eps0)) > thr
            out(i, j) = true;
        end
    end
end
nOut = nnz(out);
U(out) = NaN;
V(out) = NaN;
if doReplace && nOut > 0
    [ri, cj] = find(out);
    U2 = U;
    V2 = V;
    for k = 1:numel(ri)
        ii = max(1, ri(k) - 1):min(ny, ri(k) + 1);
        jj = max(1, cj(k) - 1):min(nx, cj(k) + 1);
        nu = U(ii, jj);
        nv = V(ii, jj);
        ok = ~isnan(nu) & ~isnan(nv);
        if nnz(ok) >= 2
            U2(ri(k), cj(k)) = median(nu(ok));
            V2(ri(k), cj(k)) = median(nv(ok));
        end
    end
    U = U2;
    V = V2;
end
end

function [cx, cy] = circlesPoly(x, y, r)
% NaN-separated circle outlines (one line object for many circles).
th = linspace(0, 2 * pi, 17)';
cx = x(:)' + r(:)' .* cos(th);
cy = y(:)' + r(:)' .* sin(th);
cx(end + 1, :) = NaN;
cy(end + 1, :) = NaN;
cx = cx(:);
cy = cy(:);
end

function [xs, ys] = nanSeparate(id, x, y)
% Insert NaN between consecutive tracks (rows sorted by id).
n = numel(id);
brk = [0; cumsum(diff(id(:)) ~= 0)];
xs = nan(n + brk(end), 1);
ys = xs;
pos = (1:n)' + brk;
xs(pos) = x;
ys(pos) = y;
end

function roseManual(ax, ang, nb, cmapName, ttl)
% Rose (polar) histogram drawn in Cartesian axes. 0 deg = +x, 90 deg = up.
edges = linspace(0, 360, nb + 1);
cnt = histcounts(mod(ang, 360), edges);
frac = cnt / max(sum(cnt), 1);
rmax = max(frac);
if rmax <= 0
    rmax = 1;
end
hold(ax, 'on');
th = linspace(0, 2 * pi, 181);
for rr = (1:4) / 4 * rmax
    plot(ax, rr * cos(th), rr * sin(th), ':', 'Color', [0.6 0.6 0.6]);
    text(ax, rr * cosd(75), rr * sind(75), sprintf('%.1f%%', 100 * rr), 'FontSize', 8, ...
        'Color', [0.35 0.35 0.35]);
end
for a = 0:45:315
    plot(ax, [0 1.05 * rmax * cosd(a)], [0 1.05 * rmax * sind(a)], ':', 'Color', [0.75 0.75 0.75]);
end
for k = 1:nb
    if frac(k) == 0
        continue
    end
    t = linspace(edges(k), edges(k + 1), 10);
    patch(ax, [0 frac(k) * cosd(t) 0], [0 frac(k) * sind(t) 0], frac(k), ...
        'EdgeColor', [1 1 1], 'FaceAlpha', 0.92);
end
deg = char(176);
lab = {['0' deg ' (+x)'], ['90' deg ' (up)'], ['180' deg], ['270' deg ' (down)']};
angs = [0 90 180 270];
for k = 1:4
    text(ax, 1.2 * rmax * cosd(angs(k)), 1.2 * rmax * sind(angs(k)), lab{k}, ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end
hold(ax, 'off');
axis(ax, 'equal');
ax.XLim = [-1.45 1.45] * rmax;
ax.YLim = [-1.35 1.35] * rmax;
ax.XColor = 'none';
ax.YColor = 'none';
ax.CLim = [0 rmax];
colormap(ax, cmapName);
title(ax, ttl);
end
