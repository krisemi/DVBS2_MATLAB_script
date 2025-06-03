function compare_hex_files_both_txt(filename1, filename2)
    % Read first file into a cell array
    fid1 = fopen(filename1, 'r');
    if fid1 == -1
        error('Cannot open file: %s', filename1);
    end
    data1 = textscan(fid1, '%s', 'Delimiter', '\n');
    fclose(fid1);
    data1 = data1{1};

    % Read second file into a cell array
    fid2 = fopen(filename2, 'r');
    if fid2 == -1
        error('Cannot open file: %s', filename2);
    end
    data2 = textscan(fid2, '%s', 'Delimiter', '\n');
    fclose(fid2);
    data2 = data2{1};

    % Ensure both files have the same number of lines
    if length(data1) ~= length(data2)
        warning('Files have different numbers of lines (%d vs %d)', length(data1), length(data2));
    end

    % Initialize mismatch counter
    mismatch_count = 0;
    N = min(length(data1), length(data2));  % Compare up to shorter file length

    % Compare values ignoring positions 3, 4, 7, and 8
    for i = 1:N
        val1 = preprocess_value(data1{i});
        val2 = preprocess_value(data2{i});

        if isempty(val1) || isempty(val2)
            continue;
        end

        % Ensure strings are long enough before indexing
        if length(val1) < 6 || length(val2) < 6
            fprintf('Warning: Skipping short line %d: %s vs %s\n', i, val1, val2);
            continue;
        end

        % Keep positions 1–2 and 5–6
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
    % Convert to uppercase and trim whitespace
    hex_val = upper(strtrim(hex_val));

    % Pad with '0000' if value is 8000 or 8001
    if strcmp(hex_val, '8000') || strcmp(hex_val, '8001')
        val = ['0000', hex_val];
    else
        val = hex_val;
    end
end
