clc;
clear;

%% Parameters
Fs = 25e6;             % Sampling frequency
sps = 8;               % Samples per symbol (interpolation factor)
symbolRate = Fs / sps; % Symbol rate

% RRC filter parameters
rolloff = 0.2;         % Roll-off factor
span = 16;             % Filter span in symbols
N = span * sps;        % Filter order
fprintf('Filter order: %d\n', N);

% Ensure span is integer
span = N / sps;
if mod(span, 1) ~= 0
    error('Filter order must be divisible by sps for valid span.');
end

%% Read input I/Q hex data from file
fid = fopen('s2x_qpsk_normal_c13_45plframe_hex.txt', 'r');
hexLines = textscan(fid, '%s');
fclose(fid);
hexLines = hexLines{1};

numSymbols = length(hexLines);
I = zeros(numSymbols, 1);
Q = zeros(numSymbols, 1);

for k = 1:numSymbols
    hexStr = hexLines{k};
    
    % Pad to 8 characters if needed
    if length(hexStr) < 8
        hexStr = [repmat('0', 1, 8 - length(hexStr)), hexStr];
    end
    
    % Extract 16-bit hex for I and Q
    hexI = hexStr(1:4);
    hexQ = hexStr(5:8);

    % Convert to signed 16-bit integers
    intI = typecast(uint16(hex2dec(hexI)), 'int16');
    intQ = typecast(uint16(hex2dec(hexQ)), 'int16');

    % Normalize to [-1, 1]
    I(k) = double(intI) / 32768;
    Q(k) = double(intQ) / 32768;
end

%% Read external filter coefficients from .coe file
fid = fopen('Filter_coefficients_for_ref.coe', 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = lines{1};

startIdx = find(contains(lines, 'coefdata=')) + 1;
rawCoeffs = lines(startIdx:end);

% Clean up .coe format (remove semicolons and commas)
for i = 1:length(rawCoeffs)
    rawCoeffs{i} = strrep(rawCoeffs{i}, ';', '');
    rawCoeffs{i} = strrep(rawCoeffs{i}, ',', '');
end

scale = 32767;
coeffs = str2double(rawCoeffs) / scale;

%% Filter + Upsample using upfirdn (no delay trim)
filteredI = upfirdn(I, coeffs, sps, 1);  % Upsample by sps
filteredQ = upfirdn(Q, coeffs, sps, 1);

% Write filtered values
writematrix(filteredI, 'I_values_Mat_rrc.txt');
writematrix(filteredQ, 'Q_values_Mat_rrc.txt');

%% Combine into complex signal
filteredQPSK = filteredI + 1i * filteredQ;
writematrix(filteredQPSK, 'filtered_qpsk_at_transmitter.txt');


%% Plot original and filtered constellations
figure;
subplot(2,1,1);
plot(I, Q, 'bo');
title('Original QPSK Constellation');
xlabel('In-phase');
ylabel('Quadrature');
axis equal;
grid on;

subplot(2,1,2);
plot(real(filteredQPSK), imag(filteredQPSK), 'ro');
title('Filtered QPSK Constellation (with Upsampling)');
xlabel('In-phase');
ylabel('Quadrature');
axis equal;
grid on;

%% Upsample-only I/Q (for pre-filter waveform)
I_upsampled = upfirdn(I, 1, sps, 1);
Q_upsampled = upfirdn(Q, 1, sps, 1);
t_upsampled = (0:length(I_upsampled)-1) / Fs;

%% Filtered I/Q time vector
t_filtered = (0:length(filteredI)-1) / Fs;

%% Plot I/Q waveforms
figure;

subplot(2,1,1);
plot(t_upsampled*1e6, I_upsampled, 'b');
hold on;
plot(t_upsampled*1e6, Q_upsampled, 'r');
grid on;
title('Upsampled I and Q (before RRC filtering)');
xlabel('Time (µs)');
ylabel('Amplitude');
legend('I channel', 'Q channel');

subplot(2,1,2);
plot(t_filtered*1e6, filteredI, 'b');
hold on;
plot(t_filtered*1e6, filteredQ, 'r');
grid on;
title('Pulse-shaped I and Q (after RRC filtering)');
xlabel('Time (µs)');
ylabel('Amplitude');
legend('I channel', 'Q channel');

%% Downsample for constellation display
offset = 0;  % Try 0 to sps-1 to find best symbol center
sampled_I = filteredI(offset+1:sps:end);
sampled_Q = filteredQ(offset+1:sps:end);

% Normalize
sampled_I = sampled_I / max(abs(sampled_I));
sampled_Q = sampled_Q / max(abs(sampled_Q));

%% Plot downsampled constellation
figure;
plot(sampled_I, sampled_Q, 'o');
title(sprintf('Constellation at offset = %d', offset));
xlabel('In-phase (I)');
ylabel('Quadrature (Q)');
axis([-1 1 -1 1]);
grid on;
axis square;
