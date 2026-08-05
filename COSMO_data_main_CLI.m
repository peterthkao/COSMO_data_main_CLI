function status = COSMO_data_main_CLI(varargin)
%COSMO_DATA_MAIN_CLI  Raw CSV -> Level 0 + HK conversion, runnable from the CLI.
%
%   Converts COSMO CubeSat raw downlink CSVs (APIDs 1625, 520, 519) into a
%   Level 0 science CDF and an HK CDF, driven entirely by arguments so no
%   script editing is needed.
%
%   REQUIRED:
%     dataPath   Folder that CONTAINS the COSMO_* downlink folders (not a
%                downlink folder itself).
%
%   Usage:
%     matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV')"
%     matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','folder','COSMO_20260801T033702')"
%     matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','folder','COSMO*')"
%     matlab -batch "COSMO_data_main_CLI('dataPath','D:\COSMO\Raw CSV','dryRun',true)"
%
%   OPTIONS (name-value):
%     folder      Downlink folder pattern. Default: the newest COSMO_* folder,
%                 ranked by the timestamp in the NAME (folder mtimes are not
%                 reliable - cloud sync rewrites them out of order). A name
%                 given without a trailing '*' gets one appended: dir on an
%                 exact folder name lists that folder's CONTENTS, not the
%                 folder, and the run then dies inside read_CCSDS.
%     level0Path  Level 0 output dir. Default <this folder>\output\Level 0
%     hkPath      HK output dir.      Default <this folder>\output\HK
%                 Both are created if missing.
%     toolboxPath Default <this folder>\toolbox - normally leave alone.
%     makeL0Cdf   Write the Level 0 CDF (default true). These are large,
%                 roughly 100-250 MB for a full pass.
%     makeHK      Write the HK CDF (default true).
%     dryRun      List the folders that would be processed, write nothing.
%
%   PARTIAL DOWNLINKS
%   A contact does not always carry all three packets, and the two products
%   need different subsets:
%     Level 0  <- APID 1625 (science) and/or 520 (position/velocity)
%     HK       <- APID 519  (payload) and/or 520 (XACT)
%   Whichever is available is written. A family that is absent becomes
%   zero-record variables in the CDF, so the file keeps its full variable
%   layout (40 for L0, 149 for HK) without inventing any values. A folder
%   with none of the three APIDs is skipped.
%
%   Note: a Level 0 file missing APID 520 has no GPS_Time, and the Level 1
%   stage requires both GPS_Time and Scalar_Time, so such a file is for
%   direct reading only - it will not contribute to Level 1.
%
%   RETURNS
%   0 if every matched folder produced at least one file, 1 if any was
%   skipped or failed. Called with no output (the -batch case) it throws on
%   an incomplete run so the MATLAB process exits non-zero. When skips are
%   expected, capture the value instead: s = COSMO_data_main_CLI(...).
%
%   REQUIREMENTS
%   MATLAB R2019b or newer (developed and tested on R2024a) and the Aerospace
%   Toolbox (create_COSMO_cdf calls ecef2lla). Writing uses MATLAB's built-in
%   cdflib - no external CDF library is needed.
%
%   Level 1 / HK daily / Level 2 are not covered here.

p = inputParser;
addParameter(p,'dataPath','',@(x) ischar(x) || isstring(x));
addParameter(p,'folder','',@(x) ischar(x) || isstring(x));
addParameter(p,'level0Path','',@(x) ischar(x) || isstring(x));
addParameter(p,'hkPath','',@(x) ischar(x) || isstring(x));
addParameter(p,'toolboxPath','',@(x) ischar(x) || isstring(x));
addParameter(p,'makeL0Cdf',true,@(x) islogical(x) || isnumeric(x));
addParameter(p,'makeHK',true,@(x) islogical(x) || isnumeric(x));
addParameter(p,'dryRun',false,@(x) islogical(x) || isnumeric(x));
parse(p,varargin{:});
opt = p.Results;

% Everything defaults relative to this file so the package runs from wherever
% it is unpacked
repo_path = fileparts(mfilename('fullpath'));

folder      = char(opt.folder);
make_l0_cdf = logical(opt.makeL0Cdf);
make_hk     = logical(opt.makeHK);
dry_run     = logical(opt.dryRun);

data_path = char(opt.dataPath);
if isempty(data_path)
    error('COSMO_data_main_CLI:noDataPath',...
        ['dataPath is required. Give the folder that CONTAINS the COSMO_* downlink\n',...
         'folders, e.g. COSMO_data_main_CLI(''dataPath'',''D:\\COSMO\\Raw CSV'')']);
end
data_path = ensure_trailing_sep(data_path);

level0_path = char(opt.level0Path);
if isempty(level0_path), level0_path = fullfile(repo_path,'output','Level 0'); end
level0_path = ensure_trailing_sep(level0_path);

hk_path = char(opt.hkPath);
if isempty(hk_path), hk_path = fullfile(repo_path,'output','HK'); end
hk_path = ensure_trailing_sep(hk_path);

toolbox_path = char(opt.toolboxPath);
if isempty(toolbox_path), toolbox_path = fullfile(repo_path,'toolbox'); end

t_start = tic;

%% Path setup
if ~isfolder(toolbox_path)
    error('COSMO_data_main_CLI:noToolbox','Toolbox path does not exist: %s',toolbox_path)
end
addpath(toolbox_path)
addpath(repo_path)

if ~isfolder(data_path)
    error('COSMO_data_main_CLI:badDataPath','Raw CSV path does not exist: %s',data_path)
end
if ~license('test','Aerospace_Toolbox') || isempty(which('ecef2lla'))
    error('COSMO_data_main_CLI:noAerospace',...
        ['The Aerospace Toolbox is required (create_COSMO_cdf calls ecef2lla) ',...
         'but was not found on this machine.']);
end
if ~make_l0_cdf && ~make_hk
    error('COSMO_data_main_CLI:nothingToDo','makeL0Cdf and makeHK are both false - nothing to write.')
end

% Output directories are created rather than demanded, so a fresh checkout
% works with no setup
for d = {level0_path,hk_path}
    if ~isfolder(d{1})
        [ok,msg] = mkdir(d{1});
        if ~ok
            error('COSMO_data_main_CLI:mkdirFailed','Could not create %s: %s',d{1},msg)
        end
        fprintf('Created output directory %s\n',d{1});
    end
end

fprintf('Raw CSV  : %s\nLevel 0  : %s\nHK       : %s\n',data_path,level0_path,hk_path);

%% Resolve which downlink folder(s) to process
if isempty(folder)
    fo = dir([data_path,'COSMO*']);
    fo = fo([fo.isdir]);
    fo = fo(~ismember({fo.name},{'.','..'}));
    if isempty(fo)
        error('COSMO_data_main_CLI:noFolders','No COSMO* downlink folders under %s',data_path)
    end
    % Rank by the timestamp in the name, not by folder mtime: cloud sync
    % rewrites mtimes out of order, and COSMO* also matches non-downlink
    % folders that have no timestamp at all
    stamp = regexp({fo.name},'^COSMO_(\d{8}T\d{6})$','tokens','once');
    has_stamp = ~cellfun(@isempty,stamp);
    if any(has_stamp)
        fo = fo(has_stamp);
        stamp = string(cellfun(@(c) c{1},stamp(has_stamp),'UniformOutput',false));
        [~,newest] = max(datetime(stamp,'InputFormat','yyyyMMdd''T''HHmmss'));
    else
        [~,newest] = max([fo.datenum]);                                    % No named downlinks - fall back to mtime
    end
    fo = fo(newest);
    fprintf('No folder given - processing the newest downlink: %s\n',fo(1).name);
else
    pattern = folder;
    if ~contains(pattern,'*')
        % dir on an exact folder name lists its contents, not the folder
        pattern = [pattern,'*'];
    end
    fo = dir([data_path,pattern]);
    fo = fo([fo.isdir]);
    fo = fo(~ismember({fo.name},{'.','..'}));
    if isempty(fo)
        error('COSMO_data_main_CLI:noMatch','No downlink folder matches "%s" under %s',pattern,data_path)
    end
end

fprintf('Level 0/HK: %d downlink folder(s) matched\n',length(fo));
for k = 1:length(fo)
    fprintf('  %s\n',fo(k).name);
end

if dry_run
    fprintf('Dry run - nothing written.\n');
    status = 0;
    if nargout == 0
        clear status
    end
    return
end

%% Create Level 0 / HK data
ID = [1625,520,519];
n_ok = 0; n_skip = 0; n_fail = 0;

for k = 1:length(fo)
    fprintf('\n--- %s (%d/%d) ---\n',fo(k).name,k,length(fo));

    % Every folder must start from a clean slate. Without this a downlink
    % that is missing one of the three APIDs silently inherits the previous
    % folder's structs and writes them out under its own filename.
    clear scalar_data coil_data att_data PV_data XACT_HK PLD_HK

    % A contact does not always carry all three packets, and the two writers
    % need different subsets: create_COSMO_cdf builds Level 0 from the science
    % (1625) and XACT meta (520) packets, create_COSMO_hk builds HK from the
    % payload (519) and XACT meta (520) packets. Gate them separately so a
    % partial downlink still yields whatever it has the inputs for.
    fns = cell(1,3);
    for j = 1:3
        fns{j} = dir(fullfile(data_path,fo(k).name,['*',num2str(ID(j),'%d'),'.csv']));
    end
    n_csv = cellfun(@numel,fns);
    if any(n_csv > 1)
        warning('Skipping %s: expected at most one CSV per APID, found %d/%d/%d for APID %d/%d/%d.',...
            fo(k).name,n_csv(1),n_csv(2),n_csv(3),ID(1),ID(2),ID(3))
        n_skip = n_skip + 1;
        continue
    end
    % Either family alone is enough for a writer: the absent one is passed as
    % [] and lands in the CDF as zero-record variables, so the file keeps its
    % full variable layout without inventing any values.
    have = n_csv == 1;                                                     % ID = [1625,520,519]
    can_l0 = make_l0_cdf && (have(1) || have(2));
    can_hk = make_hk     && (have(3) || have(2));
    fprintf('  APID present: 1625=%d 520=%d 519=%d\n',have(1),have(2),have(3));
    if ~can_l0 && ~can_hk
        warning('Skipping %s: no APID CSV that either writer can use.',fo(k).name)
        n_skip = n_skip + 1;
        continue
    end

    before_l0 = snapshot_dir(level0_path,'*.cdf');
    before_hk = snapshot_dir(hk_path,'*.cdf');

    try
        for j = find(have)                                                 % Only the packets this folder actually has
            fn = fns{j};

            % Load and process science data
            [data,apid] = read_CCSDS(ensure_trailing_sep(fn.folder),fn.name);
            if isfield(data,'src_seq_ctr') && ~isfield(data,'seq_ctr')
                data.seq_ctr = data.src_seq_ctr;
            end
            [pdata,apid] = cosmo_conversion(data,apid);
            if isfield(pdata,'src_seq_ctr') && ~isfield(pdata,'seq_ctr')
                pdata.seq_ctr = pdata.src_seq_ctr;
            end
            if apid == 1625
                [scalar_data,coil_data,att_data] = read_COSMO_science(pdata,apid);
            elseif apid == 520
                [PV_data] = read_COSMO_science(pdata,apid);
                [XACT_HK] = read_COSMO_hk(pdata,apid);
                XACT_HK = expand_vector_fields(XACT_HK);
                if isfield(XACT_HK,'meta_momentum_torque_rod_mode3') && ~isfield(XACT_HK,'meta_adcs_momentum_torque_rod_mode3')
                    XACT_HK.meta_adcs_momentum_torque_rod_mode3 = XACT_HK.meta_momentum_torque_rod_mode3;
                end
            elseif apid == 519
                [PLD_HK] = read_COSMO_hk(pdata,apid);
            else
                error('This is not a correct packet!')
            end
        end

        % A family whose packet was absent, or was present but failed to
        % decode, becomes [] - the writers turn that into zero records rather
        % than dropping the whole folder.
        if ~exist('scalar_data','var')
            scalar_data = []; coil_data = []; att_data = [];
        end
        if ~exist('PV_data','var'),  PV_data = []; end
        if ~exist('XACT_HK','var'),  XACT_HK = []; end
        if ~exist('PLD_HK','var'),   PLD_HK  = []; end

        can_l0 = can_l0 && ~(isempty(scalar_data) && isempty(PV_data));
        can_hk = can_hk && ~(isempty(XACT_HK) && isempty(PLD_HK));
        if ~can_l0 && ~can_hk
            warning('Skipping %s: nothing decoded that either writer can use.',fo(k).name)
            n_skip = n_skip + 1;
            continue
        end

        % Create Level 0
        if can_l0
            level = 0;
            type = 1;
            scalar = 1;
            create_COSMO_cdf(level0_path,level,type,scalar,scalar_data,coil_data,att_data,PV_data)
            fprintf('Level 0 written for %s (science %s, PV %s)\n',fo(k).name,...
                span_str(scalar_data),span_str(PV_data));
            if isempty(PV_data)
                % data_synchronization returns early unless BOTH GPS_Time and
                % Scalar_Time have samples, so this file cannot feed Level 1
                fprintf(2,['  NOTE: no APID 520, so GPS_Time is empty - this Level 0 file ',...
                    'will not contribute to Level 1.\n']);
            elseif isempty(scalar_data)
                fprintf(2,['  NOTE: no APID 1625, so Scalar_Time is empty - this Level 0 file ',...
                    'will not contribute to Level 1.\n']);
            end
        end

        % Save HK in cdf
        if can_hk
            level = 1;
            create_COSMO_hk(hk_path,level,XACT_HK,PLD_HK)
            fprintf('HK written for %s (XACT %s, PLD %s)\n',fo(k).name,...
                span_str(XACT_HK),span_str(PLD_HK));
        end

        n_ok = n_ok + 1;
    catch ME
        % One bad folder must not abort the rest of a multi-folder run
        n_fail = n_fail + 1;
        fprintf(2,'FAILED %s: %s\n',fo(k).name,ME.message);
        if ~isempty(ME.stack)
            fprintf(2,'  at %s line %d\n',ME.stack(1).name,ME.stack(1).line);
        end
        continue
    end

    % create_COSMO_cdf / create_COSMO_hk do not return the name they wrote,
    % so diff the output directories to report it
    if can_l0
        report_new_files(level0_path,'*.cdf',before_l0,'Level 0');
    end
    if can_hk
        report_new_files(hk_path,'*.cdf',before_hk,'HK');
    end
end

%% Summary
fprintf('\n=== %d processed / %d skipped / %d failed in %.1f min ===\n',...
    n_ok,n_skip,n_fail,toc(t_start)/60);

status = double(n_skip > 0 || n_fail > 0);
if nargout == 0
    % matlab -batch exits 0 unless an error escapes, so surface an incomplete
    % run as one - otherwise an automated caller sees success
    if status ~= 0
        error('COSMO_data_main_CLI:incomplete',...
            '%d folder(s) failed and %d skipped - see the log above.',n_fail,n_skip)
    end
    clear status
end
end

%% Helper: describe a family's time span, or note that it is absent
function s = span_str(fam)
    if isempty(fam)
        s = 'absent';
    else
        s = sprintf('%s -> %s (%d rec)',char(fam.time(1),'yyyy-MM-dd HH:mm:ss'),...
            char(fam.time(end),'yyyy-MM-dd HH:mm:ss'),numel(fam.time));
    end
end

%% Helper: normalize a directory to end in a single separator
function p = ensure_trailing_sep(p)
    if ~isempty(p) && ~ismember(p(end),{'\','/'})
        p = [p,filesep];
    end
end

%% Helper: name -> bytes map of the CDFs currently in a directory
function s = snapshot_dir(path,pattern)
    s = struct('name',{},'bytes',{});
    if isfolder(path)
        d = dir([path,pattern]);
        if ~isempty(d)
            s = struct('name',{d.name},'bytes',{d.bytes});
        end
    end
end

%% Helper: print files that appeared or changed size since the snapshot
function report_new_files(path,pattern,before,label)
    after = snapshot_dir(path,pattern);
    for i = 1:numel(after)
        idx = find(strcmp({before.name},after(i).name),1);
        if isempty(idx) || before(idx).bytes ~= after(i).bytes
            fprintf('  %s -> %s (%.1f MB)\n',label,after(i).name,after(i).bytes/1e6);
        end
    end
end

%% Helper: expand merged vector fields back to numbered fields for create_COSMO_hk
function s = expand_vector_fields(s)
    vec_map = {
        'meta_refs_position_wrt_ecef', 3;
        'meta_refs_velocity_wrt_ecef', 3;
        'meta_att_det_q_body_wrt_eci', 4;
        'meta_att_det_body_rate', 3;
        'meta_imu_imu_avg_vector', 3;
        'meta_mag_mag_vector_body', 3;
        'meta_rw_drive_meas_wheel_current', 4;
        'meta_momentum_cycle_avg_magnet_torque', 3;
        'meta_momentum_torque_rod_enable', 3;
        'meta_momentum_duty_cycle', 3;
        'meta_momentum_torque_rod_mode', 3;
    };
    for i = 1:size(vec_map,1)
        base = vec_map{i,1};
        ncols = vec_map{i,2};
        if isfield(s, base) && size(s.(base),2) == ncols
            for c = 1:ncols
                s.([base, num2str(c)]) = s.(base)(:,c);
            end
            s = rmfield(s, base);
        end
    end
end
