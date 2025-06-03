% RRC Filter Parameters
rolloff = 0.2;         % Roll-off factor
span = 8;             % Filter span in symbols
sps = 4;               % Samples per symbol
scale = 32767;         % Q1.15 fixed-point scaling factor
% symbol_rate = 6.25;     %MHZ
% sampling_freq(RRC) = 50; %MHZ

%% Design matlab Root Raised Cosine filter
rrcFilter = rcosdesign(rolloff, span, sps, 'sqrt');
% Optional: Normalize filter
%rrcFilter = rrcFilter / max(abs(rrcFilter));
% Save coefficients to .coe file and .txt file
% scale = 32767;
% rrcFilter = round(rrcFilter * scale);
% rrcFilter = max(min(rrcFilter, 32767), -32768);
% Write to .coe file
fid_coe = fopen('rrc_coeff_32_fs25MHz_sps4_span8_rof20.coe', 'w');
fprintf(fid_coe, 'radix=10;\n');
fprintf(fid_coe, 'coefdata=\n');
for i = 1:length(rrcFilter)
    if i ~= length(rrcFilter)
        fprintf(fid_coe, '%.10f,\n', rrcFilter(i));
    else
        fprintf(fid_coe, '%.10f;\n', rrcFilter(i));
    end
end
fclose(fid_coe);