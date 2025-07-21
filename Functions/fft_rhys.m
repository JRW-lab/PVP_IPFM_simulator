function fwindows = fft_rhys(twindows,fs,f0,Twin)

if size(twindows,2) == fs*Twin
    twindows = twindows.';
end

fwindows = abs(fft(twindows)) / fs;
fwindows = fwindows(1:(f0*Twin),:).';