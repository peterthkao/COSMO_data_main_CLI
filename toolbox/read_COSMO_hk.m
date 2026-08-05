function [varargout] = read_COSMO_hk(data,apid)
% By: Tzu-Hsun Kao
% Last updat: Mar. 4, 2026
% -------------------------------------------------------------------------
% Description: To read COSMO payload HK packet and XACT meta packet, fill 
% the data gaps with NaNs, and save them into structs.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% data:             (srtuct) struct output from "cosmo_conversion.m"
% apid:             (double) APID
% -------------------------------------------------------------------------
% OUTPUTS
% -------------------------------------------------------------------------
% For Payload HK Packet (APID = 519)
% varargout{1}:     (struct) contains all data from payload HK
%
% For XACT Meta Packet (APID = 520)
% varargout{1}:     (struct) contains XACT HK data
% -------------------------------------------------------------------------

% Fill in NANs for the missing filled
MAX_COUNT = 16383;                                                         % Change if necessary
deltas = diff(data.seq_ctr);
corrected_deltas = mod(deltas,MAX_COUNT);
miss_ind = [1;cumsum(corrected_deltas) + 1];
total_len = miss_ind(end);
vars = fieldnames(data);
filled = struct;
for i = 1:length(vars)
    filled.(vars{i}) = nan(total_len,width(data.(vars{i})));
    filled.(vars{i})(miss_ind,:) = data.(vars{i});
end

if apid == 519
    % Extract and concatenate all magnetometer samples from all packets
    varargout{1} = filled;
    % shcoarse is seconds since 2000-01-01, not the 1980-01-06 GPS epoch
    varargout{1}.time = datetime(2000,1,1,0,0,0) + seconds(filled.shcoarse)...
        + seconds(filled.shfine*1e-8);
    % Drop only the fields actually present: cosmo_conversion already strips
    % every '*reserved*' field, so removing them unconditionally errors out.
    drop = {'shcoarse','shfine','pld_real_time','sh_preamble','sh_padding', ...
        'pld_hk_reserved'};
    varargout{1} = rmfield(varargout{1},drop(isfield(varargout{1},drop)));

elseif apid == 520
    % Extract and concatenate all magnetometer samples from all packets
    varargout{1} = filled;
    % shcoarse epoch is 2000-01-01 (see the APID 519 branch above)
    varargout{1}.time = datetime(2000,1,1,0,0,0) + seconds(filled.shcoarse)...
        + seconds(filled.shfine*1e-3);
    drop = {'shcoarse','shfine'};
    varargout{1} = rmfield(varargout{1},drop(isfield(varargout{1},drop)));

else
    error('This is not a correct packet!')
end