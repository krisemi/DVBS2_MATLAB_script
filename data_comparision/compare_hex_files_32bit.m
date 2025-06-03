function compare_hex_files_32bit(data1, filename2)
    % Reads lines from a text file into a cell array
    fid = fopen(filename2, 'r');
    if fid == -1
        error('Cannot open file: %s', filename2);
    end
    data = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    data2 = data{1};

    % Trim to shortest length to avoid indexing errors
    minLen = min(length(data1), length(data2));
    
    % % Warn if files are different lengths
    % if length(data1) ~= length(data2)
    %     fprintf('⚠️ Warning: data1 (%d) and data2 (%d) have different lengths. Comparing only first %d lines.\n', ...
    %             length(data1), length(data2), minLen);
    % end

    % Initialize mismatch counter
    mismatch_count = 0;

    % Compare values ignoring specific byte positions
    for i = 1:minLen
        val1 = preprocess_value(data1{i});
        val2 = preprocess_value(data2{i});

        % Skip empty lines
        if isempty(val1) || isempty(val2)
            continue;
        end

        % Ensure values are long enough before masking
        if length(val1) < 6 || length(val2) < 6
            fprintf('Warning: Skipping short line %d: %s vs %s\n', i, val1, val2);
            continue;
        end

        % Keep bytes 1-2 and 5-6 (ignore 3-4 and 7-8)
        masked_val1 = [val1(1:2), val1(5:6)];
        masked_val2 = [val2(1:2), val2(5:6)];

        if ~strcmp(masked_val1, masked_val2)
            fprintf('Mismatch at line %d: %s vs %s\n', i, val1, val2);
            mismatch_count = mismatch_count + 1;
        end
    end

    % Display summary
    if mismatch_count == 0
        fprintf('✅ All values matched successfully.\n');
    else
        fprintf('❌ Comparison complete. Total mismatches: %d\n', mismatch_count);
    end
end

function val = preprocess_value(hex_val)
    % Convert to uppercase and trim spaces
    hex_val = upper(strtrim(hex_val));

    % Prepend '0000' if specific short value
    if strcmp(hex_val, '8000') || strcmp(hex_val, '8001')
        val = ['0000', hex_val];
    else
        val = hex_val;
    end
end
