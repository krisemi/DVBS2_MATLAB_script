clc; clear;close all;

%% Parameters
Fs = 50e6;             % Sampling frequency
sps = 8;               % Samples per symbol
rolloff = 0.2;
span = 16;              % Filter span in symbols
N = span * sps; % Filter order
fprintf('Filter order: %d\n', N);

%% === TRUNCATE FILES TO 16000 VALID LINES ===

% --- Truncate TX file ---
fid = fopen('filter_input_data_trunc_8x_16.txt', 'r');
txHexLines = textscan(fid, '%s'); fclose(fid);
txHexLines = txHexLines{1};
validTxHex = txHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), txHexLines));
validTxHex = validTxHex(1:min(16000, length(validTxHex)));

% --- Truncate RX I file ---
fid = fopen('rx_I_32bit_hex_trunc_8x_16.txt', 'r');
rxIHexLines = textscan(fid, '%s'); fclose(fid);
rxIHexLines = rxIHexLines{1};
validRxIHex = rxIHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), rxIHexLines));
validRxIHex = validRxIHex(1:min(16000, length(validRxIHex)));


% --- Truncate RX Q file ---
fid = fopen('rx_Q_32bit_hex_trunc_8x_16.txt', 'r');
rxQHexLines = textscan(fid, '%s'); fclose(fid);
rxQHexLines = rxQHexLines{1};
validRxQHex = rxQHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), rxQHexLines));
validRxQHex = validRxQHex(1:min(16000, length(validRxQHex)));

%% === Read Truncated Transmitted Hex Data ===
numSymbols = length(validTxHex);
I = zeros(numSymbols, 1);
Q = zeros(numSymbols, 1);

for k = 1:numSymbols
    hexStr = validTxHex{k};
    hexI = hexStr(1:4);
    hexQ = hexStr(5:8);
    intI = typecast(uint16(hex2dec(hexI)), 'int16');
    intQ = typecast(uint16(hex2dec(hexQ)), 'int16');
    I(k) = double(intI) / 32768;
    Q(k) = double(intQ) / 32768;
end

qpskSymbols = I + 1i * Q;

%% Read RRC Filter Coefficients
fid = fopen('rrc_coeff_128_fs50MHz_sps8_span16_rof20.coe', 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n'); fclose(fid);
lines = lines{1};
startIdx = find(contains(lines, 'coefdata=')) + 1;
rawCoeffs = lines(startIdx:end);
for i = 1:length(rawCoeffs)
    rawCoeffs{i} = strrep(rawCoeffs{i}, ';', '');
    rawCoeffs{i} = strrep(rawCoeffs{i}, ',', '');
end
rrcFilter = str2double(rawCoeffs);
Lh = length(rrcFilter);
fprintf('Length of RRC filter: %d\n', Lh);

%% Constellation of TX
figure;
plot(I, Q, 'bo');
title('Original QPSK Constellation');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;

%% Read Truncated RX I Data
shiftBits = 15;
rx_I_input = zeros(length(validRxIHex), 1);
for k = 1:length(validRxIHex)
    u32_val = uint32(hex2dec(validRxIHex{k}));           % Convert hex string to uint32
    i_scale1 = bitshift(u32_val, -shiftBits);            % Logical shift
    i_scale2 = bitand(i_scale1,uint32(0xFFFF));
    i16_scaled = typecast(uint16(i_scale2),'int16')'; 
    rx_I_input(k) = double(i16_scaled) / 32768;
end

%% Read Truncated RX Q Data
rx_Q_input = zeros(length(validRxQHex), 1);
for k = 1:length(validRxQHex)
    u32_val = uint32(hex2dec(validRxQHex{k}));           % Convert hex string to uint32
    q_scale1 = bitshift(u32_val, -shiftBits);            % Logical shift
    q_scale2 = bitand(q_scale1,uint32(0xFFFF));
    q16_scaled = typecast(uint16(q_scale2),'int16')';
    rx_Q_input(k) = double(q16_scaled) / 32768;
end

%% Receiver Matched Filtering
rx_I = conv(rx_I_input, rrcFilter, 'full');
rx_Q = conv(rx_Q_input, rrcFilter, 'full');

% Remove total delay
totalDelay = 2 * (span * sps / 2);
rx_I = rx_I(totalDelay+1:end-totalDelay);
rx_Q = rx_Q(totalDelay+1:end-totalDelay);

% Downsample
offset = 0;
rx_I_ds = rx_I(offset+1:sps:end);
rx_Q_ds = rx_Q(offset+1:sps:end);

% Trim to equal lengths
numValid = min([length(rx_I_ds), length(I)]);
rx_I_ds = rx_I_ds(1:numValid);
rx_Q_ds = rx_Q_ds(1:numValid);
txSymbols = I(1:numValid) + 1i * Q(1:numValid);
rxSymbols = rx_I_ds + 1i * rx_Q_ds;

%% Plot Final RX Constellation
figure;
plot(rxSymbols);
title('Received QPSK Symbols After Matched Filtering');

%% Compare TX vs RX
figure;
plot(real(txSymbols), imag(txSymbols), 'bo'); hold on;
plot(real(rxSymbols), imag(rxSymbols), 'rx');
legend('Transmitted', 'Received');
title('Transmitted vs Received QPSK Symbols');
axis equal; grid on;

%% Spectrum Plot of Receiver Input Data After Truncation
Nfft_input = 2^nextpow2(length(rx_I_input));     % FFT size
f_input = linspace(-Fs/2, Fs/2, Nfft_input);     % Frequency vector

% Compute FFT for input signals
spectrum_I_input = fftshift(abs(fft(rx_I_input, Nfft_input)));
spectrum_Q_input = fftshift(abs(fft(rx_Q_input, Nfft_input)));

% Plot the spectrum
figure;
plot(f_input/1e6, 20*log10(spectrum_I_input), 'b', 'DisplayName', 'I (Input)'); hold on;
plot(f_input/1e6, 20*log10(spectrum_Q_input), 'r', 'DisplayName', 'Q (Input)');
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('Spectrum of Input I and Q Signals (Before Filtering)');
legend(); grid on;
xlim([-Fs/2 Fs/2]/1e6);



%% Spectrum Plot of Filtered I/Q Signals (No Normalization)
Nfft = 2^nextpow2(length(rx_I));     % FFT size
f = linspace(-Fs/2, Fs/2, Nfft);     % Frequency vector

% Compute FFT for filtered I and Q signals
spectrum_I = fftshift(abs(fft(rx_I, Nfft)));
spectrum_Q = fftshift(abs(fft(rx_Q, Nfft)));

% Plot the spectrum
figure;
plot(f/1e6, 20*log10(spectrum_I), 'b', 'DisplayName', 'I'); hold on;
plot(f/1e6, 20*log10(spectrum_Q), 'r', 'DisplayName', 'Q');
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('Spectrum of Filtered I and Q Signals (No Normalization)');
legend(); grid on;
xlim([-Fs/2 Fs/2]/1e6);

%% EVM
evm = sqrt(mean(abs(rxSymbols - txSymbols).^2));
fprintf('EVM = %.4f\n', evm);
