% Parameters
Fs = 25e6;             % Sampling frequency
sps = 8;               % Samples per symbol (interpolation factor)
symbolRate = Fs / sps; % Symbol rate
% Design the RRC filter
rolloff = 0.2;          % Roll-off factor
span = 16;              % should never be less than 1
N = span * sps;         % Filter order
fprintf('Filter order: %d\n', N);

% Ensure filter span is integer
span = N / sps;
if mod(span, 1) ~= 0
    error('Filter order must be divisible by sps for valid span.');
end

% Generate random QPSK symbols (I and Q)
numSymbols = 1000;
I = (2 * randi([0, 1], numSymbols, 1) - 1) * 0.707;  % Random bits for I (±1)
Q = (2 * randi([0, 1], numSymbols, 1) - 1) * 0.707;  % Random bits for Q (±1)

% Manual interpolation:
I_upsampled = zeros(numSymbols * sps, 1);
Q_upsampled = zeros(numSymbols * sps, 1);

for k = 1:numSymbols
    I_upsampled((k-1)*sps + 1) = I(k);
    Q_upsampled((k-1)*sps + 1) = Q(k);
end

%disp(I_upsampled);

rrcCoeffs = rcosdesign(rolloff, span, sps, 'sqrt');
filterAnalyzer(rrcCoeffs);

%% Read fixed-point coefficients from .coe file
fid = fopen('Filter_coefficients_for_ref.coe', 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = lines{1};

startIdx = find(contains(lines, 'coefdata=')) + 1;
rawCoeffs = lines(startIdx:end);

% Remove trailing semicolon and commas, convert to numbers
for i = 1:length(rawCoeffs)
    rawCoeffs{i} = strrep(rawCoeffs{i}, ';', '');
    rawCoeffs{i} = strrep(rawCoeffs{i}, ',', '');
end

scale = 32767;
%% if using external coefficients uncomment the below three lines
importedCoeffs = str2double(rawCoeffs) / scale;
filterAnalyzer(str2double(rawCoeffs));
filteredI = conv(I_upsampled, str2double(rawCoeffs), 'same');
filteredQ = conv(Q_upsampled, str2double(rawCoeffs), 'same');
%% else
%if using the coefficients generated from matlab uncomment the below lines
%filteredI = conv(I_upsampled, rrcCoeffs , 'same');
%filteredQ = conv(Q_upsampled, rrcCoeffs , 'same');
%%
% combine filtered I and Q to form the complex QPSK signal
filteredQPSK = filteredI + 1i * filteredQ;
%disp(filteredQPSK);
%disp(length(filteredQPSK));

% Plot the constellation of the original and filtered QPSK signals
figure;
subplot(2,1,1);
plot(real(I + 1i*Q), imag(I + 1i*Q), 'bo');
title('Original QPSK Constellation');
xlabel('In-phase');
ylabel('Quadrature');

subplot(2,1,2);
plot(real(filteredQPSK), imag(filteredQPSK), 'ro');
title('Filtered QPSK Constellation (with Upsampling)');
xlabel('In-phase');
ylabel('Quadrature');

% Plot results
t = (0:length(I_upsampled)-1) / Fs;

figure;

subplot(2,1,1);
plot(t*1e6, I_upsampled, 'b');
hold on;
plot(t*1e6, Q_upsampled, 'r');
grid on;
title('Upsampled I and Q (before RRC filtering)');
xlabel('Time (µs)');
ylabel('Amplitude');
legend('I channel', 'Q channel');

subplot(2,1,2);
plot(t*1e6, filteredI, 'b');
hold on;
plot(t*1e6, filteredQ, 'r');
grid on;
title('Pulse-shaped I and Q (after RRC filtering)');
xlabel('Time (µs)');
ylabel('Amplitude');
legend('I channel', 'Q channel');

offset = 0; %range 1 to sps
sampled_I = I_shaped(offset+1:sps:end);  % Pick every sps-th sample
sampled_Q = Q_shaped(offset+1:sps:end);
% Normalize output for clean constellation
downsampled_I =  sampled_I/ max(abs(I_shaped));

figure;
plot(sampled_I, sampled_Q, 'o');
title(sprintf('Constellation at offset=%d sample',offset));
xlabel('In-phase (I)');
ylabel('Quadrature (Q)');
grid on;
axis([-0.8 0.8 -0.8 0.8]); 