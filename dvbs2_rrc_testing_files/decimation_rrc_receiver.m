clc; clear;

%% Parameters
Fs = 25e6;             % Sampling frequency
sps = 4;               % Samples per symbol (interpolation factor)
symbolRate = Fs / sps;
rolloff = 0.2;
span = 8;             % Filter span in symbols
N = span * sps;        % Filter order
fprintf('Filter order: %d\n', N);

%% Read input I/Q hex data from file
fid = fopen('filter_input_data.txt', 'r');
hexLines = textscan(fid, '%s');
fclose(fid);
hexLines = hexLines{1};
numSymbols = length(hexLines);
I = zeros(numSymbols, 1);
Q = zeros(numSymbols, 1);

for k = 1:numSymbols
    hexStr = hexLines{k};
    if length(hexStr) < 8
        hexStr = [repmat('0', 1, 8 - length(hexStr)), hexStr];
    end
    hexI = hexStr(1:4);
    hexQ = hexStr(5:8);
    intI = typecast(uint16(hex2dec(hexI)), 'int16');
    intQ = typecast(uint16(hex2dec(hexQ)), 'int16');
    I(k) = double(intI) / 32768;
    Q(k) = double(intQ) / 32768;
end

qpskSymbols = I + 1i * Q;

%% Read RRC filter coefficients from .coe file
fid = fopen('rrc_coeff_32_fs25MHz_sps4_rof20.coe', 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n'); fclose(fid);
lines = lines{1};
startIdx = find(contains(lines, 'coefdata=')) + 1;
rawCoeffs = lines(startIdx:end);
for i = 1:length(rawCoeffs)
    rawCoeffs{i} = strrep(rawCoeffs{i}, ';', '');
    rawCoeffs{i} = strrep(rawCoeffs{i}, ',', '');
end
scale = 32767;
rrcFilter = str2double(rawCoeffs);
Lh = length(rrcFilter);  % e.g., 129
fprintf('Length of RRC filter: %d\n', Lh);



%% Constellation plots
figure;
%subplot(1,1,1);
plot(I, Q, 'bo');
title('Original QPSK Constellation');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;



%% Initialize
rx_I_input = [];

% Read 32-bit hex values for rx_I
fid = fopen('i_filter_output_data.txt', 'r');
hex_I_lines = textscan(fid, '%s');
fclose(fid);
hex_I_lines = hex_I_lines{1};

for k = 1:length(hex_I_lines)
    hexStr = upper(strtrim(hex_I_lines{k}));  % Ensure uppercase, no spaces
    if length(hexStr) == 8 && all(ismember(hexStr, '0123456789ABCDEF'))
        val = typecast(uint32(hex2dec(hexStr)), 'int32');
        rx_I_input(end+1,1) = double(val) / (2^31);  % Normalize to ±1
    else
        % Skip invalid line (e.g., 'XXXXXXXX')
        %fprintf('Skipping invalid hex line at %d: %s\n', k, hexStr);
    end
end


% Initialize
rx_Q_input = [];

fid = fopen('q_filter_output_data.txt', 'r');
hex_Q_lines = textscan(fid, '%s');
fclose(fid);
hex_Q_lines = hex_Q_lines{1};

for k = 1:length(hex_Q_lines)
    hexStr = upper(strtrim(hex_Q_lines{k}));
    if length(hexStr) == 8 && all(ismember(hexStr, '0123456789ABCDEF'))
        val = typecast(uint32(hex2dec(hexStr)), 'int32');
        rx_Q_input(end+1,1) = double(val) / (2^31);
    else
        %fprintf('Skipping invalid hex line at %d: %s\n', k, hexStr);
    end
end


%% Receiver side: Matched filtering using conv
rx_I = conv(rx_I_input, rrcFilter, 'full');
rx_Q = conv(rx_Q_input, rrcFilter, 'full');


% Total filter delay
totalDelay = 2 * (span * sps / 2);
rx_I = rx_I(totalDelay+1:end-totalDelay);
rx_Q = rx_Q(totalDelay+1:end-totalDelay);

% Downsample with symbol alignment (try offset = 0 to sps-1 if needed)
offset = 0;
rx_I_ds = rx_I(offset+1:sps:end);
rx_Q_ds = rx_Q(offset+1:sps:end);

% Normalize
% rx_I_ds = rx_I_ds / max(abs(rx_I_ds));
% rx_Q_ds = rx_Q_ds / max(abs(rx_Q_ds));

% Ensure vectors
rx_I_ds = rx_I_ds(:);
rx_Q_ds = rx_Q_ds(:);
I = I(:);
Q = Q(:);

% Match length for EVM comparison
numValid = min([length(rx_I_ds), length(I)]);
rx_I_ds = rx_I_ds(1:numValid);
rx_Q_ds = rx_Q_ds(1:numValid);
txSymbols = I(1:numValid) + 1i * Q(1:numValid);
rxSymbols = rx_I_ds + 1i * rx_Q_ds;

%% Plot final constellation
figure;
scatterplot(rxSymbols);
title('Received QPSK Symbols After Matched Filtering');

% Compare TX vs RX
figure;
plot(real(txSymbols), imag(txSymbols), 'bo'); hold on;
plot(real(rxSymbols), imag(rxSymbols), 'rx');
legend('Transmitted', 'Received');
title('Transmitted vs Received QPSK Symbols');
axis equal; grid on;

%% EVM Calculation
evm = sqrt(mean(abs(rxSymbols - txSymbols).^2));
fprintf('EVM = %.4f\n', evm);


