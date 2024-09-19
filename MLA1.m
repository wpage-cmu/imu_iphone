% Make variables
ts = Hand14.ts; % Time (ts) column
x = Hand14.x;   % x column
y = Hand14.y;   % y column
z = Hand14.z;   % z column

% Compute the magnitude of the 3-axis IMU data
magnitude = sqrt(x.^2 + y.^2 + z.^2);

% Apply a moving average with movmean to smooth the signal
smoothedMag = movmean(magnitude, 10); % moving average

% Design and apply a Butterworth low-pass filter to remove noise
fs = 1 / mean(diff(ts));  % Sampling frequency (estimated from time data)
fc = 5;  % Cutoff frequency (Hz) - adjust this value based on your signal
[b, a] = butter(4, fc/(fs/2), 'low'); % 4th-order low-pass Butterworth filter
filteredMag = filter(b, a, smoothedMag); % Apply the filter

% Remove the DC bias by subtracting the mean of the filtered signal
filteredMagWithoutDC = filteredMag - mean(filteredMag);

% Use findpeaks to identify and capture the peaks of the signal
avgStepDuration = 0.4; % Adjust based on walking speed in seconds (.4 represents 3.5 mph)
minPeakDist = round(avgStepDuration * fs); % Calculate MinPeakDistance in samples
[pks, locs] = findpeaks(filteredMagWithoutDC, 'MinPeakDistance', minPeakDist);

% Remove the first and last peaks
if ~isempty(locs) % Check if there are any detected peaks
    locs = locs(2:end-1); % Remove the first and last peaks
    pks = pks(2:end-1);   % Correspondingly remove peak values
end

% Find zero crossings
zeroCrossings = find(diff(sign(filteredMagWithoutDC))); % Find zero crossing indices

% Plot the filtered signal with the peaks and zero crossings
figure; % Create a new figure window
plot(ts, filteredMagWithoutDC, '-b', 'LineWidth', 1.5); % Plot in blue
hold on; % Hold the plot to overlay peaks and zero crossings

% Plot the detected peaks on the filtered and DC-removed magnitude
plot(ts(locs), pks, 'rv', 'MarkerFaceColor', 'r'); % Red triangles for peaks

% Plot zero crossings
plot(ts(zeroCrossings), filteredMagWithoutDC(zeroCrossings), 'go', 'MarkerFaceColor', 'g'); % Green circles for zero crossings

% Add labels and title
xlabel('Time (ts)'); % Label for x-axis
ylabel('Filtered Magnitude (DC-Removed)');  % Label for y-axis
title('Filtered Magnitude with Detected Peaks and Zero Crossings'); % Title for the plot
legend('Filtered Magnitude', 'Peaks', 'Zero Crossings'); % Add legend
grid on; % Add grid to the plot
hold off; % Release the plot