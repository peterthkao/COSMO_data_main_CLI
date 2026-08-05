function [out,apid] = cosmo_conversion(data,apid)
% By: Tzu-Hsun Kao
% Last updat: Feb. 13, 2026
% -------------------------------------------------------------------------
% Description: To read CCSDS files and save into struct.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% data:         (struct) contain data from CCSDS csv files
% apid:         (double) AP ID
% -------------------------------------------------------------------------
% OUTPUTS
% -------------------------------------------------------------------------
% out:          (struct) contains all converted data from CCSDS
% -------------------------------------------------------------------------

vars = fieldnames(data);
out = struct;

% For XACT meta
ind_pos = 1; ind_vel = 1; ind_q = 1; ind_rat = 1; ind_imu = 1; ind_wla = 1;
ind_mag = 1; ind_trd = 1; ind_rod = 1; ind_cyc = 1; ind_tmo = 1;

% For science packet
ind_q1 = 1; ind_q2 = 1; ind_r1 = 1; ind_r2 = 1;
ind_id = 1; ind_val = 1; ind_seq = 1; ind_crc = 1; ind_sta = 1;

switch apid
    case 519
        % Payload HK
        for i = 1:length(vars)
            if sum(strcmp(vars{i},{'pld_5v_i','pld_12v_i','pld_3v3_i',...
                    'pld_5v_st_i','pld_12v_s_i'}))
                % Current
                out.(vars{i}) = round(4 * data.(vars{i}), 3);               % mA
            elseif sum(strcmp(vars{i},{'pld_sc1_sb1_i','pld_sc1_sb2_i','pld_sc1_sb3_i', ...
                    'pld_sc2_sb1_i','pld_sc2_sb2_i','pld_sc2_sb3_i'}))
                % Current
                out.(vars{i}) = round(0.4 * data.(vars{i}), 3);             % mA
            elseif sum(strcmp(vars{i},{'pld_5v_v','pld_12v_v','pld_3v3_v',...
                    'pld_5v_st_v','pld_12_vs_v', ...
                    'pld_sc1_sb1_v','pld_sc1_sb2_v','pld_sc1_sb3_v', ...
                    'pld_sc2_sb1_v','pld_sc2_sb2_v','pld_sc2_sb3_v'}))
                % Voltage
                out.(vars{i}) = round(0.001 * data.(vars{i}), 3);           % V
            elseif sum(strcmp(vars{i},{'pld_5v_reg_t','pld_3v3_reg_t','pld_sc1_t','pld_sc2_t'}))
                % Temperature (TMP100, 12-bit two's complement: raw >= 2048 is negative)
                raw = data.(vars{i});
                raw(raw >= 2^11) = raw(raw >= 2^11) - 2^12;
                out.(vars{i}) = round(0.0625 * raw, 4);                     % C
            elseif contains(vars{i},'_amp_meas')
                % Coil current
                out.(vars{i}) = round((5/16777215)*(data.(vars{i}))/(20*25),9)*1000;        % mA
            elseif contains(vars{i},'_amp_set')
                % Coil current set
                out.(vars{i}) = data.(vars{i})/2^10;                        % Percentage
            elseif contains(vars{i},'dc_offset')
                % Coil DC offset
                out.(vars{i}) = round(((5/16777215)*(data.(vars{i}))-2.643)/(20*25),9)*1000;% mA
            elseif contains(vars{i},'freq_calc')
                % Coil frequency calculated
                out.(vars{i}) = round((16000000/(2^28))*data.(vars{i}),1);  % Hz
            elseif contains(vars{i},'freq_set')
                % Coil frequency set
                out.(vars{i}) = round((16000000/(2^28))*data.(vars{i}),1);  % Hz
            elseif strcmp(vars{i},'pld_vrum_t_1')
                %out.(vars{i}) = 0.2296*data.(vars{i}) - 444.2348;           % C

                % consts
                R25 = 1000;                                                 % Ohm
                v = 3.3;                                                    % V

                % internal calculated values
                VRT = data.(vars{i}).*(v/2^12);
                RT = 1000./((v./VRT)-1);

                % temp conversion
                out.(vars{i}) = 28.54.*(RT./R25).^3-158.5.*(RT./R25).^2+474.8.*(RT./R25)-319.85; % C
            elseif strcmp(vars{i},'pld_vrum_t_2')
                %out.(vars{i}) = -4.0182e-9*(data.(vars{i})).^3 + 2.7239e-5*(data.(vars{i})).^2 - 0.0812*data.(vars{i}) + 111.342; % C

                % consts
                v = 3.3;                                                    % V

                % internal calculated values
                VRT = data.(vars{i}).*(v./2^12);
                RT = 1000./((v./VRT)-1);

                temp_k = 1./((1/298.15)+(1/3930).*log(RT./1000));           % K
                out.(vars{i}) = temp_k - 273.15;                            % C
            elseif contains(vars{i},'reserved')
                continue
            else
                out.(vars{i}) = data.(vars{i});
            end
        end

    case 520
        % XACT Meta
        for i = 1:length(vars)
            if contains(vars{i},'position_wrt_ecef')
                % ECEF Position (m)
                out.meta_refs_position_wrt_ecef(:,ind_pos) = 2e-5*data.(vars{i})*1000;
                % out.meta_refs_position_wrt_ecef(:,ind_pos) = (data.(vars{i}) - (data.(vars{i}) >= 2^31) * 2^32) * 0.00002 * 1000;
                ind_pos = ind_pos + 1;
            elseif contains(vars{i},'velocity_wrt_ecef')
                % ECEF Velocity (m/s)
                out.meta_refs_velocity_wrt_ecef(:,ind_vel) = 5e-9*data.(vars{i})*1000;
                % out.meta_refs_velocity_wrt_ecef(:,ind_vel) = (data.(vars{i}) - (data.(vars{i}) >= 2^31) * 2^32) * 5e-9 * 1000;
                ind_vel = ind_vel + 1;
            elseif contains(vars{i},'q_body_wrt_eci')
                % Bus Quaternion to ECI
                out.meta_att_det_q_body_wrt_eci(:,ind_q) = 5e-10*data.(vars{i});
                ind_q = ind_q + 1;
            elseif contains(vars{i},'body_rate')
                % Bus Body Rate
                out.meta_att_det_body_rate(:,ind_rat) = 5e-9*data.(vars{i});
                ind_rat = ind_rat + 1;
            elseif contains(vars{i},'filtered_speed_rpm')
                % Reaction Wheel Speed
                out.(vars{i}) = 0.4*data.(vars{i});
            elseif contains(vars{i},'imu_avg_vector')
                % IMU Rate
                out.meta_imu_imu_avg_vector(:,ind_imu) = 1e-5*data.(vars{i});
                % out.meta_imu_imu_avg_vector(:,ind_imu) = (data.(vars{i}) - (data.(vars{i}) >= 2^31) * 2^32) * 1e-5;
                ind_imu = ind_imu + 1;
            elseif contains(vars{i},'mag_vector_body')
                % Measured Mag Field Body
                out.meta_mag_mag_vector_body(:,ind_mag) = 5e-9*data.(vars{i});
                ind_mag = ind_mag + 1;
            elseif contains(vars{i},'meas_wheel_current')
                % Coarse Wheel Current
                out.meta_rw_drive_meas_wheel_current(:,ind_wla) = 1e-3*data.(vars{i});
                ind_wla = ind_wla + 1;
            elseif contains(vars{i},'avg_magnet_torque')
                % Torque Rod Torque
                out.meta_momentum_cycle_avg_magnet_torque(:,ind_trd) = 2e-8*data.(vars{i});
                ind_trd = ind_trd + 1;
            elseif contains(vars{i},'torque_rod_enable')
                % Torque Rod Enable
                out.meta_momentum_torque_rod_enable(:,ind_rod) = data.(vars{i});
                ind_rod = ind_rod + 1;
            elseif contains(vars{i},'duty_cycle')
                % Torque Rod Duty Cycle
                out.meta_momentum_duty_cycle(:,ind_cyc) = data.(vars{i});
                ind_cyc = ind_cyc + 1;
            elseif contains(vars{i},'rod_mode')
                % Torque Rod Ctrl Mode
                out.meta_momentum_torque_rod_mode(:,ind_tmo) = data.(vars{i});
                ind_tmo = ind_tmo + 1;
            else
                out.(vars{i}) = data.(vars{i});
            end
        end

    case 1625
        % Payload Science
        for i = 1:length(vars)
            if contains(vars{i},'pld_sci_st1_q')
                out.pld_sci_st1_q(:,ind_q1) = data.(vars{i});
                ind_q1 = ind_q1 + 1;
            elseif contains(vars{i},'pld_sci_st2_q')
                out.pld_sci_st2_q(:,ind_q2) = data.(vars{i});
                ind_q2 = ind_q2 + 1;
            elseif contains(vars{i},'pld_sci_st1_rate')
                out.pld_sci_st1_rate(:,ind_r1) = data.(vars{i});
                ind_r1 = ind_r1 + 1;
            elseif contains(vars{i},'pld_sci_st2_rate')
                out.pld_sci_st2_rate(:,ind_r2) = data.(vars{i});
                ind_r2 = ind_r2 + 1;
            elseif strcmp(vars{i},'pld_sci_st1_timeatcapture')
                out.pld_sci_st1_coarsetime = floor((floor(data.(vars{i})/1000) - 1577880000000)/1000);  % ST1 coarse timestamp in seconds
                out.pld_sci_st1_finetime = mod((floor(data.(vars{i})/1000) - 1577880000000),1000);      % ST1 fine timestamp in milliseconds
            elseif strcmp(vars{i},'pld_sci_st2_timeatcapture')
                out.pld_sci_st2_coarsetime = floor((floor(data.(vars{i})/1000) - 1577880000000)/1000);  % ST2 coarse timestamp in seconds
                out.pld_sci_st2_finetime = mod((floor(data.(vars{i})/1000) - 1577880000000),1000);      % ST2 fine timestamp in milliseconds
            elseif contains(vars{i},'_id') && contains(vars{i},'sample')
                out.pld_sci_mag_id(:,ind_id) = data.(vars{i});
                ind_id = ind_id + 1;
            elseif contains(vars{i},'_value') && contains(vars{i},'sample')
                out.pld_sci_mag_value(:,ind_val) = ((data.(vars{i}) * 4000000.0) / (2^32 - 1)) / 6.99583;% nT             
                ind_val = ind_val + 1;
            elseif contains(vars{i},'_sequence') && contains(vars{i},'sample')
                out.pld_sci_mag_sequence(:,ind_seq) = data.(vars{i});
                ind_seq = ind_seq + 1;
            elseif contains(vars{i},'_crc') && contains(vars{i},'sample')
                out.pld_sci_mag_crc(:,ind_crc) = data.(vars{i});
                ind_crc = ind_crc + 1;
            elseif contains(vars{i},'_state') && contains(vars{i},'sample')
                out.pld_sci_mag_state(:,ind_sta) = data.(vars{i});
                ind_sta = ind_sta + 1;
            elseif contains(vars{i},'_amp') && contains(vars{i},'coil')
                out.(vars{i}) = round((5/16777215)*(data.(vars{i}))/(20*25),9)*1000;          % mA
            elseif contains(vars{i},'dc_offset') && contains(vars{i},'coil')
                out.(vars{i}) = round(((5/16777215)*(data.(vars{i}))-2.643)/(20*25),9)*1000;  % mA
            elseif contains(vars{i},'reserved')
                continue
            else
                out.(vars{i}) = data.(vars{i});
            end
        end
end