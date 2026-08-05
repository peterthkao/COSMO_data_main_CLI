function create_COSMO_hk(path,level,varargin)
% By: Tzu-Hsun Kao
% Last updat: May 15, 2026
% -------------------------------------------------------------------------
% Description: To create COSMO HK data in CDF format.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% path:     (chr) path for saving the HK file
% level:    (1x1) 1 for HK, and 2 for HK daily
%
% For HK (level == 1):
% varargin{1}:  (struct) XACT_HK output from "read_COSMO_hk.m"
% varargin{2}:  (struct) PLD_HK output from "read_COSMO_hk.m"
%
% For HK daily (level == 2):
% varargin{1}:  (struct) T output from "COSMO_data_main.m" (daily synchronized/median HK)
% -------------------------------------------------------------------------

if level == 1
    XACT_HK = varargin{1};
    PLD_HK  = varargin{2};

    % A downlink can carry only one of the two HK APIDs (519 -> PLD,
    % 520 -> XACT). Pass [] for the absent one: it is written as a single
    % placeholder record so the 149-variable layout is identical to a full
    % file, then that record is deleted before the file is closed, leaving
    % the family at zero records. cdflib rejects a record count of 0 on
    % write (BAD_REC_COUNT), so the placeholder-then-delete detour is the
    % only way to get there. Nothing is fabricated: 9 XACT variables are
    % CDF_UINT1 and could not have represented "missing" as NaN.
    drop_xact = isempty(XACT_HK);
    drop_pld  = isempty(PLD_HK);
    if drop_xact && drop_pld
        error('create_COSMO_hk:noData','Both XACT_HK and PLD_HK are empty - nothing to write.')
    end
    if drop_xact, XACT_HK = placeholder_record(xact_fields()); end
    if drop_pld,  PLD_HK  = placeholder_record(pld_fields());  end

    % Name the file from a family that actually has data. XACT stays the
    % preferred source so existing filenames are unchanged.
    if drop_xact
        st = PLD_HK.time(1);
        en = PLD_HK.time(end);
    else
        st = XACT_HK.time(1);
        en = XACT_HK.time(end);
    end
    vvvv = '0001';

    filename = ['HK_',char(st,'yyyyMMdd''T''HHmmss'),...
        '_',char(en,'yyyyMMdd''T''HHmmss'),'_',vvvv,'.cdf'];

    % Check if the file exists, if so, remove it
    fn = dir([path,filename]);
    if ~isempty(fn)
        delete([path,filename])
        warning('One CDF has been removed!')
    end
    cdfid   = cdflib.create([path,filename]);
    cleaner = onCleanup(@() cdflib.close(cdfid));

    %% Global attributes
    titleAttrNum  = cdflib.createAttr(cdfid,'TITLE','global_scope');
    cdflib.putAttrEntry(cdfid,titleAttrNum,0,'CDF_CHAR',filename)
    authorAttrNum = cdflib.createAttr(cdfid,'CREATOR','global_scope');
    cdflib.putAttrEntry(cdfid,authorAttrNum,0,'CDF_CHAR','LAIR at University of Colorado Boulder')

    %% Variable attribute handles
    desAttrNum   = cdflib.createAttr(cdfid,'DESCRIPTION','variable_scope');
    unitsAttrNum = cdflib.createAttr(cdfid,'UNITS','variable_scope');

    % =====================================================================
    %% PLD_HK (APID 519)
    % =====================================================================
    N_pld       = length(PLD_HK.time);
    pldtime_ms  = (datenum(PLD_HK.time) - 1) * 86400000;

    % Time
    pld_time_id = cdflib.createVar(cdfid,'PLD_Time','CDF_EPOCH',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_time_id,[0 N_pld 1],{0 1 1},pldtime_ms)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_time_id,'CDF_CHAR','Time of payload HK packet')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_time_id,'CDF_CHAR','UTC')

    % Sequence counter
    pld_seq_id = cdflib.createVar(cdfid,'PLD_seq_ctr','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_seq_id,[0 N_pld 1],{0 1 1},PLD_HK.seq_ctr)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_seq_id,'CDF_CHAR','Payload HK packet sequence counter')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_seq_id,'CDF_CHAR','-')

    % --- Power rail currents and voltages ---
    pld_5v_i_id = cdflib.createVar(cdfid,'pld_5v_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_5v_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_i_id,'CDF_CHAR','Current at +5V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_i_id,'CDF_CHAR','mA')

    pld_5v_v_id = cdflib.createVar(cdfid,'pld_5v_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_5v_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_v_id,'CDF_CHAR','Voltage at +5V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_v_id,'CDF_CHAR','V')

    pld_12v_i_id = cdflib.createVar(cdfid,'pld_12v_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_12v_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_i_id,'CDF_CHAR','Current at 12V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_i_id,'CDF_CHAR','mA')

    pld_12v_v_id = cdflib.createVar(cdfid,'pld_12v_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_12v_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_v_id,'CDF_CHAR','Voltage at 12V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_v_id,'CDF_CHAR','V')

    pld_3v3_i_id = cdflib.createVar(cdfid,'pld_3v3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_3v3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_i_id,'CDF_CHAR','Current at 3V3 rail (for HK Sensors)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_i_id,'CDF_CHAR','mA')

    pld_3v3_v_id = cdflib.createVar(cdfid,'pld_3v3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_3v3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_v_id,'CDF_CHAR','Voltage at 3V3 rail (for HK Sensors)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_v_id,'CDF_CHAR','V')

    pld_5v_st_i_id = cdflib.createVar(cdfid,'pld_5v_st_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_st_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_5v_st_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_st_i_id,'CDF_CHAR','Current at 5V5T rail (for Star Trackers)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_st_i_id,'CDF_CHAR','mA')

    pld_5v_st_v_id = cdflib.createVar(cdfid,'pld_5v_st_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_st_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_5v_st_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_st_v_id,'CDF_CHAR','Voltage at 5V5T rail (for Star Trackers)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_st_v_id,'CDF_CHAR','V')

    pld_12v_s_i_id = cdflib.createVar(cdfid,'pld_12v_s_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_s_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_12v_s_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_s_i_id,'CDF_CHAR','Current at 12VS rail (for Scalar Boards)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_s_i_id,'CDF_CHAR','mA')

    pld_12_vs_v_id = cdflib.createVar(cdfid,'pld_12_vs_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12_vs_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_12_vs_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12_vs_v_id,'CDF_CHAR','Voltage at 12VS rail (for Scalar Boards)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12_vs_v_id,'CDF_CHAR','V')

    % --- Scalar Board 1 ---
    pld_sc1_sb1_i_id = cdflib.createVar(cdfid,'pld_sc1_sb1_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb1_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb1_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb1_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb1_i_id,'CDF_CHAR','mA')

    pld_sc1_sb1_v_id = cdflib.createVar(cdfid,'pld_sc1_sb1_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb1_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb1_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb1_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb1_v_id,'CDF_CHAR','V')

    pld_sc1_sb2_i_id = cdflib.createVar(cdfid,'pld_sc1_sb2_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb2_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb2_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb2_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb2_i_id,'CDF_CHAR','mA')

    pld_sc1_sb2_v_id = cdflib.createVar(cdfid,'pld_sc1_sb2_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb2_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb2_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb2_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb2_v_id,'CDF_CHAR','V')

    pld_sc1_sb3_i_id = cdflib.createVar(cdfid,'pld_sc1_sb3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb3_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb3_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb3_i_id,'CDF_CHAR','mA')

    pld_sc1_sb3_v_id = cdflib.createVar(cdfid,'pld_sc1_sb3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb3_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_sb3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb3_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb3_v_id,'CDF_CHAR','V')

    % --- Scalar Board 2 ---
    pld_sc2_sb1_i_id = cdflib.createVar(cdfid,'pld_sc2_sb1_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb1_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb1_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb1_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb1_i_id,'CDF_CHAR','mA')

    pld_sc2_sb1_v_id = cdflib.createVar(cdfid,'pld_sc2_sb1_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb1_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb1_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb1_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb1_v_id,'CDF_CHAR','V')

    pld_sc2_sb2_i_id = cdflib.createVar(cdfid,'pld_sc2_sb2_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb2_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb2_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb2_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb2_i_id,'CDF_CHAR','mA')

    pld_sc2_sb2_v_id = cdflib.createVar(cdfid,'pld_sc2_sb2_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb2_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb2_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb2_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb2_v_id,'CDF_CHAR','V')

    pld_sc2_sb3_i_id = cdflib.createVar(cdfid,'pld_sc2_sb3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb3_i_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb3_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb3_i_id,'CDF_CHAR','mA')

    pld_sc2_sb3_v_id = cdflib.createVar(cdfid,'pld_sc2_sb3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb3_v_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_sb3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb3_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb3_v_id,'CDF_CHAR','V')

    % --- Temperatures ---
    pld_5v_reg_t_id = cdflib.createVar(cdfid,'pld_5v_reg_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_reg_t_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_5v_reg_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_reg_t_id,'CDF_CHAR','Temperature at 5V Regulator')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_reg_t_id,'CDF_CHAR','-')

    pld_3v3_reg_t_id = cdflib.createVar(cdfid,'pld_3v3_reg_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_reg_t_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_3v3_reg_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_reg_t_id,'CDF_CHAR','Temperature at 3V3 Regulator')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_reg_t_id,'CDF_CHAR','-')

    pld_sc1_t_id = cdflib.createVar(cdfid,'pld_sc1_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_t_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc1_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_t_id,'CDF_CHAR','Temperature at Scalar Board No.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_t_id,'CDF_CHAR','-')

    pld_sc2_t_id = cdflib.createVar(cdfid,'pld_sc2_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_t_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc2_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_t_id,'CDF_CHAR','Temperature at Scalar Board No.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_t_id,'CDF_CHAR','-')

    pld_vrum_t_1_id = cdflib.createVar(cdfid,'pld_vrum_t_1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_vrum_t_1_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_vrum_t_1)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_vrum_t_1_id,'CDF_CHAR','VRuM Temperature 1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_vrum_t_1_id,'CDF_CHAR','-')

    pld_vrum_t_2_id = cdflib.createVar(cdfid,'pld_vrum_t_2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_vrum_t_2_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_vrum_t_2)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_vrum_t_2_id,'CDF_CHAR','VRuM Temperature 2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_vrum_t_2_id,'CDF_CHAR','-')

    % --- Coil 0 ---
    pld_coil_0_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_0_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_meas_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_meas_id,'CDF_CHAR','Coil 0 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_meas_id,'CDF_CHAR','-')

    pld_coil_0_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_0_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_adj_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_adj_id,'CDF_CHAR','Coil 0 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_adj_id,'CDF_CHAR','-')

    pld_coil_0_amp_set_id = cdflib.createVar(cdfid,'pld_coil_0_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_set_id,'CDF_CHAR','Coil 0 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_set_id,'CDF_CHAR','-')

    pld_coil_0_freq_set_id = cdflib.createVar(cdfid,'pld_coil_0_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_freq_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_freq_set_id,'CDF_CHAR','Coil 0 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_freq_set_id,'CDF_CHAR','-')

    pld_coil_0_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_0_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_freq_calc_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_freq_calc_id,'CDF_CHAR','Coil 0 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_freq_calc_id,'CDF_CHAR','-')

    pld_coil_0_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_0_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_dc_offset_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_0_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_dc_offset_id,'CDF_CHAR','Coil 0 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_dc_offset_id,'CDF_CHAR','-')

    % --- Coil 1 ---
    pld_coil_1_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_1_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_meas_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_meas_id,'CDF_CHAR','Coil 1 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_meas_id,'CDF_CHAR','-')

    pld_coil_1_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_1_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_adj_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_adj_id,'CDF_CHAR','Coil 1 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_adj_id,'CDF_CHAR','-')

    pld_coil_1_amp_set_id = cdflib.createVar(cdfid,'pld_coil_1_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_set_id,'CDF_CHAR','Coil 1 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_set_id,'CDF_CHAR','-')

    pld_coil_1_freq_set_id = cdflib.createVar(cdfid,'pld_coil_1_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_freq_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_freq_set_id,'CDF_CHAR','Coil 1 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_freq_set_id,'CDF_CHAR','-')

    pld_coil_1_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_1_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_freq_calc_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_freq_calc_id,'CDF_CHAR','Coil 1 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_freq_calc_id,'CDF_CHAR','-')

    pld_coil_1_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_1_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_dc_offset_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_1_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_dc_offset_id,'CDF_CHAR','Coil 1 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_dc_offset_id,'CDF_CHAR','-')

    % --- Coil 2 ---
    pld_coil_2_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_2_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_meas_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_meas_id,'CDF_CHAR','Coil 2 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_meas_id,'CDF_CHAR','-')

    pld_coil_2_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_2_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_adj_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_adj_id,'CDF_CHAR','Coil 2 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_adj_id,'CDF_CHAR','-')

    pld_coil_2_amp_set_id = cdflib.createVar(cdfid,'pld_coil_2_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_set_id,'CDF_CHAR','Coil 2 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_set_id,'CDF_CHAR','-')

    pld_coil_2_freq_set_id = cdflib.createVar(cdfid,'pld_coil_2_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_freq_set_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_freq_set_id,'CDF_CHAR','Coil 2 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_freq_set_id,'CDF_CHAR','-')

    pld_coil_2_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_2_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_freq_calc_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_freq_calc_id,'CDF_CHAR','Coil 2 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_freq_calc_id,'CDF_CHAR','-')

    pld_coil_2_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_2_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_dc_offset_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_coil_2_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_dc_offset_id,'CDF_CHAR','Coil 2 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_dc_offset_id,'CDF_CHAR','-')

    % --- Packet counters ---
    pld_pkt_recv_ct_id = cdflib.createVar(cdfid,'pld_pkt_recv_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_recv_ct_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_pkt_recv_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_recv_ct_id,'CDF_CHAR','Packet counter value for received packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_recv_ct_id,'CDF_CHAR','-')

    pld_pkt_ack_ct_id = cdflib.createVar(cdfid,'pld_pkt_ack_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_ack_ct_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_pkt_ack_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_ack_ct_id,'CDF_CHAR','Packet counter value for acknowledged packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_ack_ct_id,'CDF_CHAR','-')

    pld_pkt_nack_ct_id = cdflib.createVar(cdfid,'pld_pkt_nack_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_nack_ct_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_pkt_nack_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_nack_ct_id,'CDF_CHAR','Packet counter value for not acknowledged packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_nack_ct_id,'CDF_CHAR','-')

    % --- MCP4131 Digital Potentiometer states ---
    pld_mcp4131_1_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_1_cfg_id,'CDF_CHAR','1 - DigPot No.1 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_1_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_2_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_2_cfg_id,'CDF_CHAR','1 - DigPot No.2 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_2_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_3_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_3_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_3_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_3_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_3_cfg_id,'CDF_CHAR','1 - DigPot No.3 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_3_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_1_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_1_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_1_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_1_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_1_ctrl_id,'CDF_CHAR','1 - DigPot No.1 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_1_ctrl_id,'CDF_CHAR','-')

    pld_mcp4131_2_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_2_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_2_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_2_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_2_ctrl_id,'CDF_CHAR','1 - DigPot No.2 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_2_ctrl_id,'CDF_CHAR','-')

    pld_mcp4131_3_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_3_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_3_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_mcp4131_3_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_3_ctrl_id,'CDF_CHAR','1 - DigPot No.3 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_3_ctrl_id,'CDF_CHAR','-')

    % --- AD9837 Waveform Generator states ---
    pld_ad9837_1_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_1_cfg_id,'CDF_CHAR','1 - WaveGen No.1 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_1_cfg_id,'CDF_CHAR','-')

    pld_ad9837_2_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_2_cfg_id,'CDF_CHAR','1 - WaveGen No.2 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_2_cfg_id,'CDF_CHAR','-')

    pld_ad9837_3_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_3_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_3_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_3_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_3_cfg_id,'CDF_CHAR','1 - WaveGen No.3 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_3_cfg_id,'CDF_CHAR','-')

    pld_ad9837_1_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_1_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_1_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_1_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_1_ctrl_id,'CDF_CHAR','1 - WaveGen No.1 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_1_ctrl_id,'CDF_CHAR','-')

    pld_ad9837_2_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_2_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_2_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_2_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_2_ctrl_id,'CDF_CHAR','1 - WaveGen No.2 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_2_ctrl_id,'CDF_CHAR','-')

    pld_ad9837_3_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_3_ctrl_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_3_ctrl_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ad9837_3_ctrl_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_3_ctrl_id,'CDF_CHAR','1 - WaveGen No.3 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_3_ctrl_id,'CDF_CHAR','-')

    % --- TMP100 Temperature Sensor states ---
    pld_tmp100_1_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_1_cfg_id,'CDF_CHAR','1 - TMP No.1 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_1_cfg_id,'CDF_CHAR','-')

    pld_tmp100_2_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_2_cfg_id,'CDF_CHAR','1 - TMP No.2 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_2_cfg_id,'CDF_CHAR','-')

    pld_tmp100_sc1_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_sc1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_sc1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc1_cfg_id,'CDF_CHAR','1 - TMP (Scalar Board No.1) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc1_cfg_id,'CDF_CHAR','-')

    pld_tmp100_sc2_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_sc2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_sc2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc2_cfg_id,'CDF_CHAR','1 - TMP (Scalar Board No.2) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc2_cfg_id,'CDF_CHAR','-')

    pld_tmp100_1_read_id = cdflib.createVar(cdfid,'pld_tmp100_1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_1_read_id,'CDF_CHAR','1 - TMP No.1 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_1_read_id,'CDF_CHAR','-')

    pld_tmp100_2_read_id = cdflib.createVar(cdfid,'pld_tmp100_2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_2_read_id,'CDF_CHAR','1 - TMP No.2 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_2_read_id,'CDF_CHAR','-')

    pld_tmp100_sc1_read_id = cdflib.createVar(cdfid,'pld_tmp100_sc1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_sc1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc1_read_id,'CDF_CHAR','1 - TMP (Scalar Board No.1) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc1_read_id,'CDF_CHAR','-')

    pld_tmp100_sc2_read_id = cdflib.createVar(cdfid,'pld_tmp100_sc2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_tmp100_sc2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc2_read_id,'CDF_CHAR','1 - TMP (Scalar Board No.2) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc2_read_id,'CDF_CHAR','-')

    % --- INA3221 Power Sensor states ---
    pld_ina3221_1_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_1_cfg_id,'CDF_CHAR','1 - INA No.1 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_1_cfg_id,'CDF_CHAR','-')

    pld_ina3221_2_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_2_cfg_id,'CDF_CHAR','1 - INA No.2 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_2_cfg_id,'CDF_CHAR','-')

    pld_ina3221_sc1_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_sc1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_sc1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc1_cfg_id,'CDF_CHAR','1 - INA (Scalar Board No.1) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc1_cfg_id,'CDF_CHAR','-')

    pld_ina3221_sc2_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_sc2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_sc2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc2_cfg_id,'CDF_CHAR','1 - INA (Scalar Board No.2) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc2_cfg_id,'CDF_CHAR','-')

    pld_ina3221_1_read_id = cdflib.createVar(cdfid,'pld_ina3221_1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_1_read_id,'CDF_CHAR','1 - INA No.1 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_1_read_id,'CDF_CHAR','-')

    pld_ina3221_2_read_id = cdflib.createVar(cdfid,'pld_ina3221_2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_2_read_id,'CDF_CHAR','1 - INA No.2 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_2_read_id,'CDF_CHAR','-')

    pld_ina3221_sc1_read_id = cdflib.createVar(cdfid,'pld_ina3221_sc1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_sc1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc1_read_id,'CDF_CHAR','1 - INA (Scalar Board No.1) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc1_read_id,'CDF_CHAR','-')

    pld_ina3221_sc2_read_id = cdflib.createVar(cdfid,'pld_ina3221_sc2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_ina3221_sc2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc2_read_id,'CDF_CHAR','1 - INA (Scalar Board No.2) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc2_read_id,'CDF_CHAR','-')

    % --- Star Tracker states ---
    pld_st_1_cfg_id = cdflib.createVar(cdfid,'pld_st_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_1_cfg_id,'CDF_CHAR','1 - Star Tracker No.1 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_1_cfg_id,'CDF_CHAR','-')

    pld_st_2_cfg_id = cdflib.createVar(cdfid,'pld_st_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_2_cfg_id,'CDF_CHAR','1 - Star Tracker No.2 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_2_cfg_id,'CDF_CHAR','-')

    pld_st_1_read_id = cdflib.createVar(cdfid,'pld_st_1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st_1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_1_read_id,'CDF_CHAR','1 - Star Tracker No.1 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_1_read_id,'CDF_CHAR','-')

    pld_st_2_read_id = cdflib.createVar(cdfid,'pld_st_2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st_2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_2_read_id,'CDF_CHAR','1 - Star Tracker No.2 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_2_read_id,'CDF_CHAR','-')

    % --- Scalar Board states ---
    pld_scalar_1_cfg_id = cdflib.createVar(cdfid,'pld_scalar_1_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_1_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_scalar_1_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_1_cfg_id,'CDF_CHAR','1 - Scalar Board No.1 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_1_cfg_id,'CDF_CHAR','-')

    pld_scalar_2_cfg_id = cdflib.createVar(cdfid,'pld_scalar_2_cfg_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_2_cfg_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_scalar_2_cfg_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_2_cfg_id,'CDF_CHAR','1 - Scalar Board No.2 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_2_cfg_id,'CDF_CHAR','-')

    pld_scalar_1_read_id = cdflib.createVar(cdfid,'pld_scalar_1_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_1_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_scalar_1_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_1_read_id,'CDF_CHAR','1 - Scalar Board No.1 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_1_read_id,'CDF_CHAR','-')

    pld_scalar_2_read_id = cdflib.createVar(cdfid,'pld_scalar_2_read_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_2_read_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_scalar_2_read_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_2_read_id,'CDF_CHAR','1 - Scalar Board No.2 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_2_read_id,'CDF_CHAR','-')

    % --- Scalar read health ---
    pld_cdh_comm_state_id = cdflib.createVar(cdfid,'pld_cdh_comm_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_cdh_comm_state_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_cdh_comm_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_cdh_comm_state_id,'CDF_CHAR','CDH Comm State Machine')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_cdh_comm_state_id,'CDF_CHAR','-')

    pld_active_coil_id = cdflib.createVar(cdfid,'pld_active_coil_control','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_active_coil_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_active_coil_control))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_active_coil_id,'CDF_CHAR','Active coil control flag; 0 - OFF, 1 - ON')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_active_coil_id,'CDF_CHAR','-')

    pld_sc_warmup_id = cdflib.createVar(cdfid,'pld_sc_warmup_timeout','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_warmup_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc_warmup_timeout)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_warmup_id,'CDF_CHAR','Scalar warmup timeout set')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_warmup_id,'CDF_CHAR','s')

    pld_sc_cooldown_id = cdflib.createVar(cdfid,'pld_sc_cooldown_timeout','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_cooldown_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc_cooldown_timeout)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_cooldown_id,'CDF_CHAR','Scalar cooldown timeout set')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_cooldown_id,'CDF_CHAR','s')

    pld_sc_reinit_id = cdflib.createVar(cdfid,'pld_sc_reinit_counts','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_reinit_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_sc_reinit_counts)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_reinit_id,'CDF_CHAR','Counter for scalar reinits due to timeout')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_reinit_id,'CDF_CHAR','-')

    pld_sc_read_timeout_id = cdflib.createVar(cdfid,'pld_sc_read_timeout','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_read_timeout_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_read_timeout))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_read_timeout_id,'CDF_CHAR','Timeout waiting for scalar packet; 0 - NO, 1 - TIMEOUT')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_read_timeout_id,'CDF_CHAR','-')

    pld_sc_uflow_id = cdflib.createVar(cdfid,'pld_sc_read_buffer_underflow','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_uflow_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_read_buffer_underflow))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_uflow_id,'CDF_CHAR','Transmitted scalar buffer is empty (missing samples); 0 - NO, 1 - UNDERFLOW')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_uflow_id,'CDF_CHAR','-')

    pld_sc_oflow_id = cdflib.createVar(cdfid,'pld_sc_read_buffer_overflow','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_oflow_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_read_buffer_overflow))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_oflow_id,'CDF_CHAR','Scalar ringbuffer not emptied fast enough; 0 - NO, 1 - OVERFLOW')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_oflow_id,'CDF_CHAR','-')

    pld_sc_mag_crc_id = cdflib.createVar(cdfid,'pld_sc_mag_crc_flag','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_crc_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_mag_crc_flag))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_crc_id,'CDF_CHAR','Payload science scalar CRC flag; 0 - FAIL, 1 - PASS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_crc_id,'CDF_CHAR','-')

    pld_sc_mag_state_id = cdflib.createVar(cdfid,'pld_sc_mag_state','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_state_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_mag_state))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_state_id,'CDF_CHAR','Scalar magnetometer state; 2-STARTUP 3-WARMUP 4-LASERLOCKSCAN 5-RESONANCESCAN 6-LOCK')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_state_id,'CDF_CHAR','-')

    pld_st1_trust_id = cdflib.createVar(cdfid,'pld_st1_is_trustworthy','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st1_trust_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st1_is_trustworthy))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st1_trust_id,'CDF_CHAR','Star tracker 1 solution is trustworthy; 0 - NO, 1 - YES')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st1_trust_id,'CDF_CHAR','-')

    pld_st2_trust_id = cdflib.createVar(cdfid,'pld_st2_is_trustworthy','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st2_trust_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_st2_is_trustworthy))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st2_trust_id,'CDF_CHAR','Star tracker 2 solution is trustworthy; 0 - NO, 1 - YES')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st2_trust_id,'CDF_CHAR','-')

    pld_fw_major_id = cdflib.createVar(cdfid,'pld_firmware_major_rev','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_major_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_firmware_major_rev)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_major_id,'CDF_CHAR','Firmware revision major version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_major_id,'CDF_CHAR','-')

    pld_fw_minor_id = cdflib.createVar(cdfid,'pld_firmware_minor_rev','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_minor_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_firmware_minor_rev)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_minor_id,'CDF_CHAR','Firmware revision minor version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_minor_id,'CDF_CHAR','-')

    pld_sc_mag_mod16_id = cdflib.createVar(cdfid,'pld_sc_mag_mod_16_sequence','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_mod16_id,[0 N_pld 1],{0 1 1},uint8(PLD_HK.pld_sc_mag_mod16Sequence))
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_mod16_id,'CDF_CHAR','Payload Science Scalar Mod 16 Sequence Counter')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_mod16_id,'CDF_CHAR','-')

    pld_fw_patch_id = cdflib.createVar(cdfid,'pld_firmware_patch_no','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_patch_id,[0 N_pld 1],{0 1 1},PLD_HK.pld_firmware_patch__)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_patch_id,'CDF_CHAR','Firmware Revision Patch Version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_patch_id,'CDF_CHAR','-')

    % =====================================================================
    %% XACT_HK (APID 520)
    % =====================================================================
    N_xact      = length(XACT_HK.time);
    xacttime_ms = (datenum(XACT_HK.time) - 1) * 86400000;

    xact_time_id = cdflib.createVar(cdfid,'XACT_Time','CDF_EPOCH',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_time_id,[0 N_xact 1],{0 1 1},xacttime_ms)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_time_id,'CDF_CHAR','Time of XACT HK packet')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_time_id,'CDF_CHAR','UTC')

    xact_seq_id = cdflib.createVar(cdfid,'XACT_seq_ctr','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_seq_id,[0 N_xact 1],{0 1 1},XACT_HK.seq_ctr)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_seq_id,'CDF_CHAR','XACT HK packet sequence counter')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_seq_id,'CDF_CHAR','-')

    xact_tai_id = cdflib.createVar(cdfid,'XACT_meta_time_tai_seconds','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tai_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_time_tai_seconds)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tai_id,'CDF_CHAR','TAI Seconds')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tai_id,'CDF_CHAR','s')

    % --- Orbit position ECEF ---
    xact_pos1_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_position_wrt_ecef1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos1_id,'CDF_CHAR','Orbit Position ECEF (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos1_id,'CDF_CHAR','m')

    xact_pos2_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_position_wrt_ecef2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos2_id,'CDF_CHAR','Orbit Position ECEF (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos2_id,'CDF_CHAR','m')

    xact_pos3_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_position_wrt_ecef3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos3_id,'CDF_CHAR','Orbit Position ECEF (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos3_id,'CDF_CHAR','m')

    % --- Orbit velocity ECEF ---
    xact_vel1_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_velocity_wrt_ecef1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel1_id,'CDF_CHAR','Orbit Velocity ECEF (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel1_id,'CDF_CHAR','m/s')

    xact_vel2_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_velocity_wrt_ecef2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel2_id,'CDF_CHAR','Orbit Velocity ECEF (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel2_id,'CDF_CHAR','m/s')

    xact_vel3_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_refs_velocity_wrt_ecef3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel3_id,'CDF_CHAR','Orbit Velocity ECEF (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel3_id,'CDF_CHAR','m/s')

    xact_pulse_id = cdflib.createVar(cdfid,'XACT_meta_pulse_recv_ms','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pulse_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_pulse_recv_ms)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pulse_id,'CDF_CHAR','Local time in ms when last time pulse was received')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pulse_id,'CDF_CHAR','ms')

    % --- Attitude quaternion ---
    xact_q1_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_q_body_wrt_eci1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q1_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q1_id,'CDF_CHAR','-')

    xact_q2_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_q_body_wrt_eci2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q2_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q2_id,'CDF_CHAR','-')

    xact_q3_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_q_body_wrt_eci3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q3_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q3_id,'CDF_CHAR','-')

    xact_q4_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci4','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q4_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_q_body_wrt_eci4)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q4_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 4)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q4_id,'CDF_CHAR','-')

    % --- Body frame rates ---
    xact_rate1_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_body_rate1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate1_id,'CDF_CHAR','Body Frame Rate (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate1_id,'CDF_CHAR','rad/s')

    xact_rate2_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_body_rate2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate2_id,'CDF_CHAR','Body Frame Rate (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate2_id,'CDF_CHAR','rad/s')

    xact_rate3_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_att_det_body_rate3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate3_id,'CDF_CHAR','Body Frame Rate (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate3_id,'CDF_CHAR','rad/s')

    % --- Reaction wheel speeds ---
    xact_rw1_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_161','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_filtered_speed_rpm_161)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw1_id,'CDF_CHAR','Wheel 1 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw1_id,'CDF_CHAR','RPM')

    xact_rw2_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_162','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_filtered_speed_rpm_162)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw2_id,'CDF_CHAR','Wheel 2 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw2_id,'CDF_CHAR','RPM')

    xact_rw3_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_163','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_filtered_speed_rpm_163)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw3_id,'CDF_CHAR','Wheel 3 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw3_id,'CDF_CHAR','RPM')

    xact_rw4_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_164','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw4_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_filtered_speed_rpm_164)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw4_id,'CDF_CHAR','Wheel 4 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw4_id,'CDF_CHAR','RPM')

    % --- IMU rates ---
    xact_imu1_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_imu_imu_avg_vector1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu1_id,'CDF_CHAR','IMU Rate (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu1_id,'CDF_CHAR','rad/s')

    xact_imu2_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_imu_imu_avg_vector2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu2_id,'CDF_CHAR','IMU Rate (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu2_id,'CDF_CHAR','rad/s')

    xact_imu3_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_imu_imu_avg_vector3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu3_id,'CDF_CHAR','IMU Rate (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu3_id,'CDF_CHAR','rad/s')

    % --- Measured magnetic field body frame ---
    xact_mag1_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_mag_mag_vector_body1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag1_id,'CDF_CHAR','Measured Mag Field Body (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag1_id,'CDF_CHAR','T')

    xact_mag2_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_mag_mag_vector_body2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag2_id,'CDF_CHAR','Measured Mag Field Body (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag2_id,'CDF_CHAR','T')

    xact_mag3_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_mag_mag_vector_body3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag3_id,'CDF_CHAR','Measured Mag Field Body (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag3_id,'CDF_CHAR','T')

    % --- Reaction wheel coarse currents ---
    xact_rwi1_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_meas_wheel_current1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi1_id,'CDF_CHAR','Coarse Wheel 1 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi1_id,'CDF_CHAR','A')

    xact_rwi2_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_meas_wheel_current2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi2_id,'CDF_CHAR','Coarse Wheel 2 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi2_id,'CDF_CHAR','A')

    xact_rwi3_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_meas_wheel_current3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi3_id,'CDF_CHAR','Coarse Wheel 3 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi3_id,'CDF_CHAR','A')

    xact_rwi4_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current4','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi4_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_rw_drive_meas_wheel_current4)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi4_id,'CDF_CHAR','Coarse Wheel 4 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi4_id,'CDF_CHAR','A')

    % --- Torque rod torques ---
    xact_tr1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_cycle_avg_magnet_torque1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr1_id,'CDF_CHAR','Torque Rod 1 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr1_id,'CDF_CHAR','N m')

    xact_tr2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_cycle_avg_magnet_torque2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr2_id,'CDF_CHAR','Torque Rod 2 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr2_id,'CDF_CHAR','N m')

    xact_tr3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_cycle_avg_magnet_torque3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr3_id,'CDF_CHAR','Torque Rod 3 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr3_id,'CDF_CHAR','N m')

    % --- Torque rod enable ---
    xact_tre1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable1','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre1_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_momentum_torque_rod_enable1))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre1_id,'CDF_CHAR','Torque Rod 1 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre1_id,'CDF_CHAR','-')

    xact_tre2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable2','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre2_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_momentum_torque_rod_enable2))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre2_id,'CDF_CHAR','Torque Rod 2 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre2_id,'CDF_CHAR','-')

    xact_tre3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable3','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre3_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_momentum_torque_rod_enable3))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre3_id,'CDF_CHAR','Torque Rod 3 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre3_id,'CDF_CHAR','-')

    % --- Torque rod duty cycles ---
    xact_dc1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc1_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_duty_cycle1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc1_id,'CDF_CHAR','Torque Rod 1 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc1_id,'CDF_CHAR','-')

    xact_dc2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc2_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_duty_cycle2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc2_id,'CDF_CHAR','Torque Rod 2 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc2_id,'CDF_CHAR','-')

    xact_dc3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc3_id,[0 N_xact 1],{0 1 1},XACT_HK.meta_momentum_duty_cycle3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc3_id,'CDF_CHAR','Torque Rod 3 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc3_id,'CDF_CHAR','-')

    % --- Torque rod control modes ---
    xact_trm1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_mode1','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm1_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_momentum_torque_rod_mode1))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm1_id,'CDF_CHAR','Torque Rod 1 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm1_id,'CDF_CHAR','-')

    xact_trm2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_mode2','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm2_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_momentum_torque_rod_mode2))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm2_id,'CDF_CHAR','Torque Rod 2 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm2_id,'CDF_CHAR','-')

    xact_trm3_id = cdflib.createVar(cdfid,'XACT_meta_adcs_momentum_torque_rod_mode3','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm3_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_adcs_momentum_torque_rod_mode3))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm3_id,'CDF_CHAR','Torque Rod 3 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm3_id,'CDF_CHAR','-')

    % --- Attitude validity flags ---
    xact_attv_id = cdflib.createVar(cdfid,'XACT_meta_att_det_attitude_valid','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_attv_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_att_det_attitude_valid))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_attv_id,'CDF_CHAR','Attitude Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_attv_id,'CDF_CHAR','-')

    xact_mav_id = cdflib.createVar(cdfid,'XACT_meta_att_det_meas_att_valid','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mav_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_att_det_meas_att_valid))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mav_id,'CDF_CHAR','Measured Attitude Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mav_id,'CDF_CHAR','-')

    xact_mrv_id = cdflib.createVar(cdfid,'XACT_meta_att_det_meas_rate_valid','CDF_UINT1',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mrv_id,[0 N_xact 1],{0 1 1},uint8(XACT_HK.meta_att_det_meas_rate_valid))
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mrv_id,'CDF_CHAR','Measured Rate Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mrv_id,'CDF_CHAR','-')

    % Drop the placeholder record so the absent family reads back as zero
    % records rather than one row of invented values
    if drop_xact, delete_placeholder(cdfid,{'XACT_'}); end
    if drop_pld,  delete_placeholder(cdfid,{'PLD_','pld_'}); end

    cdflib.close(cdfid)

elseif level == 2
    T = varargin{1};
    N = length(T.time);
    time_ms = (datenum(T.time) - 1) * 86400000;
    st   = T.time(1);
    en   = T.time(end);
    vvvv = '0001';

    filename = ['HK_',char(st,'yyyyMMdd''T''HHmmss'),...
        '_',char(en,'yyyyMMdd''T''HHmmss'),'_',vvvv,'.cdf'];

    fn = dir([path,filename]);
    if ~isempty(fn)
        delete([path,filename])
        warning('One CDF has been removed!')
    end
    cdfid   = cdflib.create([path,filename]);
    cleaner = onCleanup(@() cdflib.close(cdfid));

    %% Global attributes
    titleAttrNum  = cdflib.createAttr(cdfid,'TITLE','global_scope');
    cdflib.putAttrEntry(cdfid,titleAttrNum,0,'CDF_CHAR',filename)
    authorAttrNum = cdflib.createAttr(cdfid,'CREATOR','global_scope');
    cdflib.putAttrEntry(cdfid,authorAttrNum,0,'CDF_CHAR','LAIR at University of Colorado Boulder')

    %% Variable attribute handles
    desAttrNum   = cdflib.createAttr(cdfid,'DESCRIPTION','variable_scope');
    unitsAttrNum = cdflib.createAttr(cdfid,'UNITS','variable_scope');

    % Time
    time_id = cdflib.createVar(cdfid,'Time','CDF_EPOCH',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,time_id,[0 N 1],{0 1 1},time_ms)
    cdflib.putAttrEntry(cdfid,desAttrNum,time_id,'CDF_CHAR','Time of HK daily data')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,time_id,'CDF_CHAR','UTC')

    % =====================================================================
    %% PLD_HK (APID 519) — daily median
    % =====================================================================

    % --- Power rail currents and voltages ---
    pld_5v_i_id = cdflib.createVar(cdfid,'pld_5v_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_i_id,[0 N 1],{0 1 1},T.pld_5v_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_i_id,'CDF_CHAR','Current at +5V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_i_id,'CDF_CHAR','mA')

    pld_5v_v_id = cdflib.createVar(cdfid,'pld_5v_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_v_id,[0 N 1],{0 1 1},T.pld_5v_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_v_id,'CDF_CHAR','Voltage at +5V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_v_id,'CDF_CHAR','V')

    pld_12v_i_id = cdflib.createVar(cdfid,'pld_12v_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_i_id,[0 N 1],{0 1 1},T.pld_12v_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_i_id,'CDF_CHAR','Current at 12V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_i_id,'CDF_CHAR','mA')

    pld_12v_v_id = cdflib.createVar(cdfid,'pld_12v_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_v_id,[0 N 1],{0 1 1},T.pld_12v_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_v_id,'CDF_CHAR','Voltage at 12V rail (for Analog Board)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_v_id,'CDF_CHAR','V')

    pld_3v3_i_id = cdflib.createVar(cdfid,'pld_3v3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_i_id,[0 N 1],{0 1 1},T.pld_3v3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_i_id,'CDF_CHAR','Current at 3V3 rail (for HK Sensors)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_i_id,'CDF_CHAR','mA')

    pld_3v3_v_id = cdflib.createVar(cdfid,'pld_3v3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_v_id,[0 N 1],{0 1 1},T.pld_3v3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_v_id,'CDF_CHAR','Voltage at 3V3 rail (for HK Sensors)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_v_id,'CDF_CHAR','V')

    pld_5v_st_i_id = cdflib.createVar(cdfid,'pld_5v_st_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_st_i_id,[0 N 1],{0 1 1},T.pld_5v_st_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_st_i_id,'CDF_CHAR','Current at 5V5T rail (for Star Trackers)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_st_i_id,'CDF_CHAR','mA')

    pld_5v_st_v_id = cdflib.createVar(cdfid,'pld_5v_st_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_st_v_id,[0 N 1],{0 1 1},T.pld_5v_st_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_st_v_id,'CDF_CHAR','Voltage at 5V5T rail (for Star Trackers)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_st_v_id,'CDF_CHAR','V')

    pld_12v_s_i_id = cdflib.createVar(cdfid,'pld_12v_s_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12v_s_i_id,[0 N 1],{0 1 1},T.pld_12v_s_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12v_s_i_id,'CDF_CHAR','Current at 12VS rail (for Scalar Boards)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12v_s_i_id,'CDF_CHAR','mA')

    pld_12_vs_v_id = cdflib.createVar(cdfid,'pld_12_vs_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_12_vs_v_id,[0 N 1],{0 1 1},T.pld_12_vs_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_12_vs_v_id,'CDF_CHAR','Voltage at 12VS rail (for Scalar Boards)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_12_vs_v_id,'CDF_CHAR','V')

    % --- Scalar Board 1 ---
    pld_sc1_sb1_i_id = cdflib.createVar(cdfid,'pld_sc1_sb1_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb1_i_id,[0 N 1],{0 1 1},T.pld_sc1_sb1_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb1_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb1_i_id,'CDF_CHAR','mA')

    pld_sc1_sb1_v_id = cdflib.createVar(cdfid,'pld_sc1_sb1_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb1_v_id,[0 N 1],{0 1 1},T.pld_sc1_sb1_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb1_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb1_v_id,'CDF_CHAR','V')

    pld_sc1_sb2_i_id = cdflib.createVar(cdfid,'pld_sc1_sb2_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb2_i_id,[0 N 1],{0 1 1},T.pld_sc1_sb2_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb2_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb2_i_id,'CDF_CHAR','mA')

    pld_sc1_sb2_v_id = cdflib.createVar(cdfid,'pld_sc1_sb2_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb2_v_id,[0 N 1],{0 1 1},T.pld_sc1_sb2_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb2_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb2_v_id,'CDF_CHAR','V')

    pld_sc1_sb3_i_id = cdflib.createVar(cdfid,'pld_sc1_sb3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb3_i_id,[0 N 1],{0 1 1},T.pld_sc1_sb3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb3_i_id,'CDF_CHAR','Current at Scalar Board No.1 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb3_i_id,'CDF_CHAR','mA')

    pld_sc1_sb3_v_id = cdflib.createVar(cdfid,'pld_sc1_sb3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_sb3_v_id,[0 N 1],{0 1 1},T.pld_sc1_sb3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_sb3_v_id,'CDF_CHAR','Voltage at Scalar Board No.1 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_sb3_v_id,'CDF_CHAR','V')

    % --- Scalar Board 2 ---
    pld_sc2_sb1_i_id = cdflib.createVar(cdfid,'pld_sc2_sb1_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb1_i_id,[0 N 1],{0 1 1},T.pld_sc2_sb1_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb1_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb1_i_id,'CDF_CHAR','mA')

    pld_sc2_sb1_v_id = cdflib.createVar(cdfid,'pld_sc2_sb1_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb1_v_id,[0 N 1],{0 1 1},T.pld_sc2_sb1_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb1_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb1_v_id,'CDF_CHAR','V')

    pld_sc2_sb2_i_id = cdflib.createVar(cdfid,'pld_sc2_sb2_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb2_i_id,[0 N 1],{0 1 1},T.pld_sc2_sb2_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb2_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb2_i_id,'CDF_CHAR','mA')

    pld_sc2_sb2_v_id = cdflib.createVar(cdfid,'pld_sc2_sb2_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb2_v_id,[0 N 1],{0 1 1},T.pld_sc2_sb2_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb2_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb2_v_id,'CDF_CHAR','V')

    pld_sc2_sb3_i_id = cdflib.createVar(cdfid,'pld_sc2_sb3_i','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb3_i_id,[0 N 1],{0 1 1},T.pld_sc2_sb3_i)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb3_i_id,'CDF_CHAR','Current at Scalar Board No.2 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb3_i_id,'CDF_CHAR','mA')

    pld_sc2_sb3_v_id = cdflib.createVar(cdfid,'pld_sc2_sb3_v','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_sb3_v_id,[0 N 1],{0 1 1},T.pld_sc2_sb3_v)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_sb3_v_id,'CDF_CHAR','Voltage at Scalar Board No.2 - Ch.3')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_sb3_v_id,'CDF_CHAR','V')

    % --- Temperatures ---
    pld_5v_reg_t_id = cdflib.createVar(cdfid,'pld_5v_reg_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_5v_reg_t_id,[0 N 1],{0 1 1},T.pld_5v_reg_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_5v_reg_t_id,'CDF_CHAR','Temperature at 5V Regulator')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_5v_reg_t_id,'CDF_CHAR','-')

    pld_3v3_reg_t_id = cdflib.createVar(cdfid,'pld_3v3_reg_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_3v3_reg_t_id,[0 N 1],{0 1 1},T.pld_3v3_reg_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_3v3_reg_t_id,'CDF_CHAR','Temperature at 3V3 Regulator')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_3v3_reg_t_id,'CDF_CHAR','-')

    pld_sc1_t_id = cdflib.createVar(cdfid,'pld_sc1_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc1_t_id,[0 N 1],{0 1 1},T.pld_sc1_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc1_t_id,'CDF_CHAR','Temperature at Scalar Board No.1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc1_t_id,'CDF_CHAR','-')

    pld_sc2_t_id = cdflib.createVar(cdfid,'pld_sc2_t','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc2_t_id,[0 N 1],{0 1 1},T.pld_sc2_t)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc2_t_id,'CDF_CHAR','Temperature at Scalar Board No.2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc2_t_id,'CDF_CHAR','-')

    pld_vrum_t_1_id = cdflib.createVar(cdfid,'pld_vrum_t_1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_vrum_t_1_id,[0 N 1],{0 1 1},T.pld_vrum_t_1)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_vrum_t_1_id,'CDF_CHAR','VRuM Temperature 1')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_vrum_t_1_id,'CDF_CHAR','-')

    pld_vrum_t_2_id = cdflib.createVar(cdfid,'pld_vrum_t_2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_vrum_t_2_id,[0 N 1],{0 1 1},T.pld_vrum_t_2)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_vrum_t_2_id,'CDF_CHAR','VRuM Temperature 2')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_vrum_t_2_id,'CDF_CHAR','-')

    % --- Coil 0 ---
    pld_coil_0_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_0_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_meas_id,[0 N 1],{0 1 1},T.pld_coil_0_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_meas_id,'CDF_CHAR','Coil 0 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_meas_id,'CDF_CHAR','-')

    pld_coil_0_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_0_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_adj_id,[0 N 1],{0 1 1},T.pld_coil_0_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_adj_id,'CDF_CHAR','Coil 0 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_adj_id,'CDF_CHAR','-')

    pld_coil_0_amp_set_id = cdflib.createVar(cdfid,'pld_coil_0_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_amp_set_id,[0 N 1],{0 1 1},T.pld_coil_0_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_amp_set_id,'CDF_CHAR','Coil 0 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_amp_set_id,'CDF_CHAR','-')

    pld_coil_0_freq_set_id = cdflib.createVar(cdfid,'pld_coil_0_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_freq_set_id,[0 N 1],{0 1 1},T.pld_coil_0_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_freq_set_id,'CDF_CHAR','Coil 0 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_freq_set_id,'CDF_CHAR','-')

    pld_coil_0_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_0_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_freq_calc_id,[0 N 1],{0 1 1},T.pld_coil_0_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_freq_calc_id,'CDF_CHAR','Coil 0 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_freq_calc_id,'CDF_CHAR','-')

    pld_coil_0_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_0_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_0_dc_offset_id,[0 N 1],{0 1 1},T.pld_coil_0_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_0_dc_offset_id,'CDF_CHAR','Coil 0 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_0_dc_offset_id,'CDF_CHAR','-')

    % --- Coil 1 ---
    pld_coil_1_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_1_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_meas_id,[0 N 1],{0 1 1},T.pld_coil_1_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_meas_id,'CDF_CHAR','Coil 1 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_meas_id,'CDF_CHAR','-')

    pld_coil_1_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_1_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_adj_id,[0 N 1],{0 1 1},T.pld_coil_1_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_adj_id,'CDF_CHAR','Coil 1 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_adj_id,'CDF_CHAR','-')

    pld_coil_1_amp_set_id = cdflib.createVar(cdfid,'pld_coil_1_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_amp_set_id,[0 N 1],{0 1 1},T.pld_coil_1_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_amp_set_id,'CDF_CHAR','Coil 1 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_amp_set_id,'CDF_CHAR','-')

    pld_coil_1_freq_set_id = cdflib.createVar(cdfid,'pld_coil_1_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_freq_set_id,[0 N 1],{0 1 1},T.pld_coil_1_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_freq_set_id,'CDF_CHAR','Coil 1 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_freq_set_id,'CDF_CHAR','-')

    pld_coil_1_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_1_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_freq_calc_id,[0 N 1],{0 1 1},T.pld_coil_1_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_freq_calc_id,'CDF_CHAR','Coil 1 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_freq_calc_id,'CDF_CHAR','-')

    pld_coil_1_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_1_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_1_dc_offset_id,[0 N 1],{0 1 1},T.pld_coil_1_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_1_dc_offset_id,'CDF_CHAR','Coil 1 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_1_dc_offset_id,'CDF_CHAR','-')

    % --- Coil 2 ---
    pld_coil_2_amp_meas_id = cdflib.createVar(cdfid,'pld_coil_2_amp_meas','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_meas_id,[0 N 1],{0 1 1},T.pld_coil_2_amp_meas)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_meas_id,'CDF_CHAR','Coil 2 current amplitude (measured)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_meas_id,'CDF_CHAR','-')

    pld_coil_2_amp_adj_id = cdflib.createVar(cdfid,'pld_coil_2_amp_adj','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_adj_id,[0 N 1],{0 1 1},T.pld_coil_2_amp_adj)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_adj_id,'CDF_CHAR','Coil 2 adjusted amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_adj_id,'CDF_CHAR','-')

    pld_coil_2_amp_set_id = cdflib.createVar(cdfid,'pld_coil_2_amp_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_amp_set_id,[0 N 1],{0 1 1},T.pld_coil_2_amp_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_amp_set_id,'CDF_CHAR','Coil 2 original amplitude (set)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_amp_set_id,'CDF_CHAR','-')

    pld_coil_2_freq_set_id = cdflib.createVar(cdfid,'pld_coil_2_freq_set','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_freq_set_id,[0 N 1],{0 1 1},T.pld_coil_2_freq_set)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_freq_set_id,'CDF_CHAR','Coil 2 set frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_freq_set_id,'CDF_CHAR','-')

    pld_coil_2_freq_calc_id = cdflib.createVar(cdfid,'pld_coil_2_freq_calc','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_freq_calc_id,[0 N 1],{0 1 1},T.pld_coil_2_freq_calc)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_freq_calc_id,'CDF_CHAR','Coil 2 calculated frequency')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_freq_calc_id,'CDF_CHAR','-')

    pld_coil_2_dc_offset_id = cdflib.createVar(cdfid,'pld_coil_2_dc_offset','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_coil_2_dc_offset_id,[0 N 1],{0 1 1},T.pld_coil_2_dc_offset)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_coil_2_dc_offset_id,'CDF_CHAR','Coil 2 current DC offset')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_coil_2_dc_offset_id,'CDF_CHAR','-')

    % --- Packet counters ---
    pld_pkt_recv_ct_id = cdflib.createVar(cdfid,'pld_pkt_recv_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_recv_ct_id,[0 N 1],{0 1 1},T.pld_pkt_recv_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_recv_ct_id,'CDF_CHAR','Packet counter value for received packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_recv_ct_id,'CDF_CHAR','-')

    pld_pkt_ack_ct_id = cdflib.createVar(cdfid,'pld_pkt_ack_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_ack_ct_id,[0 N 1],{0 1 1},T.pld_pkt_ack_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_ack_ct_id,'CDF_CHAR','Packet counter value for acknowledged packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_ack_ct_id,'CDF_CHAR','-')

    pld_pkt_nack_ct_id = cdflib.createVar(cdfid,'pld_pkt_nack_ct','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_pkt_nack_ct_id,[0 N 1],{0 1 1},T.pld_pkt_nack_ct)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_pkt_nack_ct_id,'CDF_CHAR','Packet counter value for not acknowledged packets')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_pkt_nack_ct_id,'CDF_CHAR','-')

    % --- MCP4131 Digital Potentiometer states ---
    pld_mcp4131_1_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_1_cfg_id,[0 N 1],{0 1 1},T.pld_mcp4131_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_1_cfg_id,'CDF_CHAR','1 - DigPot No.1 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_1_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_2_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_2_cfg_id,[0 N 1],{0 1 1},T.pld_mcp4131_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_2_cfg_id,'CDF_CHAR','1 - DigPot No.2 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_2_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_3_cfg_id = cdflib.createVar(cdfid,'pld_mcp4131_3_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_3_cfg_id,[0 N 1],{0 1 1},T.pld_mcp4131_3_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_3_cfg_id,'CDF_CHAR','1 - DigPot No.3 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_3_cfg_id,'CDF_CHAR','-')

    pld_mcp4131_1_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_1_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_1_ctrl_id,[0 N 1],{0 1 1},T.pld_mcp4131_1_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_1_ctrl_id,'CDF_CHAR','1 - DigPot No.1 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_1_ctrl_id,'CDF_CHAR','-')

    pld_mcp4131_2_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_2_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_2_ctrl_id,[0 N 1],{0 1 1},T.pld_mcp4131_2_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_2_ctrl_id,'CDF_CHAR','1 - DigPot No.2 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_2_ctrl_id,'CDF_CHAR','-')

    pld_mcp4131_3_ctrl_id = cdflib.createVar(cdfid,'pld_mcp4131_3_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_mcp4131_3_ctrl_id,[0 N 1],{0 1 1},T.pld_mcp4131_3_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_mcp4131_3_ctrl_id,'CDF_CHAR','1 - DigPot No.3 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_mcp4131_3_ctrl_id,'CDF_CHAR','-')

    % --- AD9837 Waveform Generator states ---
    pld_ad9837_1_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_1_cfg_id,[0 N 1],{0 1 1},T.pld_ad9837_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_1_cfg_id,'CDF_CHAR','1 - WaveGen No.1 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_1_cfg_id,'CDF_CHAR','-')

    pld_ad9837_2_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_2_cfg_id,[0 N 1],{0 1 1},T.pld_ad9837_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_2_cfg_id,'CDF_CHAR','1 - WaveGen No.2 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_2_cfg_id,'CDF_CHAR','-')

    pld_ad9837_3_cfg_id = cdflib.createVar(cdfid,'pld_ad9837_3_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_3_cfg_id,[0 N 1],{0 1 1},T.pld_ad9837_3_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_3_cfg_id,'CDF_CHAR','1 - WaveGen No.3 (Analog Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_3_cfg_id,'CDF_CHAR','-')

    pld_ad9837_1_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_1_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_1_ctrl_id,[0 N 1],{0 1 1},T.pld_ad9837_1_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_1_ctrl_id,'CDF_CHAR','1 - WaveGen No.1 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_1_ctrl_id,'CDF_CHAR','-')

    pld_ad9837_2_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_2_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_2_ctrl_id,[0 N 1],{0 1 1},T.pld_ad9837_2_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_2_ctrl_id,'CDF_CHAR','1 - WaveGen No.2 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_2_ctrl_id,'CDF_CHAR','-')

    pld_ad9837_3_ctrl_id = cdflib.createVar(cdfid,'pld_ad9837_3_ctrl_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ad9837_3_ctrl_id,[0 N 1],{0 1 1},T.pld_ad9837_3_ctrl_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ad9837_3_ctrl_id,'CDF_CHAR','1 - WaveGen No.3 (Analog Board) control success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ad9837_3_ctrl_id,'CDF_CHAR','-')

    % --- TMP100 Temperature Sensor states ---
    pld_tmp100_1_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_1_cfg_id,[0 N 1],{0 1 1},T.pld_tmp100_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_1_cfg_id,'CDF_CHAR','1 - TMP No.1 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_1_cfg_id,'CDF_CHAR','-')

    pld_tmp100_2_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_2_cfg_id,[0 N 1],{0 1 1},T.pld_tmp100_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_2_cfg_id,'CDF_CHAR','1 - TMP No.2 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_2_cfg_id,'CDF_CHAR','-')

    pld_tmp100_sc1_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_sc1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc1_cfg_id,[0 N 1],{0 1 1},T.pld_tmp100_sc1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc1_cfg_id,'CDF_CHAR','1 - TMP (Scalar Board No.1) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc1_cfg_id,'CDF_CHAR','-')

    pld_tmp100_sc2_cfg_id = cdflib.createVar(cdfid,'pld_tmp100_sc2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc2_cfg_id,[0 N 1],{0 1 1},T.pld_tmp100_sc2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc2_cfg_id,'CDF_CHAR','1 - TMP (Scalar Board No.2) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc2_cfg_id,'CDF_CHAR','-')

    pld_tmp100_1_read_id = cdflib.createVar(cdfid,'pld_tmp100_1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_1_read_id,[0 N 1],{0 1 1},T.pld_tmp100_1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_1_read_id,'CDF_CHAR','1 - TMP No.1 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_1_read_id,'CDF_CHAR','-')

    pld_tmp100_2_read_id = cdflib.createVar(cdfid,'pld_tmp100_2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_2_read_id,[0 N 1],{0 1 1},T.pld_tmp100_2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_2_read_id,'CDF_CHAR','1 - TMP No.2 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_2_read_id,'CDF_CHAR','-')

    pld_tmp100_sc1_read_id = cdflib.createVar(cdfid,'pld_tmp100_sc1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc1_read_id,[0 N 1],{0 1 1},T.pld_tmp100_sc1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc1_read_id,'CDF_CHAR','1 - TMP (Scalar Board No.1) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc1_read_id,'CDF_CHAR','-')

    pld_tmp100_sc2_read_id = cdflib.createVar(cdfid,'pld_tmp100_sc2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_tmp100_sc2_read_id,[0 N 1],{0 1 1},T.pld_tmp100_sc2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_tmp100_sc2_read_id,'CDF_CHAR','1 - TMP (Scalar Board No.2) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_tmp100_sc2_read_id,'CDF_CHAR','-')

    % --- INA3221 Power Sensor states ---
    pld_ina3221_1_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_1_cfg_id,[0 N 1],{0 1 1},T.pld_ina3221_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_1_cfg_id,'CDF_CHAR','1 - INA No.1 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_1_cfg_id,'CDF_CHAR','-')

    pld_ina3221_2_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_2_cfg_id,[0 N 1],{0 1 1},T.pld_ina3221_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_2_cfg_id,'CDF_CHAR','1 - INA No.2 (Digital Board) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_2_cfg_id,'CDF_CHAR','-')

    pld_ina3221_sc1_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_sc1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc1_cfg_id,[0 N 1],{0 1 1},T.pld_ina3221_sc1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc1_cfg_id,'CDF_CHAR','1 - INA (Scalar Board No.1) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc1_cfg_id,'CDF_CHAR','-')

    pld_ina3221_sc2_cfg_id = cdflib.createVar(cdfid,'pld_ina3221_sc2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc2_cfg_id,[0 N 1],{0 1 1},T.pld_ina3221_sc2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc2_cfg_id,'CDF_CHAR','1 - INA (Scalar Board No.2) configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc2_cfg_id,'CDF_CHAR','-')

    pld_ina3221_1_read_id = cdflib.createVar(cdfid,'pld_ina3221_1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_1_read_id,[0 N 1],{0 1 1},T.pld_ina3221_1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_1_read_id,'CDF_CHAR','1 - INA No.1 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_1_read_id,'CDF_CHAR','-')

    pld_ina3221_2_read_id = cdflib.createVar(cdfid,'pld_ina3221_2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_2_read_id,[0 N 1],{0 1 1},T.pld_ina3221_2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_2_read_id,'CDF_CHAR','1 - INA No.2 (Digital Board) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_2_read_id,'CDF_CHAR','-')

    pld_ina3221_sc1_read_id = cdflib.createVar(cdfid,'pld_ina3221_sc1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc1_read_id,[0 N 1],{0 1 1},T.pld_ina3221_sc1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc1_read_id,'CDF_CHAR','1 - INA (Scalar Board No.1) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc1_read_id,'CDF_CHAR','-')

    pld_ina3221_sc2_read_id = cdflib.createVar(cdfid,'pld_ina3221_sc2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_ina3221_sc2_read_id,[0 N 1],{0 1 1},T.pld_ina3221_sc2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_ina3221_sc2_read_id,'CDF_CHAR','1 - INA (Scalar Board No.2) polling success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_ina3221_sc2_read_id,'CDF_CHAR','-')

    % --- Star Tracker states ---
    pld_st_1_cfg_id = cdflib.createVar(cdfid,'pld_st_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_1_cfg_id,[0 N 1],{0 1 1},T.pld_st_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_1_cfg_id,'CDF_CHAR','1 - Star Tracker No.1 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_1_cfg_id,'CDF_CHAR','-')

    pld_st_2_cfg_id = cdflib.createVar(cdfid,'pld_st_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_2_cfg_id,[0 N 1],{0 1 1},T.pld_st_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_2_cfg_id,'CDF_CHAR','1 - Star Tracker No.2 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_2_cfg_id,'CDF_CHAR','-')

    pld_st_1_read_id = cdflib.createVar(cdfid,'pld_st_1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_1_read_id,[0 N 1],{0 1 1},T.pld_st_1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_1_read_id,'CDF_CHAR','1 - Star Tracker No.1 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_1_read_id,'CDF_CHAR','-')

    pld_st_2_read_id = cdflib.createVar(cdfid,'pld_st_2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st_2_read_id,[0 N 1],{0 1 1},T.pld_st_2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st_2_read_id,'CDF_CHAR','1 - Star Tracker No.2 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st_2_read_id,'CDF_CHAR','-')

    % --- Scalar Board states ---
    pld_scalar_1_cfg_id = cdflib.createVar(cdfid,'pld_scalar_1_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_1_cfg_id,[0 N 1],{0 1 1},T.pld_scalar_1_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_1_cfg_id,'CDF_CHAR','1 - Scalar Board No.1 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_1_cfg_id,'CDF_CHAR','-')

    pld_scalar_2_cfg_id = cdflib.createVar(cdfid,'pld_scalar_2_cfg_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_2_cfg_id,[0 N 1],{0 1 1},T.pld_scalar_2_cfg_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_2_cfg_id,'CDF_CHAR','1 - Scalar Board No.2 configuration success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_2_cfg_id,'CDF_CHAR','-')

    pld_scalar_1_read_id = cdflib.createVar(cdfid,'pld_scalar_1_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_1_read_id,[0 N 1],{0 1 1},T.pld_scalar_1_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_1_read_id,'CDF_CHAR','1 - Scalar Board No.1 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_1_read_id,'CDF_CHAR','-')

    pld_scalar_2_read_id = cdflib.createVar(cdfid,'pld_scalar_2_read_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_scalar_2_read_id,[0 N 1],{0 1 1},T.pld_scalar_2_read_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_scalar_2_read_id,'CDF_CHAR','1 - Scalar Board No.2 read success; 0 - Fail')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_scalar_2_read_id,'CDF_CHAR','-')

    % --- Scalar read health ---
    pld_cdh_comm_state_id = cdflib.createVar(cdfid,'pld_cdh_comm_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_cdh_comm_state_id,[0 N 1],{0 1 1},T.pld_cdh_comm_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_cdh_comm_state_id,'CDF_CHAR','CDH Comm State Machine')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_cdh_comm_state_id,'CDF_CHAR','-')

    pld_active_coil_id = cdflib.createVar(cdfid,'pld_active_coil_control','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_active_coil_id,[0 N 1],{0 1 1},T.pld_active_coil_control)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_active_coil_id,'CDF_CHAR','Active coil control flag; 0 - OFF, 1 - ON')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_active_coil_id,'CDF_CHAR','-')

    pld_sc_warmup_id = cdflib.createVar(cdfid,'pld_sc_warmup_timeout','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_warmup_id,[0 N 1],{0 1 1},T.pld_sc_warmup_timeout)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_warmup_id,'CDF_CHAR','Scalar warmup timeout set')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_warmup_id,'CDF_CHAR','s')

    pld_sc_cooldown_id = cdflib.createVar(cdfid,'pld_sc_cooldown_timeout','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_cooldown_id,[0 N 1],{0 1 1},T.pld_sc_cooldown_timeout)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_cooldown_id,'CDF_CHAR','Scalar cooldown timeout set')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_cooldown_id,'CDF_CHAR','s')

    pld_sc_reinit_id = cdflib.createVar(cdfid,'pld_sc_reinit_counts','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_reinit_id,[0 N 1],{0 1 1},T.pld_sc_reinit_counts)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_reinit_id,'CDF_CHAR','Counter for scalar reinits due to timeout')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_reinit_id,'CDF_CHAR','-')

    pld_sc_read_timeout_id = cdflib.createVar(cdfid,'pld_sc_read_timeout','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_read_timeout_id,[0 N 1],{0 1 1},T.pld_sc_read_timeout)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_read_timeout_id,'CDF_CHAR','Timeout waiting for scalar packet; 0 - NO, 1 - TIMEOUT')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_read_timeout_id,'CDF_CHAR','-')

    pld_sc_uflow_id = cdflib.createVar(cdfid,'pld_sc_read_buffer_underflow','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_uflow_id,[0 N 1],{0 1 1},T.pld_sc_read_buffer_underflow)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_uflow_id,'CDF_CHAR','Transmitted scalar buffer is empty (missing samples); 0 - NO, 1 - UNDERFLOW')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_uflow_id,'CDF_CHAR','-')

    pld_sc_oflow_id = cdflib.createVar(cdfid,'pld_sc_read_buffer_overflow','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_oflow_id,[0 N 1],{0 1 1},T.pld_sc_read_buffer_overflow)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_oflow_id,'CDF_CHAR','Scalar ringbuffer not emptied fast enough; 0 - NO, 1 - OVERFLOW')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_oflow_id,'CDF_CHAR','-')

    pld_sc_mag_crc_id = cdflib.createVar(cdfid,'pld_sc_mag_crc_flag','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_crc_id,[0 N 1],{0 1 1},T.pld_sc_mag_crc_flag)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_crc_id,'CDF_CHAR','Payload science scalar CRC flag; 0 - FAIL, 1 - PASS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_crc_id,'CDF_CHAR','-')

    pld_sc_mag_state_id = cdflib.createVar(cdfid,'pld_sc_mag_state','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_state_id,[0 N 1],{0 1 1},T.pld_sc_mag_state)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_state_id,'CDF_CHAR','Scalar magnetometer state; 2-STARTUP 3-WARMUP 4-LASERLOCKSCAN 5-RESONANCESCAN 6-LOCK')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_state_id,'CDF_CHAR','-')

    pld_st1_trust_id = cdflib.createVar(cdfid,'pld_st1_is_trustworthy','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st1_trust_id,[0 N 1],{0 1 1},T.pld_st1_is_trustworthy)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st1_trust_id,'CDF_CHAR','Star tracker 1 solution is trustworthy; 0 - NO, 1 - YES')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st1_trust_id,'CDF_CHAR','-')

    pld_st2_trust_id = cdflib.createVar(cdfid,'pld_st2_is_trustworthy','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_st2_trust_id,[0 N 1],{0 1 1},T.pld_st2_is_trustworthy)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_st2_trust_id,'CDF_CHAR','Star tracker 2 solution is trustworthy; 0 - NO, 1 - YES')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_st2_trust_id,'CDF_CHAR','-')

    pld_fw_major_id = cdflib.createVar(cdfid,'pld_firmware_major_rev','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_major_id,[0 N 1],{0 1 1},T.pld_firmware_major_rev)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_major_id,'CDF_CHAR','Firmware revision major version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_major_id,'CDF_CHAR','-')

    pld_fw_minor_id = cdflib.createVar(cdfid,'pld_firmware_minor_rev','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_minor_id,[0 N 1],{0 1 1},T.pld_firmware_minor_rev)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_minor_id,'CDF_CHAR','Firmware revision minor version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_minor_id,'CDF_CHAR','-')

    pld_sc_mag_mod16_id = cdflib.createVar(cdfid,'pld_sc_mag_mod_16_sequence','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_sc_mag_mod16_id,[0 N 1],{0 1 1},T.pld_sc_mag_mod_16_sequence)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_sc_mag_mod16_id,'CDF_CHAR','Payload Science Scalar Mod 16 Sequence Counter')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_sc_mag_mod16_id,'CDF_CHAR','-')

    pld_fw_patch_id = cdflib.createVar(cdfid,'pld_firmware_patch_no','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,pld_fw_patch_id,[0 N 1],{0 1 1},T.pld_firmware_patch_no)
    cdflib.putAttrEntry(cdfid,desAttrNum,pld_fw_patch_id,'CDF_CHAR','Firmware Revision Patch Version')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,pld_fw_patch_id,'CDF_CHAR','-')

    % =====================================================================
    %% XACT_HK (APID 520) — daily median
    % =====================================================================
    xact_tai_id = cdflib.createVar(cdfid,'XACT_meta_time_tai_seconds','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tai_id,[0 N 1],{0 1 1},T.XACT_meta_time_tai_seconds)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tai_id,'CDF_CHAR','TAI Seconds')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tai_id,'CDF_CHAR','s')

    % --- Orbit position ECEF ---
    xact_pos1_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos1_id,[0 N 1],{0 1 1},T.XACT_meta_refs_position_wrt_ecef1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos1_id,'CDF_CHAR','Orbit Position ECEF (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos1_id,'CDF_CHAR','m')

    xact_pos2_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos2_id,[0 N 1],{0 1 1},T.XACT_meta_refs_position_wrt_ecef2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos2_id,'CDF_CHAR','Orbit Position ECEF (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos2_id,'CDF_CHAR','m')

    xact_pos3_id = cdflib.createVar(cdfid,'XACT_meta_refs_position_wrt_ecef3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pos3_id,[0 N 1],{0 1 1},T.XACT_meta_refs_position_wrt_ecef3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pos3_id,'CDF_CHAR','Orbit Position ECEF (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pos3_id,'CDF_CHAR','m')

    % --- Orbit velocity ECEF ---
    xact_vel1_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel1_id,[0 N 1],{0 1 1},T.XACT_meta_refs_velocity_wrt_ecef1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel1_id,'CDF_CHAR','Orbit Velocity ECEF (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel1_id,'CDF_CHAR','m/s')

    xact_vel2_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel2_id,[0 N 1],{0 1 1},T.XACT_meta_refs_velocity_wrt_ecef2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel2_id,'CDF_CHAR','Orbit Velocity ECEF (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel2_id,'CDF_CHAR','m/s')

    xact_vel3_id = cdflib.createVar(cdfid,'XACT_meta_refs_velocity_wrt_ecef3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_vel3_id,[0 N 1],{0 1 1},T.XACT_meta_refs_velocity_wrt_ecef3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_vel3_id,'CDF_CHAR','Orbit Velocity ECEF (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_vel3_id,'CDF_CHAR','m/s')

    xact_pulse_id = cdflib.createVar(cdfid,'XACT_meta_pulse_recv_ms','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_pulse_id,[0 N 1],{0 1 1},T.XACT_meta_pulse_recv_ms)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pulse_id,'CDF_CHAR','Local time in ms when last time pulse was received')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pulse_id,'CDF_CHAR','ms')

    % --- Attitude quaternion ---
    xact_q1_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q1_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_q_body_wrt_eci1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q1_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q1_id,'CDF_CHAR','-')

    xact_q2_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q2_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_q_body_wrt_eci2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q2_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q2_id,'CDF_CHAR','-')

    xact_q3_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q3_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_q_body_wrt_eci3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q3_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q3_id,'CDF_CHAR','-')

    xact_q4_id = cdflib.createVar(cdfid,'XACT_meta_att_det_q_body_wrt_eci4','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_q4_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_q_body_wrt_eci4)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_q4_id,'CDF_CHAR','Attitude Quaternion body w.r.t. ECI (component 4)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_q4_id,'CDF_CHAR','-')

    % --- Body frame rates ---
    xact_rate1_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate1_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_body_rate1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate1_id,'CDF_CHAR','Body Frame Rate (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate1_id,'CDF_CHAR','rad/s')

    xact_rate2_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate2_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_body_rate2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate2_id,'CDF_CHAR','Body Frame Rate (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate2_id,'CDF_CHAR','rad/s')

    xact_rate3_id = cdflib.createVar(cdfid,'XACT_meta_att_det_body_rate3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rate3_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_body_rate3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rate3_id,'CDF_CHAR','Body Frame Rate (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rate3_id,'CDF_CHAR','rad/s')

    % --- Reaction wheel speeds ---
    xact_rw1_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_161','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw1_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_filtered_speed_rpm_161)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw1_id,'CDF_CHAR','Wheel 1 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw1_id,'CDF_CHAR','RPM')

    xact_rw2_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_162','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw2_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_filtered_speed_rpm_162)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw2_id,'CDF_CHAR','Wheel 2 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw2_id,'CDF_CHAR','RPM')

    xact_rw3_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_163','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw3_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_filtered_speed_rpm_163)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw3_id,'CDF_CHAR','Wheel 3 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw3_id,'CDF_CHAR','RPM')

    xact_rw4_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_filtered_speed_rpm_164','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rw4_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_filtered_speed_rpm_164)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rw4_id,'CDF_CHAR','Wheel 4 Measured Speed')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rw4_id,'CDF_CHAR','RPM')

    % --- IMU rates ---
    xact_imu1_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu1_id,[0 N 1],{0 1 1},T.XACT_meta_imu_imu_avg_vector1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu1_id,'CDF_CHAR','IMU Rate (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu1_id,'CDF_CHAR','rad/s')

    xact_imu2_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu2_id,[0 N 1],{0 1 1},T.XACT_meta_imu_imu_avg_vector2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu2_id,'CDF_CHAR','IMU Rate (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu2_id,'CDF_CHAR','rad/s')

    xact_imu3_id = cdflib.createVar(cdfid,'XACT_meta_imu_imu_avg_vector3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_imu3_id,[0 N 1],{0 1 1},T.XACT_meta_imu_imu_avg_vector3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_imu3_id,'CDF_CHAR','IMU Rate (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_imu3_id,'CDF_CHAR','rad/s')

    % --- Measured magnetic field body frame ---
    xact_mag1_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag1_id,[0 N 1],{0 1 1},T.XACT_meta_mag_mag_vector_body1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag1_id,'CDF_CHAR','Measured Mag Field Body (component 1)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag1_id,'CDF_CHAR','T')

    xact_mag2_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag2_id,[0 N 1],{0 1 1},T.XACT_meta_mag_mag_vector_body2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag2_id,'CDF_CHAR','Measured Mag Field Body (component 2)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag2_id,'CDF_CHAR','T')

    xact_mag3_id = cdflib.createVar(cdfid,'XACT_meta_mag_mag_vector_body3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mag3_id,[0 N 1],{0 1 1},T.XACT_meta_mag_mag_vector_body3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mag3_id,'CDF_CHAR','Measured Mag Field Body (component 3)')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mag3_id,'CDF_CHAR','T')

    % --- Reaction wheel coarse currents ---
    xact_rwi1_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi1_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_meas_wheel_current1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi1_id,'CDF_CHAR','Coarse Wheel 1 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi1_id,'CDF_CHAR','A')

    xact_rwi2_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi2_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_meas_wheel_current2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi2_id,'CDF_CHAR','Coarse Wheel 2 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi2_id,'CDF_CHAR','A')

    xact_rwi3_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi3_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_meas_wheel_current3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi3_id,'CDF_CHAR','Coarse Wheel 3 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi3_id,'CDF_CHAR','A')

    xact_rwi4_id = cdflib.createVar(cdfid,'XACT_meta_rw_drive_meas_wheel_current4','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_rwi4_id,[0 N 1],{0 1 1},T.XACT_meta_rw_drive_meas_wheel_current4)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_rwi4_id,'CDF_CHAR','Coarse Wheel 4 Current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_rwi4_id,'CDF_CHAR','A')

    % --- Torque rod torques ---
    xact_tr1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr1_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_cycle_avg_magnet_torque1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr1_id,'CDF_CHAR','Torque Rod 1 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr1_id,'CDF_CHAR','N·m')

    xact_tr2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr2_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_cycle_avg_magnet_torque2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr2_id,'CDF_CHAR','Torque Rod 2 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr2_id,'CDF_CHAR','N·m')

    xact_tr3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_cycle_avg_magnet_torque3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tr3_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_cycle_avg_magnet_torque3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tr3_id,'CDF_CHAR','Torque Rod 3 Torque')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tr3_id,'CDF_CHAR','N·m')

    % --- Torque rod enable ---
    xact_tre1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre1_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_torque_rod_enable1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre1_id,'CDF_CHAR','Torque Rod 1 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre1_id,'CDF_CHAR','-')

    xact_tre2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre2_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_torque_rod_enable2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre2_id,'CDF_CHAR','Torque Rod 2 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre2_id,'CDF_CHAR','-')

    xact_tre3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_enable3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_tre3_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_torque_rod_enable3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_tre3_id,'CDF_CHAR','Torque Rod 3 Enable; 1-EN 0-DS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_tre3_id,'CDF_CHAR','-')

    % --- Torque rod duty cycles ---
    xact_dc1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc1_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_duty_cycle1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc1_id,'CDF_CHAR','Torque Rod 1 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc1_id,'CDF_CHAR','-')

    xact_dc2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc2_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_duty_cycle2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc2_id,'CDF_CHAR','Torque Rod 2 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc2_id,'CDF_CHAR','-')

    xact_dc3_id = cdflib.createVar(cdfid,'XACT_meta_momentum_duty_cycle3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_dc3_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_duty_cycle3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_dc3_id,'CDF_CHAR','Torque Rod 3 Duty Cycle')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_dc3_id,'CDF_CHAR','-')

    % --- Torque rod control modes ---
    xact_trm1_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_mode1','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm1_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_torque_rod_mode1)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm1_id,'CDF_CHAR','Torque Rod 1 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm1_id,'CDF_CHAR','-')

    xact_trm2_id = cdflib.createVar(cdfid,'XACT_meta_momentum_torque_rod_mode2','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm2_id,[0 N 1],{0 1 1},T.XACT_meta_momentum_torque_rod_mode2)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm2_id,'CDF_CHAR','Torque Rod 2 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm2_id,'CDF_CHAR','-')

    xact_trm3_id = cdflib.createVar(cdfid,'XACT_meta_adcs_momentum_torque_rod_mode3','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_trm3_id,[0 N 1],{0 1 1},T.XACT_meta_adcs_momentum_torque_rod_mode3)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_trm3_id,'CDF_CHAR','Torque Rod 3 Ctrl Mode')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_trm3_id,'CDF_CHAR','-')

    % --- Attitude validity flags ---
    xact_attv_id = cdflib.createVar(cdfid,'XACT_meta_att_det_attitude_valid','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_attv_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_attitude_valid)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_attv_id,'CDF_CHAR','Attitude Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_attv_id,'CDF_CHAR','-')

    xact_mav_id = cdflib.createVar(cdfid,'XACT_meta_att_det_meas_att_valid','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mav_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_meas_att_valid)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mav_id,'CDF_CHAR','Measured Attitude Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mav_id,'CDF_CHAR','-')

    xact_mrv_id = cdflib.createVar(cdfid,'XACT_meta_att_det_meas_rate_valid','CDF_DOUBLE',1,[],true,[]);
    cdflib.hyperPutVarData(cdfid,xact_mrv_id,[0 N 1],{0 1 1},T.XACT_meta_att_det_meas_rate_valid)
    cdflib.putAttrEntry(cdfid,desAttrNum,xact_mrv_id,'CDF_CHAR','Measured Rate Valid; 1-YES 0-NO')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_mrv_id,'CDF_CHAR','-')

    cdflib.close(cdfid)
end
end

%% Helpers for the level-1 partial-HK case (one HK APID missing)

function s = placeholder_record(fields)
% One-record stand-in for an absent HK family. The values are never kept -
% delete_placeholder removes the record before the file is closed - but the
% record must exist because cdflib will not accept a write of 0 records.
s = struct;
for i = 1:numel(fields)
    s.(fields{i}) = NaN;
end
s.time = NaT;
end

function delete_placeholder(cdfid,prefixes)
% Remove record 0 from every variable whose name starts with one of prefixes
info = cdflib.inquire(cdfid);
for i = 0:info.numVars-1
    name = cdflib.getVarName(cdfid,i);
    if any(startsWith(name,prefixes))
        cdflib.deleteVarRecords(cdfid,i,0,0)
    end
end
end

function f = xact_fields()
% The 46 XACT_HK fields dereferenced by the level-1 block above
f = {'time','seq_ctr','meta_pulse_recv_ms','meta_time_tai_seconds',...
    'meta_refs_position_wrt_ecef1','meta_refs_position_wrt_ecef2','meta_refs_position_wrt_ecef3',...
    'meta_refs_velocity_wrt_ecef1','meta_refs_velocity_wrt_ecef2','meta_refs_velocity_wrt_ecef3',...
    'meta_att_det_q_body_wrt_eci1','meta_att_det_q_body_wrt_eci2','meta_att_det_q_body_wrt_eci3','meta_att_det_q_body_wrt_eci4',...
    'meta_att_det_body_rate1','meta_att_det_body_rate2','meta_att_det_body_rate3',...
    'meta_imu_imu_avg_vector1','meta_imu_imu_avg_vector2','meta_imu_imu_avg_vector3',...
    'meta_mag_mag_vector_body1','meta_mag_mag_vector_body2','meta_mag_mag_vector_body3',...
    'meta_rw_drive_filtered_speed_rpm_161','meta_rw_drive_filtered_speed_rpm_162',...
    'meta_rw_drive_filtered_speed_rpm_163','meta_rw_drive_filtered_speed_rpm_164',...
    'meta_rw_drive_meas_wheel_current1','meta_rw_drive_meas_wheel_current2',...
    'meta_rw_drive_meas_wheel_current3','meta_rw_drive_meas_wheel_current4',...
    'meta_momentum_cycle_avg_magnet_torque1','meta_momentum_cycle_avg_magnet_torque2','meta_momentum_cycle_avg_magnet_torque3',...
    'meta_momentum_duty_cycle1','meta_momentum_duty_cycle2','meta_momentum_duty_cycle3',...
    'meta_momentum_torque_rod_enable1','meta_momentum_torque_rod_enable2','meta_momentum_torque_rod_enable3',...
    'meta_momentum_torque_rod_mode1','meta_momentum_torque_rod_mode2','meta_adcs_momentum_torque_rod_mode3',...
    'meta_att_det_attitude_valid','meta_att_det_meas_att_valid','meta_att_det_meas_rate_valid'};
end

function f = pld_fields()
% The 103 PLD_HK fields dereferenced by the level-1 block above
f = {'time','seq_ctr',...
    'pld_12_vs_v','pld_12v_i','pld_12v_s_i','pld_12v_v','pld_3v3_i','pld_3v3_reg_t','pld_3v3_v',...
    'pld_5v_i','pld_5v_reg_t','pld_5v_st_i','pld_5v_st_v','pld_5v_v',...
    'pld_active_coil_control',...
    'pld_ad9837_1_cfg_state','pld_ad9837_1_ctrl_state','pld_ad9837_2_cfg_state','pld_ad9837_2_ctrl_state',...
    'pld_ad9837_3_cfg_state','pld_ad9837_3_ctrl_state','pld_cdh_comm_state',...
    'pld_coil_0_amp_adj','pld_coil_0_amp_meas','pld_coil_0_amp_set','pld_coil_0_dc_offset',...
    'pld_coil_0_freq_calc','pld_coil_0_freq_set',...
    'pld_coil_1_amp_adj','pld_coil_1_amp_meas','pld_coil_1_amp_set','pld_coil_1_dc_offset',...
    'pld_coil_1_freq_calc','pld_coil_1_freq_set',...
    'pld_coil_2_amp_adj','pld_coil_2_amp_meas','pld_coil_2_amp_set','pld_coil_2_dc_offset',...
    'pld_coil_2_freq_calc','pld_coil_2_freq_set',...
    'pld_firmware_major_rev','pld_firmware_minor_rev','pld_firmware_patch__',...
    'pld_ina3221_1_cfg_state','pld_ina3221_1_read_state','pld_ina3221_2_cfg_state','pld_ina3221_2_read_state',...
    'pld_ina3221_sc1_cfg_state','pld_ina3221_sc1_read_state','pld_ina3221_sc2_cfg_state','pld_ina3221_sc2_read_state',...
    'pld_mcp4131_1_cfg_state','pld_mcp4131_1_ctrl_state','pld_mcp4131_2_cfg_state','pld_mcp4131_2_ctrl_state',...
    'pld_mcp4131_3_cfg_state','pld_mcp4131_3_ctrl_state',...
    'pld_pkt_ack_ct','pld_pkt_nack_ct','pld_pkt_recv_ct',...
    'pld_sc1_sb1_i','pld_sc1_sb1_v','pld_sc1_sb2_i','pld_sc1_sb2_v','pld_sc1_sb3_i','pld_sc1_sb3_v','pld_sc1_t',...
    'pld_sc2_sb1_i','pld_sc2_sb1_v','pld_sc2_sb2_i','pld_sc2_sb2_v','pld_sc2_sb3_i','pld_sc2_sb3_v','pld_sc2_t',...
    'pld_sc_cooldown_timeout','pld_sc_mag_crc_flag','pld_sc_mag_mod16Sequence','pld_sc_mag_state',...
    'pld_sc_read_buffer_overflow','pld_sc_read_buffer_underflow','pld_sc_read_timeout',...
    'pld_sc_reinit_counts','pld_sc_warmup_timeout',...
    'pld_scalar_1_cfg_state','pld_scalar_1_read_state','pld_scalar_2_cfg_state','pld_scalar_2_read_state',...
    'pld_st1_is_trustworthy','pld_st2_is_trustworthy',...
    'pld_st_1_cfg_state','pld_st_1_read_state','pld_st_2_cfg_state','pld_st_2_read_state',...
    'pld_tmp100_1_cfg_state','pld_tmp100_1_read_state','pld_tmp100_2_cfg_state','pld_tmp100_2_read_state',...
    'pld_tmp100_sc1_cfg_state','pld_tmp100_sc1_read_state','pld_tmp100_sc2_cfg_state','pld_tmp100_sc2_read_state',...
    'pld_vrum_t_1','pld_vrum_t_2'};
end
