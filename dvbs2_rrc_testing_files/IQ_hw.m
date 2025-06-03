% Define file paths for I and Q .txt files containing 256-bit hexadecimal data
I_file = 'i_filter_output_data.txt';
Q_file = 'q_filter_output_data.txt';

% Read raw content from files
I_hex_raw = fileread(I_file);
Q_hex_raw = fileread(Q_file);

% Split into lines
I_lines = strsplit(I_hex_raw, '\n');
Q_lines = strsplit(Q_hex_raw, '\n');

% Filter valid 256-bit hex lines (64 hex chars)
valid_I_lines = {};
valid_Q_lines = {};

for i = 1:length(I_lines)
    I_line = strrep(I_lines{i}, ' ', '');
    if all(isstrprop(I_line, 'xdigit')) && length(I_line) == 64
        valid_I_lines{end+1} = I_line;
    end
end

for i = 1:length(Q_lines)
    Q_line = strrep(Q_lines{i}, ' ', '');
    if all(isstrprop(Q_line, 'xdigit')) && length(Q_line) == 64
        valid_Q_lines{end+1} = Q_line;
    end
end

% Extract 16-bit (4 hex char) chunks from each 256-bit line
I_hex = {};
Q_hex = {};
for i = 1:length(valid_I_lines)
    line = valid_I_lines{i};
    for j = 1:16
        I_hex{end+1} = line((j-1)*4 + 1 : j*4);
    end
end

for i = 1:length(valid_Q_lines)
    line = valid_Q_lines{i};
    for j = 1:16
        Q_hex{end+1} = line((j-1)*4 + 1 : j*4);
    end
end

% Convert hex to unsigned 16-bit integers
I_uint16 = uint16(hex2dec(char(I_hex)));
Q_uint16 = uint16(hex2dec(char(Q_hex)));

% Convert to signed 16-bit integers
I_signed = double(typecast(I_uint16, 'int16'));
Q_signed = double(typecast(Q_uint16, 'int16'));

% Convert from Q15 fixed-point to floating-point
I_values = I_signed / 32768;
Q_values = Q_signed / 32768;

% Save converted floating-point values to text files
writematrix(I_values.', 'i_output_float.txt', 'Delimiter', 'tab');
writematrix(Q_values.', 'q_output_float.txt', 'Delimiter', 'tab');

% Create complex QPSK symbols
complex_symbols = I_values + 1j * Q_values;

% Plot the constellation diagram
figure;
scatter(real(complex_symbols), imag(complex_symbols), 'bo');
xlabel('In-Phase (I)');
ylabel('Quadrature (Q)');
title('QPSK Constellation Diagram');
grid on;
axis equal;

% Display completion
disp(['Plotted ', num2str(length(complex_symbols)), ' complex symbols.']);
disp('Saved I/Q float data to i_output_float.txt and q_output_float.txt');
