function write_concatenated_csv(data, file_path)
    % Add header row
    header_row = {'Time', 'FD'}; % Assuming 'Time' is the header for the time points
    
    % Write header and concatenated data to CSV file
    fid = fopen(file_path, 'w');
    fprintf(fid, '%s,%s\n', header_row{:}); % Write header row
    fclose(fid);
    dlmwrite(file_path, data, '-append', 'precision', '%.15f'); % Append data
end