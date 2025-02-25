% An exploration of the Deep Learning framework.
%
% This script uses a custom classification layer
% incorporating Connectionist Temporal Classification (CTC)
%
[XTrain, YTrain] = prepareDataTrain(2048, 6, 2);

numFeatures = size(XTrain{1},1);
numHiddenUnits = 16;
numClasses = length(categories(YTrain{1}));

% Our custom classification layer
ctcLayer = CTCLayer;

layers = [ ...
    sequenceInputLayer(numFeatures)
    bilstmLayer(numHiddenUnits,...
                'OutputMode','sequence')
    fullyConnectedLayer(numClasses)
    softmaxLayer
    ctcLayer];


%% 'ExecutionEnvironment', 'cpu',...


options = trainingOptions('adam', ...
                          'ExecutionEnvironment', 'auto',...
                          'LearnRateDropPeriod',20, ...
                          'GradientThreshold',0.001, ...
                          'LearnRateSchedule','piecewise', ...
                          'MiniBatchSize', 10,...
                          'InitialLearnRate',0.01, ...
                          'Verbose',1, ...
                          'MaxEpochs', 128,...
                          'Plots','training-progress');
%% Train
net = trainNetwork(XTrain,YTrain,layers,options);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% TEST PREDICTION
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[XTest, YTest] = prepareDataTrain(256, 6, 2);

[YPred, YScore] = classify(net, XTest, 'MiniBatchSize', 1);


count = 0;
for j=1:length(YPred)
    Y = YTest{j};
    Y = Y(Y~='_');
    Z = B(YPred{j});
    if length(Z) ~= length(Y) || ~all(Z == Y)
        disp('------- Error --------');
        display(Z);
        display(Y);
        count = count + 1;
    end
end

Confusion = count / length(YPred);
Confusion
