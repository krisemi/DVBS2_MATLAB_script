function compare_hex_files(txt_file, csv_file)
    % Read hex data from both files
    data1 = read_hex_file(txt_file);
    data2 = read_csv_file(csv_file);
    
    % Ensure both files have the same number of lines
    if length(data1) ~= length(data2)
        error('Files have different number of lines.');
    end
    
    % Define the mask (ignoring 3rd, 4th, 7th, 8th hex digits)
    mask = hex2dec('FF00FFFF');
    
    % Process and compare the data
    for i = 1:length(data1)
        hex1 = process_hex(data1{i});
        hex2 = process_hex(data2{i});
        
        % Convert hex to decimal
        num1 = hex2dec(hex1);
        num2 = hex2dec(hex2);
        
        % Apply the mask
        masked_num1 = bitand(num1, mask);
        masked_num2 = bitand(num2, mask);
        
        % Compare the masked values
        if masked_num1 ~= masked_num2
            fprintf('Mismatch at line %d: %s vs %s\n', i, hex1, hex2);
        end
    end
    fprintf('Comparison completed.\n');
end

function data = read_hex_file(filename)
    % Reads hex data from a text file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    data = textscan(fid, '%s');
    fclose(fid);
    data = data{1};
end

function data = read_csv_file(filename)
    % Reads hex data from a CSV file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    data = textscan(fid, '%s', 'Delimiter', ',');
    fclose(fid);
    data = data{1};
end

function hex_str = process_hex(hex_str)
    % If the value is 8000 or 8001, prepend '0000'
    if strcmpi(hex_str, '8000') || strcmpi(hex_str, '8001')
        hex_str = strcat('0000', hex_str);
    end
end
