function binaryToHex(inputTxtFile, outputHexFile)
    % Function to convert binary data in a .txt file to a .hex file
    %
    % Parameters:
    %   inputTxtFile  - Path to the input .txt file containing binary data
    %   outputHexFile - Path to the output .hex file

    % Check if the input file exists
    if ~isfile(inputTxtFile)
        error('Input file does not exist.');
    end

    % Read the binary data from the input file
    fid = fopen(inputTxtFile, 'r');
    if fid == -1
        error('Failed to open the input file.');
    end
    binaryData = fscanf(fid, '%s');
    fclose(fid);

    % Validate the binary data
    if ~all(ismember(binaryData, '01'))
        error('The input file contains invalid characters. Only binary data (0 and 1) is allowed.');
    end

    % Ensure the binary data length is a multiple of 4 for hex conversion
    paddingLength = mod(-length(binaryData), 4); % Calculate padding length
    binaryData = [repmat('0', 1, paddingLength), binaryData]; % Add leading zeros if needed

    % Convert binary data to hexadecimal
    hexData = dec2hex(bin2dec(reshape(binaryData, 4, []).')).';

    % Write the hexadecimal data to the output file
    fid = fopen(outputHexFile, 'w');
    if fid == -1
        error('Failed to create the output file.');
    end
    fprintf(fid, '%s\n', hexData);
    fclose(fid);

    fprintf('Hexadecimal data has been written to %s successfully.\n', outputHexFile);
end