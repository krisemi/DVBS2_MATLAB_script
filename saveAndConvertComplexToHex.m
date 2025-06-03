function saveAndConvertComplexToHex(data, baseFileName, outputFile)
    % This function saves complex data to a text file and then converts it
    % to hexadecimal format, merging the functionality of saving and conversion.
    
    %% Save complex data to text file
    txtFile = strcat(baseFileName, '_complex.txt');
    fid = fopen(txtFile, 'w');
    if fid == -1
        error('Could not open file %s for writing', txtFile);
    end
    
    for i = 1:numel(data)
        fprintf(fid, '%.6f + %.6fi\n', real(data(i)), imag(data(i)));
    end
    fclose(fid);
    disp(['Complex data saved in ', txtFile]);
    
    %% Convert text file data to hexadecimal format
    % Open the saved text file for reading
    fid_in = fopen(txtFile, 'r');
    if fid_in == -1
        error('Failed to open input file: %s', txtFile);
    end
    
    % Open the output file for writing hexadecimal data
    fid_out = fopen(outputFile, 'w');
    if fid_out == -1
        fclose(fid_in);
        error('Failed to open output file: %s', outputFile);
    end
    
    % Process the file line by line
    while ~feof(fid_in)
        line = fgetl(fid_in);
        if isempty(line)
            continue;
        end
        
        % Convert the line to a complex number
        iq = str2num(line);  %#ok<ST2NM>
        if isempty(iq)
            warning('Skipping invalid line: %s', line);
            continue;
        end
        
        % Skip cases where both I and Q are zero
        if real(iq) == 0 && imag(iq) == 0
            continue;
        end
        
        % Extract real (I) and imaginary (Q) parts
        I = real(iq);
        Q = imag(iq);
        
        % Scale to 16-bit range
        I_scaled = round(I * 32767);
        Q_scaled = round(Q * 32767);
        
        % Convert scaled values to hexadecimal
        hex_I = dec2hex(typecast(int16(I_scaled), 'uint16'), 4);
        hex_Q = dec2hex(typecast(int16(Q_scaled), 'uint16'), 4);
        
        % Concatenate hex values
        hex_symbol = [hex_Q, hex_I];
        
        % Write the hex string to the output file
        fprintf(fid_out, '%s\n', hex_symbol);
    end
    
    fclose(fid_in);
    fclose(fid_out);
    
    fprintf('Hexadecimal conversion complete. Output written to %s\n', outputFile);
end
