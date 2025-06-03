function compare_hex_files_32bit(data1, filename2)
    % Reads lines from a text file into a cell array
    fid = fopen(filename2, 'r');
    if fid == -1
        error('Cannot open file: %s', filename2);
    end
    data = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    data2 = data{1};

    % Ensure both files have the same number of lines
    % if length(data1) ~= length(data2)
    %     error('Files have different numbers of lines');
    % end

    % Initialize mismatch counter
    mismatch_count = 0;

    % Compare the values ignoring positions 3, 4, 7, and 8
    for i = 1:length(data1)
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
        
   
%     Extract only the relevant parts for comparison (ignore 3rd, 4th, 7th, 8th positions)
        masked_val1 = [val1(1:2), val1(5:6)]; % Keeping 1-2 and 5-6
        masked_val2 = [val2(1:2), val2(5:6)];

        if ~strcmp(masked_val1, masked_val2)
                    fprintf('Mismatch at line %d: %s vs %s\n', i, val1, val2);
                    mismatch_count = mismatch_count + 1;
        end
    end
   
       
    %     if ~strcmp(val1, val2)
    %         fprintf('Mismatch at line %d: %s vs %s\n', i, val1, val2);
    %         mismatch_count = mismatch_count + 1;
    %     end
    % end
    
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
