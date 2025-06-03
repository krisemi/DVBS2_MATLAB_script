function savetofile(data, baseFileName, who)
    % Define filenames to avoid 'Unrecognized function or variable' error
    binFile = ''; hexFile = ''; txtFile = '';
    
    if who == 5 || who == 1
        % Save to binary file
        binFile = strcat(baseFileName, '.bin');
        fid = fopen(binFile, 'w');
        fwrite(fid, data, 'uint8');
        fclose(fid);
        disp(['Data saved in ', binFile]);
    end
    
    if who == 5 || who == 2
        % Save to hex file
        hexFile = strcat(baseFileName, '.hex');
        fid = fopen(hexFile, 'w');
        
        % Ensure data is a row vector
        if iscolumn(data)
            data = data';
        end
        
        n = length(data);
        hexValues = cell(1, ceil(n/8));  % Preallocate cell array for hex values
        
        for i = 1:8:n
            % Take the next 8 binary digits (1 byte)
            binBlock = data(i:min(i+7, n));

            % Pad with zeros if less than 8 bits
            binBlock = [zeros(1, 8 - length(binBlock)), binBlock];

            % Convert binary array to string
            binStr = num2str(binBlock);
            binStr(isspace(binStr)) = [];  % Remove spaces

            % Convert to hexadecimal
            hexChar = dec2hex(bin2dec(binStr), 2);  % Two-character hex representation
            
            % Store the result
            hexValues{ceil(i/8)} = hexChar;
        end
        
        % Write hex values to the file
        fprintf(fid, '%s\n', hexValues{:});
        
        fclose(fid);
        disp(['Data saved in ', hexFile]);
    end

    if who == 5 || who == 3
        % Save to text file (real values)
        txtFile = strcat(baseFileName, '.txt');
        fid = fopen(txtFile, 'w');
        fprintf(fid, '%d\n', data);
        fclose(fid);
        disp(['Data saved in ', txtFile]);
    end

    % Display saved files
    savedFiles = {binFile, hexFile, txtFile};
    savedFiles = savedFiles(~cellfun('isempty', savedFiles));  % Remove empty entries
    disp(['Data saved in: ', strjoin(savedFiles, ', ')]);
end

