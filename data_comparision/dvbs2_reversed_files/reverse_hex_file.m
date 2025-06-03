function reverse_hex_file(input_filename, output_filename)
    % Open the input file for reading
    fid_in = fopen(input_filename, 'r');
    if fid_in == -1
        error('Error opening input file.');
    end
    
    % Open the output file for writing
    fid_out = fopen(output_filename, 'w');
    if fid_out == -1
        fclose(fid_in);
        error('Error opening output file.');
    end
    
    % Read and process each line
    while ~feof(fid_in)
        hex_line = fgetl(fid_in);
        if ischar(hex_line)
            % Reverse the hex in 4-byte chunks
            reversed_hex = reverse_hex_string(hex_line);
            fprintf(fid_out, '%s\n', reversed_hex);
        end
    end
    
    % Close the files
    fclose(fid_in);
    fclose(fid_out);
end


function reversed_hex = reverse_hex_string(hex_str)
    % Ensure the string length is a multiple of 4
    if mod(length(hex_str), 4) ~= 0
        error('Hex string length must be a multiple of 4');
    end
    
    % Convert hex string into 4-character chunks and reverse the order
    num_chunks = length(hex_str) / 4;
    reversed_hex = '';
    for i = num_chunks:-1:1
        reversed_hex = strcat(reversed_hex, hex_str((i-1)*4+1:i*4));
    end
end