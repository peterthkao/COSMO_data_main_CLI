function [varargout] = read_COSMO_science(data,apid)
% By: Tzu-Hsun Kao
% Last updat: Feb. 17, 2026
% -------------------------------------------------------------------------
% Description: To read COSMO science packet and XACT meta packet, fill the 
% data gaps with NaNs, and save them into structs.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% data:             (srtuct) struct output from "cosmo_conversion.m"
% apid:             (double) APID
% -------------------------------------------------------------------------
% OUTPUTS
% -------------------------------------------------------------------------
% For Science Packet (APID = 1625)
% varargout{1}:     (struct) contains all data from scalar
% varargout{2}:     (struct) contains all data from coils
% varargout{3}:     (struct) contains all data from star trackers
%
% For XACT Meta Packet (APID = 520)
% varargout{1}:     (struct) contains position and velocity from XACT
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

if apid == 1625
    % Extract and concatenate all magnetometer samples from all packets
    varargout{1} = struct;
    varargout{2}.beta = struct;
    varargout{2}.dc_offsets = struct;

    % shcoarse is seconds since 2000-01-01; verified against the ground-generated
    % raw CSV filenames across the 2026-06-17 .. 2026-07-27 downlinks.
    % The ST coarsetime fields below share this same epoch: cosmo_conversion.m
    % already subtracts 1577880000000 from the raw timeatcapture to rebase it off
    % the GPS-referenced value. Verified 2026-08-04 on COSMO_20260731T085521 --
    % ST coarsetime trails shcoarse of the same packet by 0..97 s across all 632
    % samples, which is capture-to-packet latency, not an epoch offset.
    varargout{1}.time = datetime(2000,1,1,0,0,0) + seconds(filled.shcoarse)...
        + seconds(filled.shfine*1e-8);
    varargout{1}.pkt_seq = filled.seq_ctr;
    varargout{1}.mag_seq = filled.pld_sci_mag_sequence;
    varargout{1}.scalar = filled.pld_sci_mag_value;

    varargout{2}.beta.x = filled.pld_sci_coil_1_amp;
    varargout{2}.beta.y = filled.pld_sci_coil_2_amp;
    varargout{2}.beta.z = filled.pld_sci_coil_3_amp;
    varargout{2}.dc_offsets.x = filled.pld_sci_coil_1_dc_offset;
    varargout{2}.dc_offsets.y = filled.pld_sci_coil_2_dc_offset;
    varargout{2}.dc_offsets.z = filled.pld_sci_coil_3_dc_offset;

    varargout{1}.flagF = zeros(length(filled.pkt_apid),1);
    ind_lock = find(min(filled.pld_sci_mag_state,[],2) ~= 6);
    ind_read = find(filled.pld_sci_read_error_code ~= 0);
    ind_crc = find(min(filled.pld_sci_mag_crc,[],2) == 0);
    ind_timeout = find(filled.pld_sci_read_timeout == 1);
    ind_underflow = find(filled.pld_sci_read_buffer_underflow == 1);
    ind_overflow = find(filled.pld_sci_read_buffer_overflow == 1);
    varargout{1}.flagF(ind_lock) = 1;
    varargout{1}.flagF(ind_read) = 2;
    varargout{1}.flagF(ind_crc) = 3;
    varargout{1}.flagF(ind_timeout) = 4;
    varargout{1}.flagF(ind_underflow) = 5;
    varargout{1}.flagF(ind_overflow) = 6;
    varargout{1}.flagF(isnan(varargout{1}.pkt_seq)) = 7;
    varargout{1}.flagF = uint8(varargout{1}.flagF);

    % Extract and concatenate all star trackers data from all packets
    varargout{3} = struct;
    varargout{3}.ST1 = struct;
    varargout{3}.ST2 = struct;

    % A raw timeatcapture of 0 means the ST returned no solution; it rebases to
    % coarsetime = -1577880000 (year 1950). NaN entries are the gap-fill above.
    % Both are dropped to NaT rather than written out as real timestamps.
    valid1 = filled.pld_sci_st1_coarsetime > 0;
    varargout{3}.ST1.time = NaT(size(filled.pld_sci_st1_coarsetime));
    varargout{3}.ST1.time(valid1) = datetime(2000,1,1,0,0,0) + seconds(filled.pld_sci_st1_coarsetime(valid1))...
        + seconds(filled.pld_sci_st1_finetime(valid1)*1e-3);
    varargout{3}.ST1.q = filled.pld_sci_st1_q;
    varargout{3}.ST1.rate = filled.pld_sci_st1_rate;
    varargout{3}.ST1.nBlob = filled.pld_sci_st1_blobs;
    varargout{3}.ST1.nCen = filled.pld_sci_st1_centroids;
    varargout{3}.ST1.nMatch = filled.pld_sci_st1_matchedstars;
    varargout{3}.ST1.nRem = filled.pld_sci_st1_removedstars;
    varargout{3}.ST1.confidence = filled.pld_sci_st1_confidence;
    varargout{3}.ST1.LISApercent = filled.pld_sci_st1_lisa_percentage;
    varargout{3}.ST1.LISAclose = filled.pld_sci_st1_lisa_close_stars;
    varargout{3}.ST1.istrust = filled.pld_sci_st1_istrustworthy;
    varargout{3}.ST1.Stab = filled.pld_sci_st1_stablecount;
    varargout{3}.ST1.solstr = filled.pld_sci_st1_solutionstrategy;

    valid2 = filled.pld_sci_st2_coarsetime > 0;
    varargout{3}.ST2.time = NaT(size(filled.pld_sci_st2_coarsetime));
    varargout{3}.ST2.time(valid2) = datetime(2000,1,1,0,0,0) + seconds(filled.pld_sci_st2_coarsetime(valid2))...
        + seconds(filled.pld_sci_st2_finetime(valid2)*1e-3);
    varargout{3}.ST2.q = filled.pld_sci_st2_q;
    varargout{3}.ST2.rate = filled.pld_sci_st2_rate;
    varargout{3}.ST2.nBlob = filled.pld_sci_st2_blobs;
    varargout{3}.ST2.nCen = filled.pld_sci_st2_centroids;
    varargout{3}.ST2.nMatch = filled.pld_sci_st2_matchedstars;
    varargout{3}.ST2.nRem = filled.pld_sci_st2_removedstars;
    varargout{3}.ST2.confidence = filled.pld_sci_st2_confidence;
    varargout{3}.ST2.LISApercent = filled.pld_sci_st2_lisa_percentage;
    varargout{3}.ST2.LISAclose = filled.pld_sci_st2_lisa_close_stars;
    varargout{3}.ST2.istrust = filled.pld_sci_st2_istrustworthy;
    varargout{3}.ST2.Stab = filled.pld_sci_st2_stablecount;
    varargout{3}.ST2.solstr = filled.pld_sci_st2_solutionstrategy;

    varargout{3}.flagq = zeros(length(filled.pkt_apid),1);
    ind_st1 = find(varargout{3}.ST1.istrust ~= 1);
    ind_st2 = find(varargout{3}.ST2.istrust ~= 1);
    ind_st3 = find(varargout{3}.ST1.istrust ~= 1 & varargout{3}.ST2.istrust ~= 1);
    varargout{3}.flagq(ind_st1) = 1;
    varargout{3}.flagq(ind_st2) = 2;
    varargout{3}.flagq(ind_st3) = 3;
    varargout{3}.flagq(isnan(varargout{1}.pkt_seq)) = nan;

elseif apid == 520
    % Extract and concatenate all magnetometer samples from all packets
    varargout{1} = struct;
    % shcoarse epoch is 2000-01-01 (see the APID 1625 branch above)
    varargout{1}.time = datetime(2000,1,1,0,0,0) + seconds(filled.shcoarse)...
        + seconds(filled.shfine*1e-3);
    varargout{1}.pkt_seq = filled.seq_ctr;
    varargout{1}.ECEF_pos = filled.meta_refs_position_wrt_ecef;
    varargout{1}.ECEF_vel = filled.meta_refs_velocity_wrt_ecef;

else
    error('This is not a correct packet!')
end