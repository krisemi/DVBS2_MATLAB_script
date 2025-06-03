clc; clear;

%% Load hex values from text files
% File 1: 32-bit hex values (e.g., "7FFFFFFF")
fid1 = fopen('rx_I_32bit_hex_trunc_8x_16.txt', 'r');
hex32 = textscan(fid1, '%s'); fclose(fid1);
hex32 = hex32{1};

% File 2: 16-bit hex values (e.g., "7FFF")
fid2 = fopen('I_filt_Q15_8x_16.txt', 'r');
hex16 = textscan(fid2, '%s'); fclose(fid2);
hex16 = hex16{1};

%% Compare only the first 200 values (or fewer if files are shorter)
numCompare = min([200, length(hex32), length(hex16)]);
hex32 = hex32(1:numCompare);
hex16 = hex16(1:numCompare);

%% Compare the top 16 bits of 32-bit value to the full 16-bit value
matchCount = 0;

for i = 1:numCompare
    top16 = upper(hex32{i}(1:3));   % Take first 4 hex digits
    val16 = upper(hex16{i}(1:3));        % 16-bit value
    if strcmp(top16, val16)
        matchCount = matchCount + 1;
        fprintf('Match   [%3d]: %s == %s\n', i, top16, val16);
    else
        fprintf('Mismatch[%3d]: %s ~= %s\n', i, top16, val16);
    end
end

fprintf('\nTotal matches: %d / %d\n', matchCount, numCompare)
fprintf('\nTotal matches (top 12 bits): %d / %d\n', matchCount, numCompare);
