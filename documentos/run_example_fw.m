cfg = example_fw_config();
[traj, report] = fw_generate_program(cfg, "fw_programV2.xlsx");
disp(report.Summary)
