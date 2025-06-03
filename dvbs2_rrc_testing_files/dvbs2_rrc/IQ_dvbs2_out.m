% Read the hex data from the file
filename = 'filter_input_data.txt'; % Change this to your file name
fid = fopen(filename, 'r');
hexData = textscan(fid, '%s');
fclose(fid);
hexData = hexData{1};

% Initialize I/Q arrays
numSamples = length(hexData);
I = zeros(numSamples, 1);
Q = zeros(numSamples, 1);

for k = 1:numSamples
    hexStr = hexData{k};
    
    % Extract 4 hex digits each for I (first 4) and Q (last 4)
    i_hex = hexStr(1:4);
    q_hex = hexStr(5:8);
    
    % Convert to signed 16-bit integers
    i_val = typecast(uint16(hex2dec(i_hex)), 'int16');
    q_val = typecast(uint16(hex2dec(q_hex)), 'int16');
    
    % Scale from Q15 format to float
    I(k) = double(i_val) / 32768;
    Q(k) = double(q_val) / 32768;
end

% Plot the constellation
figure;
plot(I, Q, 'o');
xlabel('In-Phase (I)');
ylabel('Quadrature (Q)');
title('Constellation');
grid on;
axis([-1 1 -1 1]);