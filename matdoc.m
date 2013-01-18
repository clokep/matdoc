function matdoc(varargin)
% Generates MATLAB API documentation for a set of MATLAB class definitions.
% Assumes that all functions are on the MATLAB path.
%
% @author Garrett Wampole (gwampole@mitre.org)
% @author Patrick Cloke (pcloke@mitre.org)

    rootOutDir = fullfile('docs', 'matlab');
    
    techdocRoot = sprintf('http://www.mathworks.com/help/releases/R%s/techdoc/ref/', version('-release'));
    
    topics = {};
    for kt = 1:nargin
        arg = varargin{kt};
        
        package = meta.package.fromName(arg);
        if (~isempty(package))
            % ... do stuff ...
            topics = [topics, package2topics(package)]; %#ok<AGROW>
        elseif (exist(arg, 'dir'))
            files = dir(fullfile(arg, '*.m'));
            files = regexprep({files.name}, '\.m$', '');
            topics = [topics, files]; %#ok<AGROW>
        end
    end
    
    processedTopics = {};
    resourceFiles = {};
    for kt = 1:numel(topics)
        topic = topics{kt};

        writeDocumentation(topic);
    end
    
    processedTopics = sort(processedTopics);
%     writeIndex(outFiles);

    function url = writeDocumentation(topic)
    % Generates HTML documentation for the given MATLAB topic.

        if (ismember('/', topic))
            topic = regexprep(topic, '/', '.');
        elseif (ismember('\\', topic))
            topic = regexprep(topic, '\\', '.');
        end
        
        % Calculate the relative URL from the root directory.
        url = [regexprep(topic, '\.', '/'), '.html'];
        
        topicLoc = which(topic);
        if (~isempty(strfind(topicLoc, matlabroot)) || ...
            ~isempty(strfind(topicLoc, 'built-in')))
            % This is a built-in MATLAB function.
            url = [techdocRoot, url];
            return;
        end

        if (ismember(topic, processedTopics))
            % This page has already been generated, nothing to do!
            return;
        end

        fprintf('Processing %s\n', topic);

        % Output files should be in folders.
        outFile = fullfile(rootOutDir, topic2file(topic));

        % XXX use this information to not have links for topics that don't
        % exist.
        % hasDocs = ~isempty(topic);
        html = help2html(topic);

        topicOutDir = fileparts(outFile);
        if (~exist(topicOutDir, 'dir'))
            mkdir(topicOutDir);
        end

        fout = fopen(outFile, 'w');
        fprintf(fout, '%s', html);
        fclose(fout);

        processedTopics = [processedTopics, {topic}];
        writeTopicMembers(outFile, topic);
    end

    function writeTopicMembers(topicDoc, topic)
    % Creates documentation for the members of the given MATLAB topic
    % documentation file.
    %
    % @param topicDoc The MATLAB HTML documentation file.
        % Pattern to match the contents of an href only.
        elemPattern = '(?:<a href="(.*?)">|<link rel="stylesheet" href="(.*?)">)';
        hrefPattern = '(?<=href=")(.*?)(?=">)';
        helpwinPattern = 'matlab:helpwin\(''(.*)''\)';
        helpwinPattern2 = 'matlab:helpwin (.*)';

        d = fileread(topicDoc);

        [matches, splits] = regexp(d, elemPattern, 'match', 'split');

        fout = fopen(topicDoc, 'w');
        fprintf(fout, '%s', splits{1});

        for it = 1:numel(matches)
            [href, hrefSplits] = regexp(matches{it}, hrefPattern, 'tokens', 'split');
            if (~isempty(href))
                href = href{1}{1};
            else
                href = '';
            end
            
            if (~isempty(href))
                helpwinMatcher = regexp(href, helpwinPattern, 'tokens');
                helpwinMatcher2 = regexp(href, helpwinPattern2, 'tokens');

                memberName = [];
                if (~isempty(helpwinMatcher))
                    memberName = helpwinMatcher{1}{1};
                elseif (~isempty(helpwinMatcher2))
                    memberName = helpwinMatcher2{1}{1};
                elseif (strfind(href, 'matlab:') == 1)
                    % Remove the element here.
                elseif (strfind(href, 'file:') == 1)
                    [~, filename, ext] = fileparts(href);
                    filename = [filename, ext]; %#ok<AGROW>
                    if (~ismember(href, resourceFiles))
                        copyfile(href(9:end), fullfile(rootOutDir, filename));
                        resourceFiles = [resourceFiles, {href}]; %#ok<AGROW>
                    end
                    fprintf(fout, '%s%s%s', hrefSplits{1}, ...
                            createRelativeUrl(filename, nnz('.' == topic)), ...
                            hrefSplits{2});
                else
                    error('matdoc:UnexpectedHref', 'Unexpected href: %s', href);
                end

                if (~isempty(memberName))
                    url = writeDocumentation(memberName);
                    httpLoc = strfind(url, 'http:');
                    if (isempty(httpLoc) || httpLoc ~= 1)
                        url = fullfile(rootOutDir, ...
                            createRelativeUrl(url, nnz('.' == topic) + 2));
                    end
                    fprintf(fout, '%s%s%s', hrefSplits{1}, url, hrefSplits{2});
                end
            end

            % Always print the trailing information.
            fprintf(fout, '%s', splits{it + 1});
        end

        fclose(fout);
    end
end

function topics = package2topics(package)
    topics = {};
    for it = 1:numel(package.PackageList)
        subtopics = package2topics(package.PackageList(it));
        topics = [topics, subtopics]; %#ok<AGROW>
    end
    topics = [topics, {package.ClassList.Name}];
    functions = {package.FunctionList.Name};
    for it = 1:numel(functions)
        functions{it} = [package.Name, '.', functions{it}];
    end
    topics = [topics, functions];
end

function url = createRelativeUrl(url, n)
    relUrl = [];
    for it = 1:n
        relUrl = [relUrl, '../']; %#ok<AGROW>
    end
    url = [relUrl, url];
end

function file = topic2file(topic)
    file = [regexprep(topic, '\.', filesep), '.html'];
end
