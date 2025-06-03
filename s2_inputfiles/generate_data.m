% Function to generate data and store in a text file
function generate_data(value, count , filename)
    % Generate the data
    data = repmat(value, count, 1);
    
    % Open the file for writing
    fileID = fopen(filename, 'w');
    
    % Check if file opened successfully
    if fileID == -1
        error('Could not open file for writing.');
    end
    
    % Write data to file
    fprintf(fileID, '%d\n', data);
    
    % Close the file
    fclose(fileID);
    
    fprintf('Data saved successfully to %s\n', filename);
end

% Example usage
