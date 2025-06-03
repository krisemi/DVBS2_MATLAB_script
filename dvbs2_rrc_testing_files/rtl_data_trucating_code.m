clc; clear;

%% Parameters
Fs = 25e6;             % Sampling frequency
sps = 4;               % Samples per symbol
rolloff = 0.2;
span = 8;              % Filter span in symbols
N = span * sps;        % Filter order
fprintf('Filter order: %d\n', N);

%% === TRUNCATE FILES TO 16000 VALID LINES ===

% --- Truncate TX file ---
fid = fopen('filter_input_data_8x_16.txt', 'r');
txHexLines = textscan(fid, '%s'); fclose(fid);
txHexLines = txHexLines{1};
validTxHex = txHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), txHexLines));
validTxHex = validTxHex(1:min(16000, length(validTxHex)));
fid = fopen('filter_input_data_trunc_8x_16.txt', 'w');
fprintf(fid, '%s\n', validTxHex{:});
fclose(fid);

% --- Truncate RX I file ---
fid = fopen('i_filter_output_data_8x_16.txt', 'r');
rxIHexLines = textscan(fid, '%s'); fclose(fid);
rxIHexLines = rxIHexLines{1};
validRxIHex = rxIHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), rxIHexLines));
validRxIHex = validRxIHex(1:min(16000, length(validRxIHex)));
fid = fopen('rx_I_32bit_hex_trunc_8x_16.txt', 'w');
fprintf(fid, '%s\n', validRxIHex{:});
fclose(fid);

% --- Truncate RX Q file ---
fid = fopen('q_filter_output_data_8x_16.txt', 'r');
rxQHexLines = textscan(fid, '%s'); fclose(fid);
rxQHexLines = rxQHexLines{1};
validRxQHex = rxQHexLines(cellfun(@(x) length(x)==8 && all(ismember(upper(x), '0123456789ABCDEF')), rxQHexLines));
validRxQHex = validRxQHex(1:min(16000, length(validRxQHex)));
fid = fopen('rx_Q_32bit_hex_trunc_8x_16.txt', 'w');
fprintf(fid, '%s\n', validRxQHex{:});
fclose(fid);

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
fid = fopen('rrc_coeff_32_fs25MHz_sps4_rof20.coe', 'r');
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

%% Plot Constellation of TX
figure;
plot(I, Q, 'bo');
title('Original QPSK Constellation');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;

%% === RX Side: Extract Bits [29:14] as Signed 16-bit Values ===
shiftBits = 14;
mask = uint32(2^16 - 1);

decI = int32(cellfun(@(x) typecast(uint32(hex2dec(x)), 'int32'), validRxIHex));
decQ = int32(cellfun(@(x) typecast(uint32(hex2dec(x)), 'int32'), validRxQHex));

i_shifted = bitshift(decI, -shiftBits);
q_shifted = bitshift(decQ, -shiftBits);

i_masked = bitand(uint32(i_shifted), mask);
q_masked = bitand(uint32(q_shifted), mask);

i_scaled = double(typecast(uint16(i_masked), 'int16')) / 32768;
q_scaled = double(typecast(uint16(q_masked), 'int16')) / 32768;

rx_I_input_truncated = i_scaled;
rx_Q_input_truncated = q_scaled;

%% Receiver Matched Filtering
rx_I = conv(rx_I_input_truncated, rrcFilter, 'full');
rx_Q = conv(rx_Q_input_truncated, rrcFilter, 'full');

totalDelay = 2 * (span * sps / 2);
rx_I = rx_I(totalDelay+1:end-totalDelay);
rx_Q = rx_Q(totalDelay+1:end-totalDelay);

offset = 0;
rx_I_ds = rx_I(offset+1:sps:end);
rx_Q_ds = rx_Q(offset+1:sps:end);

numValid = min([length(rx_I_ds), length(I)]);
rx_I_ds = rx_I_ds(1:numValid);
rx_Q_ds = rx_Q_ds(1:numValid);
txSymbols = I(1:numValid) + 1i * Q(1:numValid);
rxSymbols = rx_I_ds + 1i * rx_Q_ds;

%% Plot Final RX Constellation
figure;
plot(real(rxSymbols), imag(rxSymbols), 'rx');
title('Received QPSK Symbols After Matched Filtering');
xlabel('In-phase'); ylabel('Quadrature');
axis equal; grid on;

%% Compare TX vs RX
figure;
plot(real(txSymbols), imag(txSymbols), 'bo'); hold on;
plot(real(rxSymbols), imag(rxSymbols), 'rx');
legend('Transmitted', 'Received');
title('Transmitted vs Received QPSK Symbols');
axis equal; grid on;

%% Spectrum Plot (Filtered I/Q)
Nfft = 2^nextpow2(length(rx_I));
f = linspace(-Fs/2, Fs/2, Nfft);

spectrum_I = fftshift(abs(fft(rx_I, Nfft)));
spectrum_Q = fftshift(abs(fft(rx_Q, Nfft)));

figure;
plot(f/1e6, 20*log10(spectrum_I), 'b', 'DisplayName', 'I'); hold on;
plot(f/1e6, 20*log10(spectrum_Q), 'r', 'DisplayName', 'Q');
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
title('Spectrum of Filtered I and Q Signals');
legend(); grid on; xlim([-Fs/2 Fs/2]/1e6);

%% Spectrum Plot (Truncated Input I/Q)
Nfft = 2^nextpow2(length(rx_I_input_truncated));
f = linspace(-Fs/2, Fs/2, Nfft);

spectrum_I_in = fftshift(abs(fft(rx_I_input_truncated, Nfft)));
spectrum_Q_in = fftshift(abs(fft(rx_Q_input_truncated, Nfft)));

figure;
plot(f/1e6, 20*log10(spectrum_I_in), 'b', 'DisplayName', 'I Input'); hold on;
plot(f/1e6, 20*log10(spectrum_Q_in), 'r', 'DisplayName', 'Q Input');
xlabel('Frequency (MHz)'); ylabel('Magnitude (dB)');
title('Spectrum of Input Truncated I and Q Signals');
legend(); grid on; xlim([-Fs/2 Fs/2]/1e6);

%% EVM Calculation
evm = sqrt(mean(abs(rxSymbols - txSymbols).^2));
fprintf('EVM = %.4f\n', evm);
