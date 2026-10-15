function generate_synthetic_firebrands(outDir, nFrames)
%GENERATE_SYNTHETIC_FIREBRANDS  Synthetic firebrand image sequence with ground truth.
%
%   generate_synthetic_firebrands()                 writes 80 frames to ./synthetic_firebrands
%   generate_synthetic_firebrands(outDir, nFrames)
%
%   Glowing firebrands (Gaussian blobs of different size and brightness)
%   are released from the lower-left region, transported to the right and
%   upwards, and slowly decelerate under gravity. The true positions and
%   velocities are written to ground_truth.csv (pixels, pixels/frame, image
%   coordinates with v positive DOWNWARDS), so the software can be
%   verified: with fps = 1 the GUI speeds in px/s equal px/frame.
%
%   Only core MATLAB functions are used.

if nargin < 1 || isempty(outDir)
    outDir = fullfile(pwd, 'synthetic_firebrands');
end
if nargin < 2
    nFrames = 80;
end
if ~isfolder(outDir)
    mkdir(outDir);
end
rng(1);
W = 800;
Hgt = 600;
[XX, YY] = meshgrid(1:W, 1:Hgt);
bg = 0.06 + 0.05 * (YY / Hgt) + 0.02 * sin(XX / 90);   % deliberately uneven illumination

nP = 60;
newP = @(m) struct('x', 20 + 250 * rand(m, 1), 'y', 250 + 330 * rand(m, 1), ...
    'u', 6 + 1.5 * randn(m, 1), 'v', -4 + 1.2 * randn(m, 1), ...
    's', 1.2 + 2.2 * rand(m, 1), 'a', 0.45 + 0.55 * rand(m, 1));
p = newP(nP);
id = (1:nP)';
nextId = nP + 1;
truth = zeros(nFrames * nP, 8);
row = 0;
for f = 1:nFrames
    I = bg + 0.012 * randn(Hgt, W);
    for k = 1:nP
        r = ceil(4 * p.s(k));
        xs = max(1, floor(p.x(k) - r)):min(W, ceil(p.x(k) + r));
        ys = max(1, floor(p.y(k) - r)):min(Hgt, ceil(p.y(k) + r));
        if isempty(xs) || isempty(ys)
            continue
        end
        I(ys, xs) = I(ys, xs) + p.a(k) * exp(-((XX(ys, xs) - p.x(k)).^2 + ...
            (YY(ys, xs) - p.y(k)).^2) / (2 * p.s(k)^2));
        row = row + 1;
        truth(row, :) = [f, id(k), p.x(k), p.y(k), p.u(k), p.v(k), 2 * p.s(k), p.a(k)];
    end
    imwrite(uint8(255 * min(max(I, 0), 1)), fullfile(outDir, sprintf('frame_%04d.png', f)));

    % motion: advection + weak gravity (v grows downwards) + small swirl
    p.x = p.x + p.u;
    p.y = p.y + p.v;
    p.v = p.v + 0.04;
    p.u = p.u + 0.05 * sin(p.y / 60);

    % respawn firebrands that leave the field of view
    out = p.x > W + 10 | p.y < -10 | p.y > Hgt + 10;
    m = nnz(out);
    if m > 0
        q = newP(m);
        p.x(out) = q.x; p.y(out) = q.y; p.u(out) = q.u;
        p.v(out) = q.v; p.s(out) = q.s; p.a(out) = q.a;
        id(out) = nextId + (0:m-1)';
        nextId = nextId + m;
    end
end
truth = truth(1:row, :);
T = array2table(truth, 'VariableNames', {'frame', 'true_id', 'x_px', 'y_px', ...
    'u_px_per_frame', 'v_down_px_per_frame', 'blob_size_px', 'brightness'});
writetable(T, fullfile(outDir, 'ground_truth.csv'));
fprintf('%d frames and ground_truth.csv written to %s\n', nFrames, outDir);
fprintf('Suggested GUI settings: fps = 1, top-hat background, robust threshold, max displacement 15 px, PTV + PIV, IA 32 px.\n');
end
