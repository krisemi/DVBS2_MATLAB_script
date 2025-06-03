clc; clear;

%% Parameters
Fs = 50e6;             % Sampling frequency
sps = 8;               % Samples per symbol (interpolation factor)
symbolRate = Fs / sps;
rolloff = 0.2;
span = 16;             % Filter span in symbols
N = span * sps;        % Filter order
fprintf('Filter order: %d\n', N);

%% Read input I/Q hex data from file
fid = fopen('filter_input_data_trunc_8x_16.txt', 'r');
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
fid = fopen('rrc_coeff_128_fs50MHz_sps8_span16_rof20.coe', 'r');
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

%% Manual interpolation using conv
I_up = zeros(numSymbols * sps, 1);
Q_up = zeros(numSymbols * sps, 1);
I_up(1:sps:end) = I;
Q_up(1:sps:end) = Q;
I_filt = conv(I_up, rrcFilter, 'full');
Q_filt = conv(Q_up, rrcFilter, 'full');

%% Convert I_filt and Q_filt to Q15 hex format

% Step 1: Scale by 32767 and clip to range [-32768, 32767]
I_fixed = round(I_filt * 32767);
Q_fixed = round(Q_filt * 32767);

I_fixed = max(min(I_fixed, 32767), -32768);
Q_fixed = max(min(Q_fixed, 32767), -32768);

% Step 2: Convert to uint16 using typecast (to get 2's complement hex)
I_hex = dec2hex(typecast(int16(I_fixed), 'uint16'), 4);  % 4 hex digits
Q_hex = dec2hex(typecast(int16(Q_fixed), 'uint16'), 4);

% Step 3: Save to .txt files
% Save I hex values
fidI = fopen('I_filt_Q15_8x_16.txt', 'w');
for k = 1:length(I_hex)
    fprintf(fidI, '%s\n', I_hex(k, :));
end
fclose(fidI);

% Save Q hex values
fidQ = fopen('Q_filt_Q15_8x_16.txt', 'w');
for k = 1:length(Q_hex)
    fprintf(fidQ, '%s\n', Q_hex(k, :));
end
fclose(fidQ);




%% Constellation plots
figure;
subplot(2,1,1);
plot(I, Q, 'bo');
title('Original QPSK Constellation');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;

subplot(2,1,2);
plot(I_filt, Q_filt, 'r.');
title('Filtered QPSK Constellation (Upsampled)');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;

%% Time-domain plots
t_upsampled = (0:length(I_up)-1) / Fs;
t_filtered = (0:length(I_filt)-1) / Fs;

figure;
subplot(2,1,1);
plot(t_upsampled * 1e6, I_up, 'b'); hold on;
plot(t_upsampled * 1e6, Q_up, 'r');
title('Upsampled I/Q (no filtering)'); xlabel('Time [µs]');
legend('I', 'Q'); grid on;

subplot(2,1,2);
plot(t_filtered * 1e6, I_filt, 'b'); hold on;
plot(t_filtered * 1e6, Q_filt, 'r');
title('Pulse-shaped I/Q (RRC filtered)'); xlabel('Time [µs]');
legend('I', 'Q'); grid on;

%% Receiver side: Matched filtering using conv
rx_I = conv(I_filt, rrcFilter, 'full');
rx_Q = conv(Q_filt, rrcFilter, 'full');

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

% % Compare TX vs RX
% figure;
% plot(real(txSymbols), imag(txSymbols), 'bo'); hold on;
% plot(real(rxSymbols), imag(rxSymbols), 'rx');
% legend('Transmitted', 'Received');
% title('Transmitted vs Received QPSK Symbols');
% axis equal; grid on;

%% EVM Calculation
evm = sqrt(mean(abs(rxSymbols - txSymbols).^2));
fprintf('EVM = %.4f\n', evm);


