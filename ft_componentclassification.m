function compclass = ft_componentclassification(cfg, comp, refdata)

% FT_COMPONENTCLASSIFICATION performs a classification of the spatiotemporal
% components
%
% Use as
%   compclass = ft_componentclassification(cfg, comp) 
% where comp is the output of FT_COMPONENTANALYSIS and cfg is a       
% configuration structure that should contain 
%
%   cfg.option1    = value, explain the value here (default = something)
%   cfg.option2    = value, describe the value here and if needed
%                    continue here to allow automatic parsing of the help
%
% The configuration can optionally contain
%   cfg.option3   = value, explain it here (default is automatic)
%
% To facilitate data-handling and distributed computing with the peer-to-peer
% module, this function has the following options:
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_COMPONENTANALYSIS, FT_TOPOPLOTIC

% Copyright (C) 2011, Jan-Mathijs Schoffelen
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

revision = '$Id$';

% do the general setup of the function
ft_defaults
ft_preamble help
ft_preamble provenance
ft_preamble randomseed
ft_preamble trackconfig
ft_preamble debug
ft_preamble loadvar comp

% ensure that the input data is valiud for this function, this will also do 
% backward-compatibility conversions of old data that for example was 
% read from an old *.mat file
comp = ft_checkdata(comp, 'datatype', 'comp', 'feedback', 'yes');
if nargin>2
  refdata = ft_checkdata(refdata, 'datatype', 'raw', 'feedback', 'yes');
end

% ensure that the required options are present
cfg = ft_checkconfig(cfg, 'required', 'method');

method  = ft_getopt(cfg, 'method'); % there is no default

if strcmp(method, 'template_timeseries') && nargin<=2
  error('for the method ''template_timeseries'' the input to this function should contain the reference time series as a separate input');
end

% copy the input to the output
compclass = comp;

switch method
  case 'template_spectrum'
    error('not supported yet')
    cfg                   = ft_checkconfig(cfg,          'required', 'template');
    cfg.template          = ft_checkconfig(cfg.template, 'required', 'spectrum');
    cfg.template.spectrum = ft_checkconfig(cfg.template.spectrum, 'required', {'freq' 'powspctrm'});
    
    % template
    template = cfg.template.spectrum;
    
    % do spectral analysis
    tmpcfg        = [];
    tmpcfg.method = 'mtmfft';
    tmpcfg.taper  = 'hanning';
    tmpcfg.output = 'pow';
    freq          = ft_freqanalysis(tmpcfg, comp);
    
    % do some interpolation here if needed
    % FIXME
    if ~all(template.freq==freq.freq)
    end
    
    % regress
    
    
    x=1;
    
  case 'template_timeseries'
    error('not supported yet')
    % check whether the inputs are compatible
    ok = true;
    for k = 1:numel(comp.trial)
      ok = size(comp.trial{k},2) == size(refdata.trial{k},2);
      if ~ok
        error('the input data structures are incompatible because of different trial lengths');
        break;
      end
    end
    Ncomp = numel(comp.label);
    comp  = ft_appenddata([], comp, refdata);
    
    % compute covariance 
    comprefcov = cellcov(comp.trial, [], 2);
    
    % compute correlation
    comprefcorr = comprefcov(1:Ncomp,(Ncomp+1):end)./sqrt(diag(comprefcov(1:Ncomp,1:Ncomp))*diag(comprefcov((Ncomp+1):end,(Ncomp+1):end))');
    
  case 'template_topography'
    error('unknown method of classification');    
  case '1/f'
    error('unknown method of classification');    
  case 'kurtosis'
  
    mx         = cellmean(comp.trial, 2);
    comp.trial = cellvecadd(comp.trial, -mx);
  
    m4 = zeros(numel(comp.label),1);
    m2 = zeros(numel(comp.label),1);
    n  = 0;
    for k = 1:numel(comp.trial)
      m4 = m4 + sum(comp.trial{k}.^4,2);
      m2 = m2 + sum(comp.trial{k}.^2,2);
      n  = n  + size(comp.trial{k},2);
    end
    m4    = m4./n;
    m2    = m2./n;
    kurt  = m4./m2.^2;
    
    compclass.kurt = kurt;
    
  case 'whiteness'
    error('unknown method of classification');    
  case 'something else'
    error('unknown method of classification');    
  otherwise
    error('unknown method of classification');    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% deal with the output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble trackconfig
ft_postamble provenance
ft_postamble randomseed
ft_postamble previous comp
ft_postamble history compclass
ft_postamble savevar compclass

%-----cellcov
function [c] = cellcov(x, y, dim, flag)

% [C] = CELLCOV(X, DIM) computes the covariance, across all cells in x along 
% the dimension dim. When there are three inputs, covariance is computed between
% all cells in x and y
% 
% X (and Y) should be linear cell-array(s) of matrices for which the size in at 
% least one of the dimensions should be the same for all cells 

if nargin==2,
  flag = 1;
  dim  = y;
  y    = [];
elseif nargin==3,
  flag = 1;
end

nx = size(x);
if ~iscell(x) || length(nx)>2 || all(nx>1),
  error('incorrect input for cellmean');
end

if nargin==1,
  scx1 = cellfun('size', x, 1);
  scx2 = cellfun('size', x, 2);
  if     all(scx2==scx2(1)), dim = 2; %let second dimension prevail
  elseif all(scx1==scx1(1)), dim = 1;
  else   error('no dimension to compute covariance for');
  end
end

if flag,
  mx   = cellmean(x, 2);
  x    = cellvecadd(x, -mx);
  if ~isempty(y),
    my = cellmean(y, 2);
    y  = cellvecadd(y, -my);
  end
end

nx   = max(nx);
nsmp = cellfun('size', x, dim);
if isempty(y), 
  csmp = cellfun(@covc, x, repmat({dim},1,nx), 'UniformOutput', 0);
else
  csmp = cellfun(@covc, x, y, repmat({dim},1,nx), 'UniformOutput', 0);
end
nc   = size(csmp{1});
c    = sum(reshape(cell2mat(csmp), [nc(1) nc(2) nx]), 3)./sum(nsmp); 

function [c] = covc(x, y, dim)

if nargin==2,
  dim = y;
  y   = x;
end

if dim==1,
  c = x'*y;
elseif dim==2,
  c = x*y';
end

%-----cellmean
function [m] = cellmean(x, dim)

% [M] = CELLMEAN(X, DIM) computes the mean, across all cells in x along 
% the dimension dim.
% 
% X should be an linear cell-array of matrices for which the size in at 
% least one of the dimensions should be the same for all cells 

nx = size(x);
if ~iscell(x) || length(nx)>2 || all(nx>1),
  error('incorrect input for cellmean');
end

if nargin==1,
  scx1 = cellfun('size', x, 1);
  scx2 = cellfun('size', x, 2);
  if     all(scx2==scx2(1)), dim = 2; %let second dimension prevail
  elseif all(scx1==scx1(1)), dim = 1;
  else   error('no dimension to compute mean for');
  end
end

nx   = max(nx);
nsmp = cellfun('size', x, dim);
ssmp = cellfun(@sum,   x, repmat({dim},1,nx), 'UniformOutput', 0);
m    = sum(cell2mat(ssmp), dim)./sum(nsmp);  

%-----cellstd
function [sd] = cellstd(x, dim, flag)

% [M] = CELLSTD(X, DIM, FLAG) computes the standard deviation, across all cells in x along 
% the dimension dim, normalising by the total number of samples 
% 
% X should be an linear cell-array of matrices for which the size in at 
% least one of the dimensions should be the same for all cells. If flag==1, the mean will
% be subtracted first (default behaviour, but to save time on already demeaned data, it
% can be set to 0).

nx = size(x);
if ~iscell(x) || length(nx)>2 || all(nx>1),
  error('incorrect input for cellstd');
end

if nargin<2,
  scx1 = cellfun('size', x, 1);
  scx2 = cellfun('size', x, 2);
  if     all(scx2==scx2(1)), dim = 2; %let second dimension prevail
  elseif all(scx1==scx1(1)), dim = 1;
  else   error('no dimension to compute mean for');
  end
elseif nargin==2,
  flag = 1;
end

if flag,
  m    = cellmean(x, dim);
  x    = cellvecadd(x, -m);
end

nx   = max(nx);
nsmp = cellfun('size', x, dim);
ssmp = cellfun(@sumsq,   x, repmat({dim},1,nx), 'UniformOutput', 0);
sd   = sqrt(sum(cell2mat(ssmp), dim)./sum(nsmp));  

function [s] = sumsq(x, dim)

s = sum(x.^2, dim);

%-----cellvecadd
function [y] = cellvecadd(x, v)

% [Y]= CELLVECADD(X, V) - add vector to all rows or columns of each matrix 
% in cell-array X

% check once and for all to save time
persistent bsxfun_exists;
if isempty(bsxfun_exists); 
    bsxfun_exists=(exist('bsxfun')==5); 
    if ~bsxfun_exists; 
        error('bsxfun not found.');
    end
end

nx = size(x);
if ~iscell(x) || length(nx)>2 || all(nx>1),
  error('incorrect input for cellmean');
end

if ~iscell(v),
  v = repmat({v}, nx);
end

sx1 = cellfun('size', x, 1);
sx2 = cellfun('size', x, 2);
sv1 = cellfun('size', v, 1);
sv2 = cellfun('size', v, 2);
if all(sx1==sv1) && all(sv2==1),    
  dim = mat2cell([ones(length(sx2),1) sx2(:)]', repmat(2,nx(1),1), repmat(1,nx(2),1)); 
elseif all(sx2==sv2) && all(sv1==1),
  dim = mat2cell([sx1(:) ones(length(sx1),1)]', repmat(2,nx(1),1), repmat(1,nx(2),1));
elseif all(sv1==1) && all(sv2==1),
  dim = mat2cell([sx1(:) sx2(:)]'', nx(1), nx(2));
else   error('inconsistent input');
end  

y  = cellfun(@bsxfun, repmat({@plus}, nx), x, v, 'UniformOutput', 0);
%y = cellfun(@vplus, x, v, dim, 'UniformOutput', 0);

function y = vplus(x, v, dim)

y = x + repmat(v, dim);

%-----cellvecmult
function [y] = cellvecmult(x, v)

% [Y]= CELLVECMULT(X, V) - multiply vectors in cell-array V
% to all rows or columns of each matrix in cell-array X
% V can be a vector or a cell-array of vectors

% check once and for all to save time
persistent bsxfun_exists;
if isempty(bsxfun_exists); 
    bsxfun_exists=(exist('bsxfun')==5); 
    if ~bsxfun_exists; 
        error('bsxfun not found.');
    end
end

nx = size(x);
if ~iscell(x) || length(nx)>2 || all(nx>1),
  error('incorrect input for cellmean');
end

if ~iscell(v),
  v = repmat({v}, nx);
end

sx1 = cellfun('size', x, 1);
sx2 = cellfun('size', x, 2);
sv1 = cellfun('size', v, 1);
sv2 = cellfun('size', v, 2);
if all(sx1==sv1) && all(sv2==1),    
elseif all(sx2==sv2) && all(sv1==1),
elseif all(sv1==1) && all(sv2==1),
else   error('inconsistent input');
end  

y  = cellfun(@bsxfun, repmat({@times}, nx), x, v, 'UniformOutput', 0);
