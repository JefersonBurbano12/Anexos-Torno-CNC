function cfg = example_fw_config()
%EXAMPLE_FW_CONFIG Configuracion base para poste cilindrico 2 ejes.

% -------------------------
% Pieza
% -------------------------
cfg.part.name = "Poste_PRFV";
cfg.part.D_mm = 200;
cfg.part.L_mm = 3000;
cfg.part.zStart_mm = 0;
cfg.part.zEnd_mm = 3000;

% -------------------------
% Maquina
% -------------------------
cfg.machine.name = "FW_2Ejes_Postes";
cfg.machine.rotAxisName = "Mandrel";
cfg.machine.linAxisName = "Carriage";
cfg.machine.rotMax_rpm = 60;
cfg.machine.linMax_mm_s = 200;
cfg.machine.reposition_mm_s = 120;
cfg.machine.index_mm_s = 80;
cfg.machine.positionMode = "ABS";
cfg.machine.rotationMode = "CONTINUOUS_POSITIVE";

% -------------------------
% Proceso
% -------------------------
cfg.process.bandWidth_mm = 25;
cfg.process.overlap_frac = 0.10;
cfg.process.dzStep_mm = 2;
cfg.process.dThetaDeg = 10;
cfg.process.turnsPerBand90 = 4;
cfg.process.angleTolerance_deg = 0.5;

% -------------------------
% Laminado mixto
% Cada capa se expande internamente a ambos sentidos: + y -
% -------------------------
cfg.layers(1).label = 'HOOP_01';
cfg.layers(1).angle_deg = 90;
cfg.layers(1).repeats = 1;
cfg.layers(1).speedRot_rpm = 20;
cfg.layers(1).zStart_mm = 0;
cfg.layers(1).zEnd_mm = 3000;
cfg.layers(1).turnsPerBand90 = 4;

cfg.layers(2).label = 'HELIX_01';
cfg.layers(2).angle_deg = 55;
cfg.layers(2).repeats = 1;
cfg.layers(2).speedRot_rpm = 18;
cfg.layers(2).zStart_mm = 0;
cfg.layers(2).zEnd_mm = 3000;

cfg.layers(3).label = 'HELIX_02';
cfg.layers(3).angle_deg = 55;
cfg.layers(3).repeats = 1;
cfg.layers(3).speedRot_rpm = 15;
cfg.layers(3).zStart_mm = 0;
cfg.layers(3).zEnd_mm = 3000;

cfg.layers(4).label = 'HELIX_03';
cfg.layers(4).angle_deg = 55;
cfg.layers(4).repeats = 1;
cfg.layers(4).speedRot_rpm = 15;
cfg.layers(4).zStart_mm = 0;
cfg.layers(4).zEnd_mm = 3000;

cfg.layers(5).label = 'HELIX_04';
cfg.layers(5).angle_deg = 55;
cfg.layers(5).repeats = 1;
cfg.layers(5).speedRot_rpm = 15;
cfg.layers(5).zStart_mm = 0;
cfg.layers(5).zEnd_mm = 3000;

cfg.layers(6).label = 'HOOP_02';
cfg.layers(6).angle_deg = 90;
cfg.layers(6).repeats = 1;
cfg.layers(6).speedRot_rpm = 20;
cfg.layers(6).zStart_mm = 0;
cfg.layers(6).zEnd_mm = 3000;
cfg.layers(6).turnsPerBand90 = 4;

% -------------------------
% Exportacion
% -------------------------
cfg.export.writeExcel = true;
cfg.export.writeControllerSheet = true;
cfg.export.writeCSV = false;
cfg.export.controllerCsvFile = "fw_controllerV2.csv";

% Uso:
% cfg = example_fw_config();
% [traj, report] = fw_generate_program(cfg, "fw_program.xlsx");
end
