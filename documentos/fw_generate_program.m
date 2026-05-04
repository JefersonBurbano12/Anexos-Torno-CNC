function [traj, report] = fw_generate_program(cfg, outFile)
%FW_GENERATE_PROGRAM Generador estructurado de trayectorias filament winding.
%   [traj, report] = fw_generate_program(cfg, outFile)
%
%   Genera trayectorias para un poste cilindrico en una maquina de 2 ejes:
%   - Eje 1: rotacion del mandril
%   - Eje 2: traslacion del carro
%
%   Soporta:
%   - Capas helicoidales (ej. 55 deg)
%   - Capas hoop 90 deg indexadas
%   - Ambos sentidos para cada capa: + y -
%   - Secuencia mixta definida por el usuario
%   - Exportacion a Excel con hojas:
%       Parametros, Secuencia_Capas, Trayectoria, Controlador, Resumen, Alertas
%
%   Entrada minima esperada:
%       cfg.part.D_mm
%       cfg.part.L_mm
%       cfg.layers(i).angle_deg
%
%   Ejemplo:
%       cfg = example_fw_config();
%       [traj, report] = fw_generate_program(cfg, "fw_program.xlsx");

if nargin < 2 || isempty(outFile)
    outFile = "fw_program.xlsx";
end

cfg = fw_complete_cfg(cfg);
fw_validate_cfg(cfg);
seq = fw_expand_layers(cfg);
[traj, report] = fw_build_program(cfg, seq);
fw_write_outputs(cfg, seq, traj, report, outFile);
end

% =========================================================================
% CONFIGURACION
% =========================================================================
function cfg = fw_complete_cfg(cfg)
% ---------- Pieza ----------
if ~isfield(cfg, 'part')
    error('Falta cfg.part');
end
if ~isfield(cfg.part, 'D_mm')
    error('Falta cfg.part.D_mm');
end
if ~isfield(cfg.part, 'L_mm')
    error('Falta cfg.part.L_mm');
end
if ~isfield(cfg.part, 'zStart_mm'), cfg.part.zStart_mm = 0; end
if ~isfield(cfg.part, 'zEnd_mm'),   cfg.part.zEnd_mm   = cfg.part.L_mm; end
if ~isfield(cfg.part, 'name'),      cfg.part.name      = "Poste_Cilindrico"; end

% ---------- Maquina ----------
if ~isfield(cfg, 'machine'), cfg.machine = struct(); end
if ~isfield(cfg.machine, 'name'),             cfg.machine.name = "FW_2_Axes"; end
if ~isfield(cfg.machine, 'rotAxisName'),      cfg.machine.rotAxisName = "Mandrel"; end
if ~isfield(cfg.machine, 'linAxisName'),      cfg.machine.linAxisName = "Carriage"; end
if ~isfield(cfg.machine, 'rotMax_rpm'),       cfg.machine.rotMax_rpm = 60; end
if ~isfield(cfg.machine, 'linMax_mm_s'),      cfg.machine.linMax_mm_s = 200; end
if ~isfield(cfg.machine, 'reposition_mm_s'),  cfg.machine.reposition_mm_s = 120; end
if ~isfield(cfg.machine, 'index_mm_s'),       cfg.machine.index_mm_s = 80; end
if ~isfield(cfg.machine, 'rotAcceleration_deg_s2')
    cfg.machine.rotAcceleration_deg_s2 = 3600;
end
if ~isfield(cfg.machine, 'linAcceleration_mm_s2')
    cfg.machine.linAcceleration_mm_s2 = 1000;
end
if ~isfield(cfg.machine, 'positionMode')
    cfg.machine.positionMode = "ABS";
end
if ~isfield(cfg.machine, 'rotationMode')
    cfg.machine.rotationMode = "CONTINUOUS_POSITIVE";
end

% ---------- Proceso ----------
if ~isfield(cfg, 'process'), cfg.process = struct(); end
if ~isfield(cfg.process, 'bandWidth_mm'),   cfg.process.bandWidth_mm = 25; end
if ~isfield(cfg.process, 'overlap_frac'),   cfg.process.overlap_frac = 0.10; end
if ~isfield(cfg.process, 'dzStep_mm'),      cfg.process.dzStep_mm = 2; end
if ~isfield(cfg.process, 'dThetaDeg'),      cfg.process.dThetaDeg = 10; end
if ~isfield(cfg.process, 'turnsPerBand90'), cfg.process.turnsPerBand90 = 4; end
if ~isfield(cfg.process, 'hoopMode'),       cfg.process.hoopMode = "INDEXED"; end
if ~isfield(cfg.process, 'angleTolerance_deg')
    cfg.process.angleTolerance_deg = 0.5;
end
if ~isfield(cfg.process, 'indexStep_mm')
    cfg.process.indexStep_mm = cfg.process.bandWidth_mm * (1 - cfg.process.overlap_frac);
end
cfg.process.indexStep_mm = max(cfg.process.indexStep_mm, eps);

% ---------- Exportacion ----------
if ~isfield(cfg, 'export'), cfg.export = struct(); end
if ~isfield(cfg.export, 'writeExcel'), cfg.export.writeExcel = true; end
if ~isfield(cfg.export, 'writeControllerSheet'), cfg.export.writeControllerSheet = true; end
if ~isfield(cfg.export, 'writeCSV'), cfg.export.writeCSV = false; end
if ~isfield(cfg.export, 'controllerCsvFile')
    cfg.export.controllerCsvFile = "fw_controller.csv";
end
if ~isfield(cfg.export, 'controllerColumns')
    cfg.export.controllerColumns = {
        'Point', 'Time_s', 'Mandrel_Rotation_deg', 'Carriage_Position_mm', ...
        'Mandrel_Speed_deg_s', 'Carriage_Speed_mm_s', 'Angle_Command_deg', ...
        'DirectionLabel', 'Path_Type', 'Motion_Type'};
end

% ---------- Capas ----------
if ~isfield(cfg, 'layers') || isempty(cfg.layers)
    error('Debes definir cfg.layers');
end

for i = 1:numel(cfg.layers)
    if ~isfield(cfg.layers(i), 'angle_deg')
        error('Falta cfg.layers(%d).angle_deg', i);
    end
    if ~isfield(cfg.layers(i), 'repeats'), cfg.layers(i).repeats = 1; end
    if ~isfield(cfg.layers(i), 'speedRot_rpm'), cfg.layers(i).speedRot_rpm = 20; end
    if ~isfield(cfg.layers(i), 'zStart_mm'), cfg.layers(i).zStart_mm = cfg.part.zStart_mm; end
    if ~isfield(cfg.layers(i), 'zEnd_mm'),   cfg.layers(i).zEnd_mm   = cfg.part.zEnd_mm; end
    if ~isfield(cfg.layers(i), 'turnsPerBand90')
        cfg.layers(i).turnsPerBand90 = cfg.process.turnsPerBand90;
    end
    if ~isfield(cfg.layers(i), 'label')
        cfg.layers(i).label = sprintf('L%02d', i);
    end
end
end

function fw_validate_cfg(cfg)
if cfg.part.D_mm <= 0
    error('cfg.part.D_mm debe ser > 0');
end
if cfg.part.L_mm <= 0
    error('cfg.part.L_mm debe ser > 0');
end
if cfg.part.zEnd_mm < cfg.part.zStart_mm
    error('cfg.part.zEnd_mm debe ser >= cfg.part.zStart_mm');
end
if cfg.machine.rotMax_rpm <= 0
    error('cfg.machine.rotMax_rpm debe ser > 0');
end
if cfg.machine.linMax_mm_s <= 0
    error('cfg.machine.linMax_mm_s debe ser > 0');
end
if cfg.process.bandWidth_mm <= 0
    error('cfg.process.bandWidth_mm debe ser > 0');
end
if cfg.process.dzStep_mm <= 0
    error('cfg.process.dzStep_mm debe ser > 0');
end
if cfg.process.dThetaDeg <= 0
    error('cfg.process.dThetaDeg debe ser > 0');
end

for i = 1:numel(cfg.layers)
    a = cfg.layers(i).angle_deg;
    if ~(abs(a - 90) < 1e-9 || (a > 0 && a < 90))
        error('La capa %d tiene un angulo no valido: %g', i, a);
    end
    if cfg.layers(i).speedRot_rpm <= 0
        error('La capa %d debe tener speedRot_rpm > 0', i);
    end
    zMin = min(cfg.layers(i).zStart_mm, cfg.layers(i).zEnd_mm);
    zMax = max(cfg.layers(i).zStart_mm, cfg.layers(i).zEnd_mm);
    if zMin < cfg.part.zStart_mm - 1e-9 || zMax > cfg.part.zEnd_mm + 1e-9
        error('La capa %d excede los limites axiales de la pieza', i);
    end
end
end

% =========================================================================
% EXPANSION DE CAPAS A SUBTRAYECTORIAS
% =========================================================================
function seq = fw_expand_layers(cfg)
seq = struct([]);
n = 0;

for i = 1:numel(cfg.layers)
    L = cfg.layers(i);
    for r = 1:L.repeats
        dirs = [1, -1];
        for d = 1:numel(dirs)
            n = n + 1;
            dirSign = dirs(d);
            seq(n).Subpath_ID = n;
            seq(n).Layer_ID = i;
            seq(n).Repeat_ID = r;
            seq(n).Layer_Label = string(L.label);
            seq(n).Angle_Command_deg = L.angle_deg;
            seq(n).Direction = dirSign;
            seq(n).DirectionLabel = string(fw_sign_to_label(dirSign));
            seq(n).SpeedRot_rpm = L.speedRot_rpm;
            seq(n).TurnsPerBand90 = L.turnsPerBand90;
            if abs(L.angle_deg - 90) < 1e-9
                seq(n).Path_Type = "HOOP";
            else
                seq(n).Path_Type = "HELICAL";
            end
            if dirSign > 0
                seq(n).StartZ_mm = L.zStart_mm;
                seq(n).EndZ_mm = L.zEnd_mm;
            else
                seq(n).StartZ_mm = L.zEnd_mm;
                seq(n).EndZ_mm = L.zStart_mm;
            end
            seq(n).Description = string(sprintf('%s_R%d_%s%d', L.label, r, fw_sign_to_label(dirSign), round(L.angle_deg)));
        end
    end
end
end

% =========================================================================
% GENERACION GENERAL DEL PROGRAMA
% =========================================================================
function [traj, report] = fw_build_program(cfg, seq)
traj = table();
state = fw_init_state(cfg);

for k = 1:numel(seq)
    if abs(state.Carriage_Position_mm - seq(k).StartZ_mm) > 1e-9
        trMove = fw_gen_transition(state, seq(k), seq(k).StartZ_mm, cfg.machine.reposition_mm_s, ...
            "TRANSITION", "REPOSITION", cfg);
        traj = [traj; trMove]; %#ok<AGROW>
        state = fw_update_state_from_table(state, trMove);
    end

    if seq(k).Path_Type == "HELICAL"
        tr = fw_gen_helical(state, seq(k), cfg);
    else
        tr = fw_gen_hoop(state, seq(k), cfg);
    end

    traj = [traj; tr]; %#ok<AGROW>
    state = fw_update_state_from_table(state, tr);
end

traj = fw_finalize_trajectory(traj, cfg);
report = fw_build_report(cfg, seq, traj);
end

function state = fw_init_state(cfg)
state.Point = 1;
state.Time_s = 0;
state.Mandrel_Rotation_deg = 0;
state.Carriage_Position_mm = cfg.part.zStart_mm;
end

% =========================================================================
% GENERADORES DE SUBTRAYECTORIAS
% =========================================================================
function tr = fw_gen_helical(state, seq, cfg)
D = cfg.part.D_mm;
pitch_mm_per_rev = pi * D / tand(abs(seq.Angle_Command_deg));

z = fw_make_linear_path(seq.StartZ_mm, seq.EndZ_mm, cfg.process.dzStep_mm);
N = numel(z);

if N == 1
    theta = state.Mandrel_Rotation_deg;
    time = state.Time_s;
    mSpeed = 0;
    cSpeed = 0;
else
    deltaZ = [0; diff(z)];
    deltaTheta = 360 * abs(deltaZ) / pitch_mm_per_rev;
    theta = state.Mandrel_Rotation_deg + cumsum(deltaTheta);

    omega_deg_s = seq.SpeedRot_rpm * 360 / 60;
    deltaTime = zeros(N,1);
    deltaTime(2:end) = deltaTheta(2:end) / omega_deg_s;
    time = state.Time_s + cumsum(deltaTime);

    mSpeed = zeros(N,1);
    mSpeed(2:end) = omega_deg_s;

    cSpeed = zeros(N,1);
    cSpeed(2:end) = deltaZ(2:end) ./ max(deltaTime(2:end), eps);
end

tr = fw_build_table(state.Point, seq, time, theta, z, mSpeed, cSpeed, "HELICAL", "WIND", cfg);
end

function tr = fw_gen_hoop(state, seq, cfg)
step = cfg.process.indexStep_mm;
zBands = fw_make_linear_path(seq.StartZ_mm, seq.EndZ_mm, step);

tr = table();
local = state;

for i = 1:numel(zBands)
    turns = seq.TurnsPerBand90;
    totalTheta = 360 * turns;
    nPts = max(2, ceil(totalTheta / cfg.process.dThetaDeg) + 1);

    theta = local.Mandrel_Rotation_deg + linspace(0, totalTheta, nPts)';
    z = zBands(i) * ones(nPts, 1);

    omega_deg_s = seq.SpeedRot_rpm * 360 / 60;
    deltaTime = zeros(nPts,1);
    deltaTime(2:end) = diff(theta) / omega_deg_s;
    time = local.Time_s + cumsum(deltaTime);

    mSpeed = zeros(nPts,1);
    mSpeed(2:end) = omega_deg_s;
    cSpeed = zeros(nPts,1);

    trBand = fw_build_table(local.Point, seq, time, theta, z, mSpeed, cSpeed, "HOOP", "WIND", cfg);
    tr = [tr; trBand]; %#ok<AGROW>
    local = fw_update_state_from_table(local, trBand);

    if i < numel(zBands)
        trIndex = fw_gen_transition(local, seq, zBands(i+1), cfg.machine.index_mm_s, ...
            "HOOP", "INDEX", cfg);
        tr = [tr; trIndex]; %#ok<AGROW>
        local = fw_update_state_from_table(local, trIndex);
    end
end
end

function tr = fw_gen_transition(state, seq, zTarget, v_mm_s, pathType, motionType, cfg)
if nargin < 5 || isempty(pathType), pathType = "TRANSITION"; end
if nargin < 6 || isempty(motionType), motionType = "MOVE"; end

travel = abs(zTarget - state.Carriage_Position_mm);
step = max(1, travel / 20);
z = fw_make_linear_path(state.Carriage_Position_mm, zTarget, step);
N = numel(z);

theta = state.Mandrel_Rotation_deg * ones(N,1);
deltaTime = zeros(N,1);
cSpeed = zeros(N,1);
if N > 1
    deltaZ = [0; diff(z)];
    deltaTime(2:end) = abs(deltaZ(2:end)) / max(v_mm_s, eps);
    cSpeed(2:end) = deltaZ(2:end) ./ max(deltaTime(2:end), eps);
end

time = state.Time_s + cumsum(deltaTime);
mSpeed = zeros(N,1);
tr = fw_build_table(state.Point, seq, time, theta, z, mSpeed, cSpeed, pathType, motionType, cfg);
end

% =========================================================================
% CONSTRUCCION TABULAR
% =========================================================================
function tr = fw_build_table(pointStart, seq, time, theta, z, mSpeed, cSpeed, pathType, motionType, cfg)
N = numel(time);
if N ~= numel(theta) || N ~= numel(z)
    error('Dimension inconsistente en fw_build_table');
end

Point = (pointStart : pointStart + N - 1)';
DeltaTime_s = [0; diff(time)];
DeltaTheta_deg = [0; diff(theta)];
DeltaZ_mm = [0; diff(z)];
Generated_Angle_deg = fw_generated_angle(cfg.part.D_mm, DeltaTheta_deg, DeltaZ_mm);
Fiber_Segment_mm = fw_fiber_segment(cfg.part.D_mm, DeltaTheta_deg, DeltaZ_mm, pathType, motionType);

tr = table();
tr.Point = Point;
tr.Layer_ID = repmat(seq.Layer_ID, N, 1);
tr.Repeat_ID = repmat(seq.Repeat_ID, N, 1);
tr.Subpath_ID = repmat(seq.Subpath_ID, N, 1);
tr.Layer_Label = repmat(string(seq.Layer_Label), N, 1);
tr.Description = repmat(string(seq.Description), N, 1);
tr.Path_Type = repmat(string(pathType), N, 1);
tr.Motion_Type = repmat(string(motionType), N, 1);
tr.Angle_Command_deg = repmat(seq.Angle_Command_deg, N, 1);
tr.Generated_Angle_deg = Generated_Angle_deg;
tr.Direction = repmat(seq.Direction, N, 1);
tr.DirectionLabel = repmat(string(seq.DirectionLabel), N, 1);
tr.Time_s = time;
tr.DeltaTime_s = DeltaTime_s;
tr.Mandrel_Rotation_deg = theta;
tr.DeltaTheta_deg = DeltaTheta_deg;
tr.Carriage_Position_mm = z;
tr.DeltaZ_mm = DeltaZ_mm;
tr.Mandrel_Speed_deg_s = mSpeed;
tr.Mandrel_Speed_rpm = mSpeed / 6;
tr.Carriage_Speed_mm_s = cSpeed;
tr.Fiber_Segment_mm = Fiber_Segment_mm;
end

function traj = fw_finalize_trajectory(traj, cfg)
traj.Fiber_Cumulative_m = cumsum(traj.Fiber_Segment_mm) / 1000;
traj.Alert = strings(height(traj), 1);

rotLimit_deg_s = cfg.machine.rotMax_rpm * 360 / 60;
idx = abs(traj.Mandrel_Speed_deg_s) > rotLimit_deg_s + 1e-9;
traj.Alert(idx) = traj.Alert(idx) + "ROT_MAX;";

idx = abs(traj.Carriage_Speed_mm_s) > cfg.machine.linMax_mm_s + 1e-9;
traj.Alert(idx) = traj.Alert(idx) + "LIN_MAX;";

idx = traj.Carriage_Position_mm < min(cfg.part.zStart_mm, cfg.part.zEnd_mm) - 1e-9 | ...
      traj.Carriage_Position_mm > max(cfg.part.zStart_mm, cfg.part.zEnd_mm) + 1e-9;
traj.Alert(idx) = traj.Alert(idx) + "Z_OUT;";

idxWind = traj.Motion_Type == "WIND";
idxAngle = idxWind & abs(traj.Generated_Angle_deg - traj.Angle_Command_deg) > cfg.process.angleTolerance_deg;
traj.Alert(idxAngle) = traj.Alert(idxAngle) + "ANGLE_DEV;";

idxTime = [false; diff(traj.Time_s) < -1e-12];
traj.Alert(idxTime) = traj.Alert(idxTime) + "TIME_NON_MONOTONIC;";

idxTheta = [false; diff(traj.Mandrel_Rotation_deg) < -1e-12];
traj.Alert(idxTheta) = traj.Alert(idxTheta) + "THETA_NON_MONOTONIC;";
end

function state = fw_update_state_from_table(state, tr)
state.Point = tr.Point(end) + 1;
state.Time_s = tr.Time_s(end);
state.Mandrel_Rotation_deg = tr.Mandrel_Rotation_deg(end);
state.Carriage_Position_mm = tr.Carriage_Position_mm(end);
end

% =========================================================================
% REPORTES Y EXPORTACION
% =========================================================================
function report = fw_build_report(cfg, seq, traj)
report = struct();
report.Parameters = fw_build_parameters_table(cfg);
report.Sequence = struct2table(seq);
report.Controller = fw_build_controller_table(traj, cfg);
report.Summary = fw_build_summary_table(cfg, seq, traj);
report.Alerts = traj(strlength(traj.Alert) > 0, :);
end

function T = fw_build_parameters_table(cfg)
names = {
    'Part_Name'; 'D_mm'; 'L_mm'; 'zStart_mm'; 'zEnd_mm'; ...
    'Machine_Name'; 'Rot_Axis'; 'Lin_Axis'; 'Position_Mode'; 'Rotation_Mode'; ...
    'rotMax_rpm'; 'linMax_mm_s'; 'reposition_mm_s'; 'index_mm_s'; ...
    'bandWidth_mm'; 'overlap_frac'; 'indexStep_mm'; 'dzStep_mm'; 'dThetaDeg'; 'turnsPerBand90'; ...
    'hoopMode'; 'angleTolerance_deg'};
values = {
    cfg.part.name; cfg.part.D_mm; cfg.part.L_mm; cfg.part.zStart_mm; cfg.part.zEnd_mm; ...
    cfg.machine.name; cfg.machine.rotAxisName; cfg.machine.linAxisName; cfg.machine.positionMode; cfg.machine.rotationMode; ...
    cfg.machine.rotMax_rpm; cfg.machine.linMax_mm_s; cfg.machine.reposition_mm_s; cfg.machine.index_mm_s; ...
    cfg.process.bandWidth_mm; cfg.process.overlap_frac; cfg.process.indexStep_mm; cfg.process.dzStep_mm; cfg.process.dThetaDeg; cfg.process.turnsPerBand90; ...
    cfg.process.hoopMode; cfg.process.angleTolerance_deg};
units = {
    '-'; 'mm'; 'mm'; 'mm'; 'mm'; ...
    '-'; '-'; '-'; '-'; '-'; ...
    'rpm'; 'mm/s'; 'mm/s'; 'mm/s'; ...
    'mm'; '-'; 'mm'; 'mm'; 'deg'; 'turns'; ...
    '-'; 'deg'};

T = table(string(names(:)), values(:), string(units(:)), ...
    'VariableNames', {'Parameter', 'Value', 'Unit'});
end

function T = fw_build_controller_table(traj, cfg)
vars = cfg.export.controllerColumns;
keep = vars(ismember(vars, traj.Properties.VariableNames));
T = traj(:, keep);
end

function T = fw_build_summary_table(cfg, seq, traj)
idxWind = traj.Motion_Type == "WIND";
summaryNames = {
    'Part_Name';
    'Machine_Name';
    'Total_Layers';
    'Total_Subpaths';
    'Total_Points';
    'Winding_Points';
    'Program_Time_s';
    'Winding_Time_s';
    'Total_Fiber_m';
    'Max_Mandrel_Speed_rpm';
    'Max_Carriage_Speed_mm_s';
    'Final_Mandrel_Rotation_deg';
    'Start_Z_mm';
    'End_Z_mm';
    'Alerts_Count'};
summaryValues = {
    cfg.part.name;
    cfg.machine.name;
    numel(unique([seq.Layer_ID]));
    numel(seq);
    height(traj);
    sum(idxWind);
    traj.Time_s(end);
    sum(traj.DeltaTime_s(idxWind));
    sum(traj.Fiber_Segment_mm) / 1000;
    max(abs(traj.Mandrel_Speed_rpm));
    max(abs(traj.Carriage_Speed_mm_s));
    traj.Mandrel_Rotation_deg(end);
    traj.Carriage_Position_mm(1);
    traj.Carriage_Position_mm(end);
    nnz(strlength(traj.Alert) > 0)};
summaryUnits = {
    '-'; '-'; '-'; '-'; '-'; '-'; 's'; 's'; 'm'; 'rpm'; 'mm/s'; 'deg'; 'mm'; 'mm'; '-'};

T = table(string(summaryNames), summaryValues, string(summaryUnits), ...
    'VariableNames', {'Metric', 'Value', 'Unit'});
end

function fw_write_outputs(cfg, seq, traj, report, outFile)
if ~cfg.export.writeExcel
    return
end

writetable(report.Parameters, outFile, 'Sheet', 'Parametros');
writetable(report.Sequence, outFile, 'Sheet', 'Secuencia_Capas');
writetable(traj, outFile, 'Sheet', 'Trayectoria');

if cfg.export.writeControllerSheet
    writetable(report.Controller, outFile, 'Sheet', 'Controlador');
end

writetable(report.Summary, outFile, 'Sheet', 'Resumen');

if isempty(report.Alerts)
    emptyAlerts = table(strings(0,1), 'VariableNames', {'Alert'});
    writetable(emptyAlerts, outFile, 'Sheet', 'Alertas');
else
    writetable(report.Alerts, outFile, 'Sheet', 'Alertas');
end

if cfg.export.writeCSV
    writetable(report.Controller, cfg.export.controllerCsvFile);
end
end

% =========================================================================
% UTILIDADES NUMERICAS
% =========================================================================
function x = fw_make_linear_path(x0, x1, step)
if abs(x1 - x0) < 1e-12
    x = x0;
    return
end

step = abs(step);
dirSign = sign(x1 - x0);
x = (x0 : dirSign * step : x1)';
if isempty(x) || abs(x(end) - x1) > 1e-9
    x = [x; x1];
end
end

function txt = fw_sign_to_label(s)
if s >= 0
    txt = '+';
else
    txt = '-';
end
end

function ang = fw_generated_angle(D_mm, deltaTheta_deg, deltaZ_mm)
circAdvance = pi * D_mm * abs(deltaTheta_deg) / 360;
ang = zeros(size(deltaTheta_deg));

for i = 1:numel(deltaTheta_deg)
    if abs(deltaTheta_deg(i)) < 1e-12 && abs(deltaZ_mm(i)) < 1e-12
        ang(i) = 0;
    elseif abs(deltaZ_mm(i)) < 1e-12
        ang(i) = 90;
    elseif abs(deltaTheta_deg(i)) < 1e-12
        ang(i) = 0;
    else
        ang(i) = atan2d(circAdvance(i), abs(deltaZ_mm(i)));
    end
end
end

function seg = fw_fiber_segment(D_mm, deltaTheta_deg, deltaZ_mm, pathType, motionType)
seg = zeros(size(deltaTheta_deg));
if motionType ~= "WIND"
    return
end

circAdvance = pi * D_mm * abs(deltaTheta_deg) / 360;
if pathType == "HELICAL"
    seg = hypot(abs(deltaZ_mm), circAdvance);
elseif pathType == "HOOP"
    seg = circAdvance;
end
end
