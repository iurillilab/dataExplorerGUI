function stdshade_modified(amatrix,alpha,acolor,F,...
    smth,lineStyle, lineWidth, errMethod)
% usage: stdshading(amatrix,alpha,acolor,F,smth)
% plot mean and sem/std coming from a matrix of data, at which each row is an
% observation. sem/std is shown as shading.
% - acolor defines the used color (default is red) 
% - F assignes the used x axis (default is steps of 1).
% - alpha defines transparency of the shading (default is no shading and black mean line)
% - smth defines the smoothing factor (default is no smooth)
% - errMethod: 1: std (defult), 2: stm
% smusall 2010/4/23
if exist('acolor','var')==0 || isempty(acolor)
    acolor='r'; 
end
if exist('lineStyle','var')==0 || isempty(lineStyle)
    lineStyle='-'; 
end
if exist('lineWidth','var')==0 || isempty(lineWidth)
    lineWidth=1.5; 
end
if exist('errMethod','var')==0 || isempty(errMethod)
    errMethod = 1;
end
if exist('F','var')==0 || isempty(F)
    F=1:size(amatrix,2);
end

if exist('smth','var'); if isempty(smth); smth=1; end
else smth=1; %no smoothing by default
end  

if ne(size(F,1),1)
    F=F';
end

amean = nanmean(amatrix,1); %get man over first dimension
if smth > 1
  %   amean = boxFilter(nanmean(amatrix,1),smth); %use boxfilter to smooth data
    amean = gen_fx_gsmooth(nanmean(amatrix,1),smth);
end
if errMethod == 1
    astd = nanstd(amatrix,[],1); % to get std shading
elseif errMethod == 2
    astd = nanstd(amatrix,[],1)/...
        sqrt(sum(max(~isnan(amatrix), [], 2))); % to get sem shading
else
    error('err method is invalid')
end
if exist('alpha','var')==0 || isempty(alpha) 
    h = fill([F fliplr(F)],[amean+astd fliplr(amean-astd)],acolor,'linestyle','none');
    acolor='k';
else
    h = fill([F fliplr(F)],[amean+astd fliplr(amean-astd)],acolor, 'FaceAlpha', alpha,'linestyle','none');
end

h.Annotation.LegendInformation.IconDisplayStyle = 'off';

if ishold==0
    check=true; else check=false;
end

hold on;plot(F,amean,'Color', acolor,'LineStyle',lineStyle,...
    'linewidth',lineWidth); %% change color or linewidth to adjust mean line

if check
    hold off;
end

end


% function dataOut = boxFilter(dataIn, fWidth)
% % apply 1-D boxcar filter for smoothing
% 
% dataStart = cumsum(dataIn(1:fWidth-2),2);
% dataStart = dataStart(1:2:end) ./ (1:2:(fWidth-2));
% dataEnd = cumsum(dataIn(length(dataIn):-1:length(dataIn)-fWidth+3),2);
% dataEnd = dataEnd(end:-2:1) ./ (fWidth-2:-2:1);
% dataOut = conv(dataIn,ones(fWidth,1)/fWidth,'full');
% dataOut = [dataStart,dataOut(fWidth:end-fWidth+1),dataEnd];
% 
% end

