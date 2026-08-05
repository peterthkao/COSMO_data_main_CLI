function create_COSMO_cdf(path,level,type,scalar,varargin)
% By: Tzu-Hsun Kao
% Last updat: April 9, 2026
% -------------------------------------------------------------------------
% Description: To create COSMO level 0, 1, and 2 CDF data.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% path:     (chr) path for saving the CDF file
% level:    (1x1) 0, 1, and 2 for level 0, 1, and 2
% type:     (1x1) 0 for operational, 1 for test, and 2 for internal data
% scalar:   (1x1) 1 for scalar 1, and 2 for scalar 2
%
% For Level 0:
% varargin{1}:  (struct) scalar_data output from "read_COSMO_science.m"
% varargin{2}:  (struct) coil_data output from "read_COSMO_science.m"
% varargin{3}:  (struct) att_data output from "read_COSMO_science.m"
% varargin{4}:  (struct) PV_data output from "read_COSMO_science.m"
%
% For Level 1:
% varargin{1}:  (struct) T output from "COSMO_data_main.m"
%
% For Level 2:
% varargin{1}:  (struct) out output from "COSMO_data_main.m"
% -------------------------------------------------------------------------

%% filename
QQQ = 'UCB';
switch type
    case 0
        CCCC = 'OPER';
    case 1
        CCCC = 'TEST';
    case 2
        CCCC = 'INTL';
end

switch scalar
    case 1
        R = '1';
    case 2
        R = '2';
end

% For a partial Level 0 (APID 1625 absent) varargin{1} is [] - name the file
% from the PV family instead. Levels 1 and 2 always pass a populated struct.
if ~isempty(varargin{1})
    st = varargin{1}.time(1);
    en = varargin{1}.time(end);
else
    st = varargin{4}.time(1);
    en = varargin{4}.time(end);
end
vvvv = '0001';

filename = [QQQ,'_',CCCC,'_S',R,'_L',num2str(level),'_',char(st,'yyyyMMdd''T''HHmmss'),...
    '_',char(en,'yyyyMMdd''T''HHmmss'),'_',vvvv,'.cdf'];

%% Check if the file exist, if so, remove it
fn = dir([path,filename]);
if ~isempty(fn)
    delete([path,filename])
    warning('One CDF has been removed!')
end
cdfid = cdflib.create([path,filename]);
cleaner = onCleanup(@() cdflib.close(cdfid));

%% Create CDF
% Global attribution
titleAttrNum = cdflib.createAttr(cdfid,'TITLE','global_scope');
cdflib.putAttrEntry(cdfid,titleAttrNum,0,'CDF_CHAR',filename)
authorAttrNum = cdflib.createAttr(cdfid,'CREATOR','global_scope');
cdflib.putAttrEntry(cdfid,authorAttrNum,0,'CDF_CHAR','LAIR at University of Colorado Boulder')

if level == 0
    scalar_data = varargin{1};
    coil_data = varargin{2};
    att_data = varargin{3};
    PV_data = varargin{4};

    % A downlink can carry the science APID (1625 -> scalar/coil/attitude)
    % without the XACT one (520 -> position/velocity), or the reverse. Pass []
    % for an absent family: it is written as a single placeholder record so the
    % 40-variable layout matches a full file, then the record is deleted before
    % close, leaving that family at zero records. cdflib refuses a write of 0
    % records (BAD_REC_COUNT), which is why the placeholder is needed at all.
    drop_sci = isempty(scalar_data);
    drop_pv  = isempty(PV_data);
    if drop_sci && drop_pv
        error('create_COSMO_cdf:noData','Level 0 needs at least one of the science or PV families.')
    end
    % Every record count below is taken as length(field), so the placeholder
    % must be LONGER than the widest variable (F and mag_seq are 100 elements)
    % or length() would return the width instead of the record count.
    nph = 101;
    if drop_sci
        % flagF is the one CDF_UINT1 variable written without a uint8() cast,
        % so the placeholder has to carry the matching type
        scalar_data = struct('time',NaT(nph,1),'pkt_seq',nan(nph,1),'mag_seq',nan(nph,100),...
            'scalar',nan(nph,100),'flagF',zeros(nph,1,'uint8'));
        coil_data = struct('beta',struct('x',nan(nph,1),'y',nan(nph,1),'z',nan(nph,1)),...
            'dc_offsets',struct('x',nan(nph,1),'y',nan(nph,1),'z',nan(nph,1)));
        st_stub = struct('time',NaT(nph,1),'q',nan(nph,4),'rate',nan(nph,3),'nBlob',nan(nph,1),...
            'nCen',nan(nph,1),'nMatch',nan(nph,1),'nRem',nan(nph,1),'confidence',nan(nph,1),...
            'LISApercent',nan(nph,1),'LISAclose',nan(nph,1),'istrust',nan(nph,1),...
            'Stab',nan(nph,1),'solstr',nan(nph,1));
        att_data = struct('ST1',st_stub,'ST2',st_stub,'flagq',nan(nph,1));
    end
    if drop_pv
        PV_data = struct('time',NaT(nph,1),'pkt_seq',nan(nph,1),...
            'ECEF_pos',nan(nph,3),'ECEF_vel',nan(nph,3));
    end

    % Create Level-0 data
    gpstime_ms = (datenum(PV_data.time) - 1) * 86400000;
    scatime_ms = (datenum(scalar_data.time) - 1) * 86400000;
    st1time_ms = (datenum(att_data.ST1.time) - 1) * 86400000;
    st2time_ms = (datenum(att_data.ST2.time) - 1) * 86400000;
    lla = ecef2lla(PV_data.ECEF_pos,'WGS84');                              % input in meters
    rad = vecnorm(PV_data.ECEF_pos,2,2);
    beta = [coil_data.beta.x,coil_data.beta.y,coil_data.beta.z];
    dc = [coil_data.dc_offsets.x,coil_data.dc_offsets.y,coil_data.dc_offsets.z];

    % Create variables
    sci_pkt_id = cdflib.createVar(cdfid,'sci_pkt_seq','CDF_DOUBLE',1,[],true,[]);
    xact_pkt_id = cdflib.createVar(cdfid,'xact_pkt_seq','CDF_DOUBLE',1,[],true,[]);
    mag_pkt_id = cdflib.createVar(cdfid,'mag_seq','CDF_DOUBLE',1,100,true,true);
    gpstime_id = cdflib.createVar(cdfid,'GPS_Time','CDF_EPOCH',1,[],true,[]);
    lat_id = cdflib.createVar(cdfid,'Latitude','CDF_DOUBLE',1,[],true,[]);
    lon_id = cdflib.createVar(cdfid,'Longitude','CDF_DOUBLE',1,[],true,[]);
    rad_id = cdflib.createVar(cdfid,'Radius','CDF_DOUBLE',1,[],true,[]);
    vel_id = cdflib.createVar(cdfid,'Velocity','CDF_DOUBLE',1,3,true,true);
    scatime_id = cdflib.createVar(cdfid,'Scalar_Time','CDF_EPOCH',1,[],true,[]);
    F_id = cdflib.createVar(cdfid,'F','CDF_DOUBLE',1,100,true,true);
    flag_F_id = cdflib.createVar(cdfid,'Flag_F','CDF_UINT1',1,[],true,[]);
    beta_id = cdflib.createVar(cdfid,'Beta','CDF_DOUBLE',1,3,true,true);
    dc_id = cdflib.createVar(cdfid,'DC_offset','CDF_DOUBLE',1,3,true,true);
    ST1_time_id = cdflib.createVar(cdfid,'ST1_Time','CDF_EPOCH',1,[],true,[]);
    ST2_time_id = cdflib.createVar(cdfid,'ST2_Time','CDF_EPOCH',1,[],true,[]);
    ST1_q_id = cdflib.createVar(cdfid,'ST1_q','CDF_DOUBLE',1,4,true,true);
    ST2_q_id = cdflib.createVar(cdfid,'ST2_q','CDF_DOUBLE',1,4,true,true);
    ST1_rate_id = cdflib.createVar(cdfid,'ST1_rate','CDF_DOUBLE',1,3,true,true);
    ST2_rate_id = cdflib.createVar(cdfid,'ST2_rate','CDF_DOUBLE',1,3,true,true);
    ST1_nBlob_id = cdflib.createVar(cdfid,'ST1_nBlob','CDF_DOUBLE',1,[],true,[]);
    ST2_nBlob_id = cdflib.createVar(cdfid,'ST2_nBlob','CDF_DOUBLE',1,[],true,[]);
    ST1_nCen_id = cdflib.createVar(cdfid,'ST1_nCen','CDF_DOUBLE',1,[],true,[]);
    ST2_nCen_id = cdflib.createVar(cdfid,'ST2_nCen','CDF_DOUBLE',1,[],true,[]);
    ST1_nMatch_id = cdflib.createVar(cdfid,'ST1_nMatch','CDF_DOUBLE',1,[],true,[]);
    ST2_nMatch_id = cdflib.createVar(cdfid,'ST2_nMatch','CDF_DOUBLE',1,[],true,[]);
    ST1_nRem_id = cdflib.createVar(cdfid,'ST1_nRem','CDF_DOUBLE',1,[],true,[]);
    ST2_nRem_id = cdflib.createVar(cdfid,'ST2_nRem','CDF_DOUBLE',1,[],true,[]);
    ST1_confidence_id = cdflib.createVar(cdfid,'ST1_confidence','CDF_DOUBLE',1,[],true,[]);
    ST2_confidence_id = cdflib.createVar(cdfid,'ST2_confidence','CDF_DOUBLE',1,[],true,[]);
    ST1_LISApercent_id = cdflib.createVar(cdfid,'ST1_LISApercent','CDF_DOUBLE',1,[],true,[]);
    ST2_LISApercent_id = cdflib.createVar(cdfid,'ST2_LISApercent','CDF_DOUBLE',1,[],true,[]);
    ST1_LISAclose_id = cdflib.createVar(cdfid,'ST1_LISAclose','CDF_DOUBLE',1,[],true,[]);
    ST2_LISAclose_id = cdflib.createVar(cdfid,'ST2_LISAclose','CDF_DOUBLE',1,[],true,[]);
    ST1_istrust_id = cdflib.createVar(cdfid,'ST1_istrust','CDF_UINT1',1,[],true,[]);
    ST2_istrust_id = cdflib.createVar(cdfid,'ST2_istrust','CDF_UINT1',1,[],true,[]);
    ST1_Stab_id = cdflib.createVar(cdfid,'ST1_Stab','CDF_DOUBLE',1,[],true,[]);
    ST2_Stab_id = cdflib.createVar(cdfid,'ST2_Stab','CDF_DOUBLE',1,[],true,[]);
    ST1_solstr_id = cdflib.createVar(cdfid,'ST1_solstr','CDF_UINT1',1,[],true,[]);
    ST2_solstr_id = cdflib.createVar(cdfid,'ST2_solstr','CDF_UINT1',1,[],true,[]);
    flag_q_id = cdflib.createVar(cdfid,'Flag_q','CDF_UINT1',1,[],true,[]);

    cdflib.hyperPutVarData(cdfid,sci_pkt_id,[0 length(scalar_data.pkt_seq) 1],{0 1 1},scalar_data.pkt_seq)
    cdflib.hyperPutVarData(cdfid,xact_pkt_id,[0 length(PV_data.pkt_seq) 1],{0 1 1},PV_data.pkt_seq)
    cdflib.hyperPutVarData(cdfid,mag_pkt_id,[0 length(scalar_data.mag_seq) 1],{0 100 1},scalar_data.mag_seq')
    cdflib.hyperPutVarData(cdfid,gpstime_id,[0 length(gpstime_ms) 1],{0 1 1},gpstime_ms)
    cdflib.hyperPutVarData(cdfid,lat_id,[0 length(lla(:,1)) 1],{0 1 1},lla(:,1))
    cdflib.hyperPutVarData(cdfid,lon_id,[0 length(lla(:,2)) 1],{0 1 1},lla(:,2))
    cdflib.hyperPutVarData(cdfid,rad_id,[0 length(rad) 1],{0 1 1},rad)
    cdflib.hyperPutVarData(cdfid,vel_id,[0 length(PV_data.ECEF_vel) 1],{0 3 1},PV_data.ECEF_vel')
    cdflib.hyperPutVarData(cdfid,scatime_id,[0 length(scatime_ms) 1],{0 1 1},scatime_ms)
    cdflib.hyperPutVarData(cdfid,F_id,[0 length(scalar_data.scalar) 1],{0 100 1},scalar_data.scalar')
    cdflib.hyperPutVarData(cdfid,flag_F_id,[0 length(scalar_data.flagF) 1],{0 1 1},scalar_data.flagF)
    cdflib.hyperPutVarData(cdfid,beta_id,[0 length(beta) 1],{0 3 1},beta')
    cdflib.hyperPutVarData(cdfid,dc_id,[0 length(dc) 1],{0 3 1},dc')
    cdflib.hyperPutVarData(cdfid,ST1_time_id,[0 length(st1time_ms) 1],{0 1 1},st1time_ms)
    cdflib.hyperPutVarData(cdfid,ST2_time_id,[0 length(st1time_ms) 1],{0 1 1},st2time_ms)
    cdflib.hyperPutVarData(cdfid,ST1_q_id,[0 length(att_data.ST1.q) 1],{0 4 1},att_data.ST1.q')
    cdflib.hyperPutVarData(cdfid,ST2_q_id,[0 length(att_data.ST2.q) 1],{0 4 1},att_data.ST2.q')
    cdflib.hyperPutVarData(cdfid,ST1_rate_id,[0 length(att_data.ST1.rate) 1],{0 3 1},att_data.ST1.rate')
    cdflib.hyperPutVarData(cdfid,ST2_rate_id,[0 length(att_data.ST2.rate) 1],{0 3 1},att_data.ST2.rate')
    cdflib.hyperPutVarData(cdfid,ST1_nBlob_id,[0 length(att_data.ST1.nBlob) 1],{0 1 1},att_data.ST1.nBlob)
    cdflib.hyperPutVarData(cdfid,ST2_nBlob_id,[0 length(att_data.ST2.nBlob) 1],{0 1 1},att_data.ST2.nBlob)
    cdflib.hyperPutVarData(cdfid,ST1_nCen_id,[0 length(att_data.ST1.nCen) 1],{0 1 1},att_data.ST1.nCen)
    cdflib.hyperPutVarData(cdfid,ST2_nCen_id,[0 length(att_data.ST2.nCen) 1],{0 1 1},att_data.ST2.nCen)
    cdflib.hyperPutVarData(cdfid,ST1_nMatch_id,[0 length(att_data.ST1.nMatch) 1],{0 1 1},att_data.ST1.nMatch)
    cdflib.hyperPutVarData(cdfid,ST2_nMatch_id,[0 length(att_data.ST2.nMatch) 1],{0 1 1},att_data.ST2.nMatch)
    cdflib.hyperPutVarData(cdfid,ST1_nRem_id,[0 length(att_data.ST1.nRem) 1],{0 1 1},att_data.ST1.nRem)
    cdflib.hyperPutVarData(cdfid,ST2_nRem_id,[0 length(att_data.ST2.nRem) 1],{0 1 1},att_data.ST2.nRem)
    cdflib.hyperPutVarData(cdfid,ST1_confidence_id,[0 length(att_data.ST1.confidence) 1],{0 1 1},att_data.ST1.confidence)
    cdflib.hyperPutVarData(cdfid,ST2_confidence_id,[0 length(att_data.ST2.confidence) 1],{0 1 1},att_data.ST2.confidence)
    cdflib.hyperPutVarData(cdfid,ST1_LISApercent_id,[0 length(att_data.ST1.LISApercent) 1],{0 1 1},att_data.ST1.LISApercent)
    cdflib.hyperPutVarData(cdfid,ST2_LISApercent_id,[0 length(att_data.ST2.LISApercent) 1],{0 1 1},att_data.ST2.LISApercent)
    cdflib.hyperPutVarData(cdfid,ST1_LISAclose_id,[0 length(att_data.ST1.LISAclose) 1],{0 1 1},att_data.ST1.LISAclose)
    cdflib.hyperPutVarData(cdfid,ST2_LISAclose_id,[0 length(att_data.ST2.LISAclose) 1],{0 1 1},att_data.ST2.LISAclose)
    cdflib.hyperPutVarData(cdfid,ST1_istrust_id,[0 length(att_data.ST1.istrust) 1],{0 1 1},uint8(att_data.ST1.istrust))
    cdflib.hyperPutVarData(cdfid,ST2_istrust_id,[0 length(att_data.ST2.istrust) 1],{0 1 1},uint8(att_data.ST2.istrust))
    cdflib.hyperPutVarData(cdfid,ST1_Stab_id,[0 length(att_data.ST1.Stab) 1],{0 1 1},att_data.ST1.Stab)
    cdflib.hyperPutVarData(cdfid,ST2_Stab_id,[0 length(att_data.ST2.Stab) 1],{0 1 1},att_data.ST2.Stab)
    cdflib.hyperPutVarData(cdfid,ST1_solstr_id,[0 length(att_data.ST1.solstr) 1],{0 1 1},uint8(att_data.ST1.solstr))
    cdflib.hyperPutVarData(cdfid,ST2_solstr_id,[0 length(att_data.ST2.solstr) 1],{0 1 1},uint8(att_data.ST2.solstr))
    cdflib.hyperPutVarData(cdfid,flag_q_id,[0 length(att_data.flagq) 1],{0 1 1},uint8(att_data.flagq))

    % Variable attribution
    desAttrNum = cdflib.createAttr(cdfid,'DESCRIPTION','variable_scope');
    unitsAttrNum = cdflib.createAttr(cdfid,'UNITS','variable_scope');

    cdflib.putAttrEntry(cdfid,desAttrNum,sci_pkt_id,'CDF_CHAR','Packet sequence number of the science packet')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,sci_pkt_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,xact_pkt_id,'CDF_CHAR','Packet sequence number of the XACT meta packet')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,xact_pkt_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,mag_pkt_id,'CDF_CHAR','Magnetic data packet sequence number')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,mag_pkt_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,gpstime_id,'CDF_CHAR','Time of observation of the GPS')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,gpstime_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,lat_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric latitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lat_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,lon_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric longitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lon_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,rad_id,'CDF_CHAR','Position of magnetic sensor in ITRF – radius')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,rad_id,'CDF_CHAR','m')

    cdflib.putAttrEntry(cdfid,desAttrNum,vel_id,'CDF_CHAR','Velocity of magnetic sensor in ECEF')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,vel_id,'CDF_CHAR','m/s')

    cdflib.putAttrEntry(cdfid,desAttrNum,scatime_id,'CDF_CHAR','Time of observation of the scalar')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,scatime_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,F_id,'CDF_CHAR','Magnetic field intensity')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,F_id,'CDF_CHAR','nT')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_F_id,'CDF_CHAR','Flags characterizing the magnetic field intensity measurement (F); 0 indicates nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_F_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,beta_id,'CDF_CHAR','Coil current amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,beta_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,dc_id,'CDF_CHAR','DC offset of the coil current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,dc_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_time_id,'CDF_CHAR','Time of capture of the ST1 quaternion')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_time_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_time_id,'CDF_CHAR','Time of capture of the ST2 quaternion')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_time_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_q_id,'CDF_CHAR','Quaternions from Star Tracker 1, transformation from ECI to ST1 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_q_id,'CDF_CHAR','Quaternions from Star Tracker 2, transformation from ECI to ST2 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_rate_id,'CDF_CHAR','Estimated rate retrieved from quaternions')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_rate_id,'CDF_CHAR','deg/s')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_rate_id,'CDF_CHAR','Estimated rate retrieved from quaternions')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_rate_id,'CDF_CHAR','deg/s')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_nBlob_id,'CDF_CHAR','Number of blobs detected by the blob algorithm')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_nBlob_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_nBlob_id,'CDF_CHAR','Number of blobs detected by the blob algorithm')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_nBlob_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_nCen_id,'CDF_CHAR','Number of blobs recognized as centroids by the centroiding algorithm')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_nCen_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_nCen_id,'CDF_CHAR','Number of blobs recognized as centroids by the centroiding algorithm')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_nCen_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_nMatch_id,'CDF_CHAR','Number of stars of the camera matched to a database image')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_nMatch_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_nMatch_id,'CDF_CHAR','Number of stars of the camera matched to a database image')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_nMatch_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_nRem_id,'CDF_CHAR','Number of stars removed/ignored by the tracking algorithm in the solution')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_nRem_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_nRem_id,'CDF_CHAR','Number of stars removed/ignored by the tracking algorithm in the solution')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_nRem_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_confidence_id,'CDF_CHAR','Confidence in the tracking solution. A lower value indicates more confidence in the solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_confidence_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_confidence_id,'CDF_CHAR','Confidence in the tracking solution. A lower value indicates more confidence in the solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_confidence_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_LISApercent_id,'CDF_CHAR','Percentage of stars identified as close in the comparison of the camera and database image of the LISA solution. A higher value indicates more confidence in the LISA solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_LISApercent_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_LISApercent_id,'CDF_CHAR','Percentage of stars identified as close in the comparison of the camera and database image of the LISA solution. A higher value indicates more confidence in the LISA solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_LISApercent_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_LISAclose_id,'CDF_CHAR','Number of stars identified as close in the comparison of the camera and database image of the LISA solution. A higher value indicates more confidence in the LISA solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_LISAclose_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_LISAclose_id,'CDF_CHAR','Number of stars identified as close in the comparison of the camera and database image of the LISA solution. A higher value indicates more confidence in the LISA solution.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_LISAclose_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_istrust_id,'CDF_CHAR','Indicates if the obtained solution is trustworthy; 1 is trustworthy.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_istrust_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_istrust_id,'CDF_CHAR','Indicates if the obtained solution is trustworthy; 1 is trustworthy.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_istrust_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_Stab_id,'CDF_CHAR','The number of consecutive validated and stable solutions')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_Stab_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_Stab_id,'CDF_CHAR','The number of consecutive validated and stable solutions')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_Stab_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_solstr_id,'CDF_CHAR','Algorithm path that was followed to determine the attitude; 5 means stay in the tracking mode.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_solstr_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_solstr_id,'CDF_CHAR','Algorithm path that was followed to determine the attitude; 5 means stay in the tracking mode.')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_solstr_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_q_id,'CDF_CHAR','Flags characterizing attitude information; 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_q_id,'CDF_CHAR','-')

    % Drop the placeholder record so the absent family reads back as zero
    % records rather than one row of invented values
    pv_vars = {'xact_pkt_seq','GPS_Time','Latitude','Longitude','Radius','Velocity'};
    if drop_pv
        drop_records(cdfid,@(n) any(strcmp(n,pv_vars)),nph)
    end
    if drop_sci
        drop_records(cdfid,@(n) ~any(strcmp(n,pv_vars)),nph)
    end

    cdflib.close(cdfid)

elseif level == 1
    T = varargin{1};

    % Create Level-1 data
    time_ms = (datenum(T.time) - 1) * 86400000;

    % Create variables
    time_id = cdflib.createVar(cdfid,'Time','CDF_EPOCH',1,[],true,[]);
    lat_id = cdflib.createVar(cdfid,'Latitude','CDF_DOUBLE',1,[],true,[]);
    lon_id = cdflib.createVar(cdfid,'Longitude','CDF_DOUBLE',1,[],true,[]);
    rad_id = cdflib.createVar(cdfid,'Radius','CDF_DOUBLE',1,[],true,[]);
    vel_id = cdflib.createVar(cdfid,'Velocity','CDF_DOUBLE',1,3,true,true);
    F_id = cdflib.createVar(cdfid,'F','CDF_DOUBLE',1,100,true,true);
    flag_F_id = cdflib.createVar(cdfid,'Flag_F','CDF_UINT1',1,[],true,[]);
    beta_id = cdflib.createVar(cdfid,'Beta','CDF_DOUBLE',1,3,true,true);
    dc_id = cdflib.createVar(cdfid,'DC_offset','CDF_DOUBLE',1,3,true,true);
    ST1_q_id = cdflib.createVar(cdfid,'ST1_q','CDF_DOUBLE',1,4,true,true);
    ST2_q_id = cdflib.createVar(cdfid,'ST2_q','CDF_DOUBLE',1,4,true,true);
    flag_q_id = cdflib.createVar(cdfid,'Flag_q','CDF_UINT1',1,[],true,[]);

    cdflib.hyperPutVarData(cdfid,time_id,[0 length(time_ms) 1],{0 1 1},time_ms)
    cdflib.hyperPutVarData(cdfid,lat_id,[0 length(T.Latitude) 1],{0 1 1},T.Latitude)
    cdflib.hyperPutVarData(cdfid,lon_id,[0 length(T.Longitude) 1],{0 1 1},T.Longitude)
    cdflib.hyperPutVarData(cdfid,rad_id,[0 length(T.Radius) 1],{0 1 1},T.Radius)
    cdflib.hyperPutVarData(cdfid,vel_id,[0 length(T.Velocity) 1],{0 3 1},T.Velocity')
    cdflib.hyperPutVarData(cdfid,F_id,[0 length(T.F) 1],{0 100 1},T.F')
    cdflib.hyperPutVarData(cdfid,flag_F_id,[0 length(T.Flag_F) 1],{0 1 1},uint8(T.Flag_F))
    cdflib.hyperPutVarData(cdfid,beta_id,[0 length(T.Beta) 1],{0 3 1},T.Beta')
    cdflib.hyperPutVarData(cdfid,dc_id,[0 length(T.DC_offset) 1],{0 3 1},T.DC_offset')
    cdflib.hyperPutVarData(cdfid,ST1_q_id,[0 length(T.ST1_q) 1],{0 4 1},T.ST1_q')
    cdflib.hyperPutVarData(cdfid,ST2_q_id,[0 length(T.ST2_q) 1],{0 4 1},T.ST2_q')
    cdflib.hyperPutVarData(cdfid,flag_q_id,[0 length(T.Flag_q) 1],{0 1 1},uint8(T.Flag_q))
    
    % Variable attribution
    desAttrNum = cdflib.createAttr(cdfid,'DESCRIPTION','variable_scope');
    unitsAttrNum = cdflib.createAttr(cdfid,'UNITS','variable_scope');

    cdflib.putAttrEntry(cdfid,desAttrNum,time_id,'CDF_CHAR','Time of observation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,time_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,lat_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric latitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lat_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,lon_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric longitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lon_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,rad_id,'CDF_CHAR','Position of magnetic sensor in ITRF – radius')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,rad_id,'CDF_CHAR','m')

    cdflib.putAttrEntry(cdfid,desAttrNum,vel_id,'CDF_CHAR','Velocity of magnetic sensor in ECEF')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,vel_id,'CDF_CHAR','m/s')

    cdflib.putAttrEntry(cdfid,desAttrNum,F_id,'CDF_CHAR','Magnetic field intensity')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,F_id,'CDF_CHAR','nT')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_F_id,'CDF_CHAR','Flags characterizing the magnetic field intensity measurement (F); 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_F_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,beta_id,'CDF_CHAR','Coil current amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,beta_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,dc_id,'CDF_CHAR','DC offset of the coil current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,dc_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_q_id,'CDF_CHAR','Quaternions from Star Tracker 1, transformation from ECI to ST1 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_q_id,'CDF_CHAR','Quaternions from Star Tracker 2, transformation from ECI to ST2 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_q_id,'CDF_CHAR','Flags characterizing attitude information; 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_q_id,'CDF_CHAR','-')

    cdflib.close(cdfid)

elseif level == 2
    out = varargin{1};

    % Create Level-2 data
    time_ms = (datenum(out.time) - 1) * 86400000;

    % Create variables
    time_id = cdflib.createVar(cdfid,'Time','CDF_EPOCH',1,[],true,[]);
    lat_id = cdflib.createVar(cdfid,'Latitude','CDF_DOUBLE',1,[],true,[]);
    lon_id = cdflib.createVar(cdfid,'Longitude','CDF_DOUBLE',1,[],true,[]);
    rad_id = cdflib.createVar(cdfid,'Radius','CDF_DOUBLE',1,[],true,[]);
    vel_id = cdflib.createVar(cdfid,'Velocity','CDF_DOUBLE',1,3,true,true);
    F_id = cdflib.createVar(cdfid,'F','CDF_DOUBLE',1,[],true,[]);
    beta_id = cdflib.createVar(cdfid,'Beta','CDF_DOUBLE',1,3,true,true);
    dc_id = cdflib.createVar(cdfid,'DC_offset','CDF_DOUBLE',1,3,true,true);
    ST1_q_id = cdflib.createVar(cdfid,'ST1_q','CDF_DOUBLE',1,4,true,true);
    ST2_q_id = cdflib.createVar(cdfid,'ST2_q','CDF_DOUBLE',1,4,true,true);
    B_VIF_id = cdflib.createVar(cdfid,'B_VIF','CDF_DOUBLE',1,3,true,true);
    B_NEC_id = cdflib.createVar(cdfid,'B_NEC','CDF_DOUBLE',1,3,true,true);
    q_VIF_ECI_id  = cdflib.createVar(cdfid,'q_VIF_ECI','CDF_DOUBLE',1,4,true,true);
    q_VIF_ECEF_id = cdflib.createVar(cdfid,'q_VIF_ECEF','CDF_DOUBLE',1,4,true,true);
    q_VIF_NEC_id  = cdflib.createVar(cdfid,'q_VIF_NEC','CDF_DOUBLE',1,4,true,true);
    Bore_angle_id = cdflib.createVar(cdfid,'Bore_angle','CDF_DOUBLE',1,[],true,[]);
    flag_F_id = cdflib.createVar(cdfid,'Flag_F','CDF_UINT1',1,[],true,[]);
    flag_B_id = cdflib.createVar(cdfid,'Flag_B','CDF_UINT1',1,[],true,[]);
    flag_q_id = cdflib.createVar(cdfid,'Flag_q','CDF_UINT1',1,[],true,[]);

    cdflib.hyperPutVarData(cdfid,time_id,[0 length(time_ms) 1],{0 1 1},time_ms)
    cdflib.hyperPutVarData(cdfid,lat_id,[0 length(out.Latitude) 1],{0 1 1},out.Latitude)
    cdflib.hyperPutVarData(cdfid,lon_id,[0 length(out.Longitude) 1],{0 1 1},out.Longitude)
    cdflib.hyperPutVarData(cdfid,rad_id,[0 length(out.Radius) 1],{0 1 1},out.Radius)
    cdflib.hyperPutVarData(cdfid,vel_id,[0 length(out.Velocity) 1],{0 3 1},out.Velocity)
    cdflib.hyperPutVarData(cdfid,F_id,[0 length(out.F) 1],{0 1 1},out.F)
    cdflib.hyperPutVarData(cdfid,beta_id,[0 length(out.Beta) 1],{0 3 1},out.Beta)
    cdflib.hyperPutVarData(cdfid,dc_id,[0 length(out.DC_offset) 1],{0 3 1},out.DC_offset)
    cdflib.hyperPutVarData(cdfid,ST1_q_id,[0 length(out.ST1_q) 1],{0 4 1},out.ST1_q)
    cdflib.hyperPutVarData(cdfid,ST2_q_id,[0 length(out.ST2_q) 1],{0 4 1},out.ST2_q)
    cdflib.hyperPutVarData(cdfid,B_VIF_id,[0 length(out.B_VIF) 1],{0 3 1},out.B_VIF)
    cdflib.hyperPutVarData(cdfid,B_NEC_id,[0 length(out.B_NEC) 1],{0 3 1},out.B_NEC)
    cdflib.hyperPutVarData(cdfid,q_VIF_ECI_id,[0 length(out.q_VIF_ECI) 1],{0 4 1},out.q_VIF_ECI)
    cdflib.hyperPutVarData(cdfid,q_VIF_ECEF_id,[0 length(out.q_VIF_ECEF) 1],{0 4 1},out.q_VIF_ECEF)
    cdflib.hyperPutVarData(cdfid,q_VIF_NEC_id, [0 length(out.q_VIF_NEC)  1],{0 4 1},out.q_VIF_NEC)
    cdflib.hyperPutVarData(cdfid,Bore_angle_id,[0 length(out.bore_angle) 1],{0 1 1},out.bore_angle)
    cdflib.hyperPutVarData(cdfid,flag_F_id,[0 length(out.Flag_F) 1],{0 1 1},out.Flag_F)
    cdflib.hyperPutVarData(cdfid,flag_B_id,[0 length(out.Flag_F) 1],{0 1 1},out.Flag_F)
    cdflib.hyperPutVarData(cdfid,flag_q_id,[0 length(out.Flag_q) 1],{0 1 1},out.Flag_q)
    
    % Variable attribution
    desAttrNum = cdflib.createAttr(cdfid,'DESCRIPTION','variable_scope');
    unitsAttrNum = cdflib.createAttr(cdfid,'UNITS','variable_scope');

    cdflib.putAttrEntry(cdfid,desAttrNum,time_id,'CDF_CHAR','Time of observation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,time_id,'CDF_CHAR','UTC')

    cdflib.putAttrEntry(cdfid,desAttrNum,lat_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric latitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lat_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,lon_id,'CDF_CHAR','Position of magnetic sensor in ITRF – geocentric longitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,lon_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,rad_id,'CDF_CHAR','Position of magnetic sensor in ITRF – radius')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,rad_id,'CDF_CHAR','m')

    cdflib.putAttrEntry(cdfid,desAttrNum,vel_id,'CDF_CHAR','Velocity of magnetic sensor in ECEF')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,vel_id,'CDF_CHAR','m/s')

    cdflib.putAttrEntry(cdfid,desAttrNum,F_id,'CDF_CHAR','Magnetic field intensity')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,F_id,'CDF_CHAR','nT')

    cdflib.putAttrEntry(cdfid,desAttrNum,beta_id,'CDF_CHAR','Coil current amplitude')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,beta_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,dc_id,'CDF_CHAR','DC offset of the coil current')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,dc_id,'CDF_CHAR','mA')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST1_q_id,'CDF_CHAR','Quaternions from Star Tracker 1, transformation from ECI to ST1 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST1_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,ST2_q_id,'CDF_CHAR','Quaternions from Star Tracker 2, transformation from ECI to ST2 frame (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,ST2_q_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,B_VIF_id,'CDF_CHAR','Magnetic field vector, VIF frame')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,B_VIF_id,'CDF_CHAR','nT')

    cdflib.putAttrEntry(cdfid,desAttrNum,B_NEC_id,'CDF_CHAR','Magnetic field vector, NEC frame')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,B_NEC_id,'CDF_CHAR','nT')

    cdflib.putAttrEntry(cdfid,desAttrNum,q_VIF_ECI_id,'CDF_CHAR','SLERP-blended quaternion (ST1+ST2), transformation from ECI to VIF (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,q_VIF_ECI_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,q_VIF_ECEF_id,'CDF_CHAR','Blended quaternion, transformation from VIF to ECEF (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,q_VIF_ECEF_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,q_VIF_NEC_id,'CDF_CHAR','Blended quaternion, transformation from VIF to NEC (scalar-first [w x y z])')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,q_VIF_NEC_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,Bore_angle_id,'CDF_CHAR','Boresight angle between the two star trackers')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,Bore_angle_id,'CDF_CHAR','deg')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_F_id,'CDF_CHAR','Flags characterizing the magnetic field intensity measurement (F); 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_F_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_B_id,'CDF_CHAR','Flags characterizing the magnetic field vector measurement (B_VIF,B_NEC); 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_B_id,'CDF_CHAR','-')

    cdflib.putAttrEntry(cdfid,desAttrNum,flag_q_id,'CDF_CHAR','Flags characterizing attitude information; 0 should indicate nominal operation')
    cdflib.putAttrEntry(cdfid,unitsAttrNum,flag_q_id,'CDF_CHAR','-')

    cdflib.close(cdfid)
end
end

function drop_records(cdfid,selector,nph)
% Remove the nph placeholder records from every variable whose name satisfies
% selector, leaving that family at zero records.
info = cdflib.inquire(cdfid);
for i = 0:info.numVars-1
    if selector(cdflib.getVarName(cdfid,i))
        cdflib.deleteVarRecords(cdfid,i,0,nph-1)
    end
end
end