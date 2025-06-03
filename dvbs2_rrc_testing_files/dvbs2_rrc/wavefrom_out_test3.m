opts = delimitedTextImportOptions("NumVariables", 14);

% Specify range and delimiter
opts.DataLines = [3, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Var1", "Var2", "Var3", "Var4", "Var5", "Var6", "Var7", "Var8", "Var9", "i_system_wrappersystem_ii_rrc_filter_Dout150", "Var11", "i_system_wrappersystem_ii_rrc_filter1_Dout150", "Var13", "Var14"];
opts.SelectedVariableNames = ["i_system_wrappersystem_ii_rrc_filter_Dout150", "i_system_wrappersystem_ii_rrc_filter1_Dout150"];
opts.VariableTypes = ["string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var4", "Var5", "Var6", "Var7", "Var8", "Var9", "i_system_wrappersystem_ii_rrc_filter_Dout150", "Var11", "i_system_wrappersystem_ii_rrc_filter1_Dout150", "Var13", "Var14"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var4", "Var5", "Var6", "Var7", "Var8", "Var9", "i_system_wrappersystem_ii_rrc_filter_Dout150", "Var11", "i_system_wrappersystem_ii_rrc_filter1_Dout150", "Var13", "Var14"], "EmptyFieldRule", "auto");

% Import the data
waveform3 = readtable("waveform3.csv", opts);
I_col = waveform3.i_system_wrappersystem_ii_rrc_filter_Dout150;
Q_col = waveform3.i_system_wrappersystem_ii_rrc_filter1_Dout150;

% Define hex pattern
isHex_I = ~cellfun(@isempty, regexp((I_col), '^[0-9A-Fa-f]{1,4}$', 'once'));
isHex_Q = ~cellfun(@isempty, regexp((Q_col), '^[0-9A-Fa-f]{1,4}$', 'once'));

% Filter valid hex rows
validRows = isHex_I & isHex_Q;
I_hex = I_col(validRows);
Q_hex = Q_col(validRows);

% Match lengths
min_len = min(length(I_hex), length(Q_hex));
I_hex = I_hex(1:min_len);
Q_hex = Q_hex(1:min_len);

% Convert to uint16
I_16 = uint16(hex2dec(I_hex));
Q_16 = uint16(hex2dec(Q_hex));

% Convert to signed 16-bit integers
I_signed = double(typecast(I_16, 'int16'));
Q_signed = double(typecast(Q_16, 'int16'));

% Normalize to Q15 range
I_float = I_signed / 32768;
Q_float = Q_signed / 32768;

writematrix(I_float, 'I_values_wavefrom3.txt', 'Delimiter','tab');
writematrix(Q_float, 'Q_values_wavefrom3.txt', 'Delimiter','tab');

% Combine into complex IQ signal
IQ = I_float + 1j * Q_float;

% Plot IQ constellation
figure;
scatter(real(IQ), imag(IQ), 'bo');
grid on;
xlabel('In-Phase');
ylabel('Quadrature');
title('IQ Constellation Plot');
axis equal;
