function [traj, report] = plot_fw_points_3d(cfg, outFile)
%PLOT_FW_POINTS_3D Grafica la trayectoria sobre el cilindro en 3D.
%   Uso:
%       plot_fw_points_3d()
%       cfg = example_fw_config();
%       plot_fw_points_3d(cfg)
%       [traj, report] = plot_fw_points_3d(cfg, "fw_program.xlsx")

if nargin < 1 || isempty(cfg)
    cfg = example_fw_config();
end
if nargin < 2 || isempty(outFile)
    outFile = "fw_programV2.xlsx";
end

[traj, report] = fw_generate_program(cfg, outFile);

R = cfg.part.D_mm / 2;
theta_deg = traj.Mandrel_Rotation_deg;
z_mm = traj.Carriage_Position_mm;

x_mm = R .* cosd(theta_deg);
y_mm = R .* sind(theta_deg);

figure('Name','FW 3D Trajectory','NumberTitle','off');
hold on;
grid on;
axis equal;
view(3);

% Cilindro de referencia
nCirc = 80;
nZ = 40;
[Theta, Z] = meshgrid(linspace(0, 2*pi, nCirc), ...
                      linspace(cfg.part.zStart_mm, cfg.part.zEnd_mm, nZ));
X = R * cos(Theta);
Y = R * sin(Theta);
surf(X, Y, Z, 'FaceAlpha', 0.08, 'EdgeAlpha', 0.12, 'HandleVisibility', 'off');

% Trayectoria de bobinado
isWind = strcmp(string(traj.Motion_Type), "WIND");
isTransition = ~isWind;

plot3(x_mm(isWind), y_mm(isWind), z_mm(isWind), '-', 'LineWidth', 1.2, ...
    'DisplayName', 'WIND');

if any(isTransition)
    plot3(x_mm(isTransition), y_mm(isTransition), z_mm(isTransition), '.', ...
        'MarkerSize', 10, 'DisplayName', 'TRANSITIONS');
end

% Inicio y fin
plot3(x_mm(1), y_mm(1), z_mm(1), 'o', 'MarkerSize', 8, 'LineWidth', 1.2, ...
    'DisplayName', 'START');
plot3(x_mm(end), y_mm(end), z_mm(end), 's', 'MarkerSize', 8, 'LineWidth', 1.2, ...
    'DisplayName', 'END');

xlabel('X [mm]');
ylabel('Y [mm]');
zlabel('Z [mm]');
title(sprintf('Trayectoria 3D - %s', cfg.part.name));
legend('Location','best');

end
