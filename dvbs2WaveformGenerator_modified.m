classdef (StrictDefaults) dvbs2WaveformGenerator_modified < satcom.internal.dvbs.s2Base
    %dvbs2WaveformGenerator DVB-S2 waveform generator

    %   Copyright 2020-2024 The MathWorks, Inc.

    %#codegen
    properties
        %FECFrame Forward error correction frame format
        FECFrame = "normal"
        %MODCOD Modulation and code rate
        MODCOD = 1
        %DFL Data field length in bits
        DFL = 15928
        %HasPilots Pilot block indicator
        HasPilots = false
    end

    % Public, non-tunable properties
    properties(Nontunable)
        %ScalingMethod Constellation amplitude scaling method
        ScalingMethod (1, 1) string {matlab.system.mustBeMember(ScalingMethod, {'outer radius as 1', 'unit average power'})} = "outer radius as 1"
        %RolloffFactor Rolloff factor for transmit filtering
        RolloffFactor = 0.35
    end

    properties (SetAccess = private, GetAccess = public)
        %MinNumPackets Minimum number of packets to create a data field
        MinNumPackets;
    end

    % Pre-computed constants
    properties(Access = private)
        %pModCodTemp Local copy of MODCOD property
        pModCodTemp
        %pModOrder Modulation order
        pModOrder
        %pCodeRate LDPC code rate (numeric)
        pCodeRate
        %pFECFrameLen FEC frame length
        pFECFrameLen
        %pNumPilotBlks Number of pilot blocks
        pNumPilotBlks
        %pPLFrameLen Physical layer (PL) frame length
        pPLFrameLen
        %pBBHeader Baseband header
        pBBHeader
        %pPLHeader Physical layer header
        pPLHeader
        %pBCHParams BCH encoding parameters (code rate, message length, codeword length)
        pBCHParams
        %pInterleaveInd Interleaver indices
        pInterleaveInd
        %pSyncBits Sync bits in TS/GS packet
        pSyncBits
        %pCodeIdentifier LDPC code identifier (char)
        pCodeIdentifier
        %pCRCConfiguration CRC configuration
        pCRCConfiguration
    end

    % Pre-computed constants
    properties(Access = private, Nontunable)
        %pPLScramSeq Physical layer complex scrambling sequence
        pPLScramSeq
        %pTxFilter Transmit filter object(RRC)
        pTxFilter
        %pGain Filter gain
        pGain
    end

    methods

        function obj = dvbs2WaveformGenerator_modified(varargin)
            %dvbs2WaveformGenerator Class constructor

            % Support name-value pair arguments when constructing object
            fecType = satcom.internal.parseProp('FECFrame', "normal", varargin{:});
            modcod = satcom.internal.parseProp('MODCOD', 1, varargin{:});
            dfl =  satcom.internal.parseProp('DFL', 15928, varargin{:});
            hasPilots = satcom.internal.parseProp('HasPilots', false, varargin{:});

            setProperties(obj, nargin+8, 'FECFrame', fecType, ...
                'MODCOD', modcod, ...
                'DFL', dfl, ...
                'HasPilots',  hasPilots, ...
                varargin{:})
        end

        function set.FECFrame(obj, val)
            propName = 'FECFrame';
            validatestring(val, {'normal', 'short'}, mfilename, 'FECFrame');
            obj.(propName) = "a";
            obj.(propName)= string(val);
        end

        function set.MODCOD(obj, val)
            propName = 'MODCOD';
            validateattributes(val, {'double', 'single', 'uint8'}, ...
                {'real', 'vector', 'integer', 'positive', '<', 29}, ...
                [class(obj) '.' propName], propName);
            temp = val;
            coder.varsize('temp',[256 256],[1 1]);
            obj.(propName) = temp;
        end

        function set.DFL(obj, val)
            propName = 'DFL';
            validateattributes(val, {'double', 'single', 'uint16'}, ...
                {'real', 'vector', 'integer', 'positive'}, ...
                [class(obj) '.' propName], propName);
            temp = val;
            coder.varsize('temp',[256 256],[1 1]);
            obj.(propName) = temp;
        end

        function set.HasPilots(obj, val)
            propName = 'HasPilots';
            validateattributes(val, {'double', 'logical'}, ...
                {'vector', 'binary'}, ...
                [class(obj) '.' propName], propName);
            temp = val;
            coder.varsize('temp',[256 256],[1 1]);
            obj.(propName) = temp;
        end

        function set.RolloffFactor(obj, val)
            propName = 'RolloffFactor';
            validateattributes(val, {'double', 'single'}, ...
                {'real', 'scalar'}, ...
                [class(obj) '.' propName], propName);
            list = cast([0.20 0.25 0.35], 'like', val);
            coder.internal.errorIf(~any(val == list), ...
                'satcom:dvbs2WaveformGenerator:InvalidRolloffFactor');
            obj.(propName) = val;
        end

        function minNumPkts = get.MinNumPackets(obj)
            pktLen = generateUPLength(obj);
            DFLen = scalarExpand(obj.DFL, obj.NumInputStreams);
            if length(DFLen) ~= obj.NumInputStreams || length(pktLen) ~= obj.NumInputStreams
                minNumPkts = zeros(0, obj.NumInputStreams);
            else
                minNumPkts = zeros(1, obj.NumInputStreams);
                for k = 1:numel(DFLen)
                    minNumPkts(k) = floor(double(DFLen(k))/double(pktLen(k)));
                end
            end
        end
    end

    methods(Access = protected)
        function setupImpl(obj, data)
            %setupImpl Perform one-time calculations, such as computing constants

            setupImpl@satcom.internal.dvbs.s2Base(obj)
            if iscell(data)
                dataCell = data;
            else
                dataCell = {data};
            end
            dummyFrameIndex = isEmptyCell(dataCell);
            % Sync Field calculation
            syncFieldLen = 8;
            obj.pSyncBits = zeros(syncFieldLen, obj.NumInputStreams);
            obj.pModCodTemp = scalarExpand(obj.MODCOD,obj.NumInputStreams);
            obj.pModCodTemp(dummyFrameIndex) = 0;
            modCod = obj.pModCodTemp;
            if strcmpi(obj.StreamFormat, 'TS')
                % Sync byte 47 HEX
                obj.pSyncBits = repmat([0 1 0 0 0 1 1 1]',1, obj.NumInputStreams);
            elseif strcmpi(obj.StreamFormat, 'GS') && ~any(obj.UPL == 0)
                for k = 1:obj.NumInputStreams
                    if modCod(k)
                        obj.pSyncBits(:,k) = dataCell{k}(1:syncFieldLen);
                    end
                end
            end
            calculateProcessingParams(obj)
            % PL scrambling sequence generation
            plScrambIntSeq = satcom.internal.dvbs.plScramblingIntegerSequence(coder.const(0));
            %disp(plScrambIntSeq);
            cMap = [1 1j -1 -1j].';
            obj.pPLScramSeq = cMap(plScrambIntSeq+1);
            % CRC configuration
            obj.pCRCConfiguration = crcConfig("Polynomial", [1 1 1 0 1 0 1 0 1]);
            % RRC transmit filter initialization
            obj.pTxFilter = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor', obj.RolloffFactor, ...
                'FilterSpanInSymbols', double(obj.FilterSpanInSymbols), ...
                'OutputSamplesPerSymbol', double(obj.SamplesPerSymbol));
            b = rcosdesign(double(obj.RolloffFactor), double(obj.FilterSpanInSymbols), ...
                double(obj.SamplesPerSymbol));
            % |H(f)| = 1  for |f| < fN(1-alpha) - Section 5.6
            obj.pGain =  1/sum(b);
        end

        function txWaveform = stepImpl(obj, data)
            %stepImpl Specifies the algorithm for DVBS2 waveform generation

            if iscell(data)
                dataCell = data;
            else
                dataCell = {data};
            end
            dummyFrameIndex = isEmptyCell(dataCell);
            if (sum(dummyFrameIndex) > 0 && any(obj.pModCodTemp~=0)) || ...
                    (sum(dummyFrameIndex) == 0 && any(obj.pModCodTemp==0))
                obj.pModCodTemp = scalarExpand(obj.MODCOD,obj.NumInputStreams);
                obj.pModCodTemp(dummyFrameIndex) = 0;
                if strcmpi(obj.StreamFormat, 'GS') && ~any(obj.UPL == 0)
                    for k = 1:obj.NumInputStreams
                        if ~dummyFrameIndex(k)
                            obj.pSyncBits(:,k) = dataCell{k}(1:8);
                        end
                    end
                end
                calculateProcessingParams(obj)
            end
            numStreams = obj.NumInputStreams;
            pktLen = obj.pPktLen;
            plFrameLen = obj.pPLFrameLen;
            cwLen = obj.pFECFrameLen;
            modOrder = obj.pModOrder;
            crStr      =  obj.pCodeIdentifier;
            % Pilot block length is 36 symbols
            numPilots = obj.pNumPilotBlks*36;

            % PL header length is 90 symbols
            plDataFrameLen = obj.pPLFrameLen-90;
            hasPilots = scalarExpand(obj.HasPilots, obj.NumInputStreams);
            [numPktsPerStream, bbFrameLen] = deal(zeros(numStreams, 1));
            pilotIndices = coder.nullcopy(cell(numStreams, 1));
            dataIndices      = coder.nullcopy(cell(numStreams, 1));
            plDataFrame      = coder.nullcopy(cell(numStreams, 1));
            for k = 1:numStreams
                if modOrder(k) ~= 1
                    dataLen = length(dataCell{k});
                    if strcmpi(obj.StreamFormat, 'TS') || obj.pIsGSPkt
                        numPktsPerStream(k) = floor(dataLen/pktLen(k));
                    end
                    bbFrameLen(k) = obj.pBCHParams(k,3);
                    [num, den] = rat(obj.pCodeRate(k));
                    crStr{k} = [sprintf('%0.0f',num) '/' sprintf('%0.0f',den)];
                    if hasPilots(k)
                        pilotIndices{k} = obj.pPilotInd(1:numPilots(k));
                        seq = (1:plDataFrameLen(k))';
                        seq(pilotIndices{k}) = [];
                        dataIndices{k} = seq;
                    end
                end
                

                plDataFrame{k} = complex(zeros(plDataFrameLen(k), 1));
                
        
            end
            unitPower = strcmpi(obj.ScalingMethod, 'Unit average power');

            % Computing CRC for packetized input streams
            crcOut = dataCell;
            if strcmpi(obj.StreamFormat, 'TS') || obj.pIsGSPkt
                for k = 1:numStreams
                    if modOrder(k) ~= 1
                        for i = 1:numPktsPerStream(k)
                            userPkt = dataCell{k}((i-1)*pktLen(k)+9:i*pktLen(k));
                            encOut = crcGenerate(userPkt, obj.pCRCConfiguration);
                            crcOut{k}((i-1)*pktLen(k)+1:i*pktLen(k)) = encOut;
                        end
                    end
                end
            end
            % Data field length calculation
            numFramesPerStream = zeros(numStreams, 1);
            if any(pktLen == 0)
                DFLen = scalarExpand(obj.DFL, numStreams);
                for k = 1:numStreams
                    numFramesPerStream(k) = length(crcOut{k})/DFLen(k);
                end
                rawDFLength = DFLen(:);
            else
                for k = 1:numStreams
                    numFramesPerStream(k) = numPktsPerStream(k)/obj.MinNumPackets(k);
                end
                rawDFLength = pktLen.*obj.MinNumPackets(:);
            end
            % When input data on any stream is given as an empty column
            % vector, a dummy frame is generated. modOrder 1 indicates
            % dummy frame. So, the number of frames on that particular
            % stream is updated as 1.
            numFramesPerStream(modOrder == 1) = 1;
            txFrames = complex(zeros(sum(numFramesPerStream.*plFrameLen),1));
            outEndIdx = 0;
            % Merger indices generation. Supports only round-robin merging
            [streamInd, frameInd] = satcom.internal.dvbs.getMergerIndices( ...
                numStreams, numFramesPerStream);
            totFrames = length(streamInd);
            for m = 1:totFrames
                k = streamInd(m);
                outStIdx = outEndIdx+1;
                outEndIdx = outEndIdx+plFrameLen(k);
                if modOrder(k) == 1 % Dummy PL frame
                    plDataFrame{k} = (1+1j).*ones(90*36,1)/sqrt(2);
                    plDataFrame{k} = plDataFrame{k}.*obj.pPLScramSeq(1:length(plDataFrame{k}));
                    txFrames(outStIdx:outEndIdx) = [obj.pPLHeader(:,k);plDataFrame{k}];
                else
                    % BB Frame generation
                    % DFL generation
                    dataField = cast(crcOut{k}((frameInd(m)-1)*rawDFLength(k)+1:frameInd(m)*rawDFLength(k)), 'int8');
                    tmpOut = [obj.pBBHeader(:,k);dataField;zeros(bbFrameLen(k)-rawDFLength(k)-80,1,'int8')];
                    bbFrame = cast(xor(tmpOut, obj.pBBScrambleSeq(1:bbFrameLen(k))), 'int8');
                    paths = config();
                    savetofile(bbFrame, fullfile(paths.dataDir, 's2_bbscrambler_output'), 2);
                    savetofile(bbFrame, fullfile(paths.dataDir, 's2_bbscrambler_output'), 3);
                    % PL Frame generation
                    % BCH encoding
                    bchOut = satcom.internal.dvbs.bchEncode(bbFrame, bbFrameLen(k), cwLen(k));
                     paths = config();
                    savetofile(bchOut, fullfile(paths.dataDir, 'bch_output'), 2);
                    savetofile(bchOut, fullfile(paths.dataDir, 'bch_output'), 3);


                    % LDPC encoding
                    ldpcOut = satcom.internal.dvbs.ldpcEncode(bchOut, crStr{k}, cwLen(k));
                     paths = config();
                     savetofile(ldpcOut, fullfile(paths.dataDir, 'ldpc_output'), 2);
                    savetofile(ldpcOut, fullfile(paths.dataDir, 'ldpc_output'), 3);

                    % Bit interleaving
                    fecFrame = ldpcOut(obj.pInterleaveInd{k});
                      paths = config();
                    savetofile(fecFrame, fullfile(paths.dataDir, 'bitinterleaver_output'), 2);
                    savetofile(fecFrame, fullfile(paths.dataDir, 'bitinterleaver_output'), 3);


                    % Symbol mapping
                    xFecFrame = satcom.internal.dvbs.mapper(fecFrame, modOrder(k), ...
                        crStr{k}, cwLen(k), unitPower);

                    paths = config();  % Get path structure
                     saveAndConvertComplexToHex(xFecFrame, ...
                        fullfile(paths.dataDir, 's2_symbolmodulator'), ...
                        fullfile(paths.dataDir, 's2_symbolmodulator_hex.txt'));

                    if hasPilots(k)
                        plDataFrame{k}(pilotIndices{k}) = repmat(obj.pPilotSeq, obj.pNumPilotBlks(k), 1);
                        plDataFrame{k}(dataIndices{k}) = xFecFrame;
                    else
                        plDataFrame{k} = xFecFrame;
                    end
                    plDataFrame{k} = plDataFrame{k}.*obj.pPLScramSeq(1:length(plDataFrame{k}));
                    txFrames(outStIdx:outEndIdx) = [obj.pPLHeader(:,k);plDataFrame{k}];
                       
                    disp(obj.pPLHeader);
                     paths = config();  % Get path structure
                     saveAndConvertComplexToHex(txFrames, ...
                            fullfile(paths.dataDir, 's2_plframe'), ...
                            fullfile(paths.dataDir, 's2_plframe_hex.txt'));

                end
            end
            % Transmit pulse shaping
            txWaveform = obj.pTxFilter(txFrames).*obj.pGain;
        end

        function resetImpl(obj)
            %resetImpl Initialize / reset internal or discrete properties

            % Reset the transmit filter
            reset(obj.pTxFilter);
        end

        function releaseImpl(obj)
            %releaseImpl Release resources, such as file handles

            release(obj.pTxFilter);
        end

        % Backup/restore functions
        function s = saveObjectImpl(obj)
            %saveObjectImpl Set properties in structure s to values in object obj

            s = saveObjectImpl@satcom.internal.dvbs.s2Base(obj);
            if isLocked(obj)
                s.pModCodTemp           =  obj.pModCodTemp;
                s.pModOrder             =  obj.pModOrder;
                s.pCodeRate             =  obj.pCodeRate;
                s.pFECFrameLen          =  obj.pFECFrameLen;
                s.pNumPilotBlks         =  obj.pNumPilotBlks;
                s.pPLFrameLen           =  obj.pPLFrameLen;
                s.pBBHeader             =  obj.pBBHeader;
                s.pPLHeader             =  obj.pPLHeader;
                s.pBCHParams            =  obj.pBCHParams;
                s.pInterleaveInd        =  obj.pInterleaveInd;
                s.pSyncBits             =  obj.pSyncBits;
                s.pTxFilter             =  matlab.System.saveObject(obj.pTxFilter);
                s.pPLScramSeq           =  obj.pPLScramSeq;
                s.pGain                 =  obj.pGain;
                s.pCodeIdentifier       =  obj.pCodeIdentifier;
                s.pCRCConfiguration     =  obj.pCRCConfiguration;
            end
        end

        function loadObjectImpl(obj, s, wasLocked)
            %loadObjectImpl Set properties in object obj to values in structure s
            if wasLocked
                obj.pModOrder             =  s.pModOrder;
                obj.pCodeRate             =  s.pCodeRate;
                obj.pFECFrameLen          =  s.pFECFrameLen;
                obj.pNumPilotBlks         =  s.pNumPilotBlks;
                obj.pPLFrameLen           =  s.pPLFrameLen;
                obj.pBBHeader             =  s.pBBHeader;
                obj.pPLHeader             =  s.pPLHeader;
                obj.pBCHParams            =  s.pBCHParams;
                obj.pInterleaveInd        =  s.pInterleaveInd;
                obj.pSyncBits             =  s.pSyncBits;
                obj.pTxFilter             =  matlab.System.loadObject(s.pTxFilter);
                obj.pPLScramSeq           =  s.pPLScramSeq;
                obj.pGain                 =  s.pGain;
                obj.pCodeIdentifier       =  s.pCodeIdentifier;
                if isfield(s, 'pCRCConfiguration')
                    % New property in R2024a
                    obj.pCRCConfiguration =  s.pCRCConfiguration;
                end
            end
            if isfield(s, 'pModCodTemp')
                obj.pModCodTemp           =  s.pModCodTemp;
            end
            % Set public properties and states
            loadObjectImpl@satcom.internal.dvbs.s2Base(obj,s,wasLocked);
        end

        % Advanced functions
        function validateInputsImpl(obj, data)
            %validateInputsImpl Validate inputs to the step method at initialization

            % Input data validation
            if iscell(data)
                dataOut = data;
            else
                dataOut = {data};
            end
            numStreams = numel(dataOut);
            pktLen = generateUPLength(obj);
            coder.internal.errorIf(~(numStreams == obj.NumInputStreams), 'satcom:dvbs2Base:InvalidNumStreams', obj.NumInputStreams);

            minNumPkts = obj.MinNumPackets(:);
            DFLen = scalarExpand(obj.DFL, numStreams);
            if strcmpi(obj.StreamFormat, 'TS')
                inputFormat = 0;
                validLen = minNumPkts;
            elseif strcmpi(obj.StreamFormat, 'GS') && ~any(obj.UPL == 0)
                inputFormat = 1;
                validLen = minNumPkts;
            else
                inputFormat = 2;
                validLen = DFLen;
            end
            for k = 1:numStreams
                satcom.internal.dvbs.validateInputData(dataOut{k}, inputFormat, ...
                    k, validLen(k), pktLen(k), mfilename);
            end
        end

        function validatePropertiesImpl(obj)
            %validatePropertiesImpl Validate related or interdependent
            %property values

            validatePropertiesImpl@satcom.internal.dvbs.s2Base(obj)

            if numel(obj.DFL) ~= 1 && numel(obj.DFL) ~= obj.NumInputStreams
                coder.internal.error('satcom:dvbs2Base:InvalidDFLSize', obj.NumInputStreams);
            end
            if ~isvector(obj.HasPilots) || (numel(obj.HasPilots) ~= 1 && numel(obj.HasPilots) ~= obj.NumInputStreams)
                coder.internal.error('satcom:dvbs2WaveformGenerator:InvalidHasPilotsSize', obj.NumInputStreams);
            end

            validatePLSProperties(obj);
            nDefVal = [16008 21408 25728 32208 38688 43040 48408 51648 53840 57472 ...
                58192 38688 43040 48408 53840 57472 58192 43040 48408 51648 53840 ...
                57472 58192 48408 51648 53840 57472 58192];
            sDefVal = [3072 5232 6312 7032 9552 10632 11712 12432 13152 14232 0 ...
                9552 10632 11712 13152 14232 0 10632 11712 12432 13152 14232 0 11712 ...
                12432 13152 14232 0];
            % BB header length is 80 bits
            maxDFLVal = [nDefVal;sDefVal]-80;
            DFLen = scalarExpand(obj.DFL, obj.NumInputStreams);
            modCod = scalarExpand(obj.MODCOD, obj.NumInputStreams);
            fIndex = 1;
            if strcmpi(obj.FECFrame, 'short')
                fIndex = 2;
            end
            pktSize = generateUPLength(obj);
            for i = 1:numel(DFLen)
                % Maximum DFL value check based on MODCOD
                if modCod(i)
                    if DFLen(i) > maxDFLVal(fIndex, modCod(i))
                        coder.internal.error('satcom:dvbs2Base:InvalidDFLValue', ...
                            DFLen(i), maxDFLVal(fIndex, modCod(i)), i);
                    end
                end
                % Maximum packet length allowed based on DFL
                if pktSize(i) > DFLen(i)
                    coder.internal.error('satcom:dvbs2Base:UPLLessThanOrEqualDFL', ...
                        pktSize(i), DFLen(i), i);
                end
            end
        end

        function validatePLSProperties(obj)
            %validatePLSProperties Validate PLS properties

            if numel(obj.MODCOD) ~= 1 && numel(obj.MODCOD) ~= obj.NumInputStreams
                coder.internal.error('satcom:dvbs2WaveformGenerator:InvalidMODCODSize', obj.NumInputStreams);
            end
            % Inter-dependent validation between MODCOD and FECFRAME
            if strcmpi(obj.FECFrame, 'short')
                for i = 1:numel(obj.MODCOD)
                    if any(obj.MODCOD(i) ==  [11 17 23 28])
                        coder.internal.error('satcom:dvbs2WaveformGenerator:InvalidCodeRate');
                    end
                end
            end
        end

        function processTunedPropertiesImpl(obj)
            %processTunedPropertiesImpl Perform actions when tunable
            %properties change between calls to the System object

            propChanged = isChangedProperty(obj,'MODCOD') || ...
                isChangedProperty(obj,'FECFrame') || isChangedProperty(obj,'DFL') || ...
                isChangedProperty(obj,'HasPilots');
            if propChanged
                obj.pModCodTemp = scalarExpand(obj.MODCOD,obj.NumInputStreams);
                calculateProcessingParams(obj)
            end
        end

        % To support adaptive coding and modulation
        function flag = isInputSizeMutableImpl(~,~)
            %isInputSizeMutableImpl Set whether input size can change
            %between calls to the System object

            flag = true;
        end

        function s = infoImpl(obj)
            %info Returns physical layer information about DVB-S2 waveform
            %generation
            %   S = info(OBJ) returns a structure containing physical layer
            %   parameters, S, about the DVB-S2 waveform generation. A
            %   description of the fields and their values is as follows:
            %
            %   ModulationScheme     - Modulation scheme provided as a
            %                          string scalar for single-input
            %                          stream and cell array of character
            %                          vectors for multi-input stream
            %   LDPCCodeIdentifier   - LDPC code identifier provided as a
            %                          string scalar for single-input
            %                          stream and cell array of character
            %                          vectors for multi-input stream
            numStreams = obj.NumInputStreams;
            modCod = scalarExpand(obj.MODCOD, numStreams);
            if ~isLocked(obj)
                % Inter-dependent validation between MODCOD and FECFRAME
                validatePLSProperties(obj);
            end
            modSchemeCell = cell(1, numStreams);
            codeRateCell = cell(1, numStreams);
            listVal = {'QPSK','8PSK','16APSK','32APSK'};
            for k = 1:numStreams
                [modOrder, cr] = ...
                    satcom.internal.dvbs.getS2PHYParams(modCod(k), obj.FECFrame);
                modSchemeCell{k} = listVal{log2(modOrder)-1};
                [n, d] = rat(cr);
                codeRateCell{k} = [sprintf('%0.0f',n) '/' sprintf('%0.0f',d)];

            end
            if numStreams == 1
                s.ModulationScheme = convertCharsToStrings(modSchemeCell{1});
                s.LDPCCodeIdentifier = convertCharsToStrings(codeRateCell{1});

            else
                s.ModulationScheme = modSchemeCell;
                s.LDPCCodeIdentifier = codeRateCell;
            end
        end

        function flag = isInactivePropertyImpl(obj,prop)
            %isInactivePropertyImpl Return false if property is visible
            %based on object configuration, for the command line

            flag = isInactivePropertyImpl@satcom.internal.dvbs.s2Base(obj, prop);
            if strcmp(prop, 'ScalingMethod')
                flag = all(obj.MODCOD <= 17);
            elseif strcmp(prop, 'MinNumPackets')
                flag = strcmpi(obj.StreamFormat, 'GS') && any(obj.UPL == 0);
            end
        end
    end

    methods(Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            %getPropertyGroupsImpl Specify the property groups for System
            %object display

            group1 = matlab.system.display.Section('PropertyList',{'StreamFormat'; 'NumInputStreams'; 'UPL'; ...
                'FECFrame'; 'MODCOD'; 'DFL'; 'ScalingMethod'; ...
                'HasPilots'; 'RolloffFactor'; 'FilterSpanInSymbols'; ...
                'SamplesPerSymbol'; 'ISSYI'; 'ISCRFormat'});
            numPackets = matlab.system.display.Section(...
                'PropertyList', {'MinNumPackets'});

            readOnlyGroup = matlab.system.display.SectionGroup(...
                'Title', 'Read-only:', ...
                'Sections', numPackets);

            groups = [group1 readOnlyGroup];
        end
    end

    methods (Access = private)
        function calculateProcessingParams(obj)
            numStreams = obj.NumInputStreams;
            [obj.pModOrder, obj.pFECFrameLen, ...
                obj.pNumPilotBlks, obj.pCodeRate, obj.pPLFrameLen, ...
                xFECFrameLen] = deal(zeros(numStreams, 1));
            modCod = obj.pModCodTemp;
            for k = 1:numStreams
                [obj.pModOrder(k), obj.pCodeRate(k), obj.pFECFrameLen(k)] = ...
                    satcom.internal.dvbs.getS2PHYParams(modCod(k),obj.FECFrame);
                bps = log2(obj.pModOrder(k));
                if modCod(k)
                    xFECFrameLen(k) = obj.pFECFrameLen(k)./bps;
                else
                    xFECFrameLen(k) = 36*90;
                end
            end
            bbHeaderLen = 80;
            plHeaderLen = 90;
            hasPilots = scalarExpand(obj.HasPilots, obj.NumInputStreams);
            for k = 1:numStreams
                if hasPilots(k) && modCod(k)
                    % XFECFrame is divided into slots of 90 symbols each.
                    numSlots = xFECFrameLen(k)/90;
                    % Pilot block of length 36 symbols is repeated every 16 slots.
                    obj.pNumPilotBlks(k) = floor(numSlots/16);
                    % Pilots shouldn't coincide with next PL Header
                    if floor(numSlots/16) == numSlots/16
                        obj.pNumPilotBlks(k) = obj.pNumPilotBlks(k)-1;
                    end
                end
                obj.pPLFrameLen(k) = plHeaderLen + xFECFrameLen(k) + obj.pNumPilotBlks(k)*36;
            end
            isVCM = numStreams > 1 && numel(obj.MODCOD) > 1 && ...
                length(obj.MODCOD) == length(unique(obj.MODCOD(:)));
            DFLen = scalarExpand(obj.DFL, obj.NumInputStreams);
            % BBHeader generation and PLHeader generation
            obj.pBBHeader = zeros(bbHeaderLen, numStreams, 'int8');
            obj.pPLHeader = complex(zeros(plHeaderLen, numStreams));
            isSIS = obj.NumInputStreams == 1;
            if strcmpi(obj.StreamFormat, 'TS')
                inputFormat = 0;
            elseif strcmpi(obj.StreamFormat, 'GS') && ~any(obj.UPL == 0)
                inputFormat = 1;
            else
                inputFormat = 2;
            end
            for k = 1:numStreams
                if modCod(k)
                    % inputFormat, pktLen, dfLen, isSIS, isVCM, rollOffFac, ISSYI, syncBits, streamIdx
                    obj.pBBHeader(:,k) =  satcom.internal.dvbs.bbHeader(inputFormat, ...
                        obj.pPktLen(k), DFLen(k), isSIS, isVCM, obj.RolloffFactor, ...
                        obj.ISSYI, obj.pSyncBits(:,k), k-1);
                end
                obj.pPLHeader(:,k) = satcom.internal.dvbs.plHeader(coder.const('s2'), ...
                    modCod(k), hasPilots(k), obj.pFECFrameLen(k));
            end
            obj.pBCHParams = zeros(numStreams, 3);
            for k = 1:numStreams
                if modCod(k)
                    obj.pBCHParams(k,1) = obj.pCodeRate(k);
                    [obj.pBCHParams(k,2), obj.pBCHParams(k,3)] = ...
                        satcom.internal.dvbs.getBCHParams(obj.pFECFrameLen(k), obj.pCodeRate(k));
                end
            end
            obj.pInterleaveInd = coder.nullcopy(cell(numStreams, 1));
            obj.pCodeIdentifier  = coder.nullcopy(cell(numStreams, 1));
            for k = 1:numStreams
                if modCod(k)
                    [n, d] = rat(obj.pCodeRate(k));
                    obj.pCodeIdentifier{k} = [sprintf('%0.0f',n) '/' sprintf('%0.0f',d)];
                    obj.pInterleaveInd{k} = satcom.internal.dvbs.interleaverIndices( ...
                        obj.pFECFrameLen(k), obj.pCodeIdentifier{k}, obj.pModOrder(k));
                end
            end
        end
    end

    methods % Public
        function out = flushFilter(obj)
            %flushFilter Flush the transmit filter
            %
            %   OUT = flushFilter(OBJ) passes zeroes through the transmit
            %   filter in the DVB-S2 waveform generator to flush the data
            %   samples remaining in the filter state. This method must be
            %   used after the step method. The number of zeros passed
            %   depends on the filter delay.
            data = complex(zeros(obj.FilterSpanInSymbols, 1));
            out = obj.pTxFilter(data).*obj.pGain;
        end
    end
end

function y = scalarExpand(x,cnt)
%scalarExpand Performs scalar expansion
if isscalar(x) && cnt > 1
    y = double(x(1)).*ones(cnt,1);
else
    y = double(x(:));
end

end

function y = isEmptyCell(x)
%isEmptyCell Specifies if the cell array element is empty
y = false(length(x),1);
for n = 1:length(x)
    y(n) = isempty(x{n});
end
end