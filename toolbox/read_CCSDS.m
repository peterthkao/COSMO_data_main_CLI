function [out,apid] = read_CCSDS(path,filename)
% By: Tzu-Hsun Kao
% Last updat: Feb. 6, 2026
% -------------------------------------------------------------------------
% Description: To read CCSDS files and save into struct.
% -------------------------------------------------------------------------
% INPUTS
% -------------------------------------------------------------------------
% path:         (chr) path of the science packet
% filename:     (chr) filename
% -------------------------------------------------------------------------
% OUTPUTS
% -------------------------------------------------------------------------
% out:          (struct) contains all data from CCSDS
% apid:         (double) AP ID
% -------------------------------------------------------------------------

data = readtable([path,filename]);
clc;
names = data.Properties.VariableNames;
apid = unique(data{:,2});
out = struct;

if length(apid) ~= 1
    error('This file contants more than one APID!')
else
    for i = 2:width(data)
        out.(names{i}) = data{:,i};
    end
end