function compare_hex_files_2(data1_filename, filename2)
    % Read the first file (data1)
    fid1 = fopen(data1_filename, 'r');
    if fid1 == -1
        error('Cannot open file: %s', data1_filename);
    end
    data1_cell = textscan(fid1, '%s', 'Delimiter', '\n');
    fclose(fid1);
    data1 = data1_cell{1};

    % Read the second file (data2)
    fid2 = fopen(filename2, 'r');
    if fid2 == -1
        error('Cannot open file: %s', filename2);
    end
    data2_cell = textscan(fid2, '%s', 'Delimiter', '\n');
    fclose(fid2);
    data2 = data2_cell{1};

    % Initialize mismatch counter
    mismatch_count = 0;

    % Determine the minimum length to avoid index overflow
    min_lines = min(length(data1), length(data2));

    % Compare the values ignoring positions 3, 4, 7, and 8
    for i = 1:min_lines
        val1 = preprocess_value(data1{i});
        val2 = preprocess_value(data2{i});

        % Skip empty lines
        if isempty(val1) || isempty(val2)
            continue;
        end

        % Ensure values are long enough before indexing
        if length(val1) < 6 || length(val2) < 6
            fprintf('Warning: Skipping short line %d: %s vs %s\n', i, val1, val2);
            continue;
        end

        % Extract only relevant parts for comparison
        masked_val1 = [val1(1:2), val1(5:6)];
        masked_val2 = [val2(1:2), val2(5:6)];

        if ~strcmp(masked_val1, masked_val2)
            fprintf('Mismatch at line %d: %s vs %s\n', i, val1, val2);
            mismatch_count = mismatch_count + 1;
        end
    end

    % Display results
    if mismatch_count == 0
        fprintf('All values matched successfully.\n');
    else
        fprintf('Comparison complete. Total mismatches: %d\n', mismatch_count);
    end
end

function val = preprocess_value(hex_val)
    % Convert to uppercase and trim spaces
    hex_val = upper(strtrim(hex_val));

    % Check if value is 8000 or 8001 and prepend '0000'
    if strcmp(hex_val, '8000') || strcmp(hex_val, '8001')
        val = ['0000', hex_val];
    else
        val = hex_val;
    end
end
