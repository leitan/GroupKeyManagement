%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% File: runSim.m
% Author: Christopher Wood, caw4567@rit.edu
% Description: Monte carlo simulation for the key distribution times
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Simulation parameters
numSamples = 1; %1000 or 10000 for proper results 
maxChildren = 2;
numNodes = [5]; %,10,15,20,25,30]; % return after the thing is working!
authProbabilities = [1]; %[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0];
keyProbabilities = [1]; %[0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0];
[~, numSims] = size(numNodes);
[~, numAuthProbs] = size(authProbabilities);
[~, numKeyProbs] = size(keyProbabilities);

% Result containers
times = zeros(numAuthProbs, numKeyProbs, numSims,numSamples); 
avgTimes = zeros(numAuthProbs, numKeyProbs, numSims);
finalTable = zeros(numAuthProbs, numKeyProbs, numSims, 4);

% Each epoch will be of size t2, and t1 = 4*t2 (it's about 4 times longer)
kMult = 4;

% Run the simulation nSamples times
disp('Starting the simulation...');
totalTime = 0;
for pAuthIndex = 1:numAuthProbs
    for pKeyIndex = 1:numKeyProbs
        for n = 1:numSims
            for i = 1:numSamples
                % Initialize the adj. matrix representation for the nodes and network
                % No one is connected at the beginning...
                time = 0; % time = #t2 events
                nConnected = 0;

                % The matrix to store authentication steps in time.
                authMatrix = zeros(kMult, numNodes(n), numNodes(n));

                % The adjacency matrix stores those nodes node connections (the
                % tree).
                aMatrix = zeros(numNodes(n), numNodes(n));
                % TODO: isn't aMatrix redundant with the above and below?

                % The connected vector that indicates whether a node has
                % the key (it is connected).
                cMatrix = zeros(numNodes(n));

                % Populate the adjacency matrix and children matrix.
                %for r = 1:numNodes(n)
                %    cMatrix(r) = 0;
                %    for c = 1:numNodes(n)
                %        aMatrix(r,c) = 0;
                %    end
                %end

                % Set the root node to have the key at time 0
                cMatrix(1) = 1;

                % Loop while we do try to establish a connection with each node
                while (nConnected < (numNodes(n) - 1)) % We go until connected == (n-1)
                    % Loop through the pipeline
                    for k = 1:kMult
                        % Find the unconnected nodes from the connected list
                        tempList = zeros(numNodes(n));
                        tempListBack = zeros(numNodes(n));
                        nUnconnected = 0;
                        for j = 1:numNodes(n)
                            tempList(j) = -1; % mark as invalid to start...
                            if (cMatrix(j) == 0)
                                nUnconnected = nUnconnected + 1;
                                tempList(nUnconnected) = j; % Flag as unconnected
                                tempListBack(j) = nUnconnected; % Mark back pointer
                                disp('adding because not in connected vector')
                                disp(j)
                            end
                        end

                        % Strip out all nodes that are currently in 
                        % authentication stage.
                        for kIndex = 1:kMult
                           for rIndex = 1:numNodes(n)
                              for cIndex = 1:numNodes(n)
                                 if (authMatrix(kIndex, rIndex, cIndex) == 1)
                                    % cIndex is being authenticated by rIndex,
                                    % so take out cIndex from the list if it's
                                    % in there.
                                    disp('taking stuff out from auth matrix')
                                    disp(cIndex)
                                    tempIndex = tempListBack(cIndex);
                                    tempList(tempIndex) = -1; % mark as invalid so it can be omitted down below
                                    nUnconnected = nUnconnected - 1; % decrement since we took it out of the list
                                 end
                              end
                           end
                        end

                        % Build up the unconnected list
                        unconnected = zeros(1, nUnconnected);
                        tempIndex = 1;
                        for j = 1:nUnconnected
                            if (tempList(tempIndex) ~= -1)
                                unconnected(j) = tempList(tempIndex);
                                tempIndex = tempIndex + 1;
                            else
                                % Search for the next item in our list that is
                                % connected.
                                while (tempList(tempIndex) == -1)
                                    tempIndex = tempIndex + 1;
                                end
                                tempIndex = tempIndex + 1;
                            end
                        end
                        
                        % Debug
                        %display(unconnected);

                        % For each node that is ready, decide with probability p
                        % if it should receive the key at this instance in time.
                        readyList = zeros(1, nUnconnected);
                        nReady = 0;
                        for j = 1:nUnconnected
                            if (rand(1) < authProbabilities(pAuthIndex))
                                readyList(j) = 1; % Flag it as ready for authentication
                                nReady = nReady + 1;
                            end
                        end

                        % Compute the set of available parents at this iteration
                        [parentList, parentCount] = readyParents(aMatrix, cMatrix, maxChildren, numNodes(n));

                        % Shuffle algorithm
                        for j = parentCount:-1:1
                            index = randi(j,1);
                            temp = parentList(index);
                            parentList(index) = parentList(j);
                            parentList(j) = temp;
                        end
                        
                        disp('Unconnected')
                        disp(unconnected)
                        disp('Ready')
                        disp(readyList)
                        
                        % TODO: need to advance time for every one of these
                        % k-steps below? Or no...
                        
                        % Now check to see if the nodes doing
                        % authentication march forwards in time
                        for kIndex = 2:(kMult - 1)
                            for rIndex = 1:numNodes(n)
                               for cIndex = 1:numNodes(n)
                                  % If a pair of nodes is attempting
                                  % authentcation, check to see if they
                                  % make progress
                                  if (authMatrix(kIndex, rIndex, cIndex) == 1)
                                      % Shift these guys over in time (to
                                      % the next k-stage)
                                      if (rand(1) < authProbabilities(pAuthIndex))
                                          authMatrix(kIndex + 1, rIndex, cIndex) = 1;
                                          authMatrix(kIndex, rIndex, cIndex) = 0;
                                      end
                                  end
                               end
                            end
                        end
                        
                        % Now handle the last guys who want to do a key
                        % exchange
                        for rIndex = 1:numNodes(n)
                           for cIndex = 1:numNodes(n)
                              if (authMatrix(kMult, rIndex, cIndex) == 1)
                                  % A connection exists, use the key
                                  % probability to see if the key
                                  % connection is passed along...
                                  if (rand(1) < authProbabilities(pKeyIndex))
                                      authMatrix(kMult, rIndex, cIndex) = 0;
                                      aMatrix(rIndex, cIndex) = 1;
                                      aMatrix(cIndex, rIndex) = 1;
                                      cMatrix(cIndex) = 1;
                                      nConnected = nConnected + 1;
                                  end
                              end
                           end
                        end
                        
                        disp('Authentication matrix')
                        disp(authMatrix)
                        
                        % Find upper bound on connections
                        bound = min(parentCount, nReady);
                        disp(bound)
                        
                        % Start these nodes off in the authentication step
                        readyIndex = 1;
                        for j = 1:bound
                            % Skip over nodes that were deemed not ready
                            while (readyList(readyIndex) == 0)
                                readyIndex = readyIndex + 1;
                            end

                            % Hook these guys into the auth matrix
                            child = unconnected(readyIndex);
                            parent = parentList(j);
                            disp('Adding element to authMatrix')
                            authMatrix(1, parent, child) = 1; % this is a directed graph, so don't point from child->parent
                            readyIndex = readyIndex + 1;
                            
                            % 
                            %aMatrix(child, parent) = 1;
                            %aMatrix(parent, child) = 1;
                            %cMatrix(child) = 1;
                            %nConnected = nConnected + 1;
                            %readyIndex = readyIndex + 1;
                        end
                        
                        %{

                        % Make the connections between ready children and available
                        % parents
                        readyIndex = 1;
                        for j = 1:bound
                            % Skip over nodes that were deemed not ready
                            while (readyList(readyIndex) == 0)
                                readyIndex = readyIndex + 1;
                            end

                            % Tie these guys together
                            %disp('connecting...');
                            child = unconnected(readyIndex);
                            parent = parentList(j);
                            aMatrix(child, parent) = 1;
                            aMatrix(parent, child) = 1;
                            cMatrix(child) = 1;
                            nConnected = nConnected + 1;
                            readyIndex = readyIndex + 1;
                        end

                        % Increment the time variable
                        time = time + 1;

                        %}
                        
                        time = time + 1;
                    end

                    % - Check for nodes to gain new parents
                    % - Loop through 1:(kMult - 1), advancing each connection to the
                    % next time if it's successful (with given probability p)
                    % - For kMult, we check to see if it succeeds, and then it
                    % advances to the next stage
                end

                totalTime = totalTime + time;
                times(pAuthIndex,pKeyIndex,n,i) = time;
            end

            avgTimes(pAuthIndex,pKeyIndex,n) = totalTime / numSamples;
        end
    end
end

% Calculate the average and standard deviation for each node simulation
for pAuthIndex = 1:numAuthProbs
    for pKeyIndex = 1:numKeyProbs
        for i = 1:numSims
            avg = mean(times(pAuthIndex, pKeyIndex, i,:));
            stddev = std(times(pAuthIndex, pKeyIndex, i,:));
            stderr = 2 * (stddev / (numSamples^(1/2)));
            finalTable(pAuthIndex,pKeyIndex,i,1) = numNodes(i);
            finalTable(pAuthIndex,pKeyIndex,i,2) = avg;
            finalTable(pAuthIndex,pKeyIndex,i,3) = stddev;
            finalTable(pAuthIndex,pKeyIndex,i,4) = stderr;
        end
    end
end

% Display the average times table
disp(avgTimes);

% Display the final table
disp(finalTable);
