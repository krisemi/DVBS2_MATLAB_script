%read the txt files
file1 = 'reversed_normal_QPSK_c1_2_plscrambling_GS.txt';
file2 = '/home/john/Desktop/DVBS2_script/testing_folder/normal_qpsk_c1_2_gs/s2_plframe_hex.txt';

%open files
fid1 = fopen(file1, 'r');
fid2 = fopen(file2, 'r');

%read lines
data1 = textscan(fid1, '%s');
data2 = textscan(fid2, '%s');

%close files
fclose(fid1);
fclose(fid2);

%extract string data
hex1 = data1{1};
hex2 = data2{1};

%Get the number of elements to compare
len = min(length(hex1), length(hex2));

%intialize the differences
difference = {};

%compare hex files
for i = 1:len
    if ~strcmpi(hex1{i}, hex2{i})
        difference{end+1} = sprintf('Line %d: %s != %s', i, hex1{i}, hex2{i});
    end
end

%handle the extra lines if files are different length
if length(hex1) ~= length(hex2)
    difference{end+1} = sprintf('File lengths differ: file has %d lines, file2 has %d lines', length(hex1), length(hex2));
end

if isempty(difference)
    disp('filesmatch exactly');
else
    disp('both are not matching');
    disp(char(difference));
end

