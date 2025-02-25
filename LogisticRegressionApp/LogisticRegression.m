classdef LogisticRegression
    
    properties
        X                               % Training data
        T                               % Target data
        Height                          % Digit height (pixels)
        Width                           % Digit width (pixels)
        Y                               % Network activation
        NErrors                         % Number of errors
        W                               % Weights
        eta                             % Learning rate
        epoch = 0                       % Epoch counter
        epoch_max;                      % Number of epochs to run
        losses = [];                    % List of loss values

        State = LogisticRegression.STATE_IDLE; % State of drawing
        ImageHandle                     % Image of a hand-drawn digit
        DigitImage                      % The hand-drawn digit image
    end

    properties(Constant)
        app_name = 'MNISTDigitLearner' % This application name
        min_eta = 1e-5                  % Stop if learning rate drops below
        alpha = 1e-1                    % Regularizer constant
        epoch_increment = 300           % Number of epochs to add
        update_period = 10              % Update stats this often

        STATE_IDLE = 0                  % We are not hand-drawing a digit
        STATE_DRAWING = 1               % We are hand-drawing a digit
    end

    properties(Access=private)
        app                             % The GUI
        x_offset;                       % For motion workaround
        y_offset;                       % For motion workaround
        savefile = [];                  % The path of save file
    end
    
    properties(Dependent)
        app_data_path                   % Where the app data is
    end
    
    methods
        function this = regularize_targets(this,p)
        % Regularize targets
        % THIS = REGULARIZE_TARGETS(THIS,P) modifies
        % the targets as if assigning class at random with probability 1-P
            [D,N] = size(X);
            [C,~] = size(T);
            T0 = 1/C*ones(C,1)*ones(1,N);
            T = (1-p)*T0 + p*T;
        end


        function path = get.app_data_path(this)
            if isdeployed
                % We will find the files in the 'application' folder
                path = '';
            else
                % We're running within MATLAB, either as a MATLAB app,
                % or from a copy of the current folder. If we're running
                % as a MATLAB app, we need to get the application folder
                % by using matlab.apputil class.
                apps = matlab.apputil.getInstalledAppInfo;
                ind=find(cellfun(@(x)strcmp(x,this.app_name),{apps.name}));
                if isempty(ind)
                    path = '.';             % Current directory
                else
                    path = apps(ind).location; % This app is installed, its path
                end
            end
        end


        function print_app_info(this)
        %PRINT_APP_INFO prints information about the app environment
            if isdeployed
                % Print deployment information
                fprintf('Running %s as a standalone application.\n',this.app_name);
                fprintf('Application files are in: %s\n', ctfroot);
                fprintf('MATLAB runtime version is: %d\n', mcrversion);
            else
                % 
                fprintf('Running %s a MATLAB app.\n',this.app_name);
                fprintf('MATLAB version: %s\n', version);
                apps = matlab.apputil.getInstalledAppInfo;
                ind = find(cellfun(@(x)strcmp(x,this.app_name), {apps.name}));
                if isempty(ind)
                    path = '.';             % Current directory
                else
                    path = apps(ind).location; % This app is installed, its path
                end
                fprintf('App data folder is %s\n',path);
            end
        end


        function this = LogisticRegression(app)
            this.app = app;
            this.print_app_info;
            this = this.clear_digit;
        end

        function this = train(this,continuing)
        %TRAIN_PATTERNNET trains a logistic regression network
        % [Y, NERRORS,W] = TRAIN_PATTERNNET(X, T, NUM_EPOCHS)    trains
        % a pattennet (logistic regression network) to recognize
        % patterns, which are columns of X, a D-by-N matrix.
        % The targets T is C-by-N, with each column being a probability
        % distribution of the patterns belonging to each of the C classes.
        % Often T(:,J) the column is the one-hot encoded true label of the 
        % pattern X(:,J). Note that the iteration can be stopped
        % at any time, by pressing the button in the left-lower corner 
        % of the plot, labeled 'BREAK'.
        %
        % The algorithm uses batch processing, whereby every sample is
        % included in the gradient computation in each epoch. The maximum number
        % of epochs can be specified by the argument NUM_EPOCHS (default: 10^4).
            if nargin < 2; continuing = false; end

            assert(size(this.X,2) == size(this.T,2), ['Inconsistent number of samples in ' ...
                                'data and targets.']);

            assert(all(sum(this.T,1)==1),'Target rows must sum up to 1');

            D = size(this.X, 1);                     % Dimension of data
            N = size(this.X, 2);                     % Number of samples
            C = size(this.T, 1);                     % Number of  classes

            if ~continuing || isempty(this.W)
                this.epoch = 0;
                SigmaW = (1 / (2 * this.alpha)) * eye(D * C);
                this.W = mvnrnd(zeros([1, D * C]), SigmaW);   % Starting weihgts
                this.W = reshape(this.W, [C, D]);
            end
            
            %% Update gradient
            this.Y = softmax(this.W * this.X);% Compute activations
            E = this.T - this.Y;
            DW = -E * this.X' + this.alpha * this.W;

            if ~continuing
                this.eta = 1 /(eps + norm(DW));          % Initial learning rate
                loss = this.loss;       % Test on the original sample
                this.losses = [loss];
                this.epoch_max = this.epoch_increment;
            else
                this.epoch_max = this.epoch_max + this.epoch_increment;
            end

            while this.epoch < this.epoch_max
                this.epoch = this.epoch + 1;
                % Update weights
                W_old = this.W;
                this.W = this.W - this.eta * DW;

                %% Update gradient
                DW_old = DW;
                this.Y = softmax(this.W * this.X);                % Compute activations
                E = this.T - this.Y;
                DW = -E * this.X' + this.alpha * this.W;

                loss = this.loss;% Test on the original sample
                this.losses = [this.losses,loss];

                % Adjust learning rate according to Barzilai-Borwein
                this.eta = ((this.W(:) - W_old(:))' * (DW(:) - DW_old(:))) ...
                    ./ (eps + norm(DW(:) - DW_old(:))^2 );

                % Visualize  learning
                if mod(this.epoch, this.update_period) == 0 
                    this.NErrors = length(find(round(this.Y)~=this.T));
                    this = this.show_learning;
                end
                % Re-center the weights
                if mod(this.epoch, 100) == 0 
                    this.W = this.W - mean(this.W);
                end
                %pause(.1);
            end
            plot_confusion(this);
        end

        function this = show_learning(this)
            if isempty(this.losses)
                return;
            end
            ax = this.app.UIAxes;
            semilogy(ax, this.losses,'-'), 
            title(ax,['Learning (epoch: ',num2str(this.epoch),')']),
            %disp(['Learning rate: ',num2str(this.eta)]);
            drawnow;
            % Update error stats
            this.app.LearningRateEditField.Value = this.eta;
            this.app.NumberOfErrorsEditField.Value = this.NErrors;
        end



        function digit = predict(this)
            myX = this.DigitImage';     % Rotate by 90 degrees
            myX = myX(:);               % Linearize
            myY = softmax(this.W * myX);% Activation
            [~,digit_idx] = max(myY);
            digit = this.app.digits(digit_idx);
        end

        function this = prepare_training_data(this)
        %PREPARE_TRAINING_DATA returns MNIST data prepared for training
        % [X,T,H,W] = PREPARE_TRAINING_DATA(D1,D2,...,DK) returns X, which is a
        % 784-by-N matrix, where N is the number of digit images. The arguments
        % D1, D2, ..., DK are the digit labels (a subset of 0, 1, ..., 9).
        % X contains linearized images. T is K-by-N matrix of one-hot encoded
        % labels for digit data.
        %
        % It should be noted that we can retrieve each digit image in the following manner:
        %
        %      [X,T] = prepare_training_data(0,1,2,3);
        %      n = 17;
        %      I=reshape(X(:,n),28,28)';
        %      imshow(I);
        %
        % This will give us the 17-th digit of the dataset, which happens to be a
        % rendition of digit '2'. 
        %
        % Transposing is necessary to get the vertical digit, else is a digit on
        % its side.
            data_file = fullfile(this.app_data_path, 'digit_data.mat');
            load(data_file);

            digits = this.app.digits;
            num_digits = length(digits);

            for j=1:num_digits
                Digit{j}=I(T==digits(j),:,:)./255;
            end
            

            % Height and width of images
            this.Height = size(Digit{1},2);
            this.Width = size(Digit{1},3);
            this.DigitImage = zeros(this.Height, this.Width);

            % Linearized images
            X0 = [];
            T0 = [];
            for j=1:num_digits
                LinDigit = reshape(Digit{j}, [size(Digit{j},1), this.Width * this.Height]);
                X0 = [X0; LinDigit];
                T1 = zeros([size(LinDigit, 1),num_digits]);
                T1(:,j) = ones([size(LinDigit, 1),1]);
                T0 = [T0; T1];
            end

            % Combined samples

            N = size(X0,1);
            P = randperm(N);

            % Permuted combined samples and labels
            this.X = X0';
            this.T = T0';

            this = this.show_sample_digits;
        end

        function plot_confusion(this)
            if isempty(this.Y) 
                return;
            end
            [c,cm] = confusion(this.T,this.Y);
            labels = this.app.DigitPickerListBox.Value;
            panel = this.app.ConfusionMatrixPanel;
            panel.AutoResizeChildren = 'off';
            ax = subplot(1,1,1,'Parent',panel);
            plotConfMat(ax,cm,labels);
        end

        function [G] = loss(this)
            G = this.cross_entropy;
            G = G + this.alpha * sum(this.W .^2,'all');% Regularize
        end

        function [Z] = cross_entropy(this)
            Z = -sum(this.T .* log(this.Y+eps),'all');
        end

        function this = plot_mean_digit(this, digit)
        % MEAN_DIGIT_IMAGE get mean image of a digit
            if nargin < 2
                digit=this.app.digit;
            end
            % Find digit index in the current training digits
            digit_idx = find(digit==this.app.digits,1);
            % Find indices which label is correct
            idx = find(this.T(digit_idx,:));
            mean_digit = reshape(mean(this.X(:,idx),2), [this.Height,this.Width])'; 
            this.ImageHandle.CData  = round(128 * mean_digit .* this.app.hint_intensity);
        end

        function this = show_sample_digits(this)
            digits = this.app.digits;
            num_digits = length(digits);

            this.app.DigitViewerPanel.AutoResizeChildren = 'off';
            g = ceil(sqrt(num_digits));
            for j=1:num_digits
                idx = find(this.T(j,:),1,'first');
                sample_digit = reshape(this.X(:,idx), [this.Height,this.Width])'; 
                ax = subplot(g,g,j,'Parent',this.app.DigitViewerPanel);
                imagesc(ax, sample_digit);
                title(ax,['Class ', num2str(j)]);
            end
        end


        function this = clear_digit(this)
            this.ImageHandle = image(this.app.UIAxes2, ones(this.Height,this.Width));
            colormap(this.app.UIAxes2, 1-gray);
        end

        function this = WindowEventFcn(this, event)
        %WINDOWEVENTFCN handles digit drawing
            if this.app.TabGroup.SelectedTab ~= this.app.DigitTracingTab
                return;
            end

            switch event.EventName,
              case 'WindowMousePress',
                % disp(event);
                %disp(event.Source);
                % disp(event.Source.Parent);                
                % disp(['Tag: ', event.Source.CurrentAxes.Tag ]);
                % disp(['Title:', event.Source.CurrentAxes.Title.String]);
                % fprintf('Event: %s, State: %d\n', event.EventName, this.State);                
                % fprintf('MousePress, state %d\n', this.State);

                if this.State == LogisticRegression.STATE_IDLE 
                    [x1, y1] = this.workaround_pos(event);

                    x = event.IntersectionPoint(1);
                    y = event.IntersectionPoint(2);
                    %disp(x); disp(y);


                    % Offset from figure position to the above - part of workaround
                    x_offset = x1 - x;
                    y_offset = y1 - y;
                    % disp(this.x_offset); disp(this.y_offset);

                    x = round(x+0.5); y=round(y+0.5);

                    if x1 <= this.Width && 1 <= x && x <= this.Width && 1 <= y && y <= this.Height
                        this.State = LogisticRegression.STATE_DRAWING;

                        % Save offsets
                        this.x_offset = x_offset;
                        this.y_offset = y_offset;

                        % Blacken the hit pixel
                        this.ImageHandle.CData(y,x) = 255;
                        % Turn on the initial pixel
                        this.DigitImage(:) = 0;
                        this.DigitImage(y,x) = 1;
                        %fprintf('New state %d\n', this.State);
                    end
                end

              case 'WindowMouseRelease',

                %fprintf('MouseRelease, state %d\n', this.State);
                if this.State == LogisticRegression.STATE_DRAWING
                    x = round(event.IntersectionPoint(1) + 0.5);
                    y = round(event.IntersectionPoint(2) + 0.5);
                    %disp(x); disp(y);
                    if 1 <= x && x <= this.Width && 1 <= y && y <= this.Height
                        %fprintf('New state %d\n', this.State);
                        this.ImageHandle.CData(y,x) = 255;
                        this.DigitImage(y,x) = 1;
                        imagesc(this.app.UIAxes3,this.DigitImage);
                        colormap(this.app.UIAxes3, 1-gray);
                        try 
                            digit = this.predict;
                            % Update GUI
                            this.app.PredictedDigitEditField.Value = num2str(digit);
                        catch e
                            uialert(this.app.MNISTDigitLearnerUIFigure, ...
                                    'Have you not yet trained your network?',...
                                    'Cannot predict yet.');
                            %disp(e.message);
                        end
                        this.plot_mean_digit;
                    end
                    this.State = LogisticRegression.STATE_IDLE;
                end

              case 'WindowMouseMotion',

                %display(event.HitObject);
                if this.State == LogisticRegression.STATE_DRAWING
                    %fprintf('MouseMotion, state %d\n', this.State);
                    [x, y] = this.workaround_pos(event);
                    %disp(p); disp(x); disp(y);
                    x = x - this.x_offset;
                    y = y - this.y_offset;
                    x = round(x + 0.5); y = round(y+0.5);

                    if 1 <= x && x <= this.Width && 1 <= y && y <= this.Height
                        this.ImageHandle.CData(y,x) = 255;
                        this.DigitImage(y,x) = 1;
                    end
                end
            end
            %fprintf('Exit State: %d\n', this.State);            
        end

        function [x,y] = workaround_pos(this, event)
        %WORKOROUND_POS find Motion event point in image
            src = event.Source;
            cp = src.CurrentPoint;
            %disp(cp);
            %ax = src.CurrentAxes;
            ax = this.app.UIAxes2;
            ap = ax.Position;
            %disp(ap);
            xwin = round(cp(1,1));
            ywin = round(cp(1,2));

            %disp(xwin);disp(ywin);

            p = this.app.UIAxes2.InnerPosition;

            % Translate parent coordinates to axes coordinates
            x = (xwin - p(1)) ./ p(3) .* this.Width;
            y = (p(2) + p(4) - ywin) ./ p(4) .* this.Height;

            %disp(x);disp(y);
        end

        function this = SaveFcn(this, event)
        %SAVEFCN saves app state to file
            if isempty(this.savefile)
                this = this.SaveAsFcn(event);
            else
                this.DoSave;
            end
        end


        function this = SaveAsFcn(this, event)
        %SAVEASFCN saves app state to a selected file
            [file, path] = uiputfile('*.mat',...
                                     'Select a .mat file', 'DigitLearnerData.mat');
            if isequal(file,0)
                disp('User selected Cancel');
            else
                this.savefile = fullfile(path,file);
                %disp(['User selected ', this.savefile]);

                this.DoSave;
            end
        end

        function DoSave(this)
        % DOSAVE prepares saved state and writes to savefile
            saved_state.digits = this.app.DigitPickerListBox.Value;
            saved_state.W = this.W;
            saved_state.losses = this.losses;
            saved_state.eta = this.eta;
            saved_state.NErrors = this.NErrors;
            saved_state.Y = this.Y;
            saved_state.X = this.X;
            saved_state.T = this.T;
            saved_state.epoch = this.epoch;
            saved_state.epoch_max = this.epoch_max;

            % Write the file
            save(this.savefile, 'saved_state');
            uialert(this.app.MNISTDigitLearnerUIFigure, ...
                    ['Saved application training data and trained ' ...
                     'weights.'],...
                    'Saved application data to file');
        end


        function this = LoadFcn(this, event)
        % LOADFCN loads saved state from file
            [file, path] = uigetfile('*.mat',...
                                     'Select a .mat file', 'DigitLearnerData.mat');

            if isequal(file,0)
                disp(['User selected ', fullfile(path,file)]);
                disp('User selected Cancel');
            else
                filepath = fullfile(path,file)
                this = this.loadStateFromFile(filepath);
            end
        end

        function this = loadStateFromFile(this, filepath)
        % TODO: Fix strange state in which GUI ends up after
        % UIGETFILE, by which the tracing window does not respond 
        % properly to a mouse click. The response is 
        %   - changing cursor to 'hand'
        %   - issuing a bunch of MouseMotion events when dragged
            s = load(filepath);
            saved_state = s.saved_state;

            % Restore state
            this.app.DigitPickerListBox.Value = saved_state.digits;
            this.W = saved_state.W;
            this.losses = saved_state.losses;
            this.eta = saved_state.eta;
            this.NErrors = saved_state.NErrors;
            this.X = saved_state.X;
            this.T = saved_state.T;
            this.Y = saved_state.Y;
            this.epoch = saved_state.epoch;
            this.epoch_max = saved_state.epoch_max;
            
            % Update GUI
            this = this.show_sample_digits;
            this = this.show_learning;
            this.plot_confusion;
            uialert(this.app.MNISTDigitLearnerUIFigure, ...
                    ['Loaded saved state, including trained weights ' ...
                     'and training data. You can resume training ' ...
                     'where you left off.'],...
                    'Loaded saved state from file');
        end

    end
end