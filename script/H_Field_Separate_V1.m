%% ===== H_z 单图导出（3 个线圈，各自一张 PNG） — R2022b 兼容 =====
clc; clear;

% ---- 输入文件（CST: x y z HxRe HxIm HyRe HyIm HzRe HzIm）----
files = {
    'E:\learn\Matlab\AWPL2\Coil 1.txt'
    'E:\learn\Matlab\AWPL2\Coil 2.txt'
    'E:\learn\Matlab\AWPL2\Coil 3.txt'
};

% ---- ROI（默认用你指定的整数范围）----
roi = [-70 70 -70 70];   % [xmin xmax ymin ymax]

% ---- 显示参数 ----
mode             = 'signedmag';     % 'real' | 'mag' | 'signedmag'
symmetricZero    = true;            % 'real'/'signedmag' 时让 0 居中
nLevels          = 10;              % 等高线数量（默认 10）
fixedTickNum     = 5;               % 每轴固定 5 个刻度
useExactROITicks = true;            % ROI 为整数时，刻度精确包含端点
showTitle        = false;           % ***默认关闭每图标题***
cbarLabel        = 'H_z (A/m)';     % 色条顶部标题
shareCLim        = true;            % true: 三图共享色轴；false: 各自色轴

% —— 每图 colorbar 开关（按索引 1..3）；***默认三图都开***
cbarOn = [true, true, true];

% 色图方案：'redblue' [默认] | 'turbo' | 'parula' | 'jet' | 'hot'
colormapName = 'redblue';
flipCmap     = false;               % 翻转配色（可选）

% ---- 色条排版 ----
cbarTitleY      = 1.01;   % 色条标题相对位置（normalized）
cbarWidthScale  = 0.7;   % 仅调宽度：0.7 更瘦；1.3 更胖；1.0 不变
cbarShiftRight  = 0.04;   % ★把色条整体向右平移的量（normalized）
lockCbarManual  = true;   % ★把色条切到 'manual'，防止自动回流

% ---- 字体/线宽与导出 ----
fontName    = 'Times'; fontSize = 18; lineWidth = 1.5;
exportFolder= 'C:\Users\RtN_R\Desktop\MatlabPlots';  % 目标文件夹
dpi         = 400;                                    % PNG 分辨率

%% ===== 读入 & 计算色轴范围（若共享）=====
N = numel(files);
Xs = cell(N,1); Ys = cell(N,1); Zs = cell(N,1); bases = cell(N,1);

for i = 1:N
    [xg, yg, Zgrid] = read_cst_scalar(files{i}, mode);
    % 统一 ROI 裁剪
    ix = (xg >= roi(1)) & (xg <= roi(2));
    iy = (yg >= roi(3)) & (yg <= roi(4));
    xg = xg(ix); yg = yg(iy); Zgrid = Zgrid(iy, ix);

    Xs{i} = xg; Ys{i} = yg; Zs{i} = Zgrid;
    [~,name,~] = fileparts(files{i}); bases{i} = name;
end

if strcmpi(mode,'mag')
    M_each = cellfun(@(Z_) max(Z_(:),[],'omitnan'), Zs);    % [0, M]
    Mglob  = max(M_each);
else
    M_each = cellfun(@(Z_) max(abs(Z_(:)),[],'omitnan'), Zs); % [-M, M]
    Mglob  = max(M_each);
end

%% ===== 逐图绘制 & 导出 =====
if ~exist(exportFolder,'dir'), mkdir(exportFolder); end

for i = 1:N
    xg = Xs{i}; yg = Ys{i}; Z = Zs{i};

    fig = figure('Units','pixels','OuterPosition',[140,120,640,540],'Visible','on');
    ax  = axes('Parent',fig);
    ax.ActivePositionProperty = 'position';  % 减少自动外边距干扰

    contourf(ax, xg, yg, Z, nLevels);
    shading(ax,'interp'); view(ax,2); axis(ax,'equal'); box(ax,'on');

    hold(ax,'on');
    if ~strcmpi(mode,'mag')
        contour(ax, xg, yg, Z, [0 0], 'k-', 'LineWidth', 1.1); % 0 等值线
    end
    hold(ax,'off');

    ax.LineWidth = lineWidth;
    ax.FontName  = fontName;
    ax.FontSize  = fontSize;
    xlabel(ax,'x (mm)'); ylabel(ax,'y (mm)');
    if showTitle
        title(ax, sprintf('%s', bases{i}), 'Interpreter','none');
    end

    % 色图 + 色轴范围
    apply_colormap(ax, colormapName, flipCmap);
    if strcmpi(mode,'mag')
        if shareCLim, caxis(ax, [0 Mglob]); else, caxis(ax, [0 M_each(i)]); end
    else
        if symmetricZero
            if shareCLim, caxis(ax, [-Mglob Mglob]); else, caxis(ax, [-M_each(i) M_each(i)]); end
        end
    end

    % === 刻度：始终 5 个，且标签为整数（端点精确等于 ROI） ===
    [tx, lx] = exact_ticks_from_limits(roi(1), roi(2), fixedTickNum);
    [ty, ly] = exact_ticks_from_limits(roi(3), roi(4), fixedTickNum);
    xticks(ax, round(tx)); xlim(ax, lx);
    yticks(ax, round(ty)); ylim(ax, ly);
    xtickformat(ax,'%.0f'); ytickformat(ax,'%.0f');

    % ========= 安全补丁：确保 x 轴标签不被裁切 =========
    drawnow;                           % 让标签/刻度尺寸真实化
    ax.Units = 'normalized';
    pos = ax.Position;                 % [left bottom width height]
    ti  = ax.TightInset;               % [left bottom right top]

    minBottom = max(0.12, ti(2) + 0.01);   % 基于 TightInset 的安全底边距
    if pos(2) < minBottom
        d = minBottom - pos(2);
        pos(2) = minBottom;
        pos(4) = max(0.2, pos(4) - d);     % 仅竖向收缩绘图区
        ax.Position = pos;
        drawnow;
    end
    % ========= 安全补丁结束 =========

    % === 每图 colorbar（右侧外部；标题置顶；宽度只向内收/放 + 可右移）===
    if i <= numel(cbarOn) && cbarOn(i)
        cb = colorbar(ax, 'Location','eastoutside');
        cb.TickDirection = 'out';
        title(cb, cbarLabel);
        if isprop(cb,'Label'), cb.Label.String = ''; end

        if lockCbarManual, cb.Location = 'manual'; end

        ax.Units = 'normalized'; cb.Units = 'normalized';
        drawnow;                        % 先让几何稳定
        ap = ax.Position;               % [x y w h]
        cp = cb.Position;               % [x y w h]

        % 顶/底与轴对齐
        cp(2) = ap(2);
        cp(4) = ap(4);

        % 以自动 eastoutside 的右边缘为基准，做宽度缩放 + 右移
        right0 = cp(1) + cp(3);
        newW   = cp(3) * cbarWidthScale;
        maxRight = 0.98;                      % 轻微防裁切（右侧留 2%）
        right    = min(maxRight, right0 + cbarShiftRight);

        cp(1) = right - newW;
        cp(3) = newW;

        cb.Position = cp;

        cb.Title.Units = 'normalized';
        cb.Title.Position = [0.5, cbarTitleY, 0];
    else
        delete(findall(fig,'Type','ColorBar'));
    end

    % 导出 PNG（figure 级导出，包含色条与标题）
    drawnow;
    outFile = fullfile(exportFolder, sprintf('%s_Hz.png', bases{i}));
    exportgraphics(fig, outFile, 'Resolution', dpi);
    fprintf('Saved: %s\n', outFile);
end

%% ========= 辅助函数（务必放在文件末尾；此后不要再写脚本代码） =========
function [xg, yg, Z] = read_cst_scalar(file, mode)
    opts = detectImportOptions(file,'FileType','text');
    T = readtable(file, opts);
    x = T{:,1}; y = T{:,2};
    HzRe = T{:,8}; HzIm = T{:,9};
    Hmag = hypot(HzRe, HzIm);
    switch lower(mode)
        case 'real',      Zval = HzRe;
        case 'mag',       Zval = Hmag;
        case 'signedmag', Zval = sign(HzRe).*Hmag;
        otherwise, error('Unknown mode.');
    end
    xg = unique(x,'sorted'); yg = unique(y,'sorted');
    [~, ix] = ismember(x, xg); [~, iy] = ismember(y, yg);
    Z = accumarray([iy ix], Zval, [numel(yg) numel(xg)], @mean, NaN);
end

% ROI 为整数端点时，tick 精确包含端点；中间尽量整数（端点不动）
function [T, L] = exact_ticks_from_limits(lo, hi, N)
    if hi < lo, [lo,hi] = deal(hi,lo); end
    T = linspace(lo, hi, max(N,2));
    if all(mod([lo hi],1)==0)
        T(2:end-1) = round(T(2:end-1));
    end
    if numel(T) > N, T = T(1:N); elseif numel(T) < N, T = linspace(lo, hi, N); end
    T = unique(T,'stable');
    L = [lo hi];
end

% “好看”的整数 tick（备用）
function [T, L] = nice_int_ticks(lo, hi, N)
    if hi < lo, tmp = lo; lo = hi; hi = tmp; end
    if lo == hi, lo = lo - 2; hi = hi + 2; end
    rawStep = (hi - lo)/max(N-1,1);
    step    = max(1, round(rawStep));
    start = floor(lo/step)*step;
    stop  = ceil(hi/step)*step;
    k = round((stop - start)/step) + 1;
    if k < N
        stop = stop + (N - k)*step;
    elseif k > N
        stop = stop - (k - N)*step;
        k2 = round((stop - start)/step) + 1;
        if k2 > N, start = start + (k2 - N)*step; end
    end
    T = start:step:stop;
    if numel(T) ~= N
        T = round(linspace(start, stop, N));
        while numel(unique(T)) < N
            stop = stop + step; T = start:step:stop;
            if numel(T) >= N, T = T(1:N); break; end
        end
    end
    T = round(unique(T,'stable'));
    L = [T(1) T(end)];
end

% 选择色图（内置 + 自定义红蓝）；可选 flipCmap 翻转
function apply_colormap(ax, name, doFlip)
    switch lower(name)
        case 'redblue',   cmap = redwhiteblue();
        case 'turbo',     cmap = turbo;
        case 'parula',    cmap = parula;
        case 'jet',       cmap = jet;
        case 'hot',       cmap = hot;
        otherwise,        cmap = redwhiteblue(); % 默认
    end
    if doFlip, cmap = flipud(cmap); end
    colormap(ax, cmap);
end

% 自定义红-白-蓝发散色表
function cmap = redwhiteblue(n)
    if nargin<1, n = 256; end
    n  = max(3, round(n));
    n2 = floor(n/2);
    b2w = [linspace(0,1,n2)', linspace(0,1,n2)', ones(n2,1)];
    n1  = n - n2;
    w2r = [ones(n1,1), linspace(1,0,n1)', linspace(1,0,n1)'];
    cmap = [b2w; w2r];
end