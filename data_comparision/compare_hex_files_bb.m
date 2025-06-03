function compare_hex_files_bb(file1, file2)
    % Read HEX data from the text files
    hex1 = read_hex_from_txt(file1);
    hex2 = read_hex_from_txt(file2);

    % Normalize HEX data (convert single chars like '1' to '01')
    hex1 = normalize_hex(hex1);
    hex2 = normalize_hex(hex2);

    % Ensure both files have the same length
    minLen = min(length(hex1), length(hex2));
    
    % Compare HEX data byte by byte
    fprintf('Comparing HEX files...\n');
    differences = 0;
    
    for i = 1:minLen
        % Case-insensitive comparison
        if ~strcmpi(hex1{i}, hex2{i})
            fprintf('Mismatch at line %d: %s ≠ %s\n', i, hex1{i}, hex2{i});
            differences = differences + 1;
        end
    end

    % If one file is longer than the other
    if length(hex1) > minLen
        fprintf('Extra data in %s from line %d onwards.\n', file1, minLen + 1);
        differences = differences + (length(hex1) - minLen);
    elseif length(hex2) > minLen
        fprintf('Extra data in %s from line %d onwards.\n', file2, minLen + 1);
        differences = differences + (length(hex2) - minLen);
    end

    % Summary
    if differences == 0
        fprintf('both files are same.\n');
    else
        fprintf('Total differences found: %d\n', differences);
    end
end

function hexData = read_hex_from_txt(filename)
    % Read hex data from text file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    hexData = textscan(fid, '%s');
    fclose(fid);
    
    % Convert cell array to a proper format
    hexData = hexData{1};
end

function normHex = normalize_hex(hexArray)
    % Normalize hex data:
    % - Ensure single characters ('1', '0', '8', '7') become '01', '00', '08', '07'
    % - Remove unwanted spaces
    normHex = cellfun(@(x) pad_single_hex(x), hexArray, 'UniformOutput', false);
end

function paddedHex = pad_single_hex(hex)
    % If single character and valid hex, pad with '0' in front
    if length(hex) == 1 && ismember(hex, {'0', '1', '2', '3', '4', '5', '6', '8', '7', '9', 'A', 'B', 'C', 'D', 'E', 'F'})
        paddedHex = ['0' hex];
    else
        paddedHex = hex;
    end
end
