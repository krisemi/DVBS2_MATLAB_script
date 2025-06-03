% Filename
filename = 'output_q15_format.coe';  % Replace with your actual .coe filename

% Read the entire file as a string
txt = fileread(filename);

% Remove whitespaces and line breaks
txt = regexprep(txt, '\s+', '');

% Find the start of the memory initialization vector
startIdx = strfind(txt, 'MEMORY_INITIALIZATION_VECTOR=') + length('MEMORY_INITIALIZATION_VECTOR=');
dataStr = txt(startIdx:end);

% Remove commas and semicolons
dataStr = regexprep(dataStr, '[,;]', '');

% How many samples to plot (each sample is 32 bits = 8 hex characters)
numSamples = min(200000, floor(length(dataStr) / 8));

% Preallocate arrays
I = zeros(numSamples, 1);
Q = zeros(numSamples, 1);

% Process the first 10,000 samples
for i = 1:numSamples
    hexWord = dataStr((i-1)*8 + 1 : i*8);
    
    I_hex = hexWord(1:4);  % First 16 bits (MSB)
    Q_hex = hexWord(5:8);  % Last 16 bits (LSB)

    % Convert from hex to signed int16
    I(i) = typecast(uint16(hex2dec(I_hex)), 'int16');
    Q(i) = typecast(uint16(hex2dec(Q_hex)), 'int16');
end

% Optional: Normalize if fixed-point (e.g., divide by 32768 if 1.15 format)
% I = double(I) / 32768;
% Q = double(Q) / 32768;

% Plot the constellation
figure;
plot(I, Q, '.');
xlabel('In-Phase (I)');
ylabel('Quadrature (Q)');
title('Constellation Diagram (First 10,000 Samples)');
grid on;
axis equal;
