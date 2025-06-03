% Define file paths for I and Q .txt files containing hexadecimal data
I_file = 'i_filter_output_data.txt'; % Path to the I file (text file with hexadecimal data)
Q_file = 'q_filter_output_data.txt'; % Path to the Q file (text file with hexadecimal data)

% Read the I and Q data from the text files
I_hex_raw = fileread(I_file); % Read the I file (hexadecimal string)
Q_hex_raw = fileread(Q_file); % Read the Q file (hexadecimal string)

% Split the contents into lines
I_lines = strsplit(I_hex_raw, '\n');
Q_lines = strsplit(Q_hex_raw, '\n');

% Initialize variables to store valid hexadecimal lines
valid_I_lines = {};
valid_Q_lines = {};

% Loop through the I lines and check for validity
for i = 1:length(I_lines)

    % Remove spaces and newlines
     I_line = strrep(I_lines{i}, ' ', ''); % Remove spaces
     I_line = strrep(I_line, '\n', ''); % Remove newlines
    % Check if the line contains only valid hexadecimal characters
    if all(isstrprop(I_line, 'xdigit')) && length(I_line) == 64 % 64 hex chars = 256 bits
     valid_I_lines{end+1} = I_line; % Store valid line
    end
end

% Loop through the Q lines and check for validity
for i = 1:length(Q_lines)
    % Remove spaces and newlines
     Q_line = strrep(Q_lines{i}, ' ', ''); % Remove spaces
     Q_line = strrep(Q_line, '\n', ''); % Remove newlines
    % Check if the line contains only valid hexadecimal characters
    if all(isstrprop(Q_line, 'xdigit')) && length(Q_line) == 64 % 64 hex chars = 256 bits
     valid_Q_lines{end+1} = Q_line; % Store valid line
    end
end

% Initialize arrays for the extracted values
I_values_all = [];
Q_values_all = [];
peak_I = zeros(length(valid_I_lines), 1);
peak_Q = zeros(length(valid_Q_lines), 1);  
scale = 32768; %the Q15 format of 16bit integer from +1 to -1
bit_min = 1;
bit_max = 4;
    % process the valid lines for I and Q
    for i = 1:length(valid_I_lines)
        I_hex = valid_I_lines{i};
        %byteArray_I = uint8(sscanf(I_hex, '%2x').');  % Convert hex string to byte array
        %samples_I = typecast(byteArray_I, 'int16');  % Convert byte array to int16 samples
        %I_scaled = double(samples_I) / scale;
        %peak_I(i) = max(abs(I_scaled));  % Store the peak value for I
        
        % truncating the MSB 16 bits
         I_msb_hex = I_hex(bit_min:bit_max);
         I_uint16 = uint16(hex2dec(I_msb_hex)); 
         I_signed = double(typecast(I_uint16, 'int16'));
         I_values = I_signed / scale;
         I_values_all = [I_values_all; I_values]; 
    
        % Process the Q line 
        Q_hex = valid_Q_lines{i}; 
        %byteArray_Q = uint8(sscanf(Q_hex, '%2x').');  
        %samples_Q = typecast(byteArray_Q, 'int16');  % Convert byte array to int16 samples
        % Scale Q samples to floating-point Q15 format (-1 to 1)
        % Q_scaled = double(samples_Q) / scale;
        %peak_Q(i) = max(abs(Q_scaled)); 
    
        Q_msb_hex = Q_hex(bit_min:bit_max); % First 4 hex of Q
        Q_uint16 = uint16(hex2dec(Q_msb_hex)); 
        Q_signed = double(typecast(Q_uint16, 'int16'));
        Q_values = Q_signed / scale;
        Q_values_all = [Q_values_all; Q_values]; 
    
        % checking magnitude of the I and Q for verification
        % mags = sqrt(double(samples_I).^2 + double(samples_Q).^2);
        % [~, idx] = max(mags);     % Find index of max magnitude
        % best_I(i) = samples_I(idx);
        % best_Q(i) = samples_Q(idx);
    end
    
    % Save into .mat files
    save('I_extracted_values.mat', 'I_values_all');
    save('Q_extracted_values.mat', 'Q_values_all');
    
    % Create a complex QPSK
    complex_symbols = I_values_all + 1j * Q_values_all;
    
    %disp(complex_symbols);
    % Plot the constellation diagram
    figure;
    scatter(real(complex_symbols), imag(complex_symbols), 'bo');
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    title('QPSK Constellation Diagram');
    axis([-0.7 0.7 -0.7 0.7]);
    grid on;
    axis equal;

% Scale to Q15
% I_q15 = double(best_I) / 32768;
% Q_q15 = double(best_Q) / 32768;
% signal = I_q15 + 1j * Q_q15;

% Plot constellation
% figure;
% plot(real(signal), imag(signal), 'o');
% title('Constellation (Q15 Scaled)');
% xlabel('In-phase (I)');
% ylabel('Quadrature (Q)');
% axis([-1.5 1.5 -1.5 1.5]);
% grid on;
% axis equal;

% figure;
% % Assume you've also calculated peak_Q
% plot(peak_I, 'b-o');
% hold on;
% plot(peak_Q, 'r-x');
% legend('I Peak', 'Q Peak');
% xlabel('Frame Index');
% ylabel('Peak |Amplitude|');
% title('Peak Amplitude per Frame (I and Q)');
% grid on;